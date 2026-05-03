import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderTrackingWidget extends StatelessWidget {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> liveUpdates;

  const OrderTrackingWidget({
    super.key,
    required this.order,
    this.liveUpdates = const <Map<String, dynamic>>[],
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final mainStatus = _normalizeStatus(order['mainOrderStatus']);
    final shipmentStatus = _normalizeStatus(order['shipmentStatus']);

    if (mainStatus == 'cancelled' || shipmentStatus == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This order has been cancelled.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final stages = _buildStages();
    final rider = _rider;
    final shipments = _shipments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryBadges(color, mainStatus, shipmentStatus),
        const SizedBox(height: 16),
        _buildStageTimeline(color, stages),
        if (_hasTrackingMeta) ...[
          const SizedBox(height: 16),
          _buildTrackingMetaCard(color),
        ],
        if (rider != null) ...[
          const SizedBox(height: 16),
          _buildRiderCard(color, rider),
        ],
        if (shipments.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildShipmentBreakdown(color, shipments),
        ],
        if (liveUpdates.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildLiveUpdates(color),
        ],
      ],
    );
  }

  List<_TrackingStage> _buildStages() {
    final status = _normalizeStatus(order['mainOrderStatus']);
    final shipmentStatus = _normalizeStatus(order['shipmentStatus']);
    final isPaid = order['isPaid'] == true || order['paidAt'] != null;
    final hasRider = _rider != null || order['claimedAt'] != null;
    final isOutForDelivery =
        status == 'out_for_delivery' || shipmentStatus == 'out_for_delivery';

    var progressLevel = 0;

    if (isPaid) {
      progressLevel = 1;
    }

    if (<String>{
      'processing',
      'partially_shipped',
      'shipped',
      'delivered',
      'completed',
    }.contains(status) ||
        <String>{
          'processing',
          'ready_for_pickup',
          'out_for_delivery',
          'delivered',
        }.contains(shipmentStatus)) {
      progressLevel = 2;
    }

    if (hasRider ||
        <String>{
          'ready_for_pickup',
          'out_for_delivery',
          'delivered',
        }.contains(shipmentStatus)) {
      progressLevel = 3;
    }

    if (<String>{'shipped', 'delivered', 'completed'}.contains(status) ||
        status == 'out_for_delivery' ||
        <String>{'out_for_delivery', 'delivered'}.contains(shipmentStatus)) {
      progressLevel = 4;
    }

    if (<String>{'delivered', 'completed'}.contains(status) ||
        shipmentStatus == 'delivered') {
      progressLevel = 5;
    }

    final currentLevel = progressLevel == 5 ? 5 : progressLevel + 1;

    return <_TrackingStage>[
      _TrackingStage(
        title: isPaid ? 'Payment confirmed' : 'Payment pending',
        subtitle: isPaid
            ? 'Your payment was received successfully.'
            : 'We are waiting for payment confirmation.',
        icon: Icons.payments_outlined,
        isCompleted: progressLevel >= 1,
        isCurrent: currentLevel == 1,
      ),
      _TrackingStage(
        title: 'Order processing',
        subtitle: 'The vendor is preparing your items for dispatch.',
        icon: Icons.inventory_2_outlined,
        isCompleted: progressLevel >= 2,
        isCurrent: currentLevel == 2,
      ),
      _TrackingStage(
        title: hasRider ? 'Rider assigned' : 'Awaiting rider',
        subtitle: hasRider
            ? 'A dispatch rider has been linked to this order.'
            : 'We are arranging pickup for delivery.',
        icon: Icons.person_pin_circle_outlined,
        isCompleted: progressLevel >= 3,
        isCurrent: currentLevel == 3,
      ),
      _TrackingStage(
        title: isOutForDelivery
            ? 'Out for delivery'
            : 'Delivery in transit',
        subtitle: isOutForDelivery
            ? 'Your rider is currently heading to your address.'
            : 'The order will move here once pickup is complete.',
        icon: Icons.local_shipping_outlined,
        isCompleted: progressLevel >= 4,
        isCurrent: currentLevel == 4,
      ),
      _TrackingStage(
        title: progressLevel >= 5 ? 'Delivered' : 'Delivery completion',
        subtitle: progressLevel >= 5
            ? 'The delivery has been completed successfully.'
            : 'Final confirmation happens here after drop-off.',
        icon: Icons.home_filled,
        isCompleted: progressLevel >= 5,
        isCurrent: currentLevel == 5,
      ),
    ];
  }

  Widget _buildSummaryBadges(
    ColorScheme color,
    String mainStatus,
    String shipmentStatus,
  ) {
    final badges = <Widget>[
      _buildBadge(
        label: _displayStatus(mainStatus.isNotEmpty ? mainStatus : 'processing'),
        icon: Icons.receipt_long_outlined,
        color: color.primary,
      ),
      _buildBadge(
        label: order['isPaid'] == true ? 'Paid' : 'Awaiting payment',
        icon: Icons.account_balance_wallet_outlined,
        color: order['isPaid'] == true ? Colors.green : Colors.orange,
      ),
    ];

    if (shipmentStatus.isNotEmpty) {
      badges.add(
        _buildBadge(
          label: _displayStatus(shipmentStatus),
          icon: Icons.route_outlined,
          color: Colors.blue,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges,
    );
  }

  Widget _buildBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageTimeline(
    ColorScheme color,
    List<_TrackingStage> stages,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: List.generate(stages.length, (index) {
          final stage = stages[index];
          final isLast = index == stages.length - 1;
          final stageColor = stage.isCompleted || stage.isCurrent
              ? color.primary
              : Colors.grey.shade400;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: stage.isCompleted
                          ? Colors.green
                          : stage.isCurrent
                          ? color.primary
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: stageColor, width: 1.8),
                    ),
                    child: Icon(
                      stage.isCompleted ? Icons.check : stage.icon,
                      size: 18,
                      color: stage.isCompleted || stage.isCurrent
                          ? Colors.white
                          : stageColor,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 30,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: stage.isCompleted
                          ? Colors.green
                          : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: stage.isCompleted || stage.isCurrent
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stage.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  bool get _hasTrackingMeta {
    return _firstTrackingNumber.isNotEmpty || _firstLogisticsPartner.isNotEmpty;
  }

  Widget _buildTrackingMetaCard(ColorScheme color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tracking Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color.primary,
            ),
          ),
          if (_firstTrackingNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMetaRow(
              icon: Icons.qr_code_2_outlined,
              label: 'Tracking number',
              value: _firstTrackingNumber,
            ),
          ],
          if (_firstLogisticsPartner.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMetaRow(
              icon: Icons.business_outlined,
              label: 'Logistics partner',
              value: _firstLogisticsPartner,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 13.5,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiderCard(ColorScheme color, Map<String, dynamic> rider) {
    final location = rider['currentLocation'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(rider['currentLocation'] as Map<String, dynamic>)
        : <String, dynamic>{};

    final locationParts = <String>[
      if ((location['address']?.toString() ?? '').isNotEmpty)
        location['address'].toString(),
      if (location['lat'] != null && location['lng'] != null)
        '${(location['lat'] as num).toStringAsFixed(5)}, ${(location['lng'] as num).toStringAsFixed(5)}',
    ];

    final lastUpdated = _formatDateTime(
      location['lastUpdated']?.toString() ??
          rider['lastUpdated']?.toString() ??
          order['claimedAt']?.toString(),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rider Tracking',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color.primary,
            ),
          ),
          const SizedBox(height: 10),
          _buildMetaRow(
            icon: Icons.person_outline,
            label: 'Rider',
            value: rider['fullName']?.toString() ?? 'Assigned rider',
          ),
          if ((rider['phoneNumber']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMetaRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: rider['phoneNumber'].toString(),
            ),
          ],
          if ((rider['plateNumber']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMetaRow(
              icon: Icons.two_wheeler_outlined,
              label: 'Plate number',
              value: rider['plateNumber'].toString(),
            ),
          ],
          if (locationParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMetaRow(
              icon: Icons.my_location_outlined,
              label: 'Latest rider location',
              value: locationParts.join(' • '),
            ),
          ],
          if (lastUpdated.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMetaRow(
              icon: Icons.access_time_outlined,
              label: 'Updated',
              value: lastUpdated,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShipmentBreakdown(
    ColorScheme color,
    List<Map<String, dynamic>> shipments,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shipment Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...shipments.asMap().entries.map((entry) {
            final shipment = entry.value;
            final vendor = shipment['vendor'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(
                    shipment['vendor'] as Map<String, dynamic>,
                  )
                : <String, dynamic>{};

            final vendorName =
                vendor['businessName']?.toString() ?? 'Vendor shipment';
            final shipmentStatus = _displayStatus(
              _normalizeStatus(shipment['shipmentStatus']),
            );
            final itemCount = (shipment['items'] as List?)?.length ?? 0;

            return Container(
              margin: EdgeInsets.only(
                bottom: entry.key == shipments.length - 1 ? 0 : 10,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vendorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          shipmentStatus,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'} in this shipment',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  if ((shipment['trackingNumber']?.toString() ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tracking: ${shipment['trackingNumber']}',
                        style: const TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLiveUpdates(ColorScheme color) {
    final updates = liveUpdates.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Delivery Updates',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...updates.asMap().entries.map((entry) {
            final update = entry.value;
            final message =
                update['message']?.toString().trim().isNotEmpty == true
                ? update['message'].toString().trim()
                : _displayStatus(
                    _normalizeStatus(update['status']) == 'rider_assigned'
                        ? 'rider assigned'
                        : update['status']?.toString() ?? 'Update received',
                  );

            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == updates.length - 1 ? 0 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: color.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDateTime(update['timestamp']?.toString()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Map<String, dynamic>? get _rider {
    if (order['rider'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(order['rider'] as Map<String, dynamic>);
    }
    return null;
  }

  List<Map<String, dynamic>> get _shipments {
    return (order['shipments'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((shipment) => Map<String, dynamic>.from(shipment))
        .toList();
  }

  String get _firstTrackingNumber {
    final orderTracking = order['trackingNumber']?.toString() ?? '';
    if (orderTracking.isNotEmpty) {
      return orderTracking;
    }

    for (final shipment in _shipments) {
      final value = shipment['trackingNumber']?.toString() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String get _firstLogisticsPartner {
    final orderPartner = order['logisticsPartner']?.toString() ?? '';
    if (orderPartner.isNotEmpty) {
      return orderPartner;
    }

    for (final shipment in _shipments) {
      final value = shipment['logisticsPartner']?.toString() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String _normalizeStatus(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  String _displayStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'Pending';
    }

    return normalized
        .split('_')
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return '';
    }

    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (_) {
      return dateString;
    }
  }
}

class _TrackingStage {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;

  const _TrackingStage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
    required this.isCurrent,
  });
}
