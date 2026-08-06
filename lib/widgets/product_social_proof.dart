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
    final rating = product.displayRating;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFB020), size: 15),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: const Color(0xFF344054),
            fontSize: compact ? 11 : 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Container(width: 1, height: 12, color: const Color(0xFFD0D5DD)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${product.formattedDisplaySoldCount}+ sold',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF667085),
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
