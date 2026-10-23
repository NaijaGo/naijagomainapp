import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/images/image_delivery.dart';

/// Cached, display-sized image provider for places that need an
/// [ImageProvider] (e.g. `CircleAvatar.backgroundImage`). [logicalSize] is
/// the widget's on-screen width.
ImageProvider appNetworkImageProvider(
  BuildContext context,
  String imageUrl, {
  required double logicalSize,
}) {
  final pixels = imagePixelWidth(
    logicalSize, MediaQuery.devicePixelRatioOf(context),
  );
  return CachedNetworkImageProvider(
    optimizedImageUrl(imageUrl, pixels),
    maxWidth: pixels,
  );
}

/// Cached, display-sized delivery for catalogue imagery. Full-screen zoom uses
/// the original image provider independently; stored URLs are never modified.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final displayWidth = width != null && width!.isFinite
          ? width!.clamp(0, constraints.maxWidth).toDouble()
          : constraints.maxWidth;
      final pixels = imagePixelWidth(
        displayWidth, MediaQuery.devicePixelRatioOf(context),
      );
      final deliveredUrl = optimizedImageUrl(imageUrl, pixels);
      Widget image(String url, {required bool allowFallback}) => CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        memCacheWidth: pixels,
        // The package defaults (500ms in, 1s out) make cached images look slow.
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: placeholder == null ? null : (context, _) => placeholder!(context, imageUrl),
        errorWidget: (context, _, error) {
          // Some Cloudinary accounts restrict transformations. Retry the
          // original once, then use the screen's existing error presentation.
          if (allowFallback && deliveredUrl != imageUrl) {
            return image(imageUrl, allowFallback: false);
          }
          return errorWidget?.call(context, imageUrl, error) ?? const Icon(Icons.error);
        },
      );
      return image(deliveredUrl, allowFallback: true);
    },
  );
}
