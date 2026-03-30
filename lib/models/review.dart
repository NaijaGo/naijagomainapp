
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
    String productId;
    String? productName;
    String userId;
    String? userName;

    if (json['product'] is Map) {
      productId = json['product']['_id'] as String;
      productName = json['product']['name'] as String?;
    } else {
      productId = json['product'] as String;
      productName = null;
    }

    if (json['user'] is Map) {
      userId = json['user']['_id'] as String;
      userName = '${json['user']['firstName']} ${json['user']['lastName']}';
    } else {
      userId = json['user'] as String;
      userName = null;
    }

    return Review(
      id: json['_id'] as String,
      productId: productId,
      productName: productName,
      userId: userId,
      userName: userName,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
}