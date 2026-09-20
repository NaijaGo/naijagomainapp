import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/explore_service.dart';
import '../../widgets/product_video_section.dart';
import 'explore_comments_screen.dart';
import 'home_screen.dart' show ProductService, SearchScreen;
import 'product_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.service});
  final ExploreService? service;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final _service = widget.service ?? ExploreService();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _campaigns = [];
  String? _cursor;
  String? _error;
  bool _loading = true;
  bool _more = false;
  int _generation = 0;
  Duration _serverOffset = Duration.zero;
  Timer? _expiryTimer;
  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.extentAfter < 500 &&
          !_loading &&
          !_more &&
          _cursor != null)
        _load(more: true);
    });
    _expiryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _campaigns.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _scroll.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_more || _cursor == null)) return;
    final generation = more ? _generation : ++_generation;
    setState(() {
      _loading = !more;
      _more = more;
      _error = null;
    });
    try {
      final data = await _service.request(
        'feed',
        query: {if (more) 'before': _cursor!, 'limit': '20'},
      );
      if (!mounted || generation != _generation) return;
      final rows = (data['items'] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      setState(() {
        _items = more ? [..._items, ...rows] : rows;
        if (!more)
          _campaigns = (data['campaigns'] as List? ?? [])
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
        _cursor = data['nextCursor'] as String?;
        final serverTime = DateTime.tryParse(
          data['serverTime']?.toString() ?? '',
        );
        if (serverTime != null)
          _serverOffset = serverTime.difference(DateTime.now());
      });
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() => _error = error.toString());
    } finally {
      if (mounted && generation == _generation)
        setState(() {
          _loading = false;
          _more = false;
        });
    }
  }

  Future<void> _blocks() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExploreBlocksScreen()),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final current = DateTime.now().add(_serverOffset);
    final activeAds = _campaigns
        .where(
          (ad) =>
              DateTime.tryParse(
                ad['expiresAt']?.toString() ?? '',
              )?.isAfter(current) ==
              true,
        )
        .toList();
    return ColoredBox(
      color: const Color(0xFFF2F5FA),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover something you love',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Real shops. Fresh finds. Good conversations.',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _blocks,
                  tooltip: 'Blocked accounts',
                  icon: const Icon(Icons.manage_accounts_outlined),
                ),
              ],
            ),
          ),
          if (activeAds.isNotEmpty)
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: activeAds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final ad = activeAds[index];
                  final media = ad['media'] as Map? ?? {};
                  return SizedBox(
                    width: 250,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Sponsored discovery'),
                              ),
                              body: SingleChildScrollView(
                                child: ExploreFeedCard(
                                  item: ad,
                                  service: _service,
                                  onBlocked: () {
                                    Navigator.pop(context);
                                    _load();
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _exploreImage(media['posterUrl'] ?? media['url']),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 7,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'Sponsored',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            if (media['kind'] == 'video')
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 9,
                              child: Text(
                                ad['title']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Text(_error!, maxLines: 3)),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _items.length)
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: _more
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _cursor != null
                                ? TextButton(
                                    onPressed: () => _load(more: true),
                                    child: const Text('Discover more'),
                                  )
                                : Text(
                                    _items.isEmpty
                                        ? 'New discoveries will appear here when products are available.'
                                        : 'You are all caught up. Pull down for fresh discoveries.',
                                    textAlign: TextAlign.center,
                                  ),
                          );
                        final item = _items[index];
                        return ExploreFeedCard(
                          key: ValueKey('${item['type']}:${item['id']}'),
                          item: item,
                          service: _service,
                          onBlocked: _load,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

Widget _exploreImage(dynamic raw) {
  final url = raw?.toString() ?? '';
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https')
    return const ColoredBox(
      color: Color(0xFFE8EDF5),
      child: Center(child: Icon(Icons.image_outlined, size: 48)),
    );
  return Image.network(
    url,
    fit: BoxFit.cover,
    loadingBuilder: (_, child, progress) =>
        progress == null ? child : const ColoredBox(color: Color(0xFFE8EDF5)),
    errorBuilder: (_, __, ___) => const ColoredBox(
      color: Color(0xFFE8EDF5),
      child: Center(child: Icon(Icons.broken_image_outlined)),
    ),
  );
}

class ExploreFeedCard extends StatefulWidget {
  const ExploreFeedCard({
    super.key,
    required this.item,
    required this.service,
    required this.onBlocked,
  });
  final Map<String, dynamic> item;
  final ExploreService service;
  final VoidCallback onBlocked;
  @override
  State<ExploreFeedCard> createState() => _ExploreFeedCardState();
}

class _ExploreFeedCardState extends State<ExploreFeedCard> {
  bool _busy = false;
  bool _opening = false;
  String get _path => 'items/${widget.item['type']}/${widget.item['id']}';
  void _message(Object error) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _react(String reaction) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.service.request(
        '$_path/reaction',
        method: 'PUT',
        body: {
          'reaction': widget.item['myReaction'] == reaction ? null : reaction,
        },
      );
      if (mounted) setState(() => widget.item.addAll(result));
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      // Recheck availability before following a cached campaign destination.
      await widget.service.request(_path);
      if (!mounted) return;
      final action = widget.item['action'] as Map? ?? {};
      final value = action['value']?.toString() ?? '';
      switch (action['type']) {
        case 'product':
          final product = await ProductService()
              .fetchProductById(value)
              .timeout(const Duration(seconds: 20));
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                product: product,
                heroTag: 'explore-$value',
              ),
            ),
          );
          break;
        case 'vendor':
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchScreen(
                initialQuery: '',
                vendorId: value,
                vendorName: widget.item['sellerName']?.toString(),
              ),
            ),
          );
          break;
        case 'category':
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchScreen(initialQuery: value),
            ),
          );
          break;
        case 'external':
          final uri = Uri.tryParse(value);
          if (uri == null ||
              uri.scheme != 'https' ||
              uri.userInfo.isNotEmpty ||
              !await launchUrl(uri, mode: LaunchMode.externalApplication))
            throw const ExploreException('Unable to open this link.');
          break;
        default:
          _message('Ask a question in the comments to learn more.');
      }
    } catch (error) {
      _message(
        error is ExploreException
            ? error
            : 'Unable to open this listing. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _watch() async {
    if (_opening) return;
    final media = widget.item['media'] as Map? ?? {};
    if (media['kind'] != 'video') {
      await _open();
      return;
    }
    setState(() => _opening = true);
    try {
      final elapsed = Stopwatch()..start();
      final view = await widget.service.request('$_path/views', method: 'POST');
      final freshMedia = view['media'] as Map? ?? {};
      if (freshMedia['kind'] != 'video') {
        throw const ExploreException('This video is no longer available.');
      }
      final remaining = (view['expiresInMilliseconds'] as num?)?.toInt();
      final expiresAfter = remaining == null
          ? null
          : Duration(milliseconds: remaining - elapsed.elapsedMilliseconds);
      if (expiresAfter != null && expiresAfter <= Duration.zero) {
        throw const ExploreException('This promotion has ended.');
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductVideoPlayer(
            url: freshMedia['url']?.toString() ?? '',
            expiresAfter: expiresAfter,
            onQualifiedWatch: (milliseconds) async {
              if (view['viewId'] == null || view['counted'] == true) return;
              try {
                await widget.service.request(
                  'views/${view['viewId']}/complete',
                  method: 'POST',
                  body: {'watchedMilliseconds': milliseconds},
                );
                await _refreshStats();
              } catch (_) {
                /* Metrics must never interrupt playback or fabricate a count. */
              }
            },
          ),
        ),
      );
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _refreshStats() async {
    try {
      final result = await widget.service.request(_path);
      if (mounted) setState(() => widget.item.addAll(result));
    } catch (_) {
      // Keep the last confirmed counts; the next feed refresh can try again.
    }
  }

  Future<void> _menu(String action) async {
    try {
      if (action == 'report') {
        final reason = await chooseExploreReport(context);
        if (reason == null) return;
        await widget.service.request(
          'reports',
          method: 'POST',
          body: {
            'targetType': widget.item['type'],
            'target': widget.item['id'],
            'reason': reason,
          },
        );
        _message('Report sent to NaijaGo.');
      } else if (action == 'block') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hide this account from Explore?'),
            content: const Text(
              'Their posts and comments will be hidden. Your orders are not affected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Block'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await widget.service.request(
          'blocks/${widget.item['vendorId']}',
          method: 'PUT',
        );
        if (mounted) widget.onBlocked();
      }
    } catch (error) {
      _message(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final media = item['media'] as Map? ?? {};
    final counts = item['reactions'] as Map? ?? {};
    final price = item['price'];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(left: 14, right: 4),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEAF0FF),
              child: Icon(Icons.storefront, color: Color(0xFF4169E1)),
            ),
            title: Text(
              item['sellerName']?.toString() ?? 'NaijaGo',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              item['sponsored'] == true ? 'Sponsored' : 'Shop this discovery',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: _menu,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'report', child: Text('Report')),
                if (item['vendorId'] != null)
                  const PopupMenuItem(
                    value: 'block',
                    child: Text('Block account'),
                  ),
              ],
            ),
          ),
          InkWell(
            onTap: _watch,
            child: AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _exploreImage(media['posterUrl'] ?? media['url']),
                  if (media['kind'] == 'video') ...[
                    const Center(
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.black54,
                        child: Icon(
                          Icons.play_arrow,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Chip(
                        avatar: const Icon(Icons.visibility_outlined, size: 16),
                        label: Text('${item['views'] ?? 0} watches'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
            child: Text(
              item['title']?.toString() ?? '',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text(
              item['caption']?.toString() ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.blueGrey, height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: price is num
                      ? Text(
                          NumberFormat.currency(
                            locale: 'en_NG',
                            symbol: '₦',
                            decimalDigits: 0,
                          ).format(price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Color(0xFF163B7A),
                          ),
                        )
                      : const SizedBox(),
                ),
                TextButton(
                  onPressed: _opening ? null : _open,
                  child: Text(_opening ? 'Opening...' : 'View listing'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Wrap(
              spacing: 4,
              children: [
                for (final entry in {
                  'like': '👍',
                  'love': '❤️',
                  'wow': '😮',
                  'dislike': '👎',
                }.entries)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 38),
                      backgroundColor: item['myReaction'] == entry.key
                          ? const Color(0xFFEAF0FF)
                          : null,
                    ),
                    onPressed: _busy ? null : () => _react(entry.key),
                    child: Text(
                      '${entry.value} ${counts[entry.key] ?? 0}',
                      semanticsLabel:
                          '${entry.key}, ${counts[entry.key] ?? 0} reactions',
                    ),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text('${item['comments'] ?? 0}'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExploreCommentsScreen(
                          type: item['type'].toString(),
                          itemId: item['id'].toString(),
                          title: item['title']?.toString() ?? 'Conversation',
                          service: widget.service,
                        ),
                      ),
                    );
                    if (mounted) await _refreshStats();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ExploreBlocksScreen extends StatefulWidget {
  const ExploreBlocksScreen({super.key});
  @override
  State<ExploreBlocksScreen> createState() => _ExploreBlocksScreenState();
}

class _ExploreBlocksScreenState extends State<ExploreBlocksScreen> {
  final _service = ExploreService();
  List<dynamic> _rows = [];
  String? _cursor;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.request(
        'blocks',
        query: {if (more && _cursor != null) 'before': _cursor!},
      );
      if (mounted)
        setState(() {
          _rows = more
              ? [..._rows, ...data['blocks'] as List]
              : data['blocks'] as List;
          _cursor = data['nextCursor'] as String?;
        });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blocked accounts')),
    body: ListView(
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          ListTile(
            title: Text(_error!),
            trailing: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        if (!_loading && _rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No blocked accounts.'),
          ),
        for (final row in _rows)
          ListTile(
            title: Text(row['name'].toString()),
            trailing: TextButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      try {
                        await _service.request(
                          'blocks/${row['userId']}',
                          method: 'DELETE',
                        );
                        if (mounted) await _load();
                      } catch (error) {
                        if (mounted)
                          setState(() {
                            _error = error.toString();
                            _loading = false;
                          });
                      }
                    },
              child: const Text('Unblock'),
            ),
          ),
        if (_cursor != null)
          TextButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: const Text('More accounts'),
          ),
      ],
    ),
  );
}
