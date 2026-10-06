import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../models/explore_video.dart';
import '../../models/product.dart';
import '../../services/explore_service.dart';
import 'explore_comments_screen.dart';
import 'home_screen.dart' show ProductService;
import 'product_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.canPublish = false, this.publisherLabel = 'Creator', this.loadProducts, this.loadFeed});
  final bool canPublish;
  final String publisherLabel;
  final Future<List<Product>> Function()? loadProducts;
  final Future<List<ExploreVideo>> Function()? loadFeed;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _service = ExploreService();
  List<ExploreVideo> _videos = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() { _loading = true; _error = null; });
    try {
      final page = widget.loadFeed == null ? await _service.fetchFeedPage() : null;
      final videos = page?.items ?? await widget.loadFeed!();
      if (mounted) setState(() { _videos = videos; _page = 1; _hasMore = page?.hasMore ?? false; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = _message(error); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || widget.loadFeed != null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.fetchFeedPage(page: _page + 1);
      if (!mounted) return;
      setState(() {
        final existing = _videos.map((video) => video.id).toSet();
        _videos = [..._videos, ...page.items.where((video) => !existing.contains(video.id))];
        _page = page.page;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadingMore = false);
        _showError(_message(error));
      }
    }
  }

  Future<void> _toggleLike(ExploreVideo video) async {
    try {
      final count = video.isLiked ? await _service.unlike(video.id) : await _service.like(video.id);
      if (!mounted) return;
      setState(() => _videos = _videos.map((item) => item.id == video.id
          ? item.copyWith(isLiked: !video.isLiked, likeCount: count)
          : item).toList());
    } catch (error) {
      if (mounted) _showError(_message(error));
    }
  }

  Future<void> _openProduct(String productId) async {
    try {
      final product = await ProductService().fetchProductById(productId);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product, heroTag: 'explore-${product.id}')));
    } catch (error) {
      if (mounted) _showError(_message(error));
    }
  }

  void _openComments(ExploreVideo video) {
    showExploreCommentsSheet(context, videoId: video.id, itemTitle: video.creatorName, onCountChanged: (count) {
      if (mounted) setState(() => _videos = _videos.map((item) => item.id == video.id ? item.copyWith(commentCount: count) : item).toList());
    });
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  String _message(Object error) => error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF081A3A),
    body: SafeArea(child: Stack(children: [
      Positioned.fill(child: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? _ExploreErrorState(message: _error!, onRetry: _loadFeed)
              : _videos.isEmpty
                  ? const _ExploreEmptyState()
                  : ExploreVideoPageFeed(videos: _videos, onLike: _toggleLike, onComments: _openComments, onProductTap: _openProduct, onNearEnd: _loadMore)),
      Positioned(top: 12, left: 20, right: 20, child: Row(children: [
        const Text('Explore', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (widget.canPublish) OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreUploadScreen(publisherLabel: widget.publisherLabel, onPublished: _loadFeed, loadProducts: widget.loadProducts))),
          icon: const Icon(Icons.add, size: 18), label: const Text('Create'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
        ),
      ])),
    ])),
  );
}

class _ExploreErrorState extends StatelessWidget {
  const _ExploreErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.cloud_off_outlined, color: Colors.white70, size: 42),
    const SizedBox(height: 12), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
    const SizedBox(height: 14), OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
  ])));
}

class _ExploreEmptyState extends StatelessWidget {
  const _ExploreEmptyState();
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 82, height: 82, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), shape: BoxShape.circle), child: const Icon(Icons.play_circle_outline, size: 44, color: Colors.white)),
    const SizedBox(height: 22),
    const Text('Discover NaijaGo', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    Text('Short videos from local businesses will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .76), height: 1.5, fontSize: 15)),
  ])));
}

class ExploreVideoFeedCard extends StatefulWidget {
  const ExploreVideoFeedCard({super.key, required this.video, this.onComment, this.onLike, this.onShare, this.onProductTap, this.autoplay = true});
  final ExploreVideo video;
  final VoidCallback? onComment;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final ValueChanged<String>? onProductTap;
  final bool autoplay;
  @override
  State<ExploreVideoFeedCard> createState() => _ExploreVideoFeedCardState();
}

class _ExploreVideoFeedCardState extends State<ExploreVideoFeedCard> {
  late final VideoPlayerController _player;
  bool _videoReady = false;
  bool _videoFailed = false;
  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
    _player.initialize().then((_) {
      if (mounted) { setState(() => _videoReady = true); _player.setLooping(true); if (widget.autoplay) _player.play(); }
    }).catchError((_) { if (mounted) setState(() => _videoFailed = true); });
  }
  @override
  void didUpdateWidget(covariant ExploreVideoFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoplay != widget.autoplay && _videoReady) {
      if (widget.autoplay) { _player.play(); } else { _player.pause(); }
    }
  }
  @override
  void dispose() { _player.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    if (_videoReady) FittedBox(fit: BoxFit.cover, child: SizedBox(width: _player.value.size.width, height: _player.value.size.height, child: VideoPlayer(_player)))
    else if (_videoFailed) const ColoredBox(color: Color(0xFF081A3A), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 44), SizedBox(height: 12), Text('This video is unavailable.', style: TextStyle(color: Colors.white70))])))
    else if (widget.video.posterUrl != null) Image.network(widget.video.posterUrl!, fit: BoxFit.cover)
    else const ColoredBox(color: Color(0xFF081A3A), child: Center(child: CircularProgressIndicator(color: Colors.white70))),
    GestureDetector(behavior: HitTestBehavior.opaque, onTap: _videoReady ? () { if (_player.value.isPlaying) { _player.pause(); } else { _player.play(); } } : null),
    Positioned(left: 18, right: 90, bottom: 28, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(radius: 18, backgroundImage: widget.video.creatorAvatarUrl == null ? null : NetworkImage(widget.video.creatorAvatarUrl!), child: widget.video.creatorAvatarUrl == null ? const Icon(Icons.storefront, size: 19) : null), const SizedBox(width: 9), Text(widget.video.creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
      const SizedBox(height: 8), Text(widget.video.caption, style: const TextStyle(color: Colors.white, fontSize: 14)),
      if (widget.video.productName != null) Padding(padding: const EdgeInsets.only(top: 12), child: ActionChip(avatar: const Icon(Icons.shopping_bag_outlined, size: 17), label: Text(widget.video.productName!), onPressed: widget.video.productId != null && widget.onProductTap != null ? () => widget.onProductTap!(widget.video.productId!) : null)),
    ])),
    Positioned(right: 15, bottom: 35, child: Column(children: [
      IconButton(onPressed: widget.onLike, icon: Icon(widget.video.isLiked ? Icons.favorite : Icons.favorite_border, color: Colors.white, size: 30)), Text('${widget.video.likeCount}', style: const TextStyle(color: Colors.white)),
      const SizedBox(height: 14), IconButton(onPressed: widget.onComment, icon: const Icon(Icons.comment_outlined, color: Colors.white, size: 28)), Text('${widget.video.commentCount}', style: const TextStyle(color: Colors.white)),
      const SizedBox(height: 14), IconButton(onPressed: widget.onShare, icon: const Icon(Icons.share_outlined, color: Colors.white, size: 27)),
    ])),
  ]);
}

class ExploreVideoPageFeed extends StatefulWidget {
  const ExploreVideoPageFeed({super.key, required this.videos, this.onLike, this.onComments, this.onProductTap, this.onNearEnd});
  final List<ExploreVideo> videos;
  final ValueChanged<ExploreVideo>? onLike;
  final ValueChanged<ExploreVideo>? onComments;
  final ValueChanged<String>? onProductTap;
  final VoidCallback? onNearEnd;
  @override
  State<ExploreVideoPageFeed> createState() => _ExploreVideoPageFeedState();
}

class _ExploreVideoPageFeedState extends State<ExploreVideoPageFeed> {
  int _activePage = 0;
  @override
  Widget build(BuildContext context) => PageView.builder(
    scrollDirection: Axis.vertical,
    itemCount: widget.videos.length,
    onPageChanged: (index) {
      setState(() => _activePage = index);
      if (index >= widget.videos.length - 3) widget.onNearEnd?.call();
    },
    itemBuilder: (context, index) {
      final video = widget.videos[index];
      return ExploreVideoFeedCard(
        key: ValueKey(video.id), video: video, autoplay: index == _activePage,
        onLike: () => widget.onLike?.call(video),
        onComment: () => widget.onComments?.call(video),
        onProductTap: widget.onProductTap,
      );
    },
  );
}

class ExploreUploadScreen extends StatefulWidget {
  const ExploreUploadScreen({super.key, required this.publisherLabel, this.onPublished, this.loadProducts});
  final String publisherLabel;
  final Future<void> Function()? onPublished;
  final Future<List<Product>> Function()? loadProducts;
  @override
  State<ExploreUploadScreen> createState() => _ExploreUploadScreenState();
}

class _ExploreUploadScreenState extends State<ExploreUploadScreen> {
  final _picker = ImagePicker();
  final _captionController = TextEditingController();
  final _service = ExploreService();
  XFile? _video;
  List<Product> _products = [];
  String? _productId;
  bool _loadingProducts = true;
  bool _publishing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    (widget.loadProducts ?? ProductService().fetchAllProducts).call().then((products) {
      if (mounted) setState(() { _products = products; _loadingProducts = false; });
    }).catchError((_) { if (mounted) setState(() => _loadingProducts = false); });
  }
  @override
  void dispose() { _captionController.dispose(); super.dispose(); }
  Future<void> _chooseVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 90));
    if (video != null && mounted) setState(() => _video = video);
  }
  Future<void> _publish() async {
    final caption = _captionController.text.trim();
    if (_video == null || caption.isEmpty) { setState(() => _error = 'Choose a video and enter a caption.'); return; }
    setState(() { _publishing = true; _error = null; });
    try {
      await _service.publishVideo(filePath: _video!.path, caption: caption, productId: _productId);
      await widget.onPublished?.call();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create Explore video')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Posting as ${widget.publisherLabel}', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Posting guidelines', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            for (final guideline in const [
              'Post legitimate content related to NaijaGo.',
              'Do not make misleading product claims. Product details must match the linked NaijaGo product.',
              'Do not post prohibited or harmful content.',
              'Do not upload content that violates another person’s rights.',
              'Do not impersonate another vendor or person.',
              'NaijaGo may remove content that violates platform rules.',
            ])
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  '),
                  Expanded(child: Text(guideline)),
                ]),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      InkWell(onTap: _publishing ? null : _chooseVideo, borderRadius: BorderRadius.circular(20), child: Container(height: 220, decoration: BoxDecoration(color: const Color(0xFFF2F5FA), borderRadius: BorderRadius.circular(20)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.video_library_outlined, size: 46), const SizedBox(height: 10), Text(_video?.name ?? 'Choose a video')]))),
      const SizedBox(height: 18), TextField(controller: _captionController, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'Caption', border: OutlineInputBorder())),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(value: _productId, decoration: const InputDecoration(labelText: 'Link a product (optional)', border: OutlineInputBorder()), items: [const DropdownMenuItem<String>(value: null, child: Text('No product')), ..._products.map((p) => DropdownMenuItem<String>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))], onChanged: _loadingProducts || _publishing ? null : (id) => setState(() => _productId = id)),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 18), FilledButton.icon(onPressed: _publishing ? null : _publish, icon: _publishing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish), label: Text(_publishing ? 'Publishing…' : 'Publish video')),
    ]),
  );
}
