/// A few stable sizes allow nearby card sizes to reuse the same cached image.
int? imagePixelWidth(double logicalWidth, double devicePixelRatio) {
  if (!logicalWidth.isFinite || logicalWidth <= 0 ||
      !devicePixelRatio.isFinite || devicePixelRatio <= 0) return null;
  final pixels = logicalWidth * devicePixelRatio;
  for (final size in [160, 320, 640, 960, 1280, 1920, 2560]) {
    if (pixels <= size) return size;
  }
  return 2560;
}

/// Resize only ordinary, unsigned Cloudinary image upload URLs. Signed URLs,
/// existing transformations and other hosts retain their original URL.
String optimizedImageUrl(String original, int? pixelWidth) {
  if (pixelWidth == null || pixelWidth <= 0) return original;
  final uri = Uri.tryParse(original);
  if (uri == null || uri.scheme != 'https' ||
      uri.host != 'res.cloudinary.com' || uri.hasPort ||
      uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) return original;
  final segments = uri.pathSegments;
  if (segments.length < 4 || segments[0].isEmpty ||
      segments[1] != 'image' || segments[2] != 'upload') return original;
  final first = segments[3];
  if (first.isEmpty || first.startsWith('s--') || first.contains(',') ||
      RegExp(r'^[a-zA-Z]{1,4}_').hasMatch(first)) return original;
  // Work on the encoded path: do not decode/re-encode public IDs or signatures.
  const marker = '/image/upload/';
  final offset = original.indexOf(marker) + marker.length;
  final width = pixelWidth.clamp(1, 2560);
  return '${original.substring(0, offset)}f_auto,q_auto,c_limit,w_$width/${original.substring(offset)}';
}
