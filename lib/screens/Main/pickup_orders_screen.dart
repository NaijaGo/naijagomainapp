import 'dart:convert';

import 'package:flutter/material.dart';

import '../../widgets/visible_back_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

class PickupOrdersScreen extends StatefulWidget {
  const PickupOrdersScreen({super.key});

  @override
  State<PickupOrdersScreen> createState() => _PickupOrdersScreenState();
}

class _PickupOrdersScreenState extends State<PickupOrdersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService.get('/api/pickup/my-orders');
      if (response.statusCode != 200) throw Exception();
      final data = (jsonDecode(response.body) as List)
          .cast<Map<String, dynamic>>();
      if (mounted)
        setState(() {
          _orders = data;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Unable to connect. Check your internet and try again.';
          _loading = false;
        });
    }
  }

  String _status(String value) =>
      const {
        'processing': 'Order received',
        'accepted': 'Vendor accepted',
        'preparing': 'Preparing',
        'ready_for_customer_pickup': 'Ready for pickup',
        'picked_up': 'Picked up / Completed',
        'cancelled': 'Cancelled',
      }[value] ??
      value.replaceAll('_', ' ');

  Future<void> _open(Map<String, dynamic> summary) async {
    final response = await ApiService.get(
      '/api/pickup/my-orders/${summary['_id']}',
    );
    if (response.statusCode != 200 || !mounted) return;
    final order = jsonDecode(response.body) as Map<String, dynamic>;
    final vendor = order['vendor'] as Map<String, dynamic>? ?? {};
    final settings = vendor['pickupSettings'] as Map<String, dynamic>? ?? {};
    final location = vendor['businessLocation'] as Map<String, dynamic>? ?? {};
    final credential = order['pickupCredential'] as Map<String, dynamic>? ?? {};
    final phone =
        '${settings['phoneNumber'] ?? vendor['businessSupportPhone'] ?? vendor['phoneNumber'] ?? ''}';
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .86,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _status('${order['shipmentStatus'] ?? ''}'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '${settings['shopName'] ?? vendor['businessName'] ?? order['sellerName'] ?? 'Pickup location'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('${location['formattedAddress'] ?? ''}'),
            if ('${settings['instructions'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Instructions: ${settings['instructions']}'),
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: location['latitude'] == null
                      ? null
                      : () => launchUrl(
                          Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${location['latitude']},${location['longitude']}',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                  icon: const Icon(Icons.directions),
                  label: const Text('Open in Maps'),
                ),
                OutlinedButton.icon(
                  onPressed: phone.isEmpty
                      ? null
                      : () => launchUrl(Uri.parse('tel:$phone')),
                  icon: const Icon(Icons.call),
                  label: const Text('Call store'),
                ),
              ],
            ),
            if (credential.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('PICKUP CODE'),
                      SelectableText(
                        '${credential['pickupCode'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      QrImageView(
                        data: '${credential['qrPayload'] ?? ''}',
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                      const Text(
                        'Show this code only when you arrive at the store.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            ...((order['items'] as List<dynamic>? ?? []).map(
              (item) => ListTile(
                title: Text('${item['name'] ?? 'Product'}'),
                subtitle: Text('Quantity: ${item['qty'] ?? 1}'),
                trailing: Text('₦${item['price'] ?? 0}'),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
          leading: const VisibleBackButton(),title: const Text('Pickup Orders')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              children: [
                const SizedBox(height: 160),
                const Icon(Icons.cloud_off_outlined, size: 56),
                Center(child: Text(_error!)),
                Center(
                  child: FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                ),
              ],
            )
          : _orders.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 160),
                Icon(Icons.storefront_outlined, size: 64),
                Center(child: Text('No pickup orders yet')),
                Center(
                  child: Text('Choose Pick up during checkout to order ahead.'),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final order = _orders[index];
                final vendor = order['vendor'] as Map<String, dynamic>? ?? {};
                final id = '${order['_id']}';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.shopping_bag_outlined),
                    ),
                    title: Text(
                      '${vendor['businessName'] ?? order['sellerName'] ?? 'Pickup store'}',
                    ),
                    subtitle: Text(
                      '${_status('${order['shipmentStatus'] ?? ''}')} • #${id.substring(0, 8).toUpperCase()}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(order),
                  ),
                );
              },
            ),
    ),
  );
}
