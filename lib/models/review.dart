class Review {
  final String id;
  final String productId;
  final String? productName;
  final String userId;
  final String? userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.productId,
    this.productName,
    required this.userId,
    this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final user = json['user'];
    final productMap = product is Map
        ? Map<String, dynamic>.from(product)
        : null;
    final userMap = user is Map ? Map<String, dynamic>.from(user) : null;
    final userFirstName = _readString(userMap?['firstName']);
    final userLastName = _readString(userMap?['lastName']);
    final userName = [
      userFirstName,
      userLastName,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');

    return Review(
      id: _readString(json['_id']) ?? _readString(json['id']) ?? '',
      productId:
          _readString(productMap?['_id']) ??
          _readString(productMap?['id']) ??
          _readString(product) ??
          '',
      productName: _readString(productMap?['name']),
      userId:
          _readString(userMap?['_id']) ??
          _readString(userMap?['id']) ??
          _readString(user) ??
          '',
      userName: userName.isEmpty ? null : userName,
      rating: _readDouble(json['rating']) ?? 0,
      comment: _readString(json['comment']) ?? '',
      createdAt: _readDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'product': productId,
      'user': userId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static String? _readString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      return _readString(value['_id']) ??
          _readString(value['id']) ??
          _readString(value['\$oid']);
    }
    return value.toString();
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _readDateTime(Object? value) {
    final dateText = _readString(value);
    if (dateText == null || dateText.isEmpty) return null;
    return DateTime.tryParse(dateText);
  }
}
