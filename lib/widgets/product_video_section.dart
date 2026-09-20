import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../constants.dart';

class ProductVideoSection extends StatefulWidget {
  const ProductVideoSection({super.key, required this.productId, this.assetId});
  final String productId;
  final String? assetId;

  @override
  State<ProductVideoSection> createState() => _ProductVideoSectionState();
}

class _ProductVideoSectionState extends State<ProductVideoSection> {
  final http.Client _client = http.Client();
  List<Map<String, dynamic>> _videos = [];
  bool _failed = false;
  bool _loading = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.assetId != null && widget.assetId!.isNotEmpty) _load();
  }

  Future<void> _load() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final response = await _client
          .get(
            Uri.parse(
              '$baseUrl/api/product-media/products/${widget.productId}',
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted || version != _requestVersion) return;
      if (response.statusCode != 200) throw Exception('Video unavailable');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _videos = (data['videos'] as List? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (_) {
      if (mounted && version == _requestVersion) setState(() => _failed = true);
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant ProductVideoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId == widget.productId &&
        oldWidget.assetId == widget.assetId) {
      return;
    }
    _requestVersion++;
    _videos = [];
    _failed = false;
    _loading = false;
    if (widget.assetId?.isNotEmpty == true) _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return TextButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text('Video unavailable. Tap to retry'),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Loading product video...'),
      );
    }
    if (_videos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'See it in action',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final video in _videos)
            Semantics(
              button: true,
              label: 'Watch product video',
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductVideoPlayer(url: video['url'].toString()),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(
                        video['posterUrl'].toString(),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(height: 200, color: Colors.black87),
                      ),
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.black54,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(video['duration'] as num?)?.ceil() ?? 0}s - tap to watch',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen, user-initiated playback; pause when the app loses focus.
class ProductVideoPlayer extends StatefulWidget {
  const ProductVideoPlayer({
    super.key,
    required this.url,
    this.onQualifiedWatch,
    this.expiresAfter,
  });
  final String url;
  final void Function(int milliseconds)? onQualifiedWatch;
  final Duration? expiresAfter;
  @override
  State<ProductVideoPlayer> createState() => _ProductVideoPlayerState();
}

class _ProductVideoPlayerState extends State<ProductVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _initializing = false;
  Timer? _watchTimer;
  Timer? _expiryTimer;
  bool _expired = false;
  DateTime? _lastSample;
  int _watchedMs = 0;
  bool _watchReported = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final expiresAfter = widget.expiresAfter;
    if (expiresAfter != null) {
      _expiryTimer = Timer(
        expiresAfter.isNegative ? Duration.zero : expiresAfter,
        () {
          _watchTimer?.cancel();
          _controller?.pause();
          if (mounted) setState(() => _expired = true);
        },
      );
    }
    _initialize();
  }

  Future<void> _initialize() async {
    if (_initializing || _expired) return;
    _watchTimer?.cancel();
    setState(() {
      _failed = false;
      _initializing = true;
    });
    final uri = Uri.tryParse(widget.url);
    if (uri == null || uri.scheme != 'https') {
      setState(() {
        _failed = true;
        _initializing = false;
      });
      return;
    }
    final old = _controller;
    _controller = null;
    await old?.dispose();
    if (!mounted) return;
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize().timeout(const Duration(seconds: 30));
      await controller.setVolume(0);
      if (!mounted || _controller != controller) return;
      setState(() => _initializing = false);
      // The shopper opens this player explicitly. It begins muted.
      if (_foreground &&
          !_expired &&
          ModalRoute.of(context)?.isCurrent == true) {
        await controller.play();
      }
      _watchTimer?.cancel();
      _lastSample = DateTime.now();
      _watchTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final current = DateTime.now();
        final elapsed = current
            .difference(_lastSample ?? current)
            .inMilliseconds;
        _lastSample = current;
        if (!mounted ||
            _watchReported ||
            _expired ||
            !_foreground ||
            ModalRoute.of(context)?.isCurrent != true)
          return;
        final value = controller.value;
        if (value.isPlaying &&
            !value.isBuffering &&
            !value.hasError &&
            elapsed <= 1000)
          _watchedMs += elapsed;
        if (_watchedMs >= 3000) {
          _watchReported = true;
          widget.onQualifiedWatch?.call(_watchedMs);
          _watchTimer?.cancel();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _initializing = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) _controller?.pause();
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _expiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Product video'),
      ),
      body: SafeArea(
        child: Center(
          child: _expired
              ? const Text(
                  'This promotion has ended.',
                  style: TextStyle(color: Colors.white),
                )
              : _failed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to play this video. Check your connection.',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: _initialize,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : controller == null || _initializing
              ? const CircularProgressIndicator()
              : ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (value.hasError) ...[
                        const Text(
                          'Playback interrupted.',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: _initialize,
                          child: const Text('Retry'),
                        ),
                      ] else ...[
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: value.aspectRatio,
                              child: VideoPlayer(controller),
                            ),
                          ),
                        ),
                        if (value.isBuffering) const LinearProgressIndicator(),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              color: Colors.white,
                              tooltip: 'Replay',
                              icon: const Icon(Icons.replay),
                              onPressed: () async {
                                await controller.seekTo(Duration.zero);
                                await controller.play();
                              },
                            ),
                            IconButton(
                              color: Colors.white,
                              tooltip: value.isPlaying ? 'Pause' : 'Play',
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              onPressed: () => value.isPlaying
                                  ? controller.pause()
                                  : controller.play(),
                            ),
                            IconButton(
                              color: Colors.white,
                              tooltip: value.volume == 0 ? 'Unmute' : 'Mute',
                              icon: Icon(
                                value.volume == 0
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                              ),
                              onPressed: () => controller.setVolume(
                                value.volume == 0 ? 1 : 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
