import 'package:flutter/material.dart';
import '../../providers/deals_provider.dart';
import '../../services/deals_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/deal_card.dart';
import '../../widgets/visible_back_button.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key, this.service, this.clock});
  final DealsService? service;
  final DateTime Function()? clock;
  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  late final DealsProvider _deals;
  @override
  void initState() {
    super.initState();
    _deals = DealsProvider(service: widget.service, clock: widget.clock);
    _deals.refresh();
  }

  @override
  void dispose() {
    _deals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _deals,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('NaijaGo Deals'),
        leading: const VisibleBackButton(),
        actions: [
          IconButton(
            tooltip: 'Refresh Deals',
            onPressed: _deals.loading ? null : _deals.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _deals.refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rows = _deals.deals;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 18),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Limited-time offers from NaijaGo vendors. Prices are confirmed at checkout.',
                      style: TextStyle(color: AppTheme.mutedText, height: 1.4),
                    ),
                  ),
                ),
                if (_deals.loading && rows.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_deals.loading)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (_deals.error != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverToBoxAdapter(
                      child: DealsStatePanel(
                        message: _deals.error!,
                        onRetry: _deals.retry,
                      ),
                    ),
                  ),
                if (!_deals.loading && _deals.error == null && rows.isEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: DealsStatePanel(
                        message:
                            'No active Deals right now. Check back for new offers.',
                        empty: true,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth >= 900
                          ? 4
                          : constraints.maxWidth >= 600
                          ? 3
                          : 2,
                      mainAxisExtent: DealCard.height(context),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => DealCard(
                        key: ValueKey(rows[index].id),
                        deal: rows[index],
                        now: _deals.serverNow,
                        service: _deals.service,
                      ),
                      childCount: rows.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: _deals.loadingMore
                          ? const CircularProgressIndicator()
                          : _deals.hasMore && !_deals.loading
                          ? OutlinedButton.icon(
                              onPressed: _deals.loadMore,
                              icon: const Icon(Icons.expand_more_rounded),
                              label: const Text('Load more Deals'),
                            )
                          : rows.isNotEmpty
                          ? const Text(
                              'You’re all caught up',
                              style: TextStyle(color: AppTheme.mutedText),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
