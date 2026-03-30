// lib/screens/Main/orders_received_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../constants.dart';
import '../../widgets/vendor_ui.dart';

// ====== Data Models ======
class VendorOrder {
  final String id;
  final String userId;
  final String buyerName;
  final String? buyerEmail;
  final String? buyerPhone;
  final String orderStatus;
  final DateTime createdAt;
  final List<VendorOrderItem> items;

  const VendorOrder({
    required this.id,
    required this.userId,
    required this.buyerName,
    this.buyerEmail,
    this.buyerPhone,
    required this.orderStatus,
    required this.createdAt,
    required this.items,
  });

  // ✅ FIXED: Parse vendor shipments correctly
  factory VendorOrder.fromJson(Map<String, dynamic> json) {
    // For vendor shipments, the structure is different
    final mainOrder = json['mainOrder'] ?? {};
    final user = mainOrder['user'] ?? {};
    
    return VendorOrder(
      id: (json['_id'] ?? json['id']).toString(),
      userId: (user['_id'] ?? user['id'] ?? '').toString(),
      // ✅ Always show "Customer Order" for vendors (hides buyer info)
      buyerName: 'Customer Order',
      buyerEmail: null, // ✅ Hide email
      buyerPhone: null, // ✅ Hide phone
      // ✅ Use shipmentStatus instead of orderStatus
      orderStatus: (json['shipmentStatus'] ?? 'processing').toString(),
      createdAt: DateTime.tryParse(
              (json['createdAt'] ?? DateTime.now().toIso8601String()).toString()) ??
          DateTime.now(),
      // ✅ Use 'items' array from Shipment model
      items: (json['items'] as List? ?? [])
          .map((itemJson) => VendorOrderItem.fromJson(itemJson))
          .toList(),
    );
  }

  VendorOrder copyWith({
    String? orderStatus,
  }) {
    return VendorOrder(
      id: id,
      userId: userId,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
      buyerPhone: buyerPhone,
      orderStatus: orderStatus ?? this.orderStatus,
      createdAt: createdAt,
      items: items,
    );
  }
}

class VendorOrderItem {
  final String productId;
  final String productName;
  final String? productImageUrl;
  final int quantity;
  final double unitPrice;

  const VendorOrderItem({
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.quantity,
    required this.unitPrice,
  });

  factory VendorOrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    return VendorOrderItem(
      productId: (product['_id'] ?? product['id'] ?? '').toString(),
      productName: (product['name'] ?? 'Product').toString(),
      productImageUrl: (product['imageUrls'] is List && product['imageUrls'].isNotEmpty)
          ? product['imageUrls'][0] as String
          : null,
      quantity: int.tryParse('${json['quantity'] ?? 1}') ?? 1,
      unitPrice: double.tryParse('${json['price'] ?? 0}') ?? 0,
    );
  }
}

// 📦 NEW DATA MODEL FOR VENDOR STATS
class VendorStats {
  final int totalProducts;
  final int productsSold;
  final int productsUnsold;

  const VendorStats({
    required this.totalProducts,
    required this.productsSold,
    required this.productsUnsold,
  });

  factory VendorStats.fromJson(Map<String, dynamic> json) {
    return VendorStats(
      totalProducts: json['totalProducts'] as int? ?? 0,
      productsSold: json['productsSold'] as int? ?? 0,
      productsUnsold: json['productsUnsold'] as int? ?? 0,
    );
  }
}

// ====== Services (New) ======
class OrdersService {
  static const String _ordersListEndpoint = '/api/orders/vendor';
  static const String _updateOrderStatusEndpoint = '/api/orders';
  // 🔗 NEW: Endpoint for vendor stats
  static const String _vendorStatsEndpoint = '/api/vendor/stats';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // ✅ NEW METHOD: Fetch vendor statistics
  Future<VendorStats> fetchVendorStats() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl$_vendorStatsEndpoint');
    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return VendorStats.fromJson(data);
    } else {
      final message = _safeMessage(resp.body) ?? 'Failed to load vendor stats (HTTP ${resp.statusCode}).';
      throw Exception(message);
    }
  }

  Future<List<VendorOrder>> fetchOrders() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl$_ordersListEndpoint');
    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return (data as List).map((e) => VendorOrder.fromJson(e)).toList();
    } else {
      final message = _safeMessage(resp.body) ?? 'Failed to load orders (HTTP ${resp.statusCode}).';
      throw Exception(message);
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl$_updateOrderStatusEndpoint/$orderId/status');
    final resp = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({'status': newStatus}),
    );

    if (resp.statusCode != 200) {
      final message = _safeMessage(resp.body) ?? 'Failed to update order status.';
      throw Exception(message);
    }
  }

  String? _safeMessage(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['message'] is String) return m['message'];
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ====== Screen ======
class OrdersRecivedScreen extends StatefulWidget {
  const OrdersRecivedScreen({super.key});

  @override
  State<OrdersRecivedScreen> createState() => _OrdersRecivedScreenState();
}

class _OrdersRecivedScreenState extends State<OrdersRecivedScreen> {
  final OrdersService _ordersService = OrdersService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<VendorOrder> _allOrders = [];
  List<VendorOrder> _displayedOrders = [];
  // 📊 NEW: Vendor statistics variable
  VendorStats? _vendorStats;
  bool _isLoading = false;
  String _errorMessage = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ✅ UPDATED METHOD: Fetch both stats and orders
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // Fetch stats first
      final stats = await _ordersService.fetchVendorStats();
      // Fetch orders next
      _allOrders = await _ordersService.fetchOrders();

      setState(() {
        _vendorStats = stats;
      });
      _filterOrders();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterOrders() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _displayedOrders = _allOrders.where((order) {
        final matchesStatus = _statusFilter == 'all' || order.orderStatus == _statusFilter;
        // ✅ Search by product name only (not buyer name)
        final matchesSearch = query.isEmpty ||
            order.items.any((item) => item.productName.toLowerCase().contains(query));
        return matchesStatus && matchesSearch;
      }).toList();
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _filterOrders();
    });
  }

  Future<void> _updateOrderStatus(VendorOrder order, String newStatus) async {
    final oldStatus = order.orderStatus;
    final idx = _displayedOrders.indexWhere((o) => o.id == order.id);
    if (idx == -1) return;

    // Optimistic update
    setState(() {
      _displayedOrders[idx] = order.copyWith(orderStatus: newStatus);
    });

    try {
      await _ordersService.updateOrderStatus(order.id, newStatus);
      _showSnack('Order updated to "$newStatus".');
      _fetchData(); // Refresh both stats and orders to get the latest data
    } catch (e) {
      // Rollback on failure
      setState(() {
        _displayedOrders[idx] = order.copyWith(orderStatus: oldStatus);
      });
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Theme.of(context).snackBarTheme.backgroundColor,
      ),
    );
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: VendorUi.theme,
      child: Scaffold(
        backgroundColor: VendorUi.surface,
        appBar: AppBar(
          title: const Text('Orders Received'),
          actions: [
            IconButton(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh orders',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _fetchData,
          color: VendorUi.deepNavyBlue,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHero()),
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildSummaryCards()),
              SliverToBoxAdapter(child: _buildFilters()),
              if (_errorMessage.isNotEmpty)
                SliverToBoxAdapter(
                  child: _ErrorState(
                    message: _errorMessage,
                    onRetry: _fetchData,
                  ),
                )
              else if (_isLoading)
                const _LoadingListSkeleton()
              else if (_displayedOrders.isEmpty)
                const SliverToBoxAdapter(child: _EmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: _displayedOrders.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = _displayedOrders[index];
                      return _OrderTile(
                        order: order,
                        onUpdateStatus: _updateOrderStatus,
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final pendingActions = _allOrders
        .where((order) => order.orderStatus != 'delivered' && order.orderStatus != 'cancelled')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: VendorPageHero(
        badge: 'Seller fulfilment',
        title: 'Orders received',
        subtitle:
            'Stay on top of incoming shipments, update fulfilment quickly, and track what your catalogue is moving.',
        icon: Icons.receipt_long_outlined,
        stats: [
          VendorHeroStat(label: 'Open actions', value: '$pendingActions'),
          VendorHeroStat(
            label: 'Products sold',
            value: '${_vendorStats?.productsSold ?? '-'}',
          ),
          VendorHeroStat(
            label: 'Unsold products',
            value: '${_vendorStats?.productsUnsold ?? '-'}',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: VendorPanel(
        title: 'Find an order',
        subtitle: 'Search by product name to reach the right shipment faster.',
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Search by product name...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final cards = [
      _StatCard(
        title: 'Total Products',
        value: _vendorStats == null ? '...' : '${_vendorStats!.totalProducts}',
        icon: Icons.inventory_2_outlined,
      ),
      _StatCard(
        title: 'Products Sold',
        value: _vendorStats == null ? '...' : '${_vendorStats!.productsSold}',
        icon: Icons.shopping_bag_outlined,
      ),
      _StatCard(
        title: 'Products Unsold',
        value: _vendorStats == null ? '...' : '${_vendorStats!.productsUnsold}',
        icon: Icons.assignment_late_outlined,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = constraints.maxWidth > 540
              ? (constraints.maxWidth - 24) / 3
              : constraints.maxWidth > 360
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((card) => SizedBox(width: tileWidth, child: card))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    final statuses = const [
      ['all', 'All'],
      ['pending', 'Pending'],
      ['processing', 'Processing'],
      ['ready_for_pickup', 'Ready for Pickup'],
      ['out_for_delivery', 'Out for Delivery'],
      ['delivered', 'Delivered'],
      ['cancelled', 'Cancelled'],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: VendorPanel(
        title: 'Fulfilment filters',
        subtitle: 'Switch between status views to focus on the next action.',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statuses.map((s) {
            final value = s[0];
            final label = s[1];
            return ChoiceChip(
              selected: _statusFilter == value,
              label: Text(label),
              onSelected: (sel) {
                setState(() {
                  _statusFilter = value;
                });
                _filterOrders();
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ====== Reusable Widgets (No Changes Needed) ======
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: VendorUi.panelDecoration(radius: 20),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: VendorUi.deepNavyBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: VendorUi.deepNavyBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: VendorUi.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: VendorUi.deepNavyBlue,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final VendorOrder order;
  final Future<void> Function(VendorOrder order, String newStatus) onUpdateStatus;

  const _OrderTile({
    required this.order,
    required this.onUpdateStatus,
  });

  Color _getBadgeColor(String status) {
    switch (status) {
      case 'delivered':
        return VendorUi.success;
      case 'ready_for_pickup':
        return VendorUi.blue;
      case 'out_for_delivery':
        return VendorUi.warning;
      case 'processing':
        return VendorUi.warning;
      case 'cancelled':
        return VendorUi.danger;
      default:
        return VendorUi.textMuted;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeColor(order.orderStatus);
    final totalAmount =
        order.items.fold(0.0, (sum, item) => sum + (item.unitPrice * item.quantity));
    final shortId = order.id.length > 8 ? '${order.id.substring(0, 8)}...' : order.id;

    return Container(
      decoration: VendorUi.panelDecoration(radius: 24),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shipment ID',
                      style: TextStyle(
                        color: VendorUi.textMuted.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shortId,
                      style: const TextStyle(
                        color: VendorUi.deepNavyBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.orderStatus.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VendorUi.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: VendorUi.border),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 18,
                  color: VendorUi.deepNavyBlue,
                ),
                SizedBox(width: 8),
                Text(
                  'Customer order',
                  style: TextStyle(
                    color: VendorUi.deepNavyBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ordered products',
            style: TextStyle(
              color: VendorUi.deepNavyBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _OrderItemRow(item: item),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order total',
                    style: TextStyle(
                      color: VendorUi.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₦${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: VendorUi.deepNavyBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Created ${_formatDate(order.createdAt)}',
                    style: const TextStyle(
                      color: VendorUi.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              _ActionsMenu(order: order, onUpdateStatus: onUpdateStatus),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final VendorOrderItem item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProductAvatar(imageUrl: item.productImageUrl, name: item.productName),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VendorUi.deepNavyBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Qty: ${item.quantity}',
                    style: const TextStyle(
                      color: VendorUi.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '₦${item.unitPrice.toStringAsFixed(2)} each',
                    style: const TextStyle(
                      color: VendorUi.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₦${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
              style: const TextStyle(
                color: VendorUi.deepNavyBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'Total',
              style: TextStyle(
                color: VendorUi.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProductAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;

  const _ProductAvatar({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (context, url) => _skeletonBox(),
          errorWidget: (context, url, error) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join()
        : 'P';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: VendorUi.deepNavyBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: VendorUi.deepNavyBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: VendorUi.deepNavyBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
      );
}

class _ActionsMenu extends StatelessWidget {
  final VendorOrder order;
  final Future<void> Function(VendorOrder order, String newStatus) onUpdateStatus;

  const _ActionsMenu({required this.order, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuItems = [];

    if (order.orderStatus == 'processing') {
      menuItems.add({'label': 'Ready for Pickup', 'value': 'ready_for_pickup', 'icon': Icons.inventory_2_outlined});
      menuItems.add({'label': 'Out for Delivery', 'value': 'out_for_delivery', 'icon': Icons.local_shipping_outlined});
    }
    if (order.orderStatus == 'ready_for_pickup') {
      menuItems.add({'label': 'Out for Delivery', 'value': 'out_for_delivery', 'icon': Icons.local_shipping_outlined});
    }
    if (order.orderStatus == 'out_for_delivery') {
      menuItems.add({'label': 'Mark Delivered', 'value': 'delivered', 'icon': Icons.check_circle_outline});
    }
    if (order.orderStatus != 'cancelled' && order.orderStatus != 'delivered') {
      menuItems.add({'label': 'Mark Cancelled', 'value': 'cancelled', 'icon': Icons.cancel_outlined});
    }

    if (menuItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: VendorUi.deepNavyBlue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.more_horiz,
          color: VendorUi.whiteBackground,
          size: 18,
        ),
      ),
      onSelected: (value) => onUpdateStatus(order, value),
      itemBuilder: (context) => menuItems
          .map((m) => PopupMenuItem<String>(
                value: m['value'] as String,
                child: Row(
                  children: [
                    Icon(
                      m['icon'] as IconData,
                      size: 18,
                      color: VendorUi.deepNavyBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(m['label'] as String),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: VendorPanel(
        title: 'No orders yet',
        subtitle:
            'When customers buy your products, their shipments will appear here for fulfilment.',
        child: Column(
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 80,
              color: VendorUi.deepNavyBlue.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your fulfilment queue is clear.',
              style: TextStyle(
                color: VendorUi.deepNavyBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: VendorPanel(
        title: 'Couldn’t load orders',
        subtitle: 'We hit a problem while reaching your fulfilment data.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: VendorUi.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingListSkeleton extends StatelessWidget {
  const _LoadingListSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => const _SkeletonTile(),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    Widget box({double h = 12, double w = double.infinity, double r = 8}) {
      return Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: VendorUi.deepNavyBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(r),
        ),
      );
    }

    return Container(
      decoration: VendorUi.panelDecoration(radius: 24),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          box(h: 56, w: 56, r: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                box(w: 120, h: 14),
                const SizedBox(height: 8),
                box(w: 190, h: 12),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: box(h: 12)),
                    const SizedBox(width: 8),
                    Expanded(child: box(h: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
