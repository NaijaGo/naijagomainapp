import 'package:flutter/material.dart';
import 'app_network_image.dart';

class ReviewPhotos extends StatelessWidget {
  const ReviewPhotos({super.key, required this.urls});
  final List<String> urls;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
    for (final url in urls.take(5))
      InkWell(onTap: () => showDialog<void>(context: context, builder: (dialogContext) => Dialog(
        child: Stack(children: [
          InteractiveViewer(child: Image.network(url, fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(32), child: Text('Photo unavailable.')))),
          Positioned(right: 0, top: 0, child: IconButton(tooltip: 'Close photo',
              onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close))),
        ]))),
        child: ClipRRect(borderRadius: BorderRadius.circular(10),
          child: AppNetworkImage(imageUrl: url, width: 84, height: 84, fit: BoxFit.cover,
            errorWidget: (context, url, error) => const SizedBox(
                width: 84, height: 84, child: Icon(Icons.image_not_supported_outlined))))),
  ]);
}
