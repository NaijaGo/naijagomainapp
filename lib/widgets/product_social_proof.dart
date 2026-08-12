import 'package:flutter/material.dart';

import '../models/product.dart';

class ProductSocialProof extends StatelessWidget {
  final Product product;
  final bool compact;

  const ProductSocialProof({
    super.key,
    required this.product,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!product.hasRealRating && !product.hasRealSales) {
      return _label(Icons.auto_awesome_rounded, 'New');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (product.hasRealRating) ...[
          const Icon(Icons.star_rounded, color: Color(0xFFFFB020), size: 15),
          const SizedBox(width: 3),
          Text(
            '${product.displayRating.toStringAsFixed(1)} (${product.numReviews})',
            style: _textStyle(const Color(0xFF344054)),
          ),
        ],
        if (product.hasRealRating && product.hasRealSales) ...[
          const SizedBox(width: 6),
          Container(width: 1, height: 12, color: const Color(0xFFD0D5DD)),
          const SizedBox(width: 6),
        ],
        if (product.hasRealSales)
          Flexible(
            child: Text(
              '${product.formattedSalesCount} sold',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _textStyle(const Color(0xFF667085)),
            ),
          ),
      ],
    );
  }

  TextStyle _textStyle(Color color) => TextStyle(
    color: color,
    fontSize: compact ? 10.5 : 12,
    fontWeight: FontWeight.w700,
  );

  Widget _label(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: const Color(0xFF08756F), size: 14),
      const SizedBox(width: 4),
      Text(text, style: _textStyle(const Color(0xFF08756F))),
    ],
  );
}
