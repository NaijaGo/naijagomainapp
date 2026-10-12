import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants.dart' show baseUrl;
import '../models/product.dart';
import '../theme/app_theme.dart';

/// Original photos from the already loaded public restaurant catalogue.
class RestaurantPhotoBanner extends StatefulWidget {
  const RestaurantPhotoBanner({
    super.key,
    required this.products,
    required this.onOpen,
  });
  final List<Product> products;
  final ValueChanged<Product> onOpen;
  static String? photoUrl(Product product) {
    for (final raw in product.imageUrls) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final uri = Uri.tryParse(value);
      if (uri == null) continue;
      if (uri.host.isNotEmpty &&
          (uri.scheme == 'http' || uri.scheme == 'https')) {
        return value;
      }
      if (!uri.hasScheme && !value.startsWith('//')) {
        return Uri.parse('$baseUrl/').resolve(value).toString();
      }
    }
    return null;
  }

  static List<Product> visibleProducts(Iterable<Product> products) {
    final seen = <String>{};
    return products
        .where(
          (p) =>
              p.isActive &&
              p.isRestaurantItem &&
              !p.isMedicine &&
              p.stockQuantity > 0 &&
              !p.vendorTemporarilyClosed &&
              photoUrl(p) != null &&
              seen.add('${p.vendorId}:${p.id}:${p.offerId ?? ''}'),
        )
        .toList(growable: false);
  }

  @override
  State<RestaurantPhotoBanner> createState() => _RestaurantPhotoBannerState();
}

class _RestaurantPhotoBannerState extends State<RestaurantPhotoBanner> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;
  List<Product> get _products =>
      RestaurantPhotoBanner.visibleProducts(widget.products);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void didUpdateWidget(RestaurantPhotoBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = RestaurantPhotoBanner.visibleProducts(oldWidget.products)
        .map((p) => '${p.id}:${p.offerId}:${RestaurantPhotoBanner.photoUrl(p)}')
        .join('|');
    final after = _products
        .map((p) => '${p.id}:${p.offerId}:${RestaurantPhotoBanner.photoUrl(p)}')
        .join('|');
    if (before != after) {
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (MediaQuery.of(context).disableAnimations ||
        !TickerMode.valuesOf(context).enabled ||
        _products.length < 2) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients || _products.length < 2) return;
      _controller.animateToPage(
        (_page + 1) % _products.length,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    if (products.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 2.6,
          child: PageView.builder(
            controller: _controller,
            itemCount: products.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) {
              final product = products[index];
              return Semantics(
                button: true,
                label:
                    '${product.name}, ${product.displayRestaurantName}. Open restaurant menu',
                child: GestureDetector(
                  key: ValueKey('restaurant-photo-${product.id}'),
                  onTap: () => widget.onOpen(product),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: RestaurantPhotoBanner.photoUrl(product)!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const ColoredBox(color: AppTheme.sageSurface),
                        errorWidget: (_, _, _) => const ColoredBox(
                          color: AppTheme.sageSurface,
                          child: Center(
                            child: Icon(
                              Icons.restaurant_outlined,
                              color: AppTheme.forestGreen,
                            ),
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xE61D2D47)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    product.displayRestaurantName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      if (products.length > 1)
                        Positioned(
                          top: 8,
                          right: 10,
                          child: Text(
                            '${index + 1}/${products.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
