// lib/models/dispute.dart
class Dispute {
  final String id;
  final String reason;
  final String orderId;
  final String status;
  final List<String> attachments;
  final DateTime createdAt;

  Dispute({
    required this.id,
    required this.reason,
    required this.orderId,
    required this.status,
    required this.attachments,
    required this.createdAt,
  });

  factory Dispute.fromJson(Map<String, dynamic> json) {
    return Dispute(
      id: json['_id'] ?? json['id'],
      reason: json['reason'] ?? '',
      orderId: json['order'] is Map ? json['order']['_id'] : (json['order'] ?? ''),
      status: json['status'] ?? 'pending',
      attachments: List<String>.from(json['attachments'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
