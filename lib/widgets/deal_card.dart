import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/deal.dart';
import '../services/deals_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../screens/Main/product_detail_screen.dart';

String formatDealPrice(double value) => NumberFormat.currency(
  locale: 'en_NG',
  symbol: '₦',
  decimalDigits: value == value.roundToDouble() ? 0 : 2,
).format(value);

class DealCard extends StatefulWidget {
  const DealCard({
    super.key,
    required this.deal,
    required this.now,
    required this.service,
    this.heroPrefix = 'deals',
  });
  final Deal deal;
  final DateTime now;
  final DealsService service;
  final String heroPrefix;
  static double height(BuildContext context) =>
      164 + MediaQuery.textScalerOf(context).scale(165);
  @override
  State<DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<DealCard> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening || !widget.deal.isActiveAt(widget.now)) return;
    setState(() => _opening = true);
    try {
      final product = await widget.service.productForDeal(widget.deal);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(
            product: product,
            heroTag: '${widget.heroPrefix}-${widget.deal.id}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is DealsException
                  ? error.message
                  : 'Could not open this Deal. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final badge = deal.discountType == 'percentage'
        ? '${deal.discountValue.toStringAsFixed(deal.discountValue % 1 == 0 ? 0 : 2)}% OFF'
        : '${formatDealPrice(deal.discountValue)} OFF';
    return Semantics(
      button: true,
      label: 'Shop ${deal.productName} Deal',
      child: Material(
        color: AppTheme.cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppTheme.borderGrey),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _opening ? null : _open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 128,
                    width: double.infinity,
                    child: Hero(
                      tag: '${widget.heroPrefix}-${deal.id}',
                      child: deal.imageUrls.isEmpty
                          ? const ColoredBox(
                              color: AppTheme.softGrey,
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                color: AppTheme.mutedText,
                                size: 36,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: deal.imageUrls.first,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  const ColoredBox(color: AppTheme.softGrey),
                              errorWidget: (_, _, _) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: AppTheme.mutedText,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: MediaQuery.textScalerOf(context).scale(36),
                        child: Text(
                          deal.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondaryBlack,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deal.vendorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        formatDealPrice(deal.originalPrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedText,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDealPrice(deal.finalPrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppTheme.primaryNavy,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              deal.countdownAt(widget.now),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          ),
                          if (_opening)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: AppTheme.primaryNavy,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DealsStatePanel extends StatelessWidget {
  const DealsStatePanel({
    super.key,
    required this.message,
    this.onRetry,
    this.empty = false,
  });
  final String message;
  final VoidCallback? onRetry;
  final bool empty;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppTheme.cardWhite,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppTheme.borderGrey),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          empty ? Icons.local_offer_outlined : Icons.info_outline_rounded,
          color: AppTheme.primaryNavy,
          size: 30,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.mutedText, height: 1.4),
        ),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
      ],
    ),
  );
}
