// my_orders_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';
import '../../models/user.dart';
import '../../widgets/order_tracking_widget.dart';
import '../../widgets/tech_glow_background.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<dynamic> _orders = []; // Changed to dynamic since we get raw JSON
  bool _isLoading = true;

  Timer? _pollingTimer;
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserIdAndOrders();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isLoading) {
        await _fetchOrders();
        _pollCount++;
        if (_pollCount >= 5) {
          await _updatePendingOrdersToProcessing();
          _pollCount = 0;
        }
      }
    });
  }

  Future<void> _updatePendingOrdersToProcessing() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    if (token.isEmpty) {
      if (kDebugMode) {
        debugPrint('❌ No token found, cannot update pending orders.');
      }
      return;
    }

    final url = '$baseUrl/api/orders/update-pending-to-processing';

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (kDebugMode) {
          debugPrint('✅ Updated pending orders: ${decoded['message']}');
        }
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchOrders();
      } else {
        if (kDebugMode) {
          debugPrint(
            '❌ Failed to update pending orders. Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Exception updating pending orders: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserIdAndOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user');

    if (userData != null) {
      try {
        final decodedUser = json.decode(userData);
        final user = User.fromJson(decodedUser);

        if (user.id.isEmpty) {
          if (kDebugMode) {
            debugPrint('❌ ERROR: User ID is empty!');
          }
          setState(() => _isLoading = false);
          return;
        }

        await _fetchOrders();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ ERROR decoding user: $e');
        }
        setState(() => _isLoading = false);
      }
    } else {
      if (kDebugMode) {
        debugPrint('⚠️ No user found in SharedPreferences.');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    if (token.isEmpty) {
      if (kDebugMode) {
        debugPrint('❌ No token found, cannot fetch orders.');
      }
      setState(() => _isLoading = false);
      return;
    }

    final url = '$baseUrl/api/orders/my';
    if (kDebugMode) {
      debugPrint('🌐 Fetching orders from: $url');
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        List<dynamic> orderList = [];
        if (decoded is List) {
          orderList = decoded;
          if (kDebugMode) {
            debugPrint('✅ Got ${orderList.length} orders from API');

            // Debug the first order's structure
            if (orderList.isNotEmpty) {
              final firstOrder = orderList.first as Map<String, dynamic>;
              debugPrint('\n📦 === DEBUG ORDER STRUCTURE ===');
              debugPrint('Order ID: ${firstOrder['_id']}');

              // Check all available keys
              debugPrint('Available keys: ${firstOrder.keys.toList()}');

              // Specifically check price fields
              debugPrint('\n💰 Price fields:');
              debugPrint(
                '  totalSubtotal: ${firstOrder['totalSubtotal']} (type: ${firstOrder['totalSubtotal']?.runtimeType})',
              );
              debugPrint(
                '  totalPrice: ${firstOrder['totalPrice']} (type: ${firstOrder['totalPrice']?.runtimeType})',
              );
              debugPrint(
                '  totalShippingPrice: ${firstOrder['totalShippingPrice']} (type: ${firstOrder['totalShippingPrice']?.runtimeType})',
              );
              debugPrint(
                '  totalTaxPrice: ${firstOrder['totalTaxPrice']} (type: ${firstOrder['totalTaxPrice']?.runtimeType})',
              );

              // Check shipments
              if (firstOrder.containsKey('shipments')) {
                final shipments = firstOrder['shipments'] as List;
                debugPrint('\n🚚 Shipments: ${shipments.length}');
                if (shipments.isNotEmpty) {
                  final firstShipment = shipments.first as Map<String, dynamic>;
                  debugPrint(
                    '  First shipment subtotal: ${firstShipment['subtotal']}',
                  );
                  debugPrint(
                    '  First shipment shippingPrice: ${firstShipment['shippingPrice']}',
                  );

                  // Check items in shipment
                  if (firstShipment.containsKey('items')) {
                    final items = firstShipment['items'] as List;
                    debugPrint('  Items in shipment: ${items.length}');
                    if (items.isNotEmpty) {
                      final firstItem = items.first as Map<String, dynamic>;
                      debugPrint('  First item:');
                      debugPrint('    Name: ${firstItem['name']}');
                      debugPrint(
                        '    Price: ${firstItem['price']} (type: ${firstItem['price']?.runtimeType})',
                      );
                      debugPrint('    Quantity: ${firstItem['quantity']}');
                    }
                  }
                }
              }
              debugPrint('===============================\n');
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ Unexpected response format: $decoded');
          }
          setState(() => _isLoading = false);
          return;
        }

        setState(() {
          _orders = orderList;
          _isLoading = false;
        });
      } else {
        if (kDebugMode) {
          debugPrint('❌ Failed to load orders. Status: ${response.statusCode}');
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Exception while fetching orders: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  String _getOrderStatus(Map<String, dynamic> order) {
    return order['mainOrderStatus']?.toString() ?? 'pending_payment';
  }

  double _getOrderTotal(Map<String, dynamic> order) {
    // Try to get from order
    final orderTotal = (order['totalPrice'] as num?)?.toDouble();
    if (orderTotal != null && orderTotal > 0) {
      return orderTotal;
    }

    // Calculate manually if not available
    final subtotal = _getSubtotal(order);
    final shipping = _getShippingPrice(order);
    final tax = (order['totalTaxPrice'] as num?)?.toDouble() ?? 0.0;

    return subtotal + shipping + tax;
  }

  double _getShippingPrice(Map<String, dynamic> order) {
    return (order['totalShippingPrice'] as num?)?.toDouble() ?? 0.0;
  }

  double _getSubtotal(Map<String, dynamic> order) {
    // First try to get from the order
    final orderSubtotal = (order['totalSubtotal'] as num?)?.toDouble();
    if (orderSubtotal != null && orderSubtotal > 0) {
      return orderSubtotal;
    }

    // Fallback 1: Try to get from shipments
    final shipments = order['shipments'] as List<dynamic>? ?? [];
    double subtotalFromShipments = 0.0;

    for (final shipment in shipments) {
      final shipmentSubtotal = (shipment['subtotal'] as num?)?.toDouble();
      if (shipmentSubtotal != null) {
        subtotalFromShipments += shipmentSubtotal;
      }
    }

    if (subtotalFromShipments > 0) {
      return subtotalFromShipments;
    }

    // Fallback 2: Calculate from items directly
    return _calculateSubtotalFromItems(order);
  }

  double _calculateSubtotalFromItems(Map<String, dynamic> order) {
    final shipments = order['shipments'] as List<dynamic>? ?? [];
    double subtotal = 0.0;

    for (final shipment in shipments) {
      final items = shipment['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        subtotal += price * quantity;
      }
    }

    return subtotal;
  }

  List<dynamic> _getAllItems(Map<String, dynamic> order) {
    final List<dynamic> allItems = [];
    final shipments = order['shipments'] as List<dynamic>? ?? [];

    for (final shipment in shipments) {
      final items = shipment['items'] as List<dynamic>? ?? [];
      allItems.addAll(items);
    }

    return allItems;
  }

  int _getTotalItemCount(Map<String, dynamic> order) {
    int total = 0;
    final shipments = order['shipments'] as List<dynamic>? ?? [];

    for (final shipment in shipments) {
      final items = shipment['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        total += (item['quantity'] as num?)?.toInt() ?? 0;
      }
    }

    return total;
  }

  Widget _buildOrderHeader(Map<String, dynamic> order, ColorScheme color) {
    final status = _getOrderStatus(order);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order['_id']?.toString().substring(0, 8) ?? ''}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status, color),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: color.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Ordered: ${_formatDateTime(order['createdAt']?.toString())}',
                style: TextStyle(
                  fontSize: 14,
                  color: color.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          if (order['paidAt'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.payment,
                  size: 16,
                  color: color.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Paid: ${_formatDateTime(order['paidAt']?.toString())}',
                  style: TextStyle(
                    fontSize: 14,
                    color: color.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
          if (order['deliveredAt'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.delivery_dining,
                  size: 16,
                  color: color.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Delivered: ${_formatDateTime(order['deliveredAt']?.toString())}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status, ColorScheme color) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'shipped':
      case 'out_for_delivery':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return color.primary;
    }
  }

  Widget _buildOrderSummary(Map<String, dynamic> order, ColorScheme color) {
    // Calculate or get amounts
    final subtotal = _getSubtotal(order);
    final shipping = _getShippingPrice(order);
    final tax = (order['totalTaxPrice'] as num?)?.toDouble() ?? 0.0;
    final total = _getOrderTotal(order);

    // Debug output
    if (kDebugMode) {
      debugPrint(
        '\n=== ORDER SUMMARY DEBUG for Order ${order['_id']?.toString().substring(0, 8)} ===',
      );
      debugPrint('Items count: ${_getTotalItemCount(order)}');
      debugPrint('Subtotal: ₦$subtotal');
      debugPrint('Shipping: ₦$shipping');
      debugPrint('Tax: ₦$tax');
      debugPrint('Total: ₦$total');
      debugPrint('==========================================\n');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            'Items (${_getTotalItemCount(order)})',
            '₦${subtotal.toStringAsFixed(2)}',
            color,
          ),
          _buildSummaryRow(
            'Delivery Fee',
            '₦${shipping.toStringAsFixed(2)}',
            color,
          ),
          if (tax > 0)
            _buildSummaryRow('Tax', '₦${tax.toStringAsFixed(2)}', color),
          const Divider(height: 24),
          _buildSummaryRow(
            'Total Amount',
            '₦${total.toStringAsFixed(2)}',
            color,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    ColorScheme color, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              color: isTotal
                  ? color.primary
                  : color.onSurface.withValues(alpha: 0.7),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? color.primary : color.onSurface,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingDetails(Map<String, dynamic> order, ColorScheme color) {
    final shipping = order['shippingAddress'];
    if (shipping == null || shipping is! Map) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: color.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            shipping['address']?.toString() ?? 'No address provided',
            style: TextStyle(fontSize: 15, color: color.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            '${shipping['city'] ?? ''}, ${shipping['postalCode'] ?? ''}',
            style: TextStyle(
              fontSize: 14,
              color: color.onSurface.withValues(alpha: 0.8),
            ),
          ),
          Text(
            shipping['country']?.toString() ?? '',
            style: TextStyle(
              fontSize: 14,
              color: color.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGallery(Map<String, dynamic> order) {
    final allItems = _getAllItems(order);
    if (allItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Order Images',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final item = allItems[index];
              final imageUrl =
                  item['image']?.toString() ??
                  'https://placehold.co/100x100/CCCCCC/000000?text=No+Image';

              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey.shade400,
                              size: 40,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 100,
                      child: Text(
                        item['name']?.toString() ?? 'Unnamed Item',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item, ColorScheme color) {
    final imageUrl =
        item['image']?.toString() ??
        'https://placehold.co/80x80/CCCCCC/000000?text=No+Image';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final selectedSize = item['selectedSize'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey.shade400,
                    size: 30,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? 'Unnamed Product',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty: $quantity × ₦${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: color.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      '₦${(quantity * price).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color.primary,
                      ),
                    ),
                  ],
                ),
                if (selectedSize != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: _buildSizeDisplay(selectedSize),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeDisplay(dynamic selectedSize) {
    if (selectedSize is String) {
      return Text(
        'Size: $selectedSize',
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue.shade800,
          fontWeight: FontWeight.w500,
        ),
      );
    } else if (selectedSize is Map) {
      final label = selectedSize['label']?.toString();
      final length = selectedSize['length']?.toString();
      final width = selectedSize['width']?.toString();
      final height = selectedSize['height']?.toString();
      final unit = selectedSize['unit']?.toString() ?? 'CM';

      if (label != null && label.isNotEmpty) {
        return Text(
          'Size: $label',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade800,
            fontWeight: FontWeight.w500,
          ),
        );
      } else if (length != null || width != null || height != null) {
        return Text(
          'Dimensions: ${length ?? '0'}×${width ?? '0'}×${height ?? '0'} $unit',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade800,
            fontWeight: FontWeight.w500,
          ),
        );
      }
    }

    return Text(
      'Custom Size',
      style: TextStyle(
        fontSize: 12,
        color: Colors.blue.shade800,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return TechGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('My Orders'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _orders.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No orders yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchOrders,
                child: ListView.builder(
                  itemCount: _orders.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final order = _orders[index] as Map<String, dynamic>;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Header
                              _buildOrderHeader(order, color),

                              const SizedBox(height: 16),

                              // Tracking Timeline
                              OrderTrackingWidget(
                                key: ValueKey(
                                  '${order['_id']}-${_getOrderStatus(order)}',
                                ),
                                orderStatus: _getOrderStatus(order),
                              ),

                              const SizedBox(height: 20),

                              // Order Summary
                              _buildOrderSummary(order, color),

                              const SizedBox(height: 16),

                              // Shipping Details
                              _buildShippingDetails(order, color),

                              const SizedBox(height: 20),

                              // Product Gallery
                              _buildProductGallery(order),

                              const SizedBox(height: 16),

                              // Order Items
                              Text(
                                'Order Items',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: color.primary,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Detailed Items List
                              ..._getAllItems(order).map(
                                (item) => _buildOrderItem(
                                  item as Map<String, dynamic>,
                                  color,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Payment Method
                              if (order['paymentMethod'] != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        order['paymentMethod'] == 'Card'
                                            ? Icons.credit_card
                                            : order['paymentMethod'] == 'Wallet'
                                            ? Icons.account_balance_wallet
                                            : Icons.account_balance,
                                        color: color.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Paid with ${order['paymentMethod']}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: color.onSurface.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.check_circle,
                                        color:
                                            (order['isPaid'] as bool?) == true
                                            ? Colors.green
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
}
