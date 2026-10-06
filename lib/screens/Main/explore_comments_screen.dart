import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/explore_service.dart';

Future<String?> chooseExploreReport(BuildContext context) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(child: ListView(shrinkWrap: true, children: [
    const ListTile(title: Text('Report to NaijaGo', style: TextStyle(fontWeight: FontWeight.bold))),
    for (final entry in {'spam':'Spam or scam','misleading':'Misleading product or ad','inappropriate':'Inappropriate content','harassment':'Harassment or hate','rights':'Copyright or image rights','other':'Something else'}.entries)
      ListTile(title: Text(entry.value), onTap: () => Navigator.pop(context, entry.key)),
  ])),
);

class ExploreCommentsScreen extends StatelessWidget {
  const ExploreCommentsScreen({super.key, required this.type, required this.itemId, this.parentId, this.title = 'Conversation'});
  final String type;
  final String itemId;
  final String? parentId;
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: _ExploreCommentsPanel(videoId: itemId, onCountChanged: (_) {}),
  );
}

Future<void> showExploreCommentsSheet(BuildContext context, {required String videoId, required String itemTitle, required ValueChanged<int> onCountChanged}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * .78,
      child: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Row(children: [
          const Icon(Icons.storefront_outlined), const SizedBox(width: 8),
          Expanded(child: Text('Comments · $itemTitle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17), overflow: TextOverflow.ellipsis)),
        ])),
        Expanded(child: _ExploreCommentsPanel(videoId: videoId, onCountChanged: onCountChanged)),
      ])),
    ),
  );
}

class _ExploreCommentsPanel extends StatefulWidget {
  const _ExploreCommentsPanel({required this.videoId, required this.onCountChanged});
  final String videoId;
  final ValueChanged<int> onCountChanged;
  @override
  State<_ExploreCommentsPanel> createState() => _ExploreCommentsPanelState();
}

class _ExploreCommentsPanelState extends State<_ExploreCommentsPanel> {
  final _service = ExploreService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _sending = false;
  String? _error;
  int _total = 0;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }
  @override
  void dispose() { _scrollController.dispose(); _controller.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.position.extentAfter < 240) _loadMore();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final page = await _service.fetchCommentsPage(widget.videoId, limit: 50);
      if (mounted) setState(() { _comments = page.items; _total = page.total; _page = page.page; _hasMore = page.hasMore; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = _message(error); _loading = false; });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() { _sending = true; _error = null; });
    try {
      final result = await _service.addComment(widget.videoId, text);
      final comment = Map<String, dynamic>.from(result['comment'] as Map);
      final count = (result['commentsCount'] as num?)?.toInt() ?? _total + 1;
      if (mounted) {
        setState(() { _comments = [comment, ..._comments]; _total = count; _controller.clear(); });
        widget.onCountChanged(count);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _service.fetchCommentsPage(widget.videoId, page: _page + 1, limit: 50);
      if (!mounted) return;
      setState(() { _comments = [..._comments, ...next.items]; _page = next.page; _hasMore = next.hasMore; _total = next.total; _loadingMore = false; });
    } catch (error) {
      if (mounted) setState(() { _loadingMore = false; _error = _message(error); });
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await _service.deleteComment(widget.videoId, comment['id'].toString());
      final count = (response['commentsCount'] as num?)?.toInt() ?? (_total - 1).clamp(0, _total).toInt();
      if (!mounted) return;
      setState(() { _comments.removeWhere((item) => item['id'] == comment['id']); _total = count; });
      widget.onCountChanged(count);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  String _message(Object error) => error.toString().replaceFirst('Exception: ', '');
  String _timestamp(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    return date == null ? '' : DateFormat('d MMM, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Expanded(child: _loading
      ? const Center(child: CircularProgressIndicator())
      : _error != null && _comments.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), TextButton(onPressed: _load, child: const Text('Try again'))])))
          : _comments.isEmpty
              ? const Center(child: Text('No comments yet. Start the conversation.'))
              : ListView.builder(controller: _scrollController, itemCount: _comments.length + (_loadingMore ? 1 : 0), itemBuilder: (context, index) {
                  if (index >= _comments.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  final comment = _comments[index];
                  final user = comment['user'] is Map ? Map<String, dynamic>.from(comment['user']) : <String, dynamic>{};
                  final avatar = user['avatarUrl']?.toString();
                  return ListTile(
                    leading: CircleAvatar(backgroundImage: avatar == null ? null : NetworkImage(avatar), child: avatar == null ? const Icon(Icons.person_outline) : null),
                    title: Row(children: [Expanded(child: Text(user['name']?.toString() ?? 'NaijaGo user', style: const TextStyle(fontWeight: FontWeight.w700))), Text(_timestamp(comment['createdAt']), style: Theme.of(context).textTheme.bodySmall)]),
                    subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(comment['text']?.toString() ?? '')),
                    trailing: comment['isMine'] == true
                        ? IconButton(tooltip: 'Delete your comment', onPressed: () => _deleteComment(comment), icon: const Icon(Icons.delete_outline))
                        : null,
                  );
                })),
    if (_error != null && _comments.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
    SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 12, 10), child: Row(children: [
      Expanded(child: TextField(controller: _controller, maxLength: 1000, minLines: 1, maxLines: 3, enabled: !_sending, decoration: const InputDecoration(counterText: '', hintText: 'Add a comment', border: OutlineInputBorder(), isDense: true), onSubmitted: (_) => _send())),
      const SizedBox(width: 8), IconButton(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
    ]))),
  ]);
}
