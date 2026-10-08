import 'package:flutter/material.dart';
import '../providers/deals_provider.dart';
import '../services/deals_service.dart';
import '../screens/Main/deals_screen.dart';
import '../theme/app_theme.dart';
import 'deal_card.dart';

class DealsHomeSection extends StatefulWidget {
  const DealsHomeSection({super.key, this.refreshToken = 0, this.service});
  final int refreshToken;
  final DealsService? service;
  @override
  State<DealsHomeSection> createState() => _DealsHomeSectionState();
}

class _DealsHomeSectionState extends State<DealsHomeSection> {
  late final DealsProvider _deals;
  @override
  void initState() {
    super.initState();
    _deals = DealsProvider(service: widget.service, limit: 6);
    _deals.refresh();
  }

  @override
  void didUpdateWidget(DealsHomeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _deals.refresh();
  }

  @override
  void dispose() {
    _deals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _deals,
    builder: (context, _) {
      final rows = _deals.deals;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: AppTheme.primaryNavy,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NaijaGo Deals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondaryBlack,
                        ),
                      ),
                      Text(
                        'Good finds. Limited-time prices.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DealsScreen(service: widget.service),
                    ),
                  ),
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_deals.loading && rows.isEmpty)
              const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_deals.error != null)
              DealsStatePanel(message: _deals.error!, onRetry: _deals.refresh)
            else if (rows.isEmpty)
              const DealsStatePanel(
                message: 'New Deals are coming. Check back soon.',
                empty: true,
              )
            else
              SizedBox(
                height: DealCard.height(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: 210,
                    child: DealCard(
                      key: ValueKey(rows[index].id),
                      deal: rows[index],
                      now: _deals.serverNow,
                      service: _deals.service,
                      heroPrefix: 'home-deals',
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
