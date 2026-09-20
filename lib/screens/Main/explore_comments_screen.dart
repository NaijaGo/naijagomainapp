import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../services/explore_service.dart';

Future<String?> chooseExploreReport(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Report to NaijaGo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final entry in {
              'spam': 'Spam or scam',
              'misleading': 'Misleading product or ad',
              'inappropriate': 'Inappropriate content',
              'harassment': 'Harassment or hate',
              'rights': 'Copyright or image rights',
              'other': 'Something else',
            }.entries)
              ListTile(
                title: Text(entry.value),
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );

class ExploreCommentsScreen extends StatefulWidget {
  const ExploreCommentsScreen({
    super.key,
    required this.type,
    required this.itemId,
    this.parentId,
    this.title = 'Conversation',
    this.service,
  });
  final String type;
  final String itemId;
  final String? parentId;
  final String title;
  final ExploreService? service;
  @override
  State<ExploreCommentsScreen> createState() => _ExploreCommentsScreenState();
}

class _ExploreCommentsScreenState extends State<ExploreCommentsScreen> {
  late final ExploreService _service = widget.service ?? ExploreService();
  final _text = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  String? _cursor;
  String? _parentBody;
  String? _error;
  String? _requestId;
  String? _requestBody;
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;
  int _loadVersion = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loadingMore || _cursor == null)) return;
    final version = more ? _loadVersion : ++_loadVersion;
    setState(() {
      _loading = !more;
      _loadingMore = more;
      _error = null;
    });
    try {
      final data = await _service.request(
        'items/${widget.type}/${widget.itemId}/comments',
        query: {
          if (widget.parentId != null) 'parent': widget.parentId!,
          if (more) 'before': _cursor!,
        },
      );
      if (!mounted || version != _loadVersion) return;
      final rows = (data['comments'] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      setState(() {
        _comments = more ? [..._comments, ...rows] : rows;
        _cursor = data['nextCursor'] as String?;
        _parentBody = (data['parentComment'] as Map?)?['body']?.toString();
      });
    } catch (error) {
      if (mounted && version == _loadVersion)
        setState(() => _error = error.toString());
    } finally {
      if (mounted && version == _loadVersion)
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
    }
  }

  void _message(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (_sending || body.isEmpty) return;
    setState(() => _sending = true);
    try {
      final config = await _service.config();
      final version = config['policyVersion']?.toString();
      if (version == null || config['enabled'] != true)
        throw const ExploreException('Explore is currently unavailable.');
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (preferences.getString('explore_guidelines') != version) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keep Explore welcoming'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final rule in config['guidelines'] as List? ?? [])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(rule.toString()),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('I agree'),
              ),
            ],
          ),
        );
        if (accepted != true) return;
        await preferences.setString('explore_guidelines', version);
      }
      // Keep this key after a timeout so retry cannot post the same comment twice.
      if (_requestBody != body) {
        _requestId = const Uuid().v4();
        _requestBody = body;
      }
      await _service.request(
        'items/${widget.type}/${widget.itemId}/comments',
        method: 'POST',
        body: {
          'body': body,
          'clientRequestId': _requestId,
          'policyVersion': version,
          if (widget.parentId != null) 'parent': widget.parentId,
        },
      );
      if (!mounted) return;
      if (_text.text.trim() == body) _text.clear();
      _requestBody = null;
      _requestId = null;
      await _load();
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _action(String action, Map<String, dynamic> row) async {
    try {
      if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove your comment?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await _service.request('comments/${row['id']}', method: 'DELETE');
      } else if (action == 'report') {
        final reason = await chooseExploreReport(context);
        if (reason == null) return;
        await _service.request(
          'reports',
          method: 'POST',
          body: {
            'targetType': 'comment',
            'target': row['id'],
            'reason': reason,
          },
        );
        _message('Report sent to NaijaGo.');
        return;
      } else if (action == 'block' && row['authorId'] != null) {
        await _service.request('blocks/${row['authorId']}', method: 'PUT');
        _message('Account blocked. Manage blocked accounts from Explore.');
      }
      if (mounted) await _load();
    } catch (error) {
      _message(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FB),
    appBar: AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (_parentBody != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: const Color(0xFFEAF0FF),
              child: Text(
                _parentBody!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: _comments.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _comments.length)
                          return _cursor != null
                              ? TextButton(
                                  onPressed: _loadingMore
                                      ? null
                                      : () => _load(more: true),
                                  child: Text(
                                    _loadingMore
                                        ? 'Loading...'
                                        : 'More comments',
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _comments.isEmpty
                                        ? 'Start a helpful conversation about this product.'
                                        : 'You are all caught up.',
                                    textAlign: TextAlign.center,
                                  ),
                                );
                        final row = _comments[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 16,
                                      child: Icon(
                                        Icons.person_outline,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        row['authorName']?.toString() ??
                                            'NaijaGo member',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (row['isVendor'] == true)
                                      const Chip(
                                        label: Text('Seller'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    PopupMenuButton<String>(
                                      onSelected: (action) =>
                                          _action(action, row),
                                      itemBuilder: (_) => [
                                        if (row['isMine'] == true)
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Remove comment'),
                                          ),
                                        if (row['isMine'] != true) ...[
                                          const PopupMenuItem(
                                            value: 'report',
                                            child: Text('Report'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'block',
                                            child: Text('Block account'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SelectableText(row['body']?.toString() ?? ''),
                                if (widget.parentId == null)
                                  TextButton.icon(
                                    icon: const Icon(Icons.reply, size: 18),
                                    label: Text(
                                      'Reply (${row['replies'] ?? 0})',
                                    ),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ExploreCommentsScreen(
                                            type: widget.type,
                                            itemId: widget.itemId,
                                            parentId: row['id'].toString(),
                                            title: 'Replies',
                                          ),
                                        ),
                                      );
                                      if (mounted) _load();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: widget.parentId == null
                          ? 'Ask about this product...'
                          : 'Write a reply...',
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  tooltip: 'Send',
                  icon: Icon(_sending ? Icons.hourglass_top : Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
