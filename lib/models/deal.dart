class Deal {
  const Deal({
    required this.id,
    required this.productId,
    required this.vendorId,
    this.offerId,
    required this.productName,
    required this.vendorName,
    required this.imageUrls,
    required this.originalPrice,
    required this.finalPrice,
    required this.discountType,
    required this.discountValue,
    required this.savingsAmount,
    required this.savingsPercentage,
    required this.startAt,
    required this.endAt,
    this.status,
    this.featured = false,
  });

  final String id, productId, vendorId, productName, vendorName, discountType;
  final String? offerId, status;
  final List<String> imageUrls;
  final double originalPrice,
      finalPrice,
      discountValue,
      savingsAmount,
      savingsPercentage;
  final DateTime? startAt, endAt;
  final bool featured;

  static DateTime? parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
  static String _id(dynamic value) {
    if (value is! String || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value)) {
      throw const FormatException('Invalid Deal identity.');
    }
    return value;
  }

  static double _number(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null || !number.isFinite || number < 0) {
      throw const FormatException('Invalid Deal price.');
    }
    return number;
  }

  factory Deal.fromJson(Map<String, dynamic> json) {
    final product = json['product'] is Map ? json['product'] as Map : const {};
    final vendor = json['vendor'] is Map ? json['vendor'] as Map : const {};
    final original = _number(json['originalPrice']);
    final finalPrice = _number(json['finalPrice']);
    final type = json['discountType'];
    if (finalPrice > original || !['percentage', 'fixed'].contains(type)) {
      throw const FormatException('Invalid Deal pricing.');
    }
    return Deal(
      id: _id(json['_id']),
      productId: _id(json['productId']),
      vendorId: _id(json['vendorId']),
      offerId: json['productOfferId'] == null
          ? null
          : _id(json['productOfferId']),
      productName: product['name']?.toString() ?? 'Product',
      vendorName: vendor['businessName']?.toString() ?? 'Vendor',
      imageUrls: product['imageUrls'] is List
          ? (product['imageUrls'] as List).whereType<String>().toList()
          : const [],
      originalPrice: original,
      finalPrice: finalPrice,
      discountType: type as String,
      discountValue: _number(json['discountValue']),
      savingsAmount: _number(json['savingsAmount']),
      savingsPercentage: _number(json['savingsPercentage']),
      startAt: parseDate(json['startAt']),
      endAt: parseDate(json['endAt']),
      status: json['status']?.toString(),
      featured: json['featured'] == true,
    );
  }
  bool isActiveAt(DateTime now) =>
      startAt != null &&
      endAt != null &&
      endAt!.isAfter(startAt!) &&
      !now.isBefore(startAt!) &&
      now.isBefore(endAt!) &&
      (status == null || status == 'approved');
  Duration remainingAt(DateTime now) =>
      isActiveAt(now) ? endAt!.difference(now) : Duration.zero;
  String countdownAt(DateTime now) {
    final remaining = remainingAt(now);
    if (remaining <= Duration.zero) return 'Offer ended';
    if (remaining.inDays > 0) {
      return 'Ends in ${remaining.inDays}d ${remaining.inHours % 24}h';
    }
    if (remaining.inHours > 0) {
      return 'Ends in ${remaining.inHours}h ${remaining.inMinutes % 60}m';
    }
    return 'Ends in ${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
  }
}

class DealPage {
  const DealPage({
    required this.deals,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
    required this.serverTime,
  });
  final List<Deal> deals;
  final int total, page, limit;
  final bool hasMore;
  final DateTime? serverTime;
  factory DealPage.fromJson(Map<String, dynamic> json) {
    if (json['deals'] is! List ||
        json['total'] is! int ||
        json['total'] < 0 ||
        json['page'] is! int ||
        json['page'] < 1 ||
        json['limit'] is! int ||
        json['limit'] < 1 ||
        json['hasMore'] is! bool) {
      throw const FormatException('Invalid Deals page.');
    }
    return DealPage(
      deals: (json['deals'] as List).map((row) {
        if (row is! Map) throw const FormatException('Invalid Deal.');
        return Deal.fromJson(Map<String, dynamic>.from(row));
      }).toList(),
      total: json['total'],
      page: json['page'],
      limit: json['limit'],
      hasMore: json['hasMore'],
      serverTime: Deal.parseDate(json['serverTime']),
    );
  }
}
