// lib/screens/Main/VendorScreen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../constants.dart';
import '../vendor/add_product_screen.dart';
import '../vendor/orders_recived_screen.dart.dart';
import '../../vendor/screens/vendor_registration_screen.dart';
import 'vendor_desist_confirmation_screen.dart';
import 'vendor_my_products_screen.dart';

// Defined custom colors for consistency
const Color deepNavyBlue = Color(0xFF03024C);
const Color greenYellow = Color(0xFFB7FFD4);
const Color whiteBackground = Colors.white;
const Color _vendorBlue = Color(0xFF0D2E91);
const Color _vendorSurface = Color(0xFFF4F7FB);
const Color _vendorBorder = Color(0xFFD8E1F0);
const Color _vendorSoftText = Color(0xFFD9E4F6);
const Color _vendorTextMuted = Color(0xFF5B6886);
const Color _vendorSuccess = Color(0xFF1E9E67);
const Color _vendorWarning = Color(0xFFE0A325);
const Color _vendorDanger = Color(0xFFC64848);

class VendorScreen extends StatefulWidget {
  final bool isApprovedVendor;
  final String vendorStatus;
  final DateTime? rejectionDate;
  final double vendorWalletBalance;
  final double appWalletBalance;
  final double userWalletBalance;
  final int totalProducts;
  final int productsSold;
  final int productsUnsold;
  final int followersCount;
  final List<dynamic> notifications;
  final VoidCallback onRefresh;

  const VendorScreen({
    super.key,
    required this.isApprovedVendor,
    required this.vendorStatus,
    this.rejectionDate,
    required this.vendorWalletBalance,
    required this.appWalletBalance,
    required this.userWalletBalance,
    required this.totalProducts,
    required this.productsSold,
    required this.productsUnsold,
    required this.followersCount,
    required this.notifications,
    required this.onRefresh,
  });

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> with WidgetsBindingObserver {
  Timer? _countdownTimer;

  String _currentCountdownMessage = '';

  // New state variables for saved withdrawal info
  String? _savedBankName;
  String? _savedBankCode;
  String? _savedAccountNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('Flutter: VendorScreen initState called.');
    if (widget.vendorStatus == 'rejected' && widget.rejectionDate != null) {
      _startCountdownTimer();
    }
    _loadSavedWithdrawalDetails();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  // New function to load saved details
  Future<void> _loadSavedWithdrawalDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedBankName = prefs.getString('savedBankName_vendor');
      _savedBankCode = prefs.getString('savedBankCode_vendor');
      _savedAccountNumber = prefs.getString('savedAccountNumber_vendor');
    });
  }

  @override
  void didUpdateWidget(covariant VendorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vendorStatus != oldWidget.vendorStatus || widget.rejectionDate != oldWidget.rejectionDate) {
      if (widget.vendorStatus == 'rejected' && widget.rejectionDate != null) {
        _startCountdownTimer();
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _currentCountdownMessage = '';
        });
      }
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentCountdownMessage = _getCountdownMessage();
        if (_currentCountdownMessage == 'You can now submit a new vendor request!') {
          timer.cancel();
          widget.onRefresh();
        }
      });
    });
  }

  String _getCountdownMessage() {
    if (widget.rejectionDate == null) return '';

    final nextAttemptDate = widget.rejectionDate!.add(const Duration(days: 30));
    final now = DateTime.now();
    final difference = nextAttemptDate.difference(now);

    if (difference.isNegative) {
      return 'You can now submit a new vendor request!';
    } else {
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;
      return 'You can try again in $days days, $hours hours, $minutes minutes, $seconds seconds.';
    }
  }

  Future<void> _refreshDashboard() async {
    widget.onRefresh();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _openVendorRegistration() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const VendorRegistrationScreen()),
    );
    if (!mounted) return;
    widget.onRefresh();
  }

  Future<void> _openAddProduct() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddProductScreen()),
    );
    if (!mounted) return;
    widget.onRefresh();
  }

  Future<void> _openMyProducts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const VendorMyProductsScreen()),
    );
    if (!mounted) return;
    widget.onRefresh();
  }

  Future<void> _openOrders() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OrdersRecivedScreen()),
    );
    if (!mounted) return;
    widget.onRefresh();
  }

  String _formatCurrency(double amount) => '₦${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _vendorSurface,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          color: deepNavyBlue,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: ValueKey(widget.vendorStatus),
                      child: _buildVendorContent(context),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVendorContent(BuildContext context) {
    switch (widget.vendorStatus) {
      case 'loading':
        return _buildStateExperience(
          badge: 'Loading',
          title: 'Checking your seller profile',
          description:
              'We are confirming your vendor access and syncing the latest store data.',
          icon: Icons.sync_rounded,
          sections: [
            _buildPanel(
              title: 'Please wait',
              subtitle: 'This usually takes only a moment.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  LinearProgressIndicator(
                    minHeight: 10,
                    backgroundColor: Color(0xFFD8E1F0),
                    valueColor: AlwaysStoppedAnimation<Color>(deepNavyBlue),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Pull down to refresh if the status does not update automatically.',
                    style: TextStyle(
                      color: _vendorTextMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 'none':
        return _buildStateExperience(
          badge: 'Start Selling',
          title: 'Open your store on NaijaGo',
          description:
              'Create a vendor profile, publish your catalog, and manage customer orders from one seller dashboard.',
          icon: Icons.storefront_rounded,
          primaryLabel: 'Start Vendor Application',
          onPrimaryPressed: _openVendorRegistration,
          sections: [
            _buildPanel(
              title: 'Why sell here',
              subtitle: 'Everything you need is already built into the flow.',
              child: Column(
                children: const [
                  _VendorBullet(
                    icon: Icons.inventory_2_outlined,
                    title: 'List products fast',
                    description:
                        'Add products, set pricing, and manage inventory from one place.',
                  ),
                  SizedBox(height: 12),
                  _VendorBullet(
                    icon: Icons.receipt_long_outlined,
                    title: 'Track every order',
                    description:
                        'Keep an eye on fulfilment status and customer demand in real time.',
                  ),
                  SizedBox(height: 12),
                  _VendorBullet(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Handle payouts securely',
                    description:
                        'Move your vendor balance to your bank account whenever you are ready.',
                  ),
                ],
              ),
            ),
          ],
        );
      case 'sent':
      case 'received':
      case 'reviewing':
        final receivedStepDone = widget.vendorStatus != 'sent';
        final reviewStepActive = widget.vendorStatus == 'reviewing';
        return _buildStateExperience(
          badge: 'Under Review',
          title: 'Your vendor request is in progress',
          description:
              'We are reviewing your business details. Once approved, your store dashboard and seller tools will unlock automatically.',
          icon: Icons.hourglass_top_rounded,
          sections: [
            _buildPanel(
              title: 'Review progress',
              subtitle: 'Current status: ${widget.vendorStatus.toUpperCase()}',
              child: Column(
                children: [
                  _buildReviewStep(
                    title: 'Application submitted',
                    description: 'We received your vendor request successfully.',
                    state: _ReviewStepState.complete,
                  ),
                  const SizedBox(height: 14),
                  _buildReviewStep(
                    title: 'Business details checked',
                    description:
                        'Our team verifies your profile, address, and category information.',
                    state: receivedStepDone
                        ? _ReviewStepState.complete
                        : _ReviewStepState.active,
                  ),
                  const SizedBox(height: 14),
                  _buildReviewStep(
                    title: 'Store activation',
                    description:
                        'Your vendor tools and dashboard go live after approval.',
                    state: reviewStepActive
                        ? _ReviewStepState.active
                        : _ReviewStepState.pending,
                  ),
                ],
              ),
            ),
            _buildPanel(
              title: 'What to do now',
              subtitle: 'No extra action is needed from you yet.',
              child: const Text(
                'Keep your contact and business details accurate. We will notify you once review is complete. You can also pull down to refresh this page anytime.',
                style: TextStyle(
                  color: _vendorTextMuted,
                  height: 1.5,
                ),
              ),
            ),
          ],
        );
      case 'approved':
        return _buildVendorDashboard(context);
      case 'rejected':
        final canResubmit = widget.rejectionDate != null &&
            DateTime.now().isAfter(
              widget.rejectionDate!.add(const Duration(days: 30)),
            );
        return _buildStateExperience(
          badge: 'Action Needed',
          title: 'Your last vendor request was not approved',
          description:
              'You can submit a new application after the review cooldown ends. Use this time to double-check your business details before reapplying.',
          icon: Icons.assignment_late_rounded,
          primaryLabel: canResubmit ? 'Submit New Request' : null,
          onPrimaryPressed: canResubmit ? _openVendorRegistration : null,
          sections: [
            _buildPanel(
              title: 'Next submission window',
              subtitle: canResubmit
                  ? 'You can apply again right now.'
                  : 'A short cooldown applies before another request.',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: canResubmit
                      ? _vendorSuccess.withValues(alpha: 0.08)
                      : _vendorWarning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: canResubmit
                        ? _vendorSuccess.withValues(alpha: 0.2)
                        : _vendorWarning.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  canResubmit
                      ? 'You can now submit a new vendor request.'
                      : _currentCountdownMessage,
                  style: TextStyle(
                    color: canResubmit ? _vendorSuccess : deepNavyBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            _buildPanel(
              title: 'Before you try again',
              subtitle: 'A stronger resubmission usually starts with cleaner details.',
              child: Column(
                children: const [
                  _VendorBullet(
                    icon: Icons.badge_outlined,
                    title: 'Use accurate identity details',
                    description:
                        'Make sure your first name, last name, and business name are correct.',
                  ),
                  SizedBox(height: 12),
                  _VendorBullet(
                    icon: Icons.location_on_outlined,
                    title: 'Confirm your business address',
                    description:
                        'Double-check the saved location and formatted address before you resend.',
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        return _buildStateExperience(
          badge: 'Refresh Needed',
          title: 'We could not confirm your vendor status',
          description:
              'Something interrupted the seller sync. Refresh the page to load the latest dashboard data.',
          icon: Icons.refresh_rounded,
          primaryLabel: 'Refresh Status',
          onPrimaryPressed: widget.onRefresh,
          sections: const [],
        );
    }
  }

  Widget _buildVendorDashboard(BuildContext context) {
    final notificationCount = widget.notifications.length;
    final hasProducts = widget.totalProducts > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth >= 860;
        final paneWidth =
            twoColumn ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDashboardHero(
              notificationCount: notificationCount,
              hasProducts: hasProducts,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: paneWidth,
                  child: _buildQuickActionsCard(),
                ),
                SizedBox(
                  width: paneWidth,
                  child: _buildBalanceCard(),
                ),
                SizedBox(
                  width: paneWidth,
                  child: _buildMetricsCard(),
                ),
                SizedBox(
                  width: paneWidth,
                  child: _buildStorePulseCard(
                    notificationCount: notificationCount,
                    hasProducts: hasProducts,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDangerZoneCard(),
          ],
        );
      },
    );
  }

  Widget _buildDashboardHero({
    required int notificationCount,
    required bool hasProducts,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deepNavyBlue, _vendorBlue],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: deepNavyBlue.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHeroPill(
                      icon: Icons.verified_rounded,
                      label: 'Approved Seller',
                    ),
                    _buildHeroPill(
                      icon: Icons.notifications_none_rounded,
                      label: notificationCount == 0
                          ? 'No new alerts'
                          : '$notificationCount new alert${notificationCount == 1 ? '' : 's'}',
                    ),
                  ],
                ),
              ),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: whiteBackground.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: whiteBackground,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Vendor dashboard',
            style: TextStyle(
              color: whiteBackground,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasProducts
                ? 'Track store health, watch incoming orders, and move your earnings without leaving the seller tab.'
                : 'Your store is approved and ready. Add your first product to start taking orders.',
            style: const TextStyle(
              color: _vendorSoftText,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _buildHeroMetric(
                label: 'Available payout',
                value: _formatCurrency(widget.vendorWalletBalance),
              ),
              _buildHeroMetric(
                label: 'Live listings',
                value: '${widget.totalProducts}',
              ),
              _buildHeroMetric(
                label: 'Orders completed',
                value: '${widget.productsSold}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return _buildPanel(
      title: 'Quick actions',
      subtitle: 'Move faster through your day-to-day seller work.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = constraints.maxWidth > 440
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: tileWidth,
                child: _buildActionTile(
                  icon: Icons.add_box_outlined,
                  title: 'Add product',
                  subtitle: 'Publish a new listing',
                  onTap: _openAddProduct,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _buildActionTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'My products',
                  subtitle: 'Update stock and pricing',
                  onTap: _openMyProducts,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _buildActionTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Orders received',
                  subtitle: 'Manage fulfilment',
                  onTap: _openOrders,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _buildActionTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Withdraw funds',
                  subtitle: 'Move earnings to your bank',
                  onTap: _showWithdrawDialog,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard() {
    return _buildPanel(
      title: 'Balances',
      subtitle: 'Keep an eye on what you can withdraw and what is still in-app.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: deepNavyBlue,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available vendor balance',
                  style: TextStyle(
                    color: _vendorSoftText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(widget.vendorWalletBalance),
                  style: const TextStyle(
                    color: whiteBackground,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildValueRow('Shopping wallet', _formatCurrency(widget.userWalletBalance)),
          const SizedBox(height: 10),
          _buildValueRow('App wallet', _formatCurrency(widget.appWalletBalance)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _showWithdrawDialog,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Withdraw'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenYellow,
                  foregroundColor: deepNavyBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: deepNavyBlue,
                  side: const BorderSide(color: _vendorBorder),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard() {
    return _buildPanel(
      title: 'Store numbers',
      subtitle: 'A quick snapshot of your current seller footprint.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = constraints.maxWidth > 440
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: tileWidth,
                child: _buildMetricTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Total products',
                  value: '${widget.totalProducts}',
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _buildMetricTile(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Products sold',
                  value: '${widget.productsSold}',
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _buildMetricTile(
                  icon: Icons.store_mall_directory_outlined,
                  label: 'Unsold products',
                  value: '${widget.productsUnsold}',
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _buildMetricTile(
                  icon: Icons.groups_2_outlined,
                  label: 'Followers',
                  value: '${widget.followersCount}',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStorePulseCard({
    required int notificationCount,
    required bool hasProducts,
  }) {
    final inventoryMessage = !hasProducts
        ? 'Add your first listing to start taking orders.'
        : widget.productsUnsold == 0
            ? 'Every listed product has seen demand already.'
            : '${widget.productsUnsold} product${widget.productsUnsold == 1 ? '' : 's'} still waiting for a first sale.';

    return _buildPanel(
      title: 'Store pulse',
      subtitle: 'The seller updates that deserve attention today.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPulseRow(
            label: 'Store status',
            value: 'Approved',
            valueColor: _vendorSuccess,
          ),
          const SizedBox(height: 12),
          _buildPulseRow(
            label: 'Alerts',
            value:
                notificationCount == 0 ? 'All clear' : '$notificationCount pending',
            valueColor:
                notificationCount == 0 ? deepNavyBlue : _vendorWarning,
          ),
          const SizedBox(height: 12),
          _buildPulseRow(
            label: 'Followers',
            value: '${widget.followersCount}',
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _vendorSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _vendorBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: deepNavyBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.insights_outlined,
                    color: deepNavyBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inventory note',
                        style: TextStyle(
                          color: deepNavyBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        inventoryMessage,
                        style: const TextStyle(
                          color: _vendorTextMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    return _buildPanel(
      title: 'Vendor account',
      subtitle: 'Manage your seller access carefully.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'If you no longer want to sell on NaijaGo, you can leave the vendor program here. This removes your seller access after confirmation.',
            style: TextStyle(
              color: _vendorTextMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final bool? confirmed = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const VendorDesistConfirmationScreen(),
                ),
              );
              if (confirmed == true) {
                _desistFromVendor();
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Leave Vendor Program'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _vendorDanger,
              foregroundColor: whiteBackground,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateExperience({
    required String badge,
    required String title,
    required String description,
    required IconData icon,
    String? primaryLabel,
    VoidCallback? onPrimaryPressed,
    required List<Widget> sections,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [deepNavyBlue, _vendorBlue],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: deepNavyBlue.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroPill(icon: icon, label: badge),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          style: const TextStyle(
                            color: whiteBackground,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: const TextStyle(
                            color: _vendorSoftText,
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                        if (primaryLabel != null && onPrimaryPressed != null) ...[
                          const SizedBox(height: 22),
                          ElevatedButton.icon(
                            onPressed: onPrimaryPressed,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(primaryLabel),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: greenYellow,
                              foregroundColor: deepNavyBlue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: whiteBackground.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      icon,
                      color: whiteBackground,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < sections.length; i++) ...[
              const SizedBox(height: 16),
              sections[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: whiteBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _vendorBorder),
        boxShadow: [
          BoxShadow(
            color: deepNavyBlue.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: deepNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: _vendorTextMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildHeroPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: whiteBackground.withValues(alpha: 0.12),
        border: Border.all(
          color: whiteBackground.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: whiteBackground, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: whiteBackground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _vendorSoftText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: whiteBackground,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _vendorSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: deepNavyBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: deepNavyBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: deepNavyBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _vendorTextMuted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _vendorTextMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: deepNavyBlue,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _vendorSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _vendorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: deepNavyBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: deepNavyBlue),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: deepNavyBlue,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _vendorTextMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseRow({
    required String label,
    required String value,
    Color valueColor = deepNavyBlue,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _vendorTextMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep({
    required String title,
    required String description,
    required _ReviewStepState state,
  }) {
    final bool isComplete = state == _ReviewStepState.complete;
    final bool isActive = state == _ReviewStepState.active;
    final Color badgeColor = isComplete
        ? _vendorSuccess
        : isActive
            ? _vendorWarning
            : _vendorBorder;
    final Color iconColor = isComplete
        ? _vendorSuccess
        : isActive
            ? _vendorWarning
            : _vendorTextMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                badgeColor.withValues(alpha: isComplete || isActive ? 0.12 : 0.4),
          ),
          child: Icon(
            isComplete
                ? Icons.check_rounded
                : isActive
                    ? Icons.more_horiz_rounded
                    : Icons.circle_outlined,
            size: 18,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: deepNavyBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: _vendorTextMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Future<List<Map<String, String>>> _fetchBanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        debugPrint('Authentication token not found. Cannot fetch banks.');
        return [];
      }

      final backendResp = await http.get(
        Uri.parse('$baseUrl/api/wallet/banks'),
        headers: _authHeaders(token),
      );

      if (backendResp.statusCode == 200) {
        final parsed = jsonDecode(backendResp.body);
        final List data = parsed['banks'] ?? [];
        return data.map<Map<String, String>>((b) => {
          'name': b['name'].toString(),
          'code': b['code'].toString(),
        }).toList();
      } else {
        debugPrint('Backend bank list error: ${backendResp.statusCode} ${backendResp.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching banks: $e');
      return [];
    }
  }

Future<Map<String, String>?> _showBankSelectionDialog(List<Map<String, String>> banks) {
  List<Map<String, String>> filteredBanks = List.from(banks); // <-- persists

  return showDialog<Map<String, String>?>(
    context: context,
    builder: (context) {
      final TextEditingController searchController = TextEditingController();

      return StatefulBuilder(
        builder: (context, setState) {
          void filterBanks(String query) {
            setState(() {
              if (query.isEmpty) {
                filteredBanks = List.from(banks);
              } else {
                filteredBanks = banks
                    .where((bank) =>
                        bank['name']!.toLowerCase().contains(query.toLowerCase()))
                    .toList();
              }
            });
          }

          return AlertDialog(
            backgroundColor: whiteBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: _vendorBorder),
            ),
            title: const Text('Select a Bank', style: TextStyle(color: deepNavyBlue)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: _inputDecoration('Search for a bank...'),
                    onChanged: filterBanks,
                  ),
                  const SizedBox(height: 12),
                  if (filteredBanks.isEmpty)
                    const Text(
                      'No banks found.',
                      style: TextStyle(
                        color: deepNavyBlue,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    SizedBox(
                      height: 320,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredBanks.length,
                        itemBuilder: (context, index) {
                          final bank = filteredBanks[index];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            title: Text(
                              bank['name']!,
                              style: const TextStyle(
                                color: deepNavyBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(context).pop(bank);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: deepNavyBlue)),
              ),
            ],
          );
        },
      );
    },
  );
}

  // UPDATED: This function now coordinates the entire two-step withdrawal process.
  void _showWithdrawDialog() async {
    _showSnack('Loading banks...');
    final banks = await _fetchBanks();

    if (!mounted) return;

    if (banks.isEmpty) {
      _showSnack('Failed to load bank list. Check your connection and try again.');
      return;
    }
    
    final TextEditingController accountNumberController = TextEditingController(text: _savedAccountNumber ?? '');
    final TextEditingController accountNameController = TextEditingController(text: '');
    final TextEditingController amountController = TextEditingController();
    
    String? selectedBankCode = _savedBankCode;
    String? selectedBankName = _savedBankName;
    bool saveDetails = false;

    // Show the initial dialog to collect withdrawal details.
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: whiteBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: _vendorBorder),
              ),
              title: const Text(
                'Withdraw Funds',
                style: TextStyle(color: deepNavyBlue),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Move available vendor earnings to your bank account securely.',
                      style: TextStyle(
                        color: _vendorTextMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_savedBankName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          'Last Used Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: deepNavyBlue,
                          ),
                        ),
                      ),
                    
                    GestureDetector(
                      onTap: () async {
                        final result = await _showBankSelectionDialog(banks);
                        if (result != null) {
                          setState(() {
                            selectedBankName = result['name'];
                            selectedBankCode = result['code'];
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                        decoration: BoxDecoration(
                          color: whiteBackground,
                          border: Border.all(color: _vendorBorder),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedBankName ?? 'Select a bank...',
                                style: TextStyle(
                                  color: selectedBankName == null ? deepNavyBlue.withValues(alpha: 0.6) : deepNavyBlue,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: deepNavyBlue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: accountNumberController,
                      decoration: _inputDecoration('Account Number'),
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: accountNameController,
                      decoration: _inputDecoration('Account Holder Name'),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      decoration: _inputDecoration('Amount (₦)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: saveDetails,
                          onChanged: (bool? newValue) {
                            setState(() {
                              saveDetails = newValue ?? false;
                            });
                          },
                          activeColor: deepNavyBlue,
                        ),
                        const Text(
                          'Save these details?',
                          style: TextStyle(color: _vendorTextMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: deepNavyBlue)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validate inputs and then call the new function to start the OTP flow.
                    final acct = accountNumberController.text.trim();
                    final accountName = accountNameController.text.trim();
                    final amtStr = amountController.text.trim();
                    final amount = double.tryParse(amtStr);

                    if (selectedBankCode == null || selectedBankCode!.isEmpty) {
                      _showSnack('Please select a bank.');
                      return;
                    }
                    if (acct.length != 10 || int.tryParse(acct) == null) {
                      _showSnack('Account number must be 10 digits.');
                      return;
                    }
                    if (accountName.isEmpty) {
                      _showSnack('Please enter account holder name.');
                      return;
                    }
                    if (amount == null || amount <= 0) {
                      _showSnack('Enter a valid amount greater than 0.');
                      return;
                    }
                    if (amount > widget.vendorWalletBalance) {
                      _showSnack('Insufficient vendor wallet balance.');
                      return;
                    }
                    
                    Navigator.pop(context); // Dismiss the first dialog
                    _requestOtpAndWithdraw(
                      bankCode: selectedBankCode!,
                      accountNumber: acct,
                      accountName: accountName,
                      amount: amount,
                      saveDetails: saveDetails,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepNavyBlue,
                    foregroundColor: whiteBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Request OTP'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _sendOtpRequest(String token) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/wallet/request-otp'),
        headers: _authHeaders(token),
        body: jsonEncode({}),
      );
      
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _showSnack(body['message'] ?? 'OTP sent to your email.');
        return true;
      } else {
        final body = jsonDecode(resp.body);
        _showSnack(body['message'] ?? 'Failed to send OTP.');
        return false;
      }
    } catch (e) {
      debugPrint('OTP request error: $e');
      _showSnack('Network error during OTP request.');
      return false;
    }
  }

  Future<void> _requestOtpAndWithdraw({
    required String bankCode,
    required String accountNumber,
    required String accountName,
    required double amount,
    required bool saveDetails,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        _showSnack('Please log in again.');
        return;
      }
    
      _showSnack('Sending OTP to your registered email...');
    
      bool otpSent = await _sendOtpRequest(token);
    
      if (!otpSent) {
        _showSnack('Failed to send OTP. Please try again.');
        return;
      }
    
      final otp = await _showOtpDialog(
        onResend: () => _resendOtp(token),
      );

      if (otp != null && otp.isNotEmpty) {
        _submitWithdrawal(
          bankCode: bankCode,
          accountNumber: accountNumber,
          accountName: accountName,
          amount: amount,
          otp: otp,
          saveDetails: saveDetails,
        );
      } else {
        _showSnack('OTP submission canceled.');
      }
    } catch (e) {
      _showSnack('Network error during OTP request.');
      debugPrint('OTP request network error: $e');
    }
  }

  Future<String?> _showOtpDialog({required Future<bool> Function() onResend}) {
    final TextEditingController otpController = TextEditingController();
    
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        int otpCountdown = 300;
        Timer? timer;

        return StatefulBuilder(
          builder: (context, setState) {
            
            if (timer == null || !timer!.isActive) {
              timer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (!mounted) {
                  timer.cancel();
                  return;
                }
                setState(() {
                  if (otpCountdown > 0) {
                    otpCountdown--;
                  } else {
                    timer.cancel();
                  }
                });
              });
            }

            String minutes = (otpCountdown ~/ 60).toString().padLeft(2, '0');
            String seconds = (otpCountdown % 60).toString().padLeft(2, '0');
            String countdownText = '$minutes:$seconds';

            return AlertDialog(
              backgroundColor: whiteBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: _vendorBorder),
              ),
              title: const Text('Enter OTP', style: TextStyle(color: deepNavyBlue)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'An OTP has been sent to your email. Please enter it below.',
                    style: TextStyle(color: deepNavyBlue.withValues(alpha: 0.8)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    decoration: _inputDecoration('Enter the 6-digit OTP'),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: otpCountdown > 0,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Time remaining: $countdownText',
                    style: TextStyle(
                      color: otpCountdown > 60 ? deepNavyBlue : _vendorDanger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                if (otpCountdown == 0)
                  ElevatedButton(
                    onPressed: () async {
                      timer?.cancel();
                      bool success = await onResend();
                      if (!context.mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('New OTP sent!'))
                        );
                      }
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: whiteBackground,
                      foregroundColor: deepNavyBlue,
                      side: const BorderSide(color: _vendorBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Resend OTP'),
                  ),
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel', style: TextStyle(color: deepNavyBlue)),
                ),
                ElevatedButton(
                  onPressed: otpCountdown > 0 && otpController.text.length == 6
                      ? () {
                          timer?.cancel();
                          Navigator.pop(context, otpController.text.trim());
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepNavyBlue,
                    foregroundColor: whiteBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _resendOtp(String token) async {
    _showSnack('Requesting new OTP...');
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/wallet/request-otp'),
        headers: _authHeaders(token),
        body: jsonEncode({}),
      );
    
      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        _showSnack(body['message'] ?? 'New OTP sent to your email.');
        return true;
      } else {
        _showSnack(body['message'] ?? 'Failed to resend OTP. Please try again.');
        return false;
      }
    } catch (e) {
      _showSnack('Network error during OTP resend.');
      debugPrint('OTP resend network error: $e');
      return false;
    }
  }

  Future<void> _submitWithdrawal({
    required String bankCode,
    required String accountNumber,
    required String accountName,
    required double amount,
    required String otp,
    required bool saveDetails,
  }) async {
    _showSnack('Processing withdrawal...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        _showSnack('Please log in again.');
        return;
      }

      if (saveDetails) {
        await prefs.setString('savedBankName_vendor', _savedBankName!);
        await prefs.setString('savedBankCode_vendor', bankCode);
        await prefs.setString('savedAccountNumber_vendor', accountNumber);
        _loadSavedWithdrawalDetails();
      }

      final resp = await http.post(
        Uri.parse('$baseUrl/api/wallet/withdraw'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'bank_code': bankCode,
          'account_number': accountNumber,
          'account_name': accountName,
          'amount': amount,
          'otp': otp,
          'wallet_type': 'vendor',
        }),
      );

      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        _showSnack(body['message'] ?? 'Withdrawal successful.');
        widget.onRefresh();
      } else {
        _showSnack(body['message'] ?? 'Withdrawal failed.');
        debugPrint('Withdraw error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _showSnack('Network error during withdrawal.');
      debugPrint('Withdraw network error: $e');
    }
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: whiteBackground,
    labelStyle: const TextStyle(color: _vendorTextMuted),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _vendorBorder),
      borderRadius: BorderRadius.circular(16),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: deepNavyBlue, width: 1.3),
      borderRadius: BorderRadius.circular(16),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  );

  Future<void> _desistFromVendor() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      _showSnack('Authentication token not found. Please log in again.');
      return;
    }

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/desist-vendor');
      final response = await http.put(
        url,
        headers: _authHeaders(token),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Successfully desisted from vendor status.')),
        );
        widget.onRefresh();
      } else {
        _showSnack(responseData['message'] ?? 'Failed to desist from vendor status.');
      }
    } catch (e) {
      _showSnack('An error occurred while desisting: $e');
      debugPrint('Desist vendor network error: $e');
    }
  }
}

enum _ReviewStepState { pending, active, complete }

class _VendorBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _VendorBullet({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: deepNavyBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: deepNavyBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: deepNavyBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: _vendorTextMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
