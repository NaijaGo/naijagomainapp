import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

String newPharmacyMessageId() {
  final random = Random.secure();
  return List.generate(
    12,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

Map<String, dynamic>? pharmacyMessage(dynamic raw) {
  if (raw is! Map || raw['senderType'] == 'ai') return null;
  final role = raw['senderType']?.toString();
  if (!['user', 'pharmacist', 'system'].contains(role)) return null;
  final id = (raw['id'] ?? raw['_id'])?.toString();
  final text = (raw['text'] ?? raw['message'])?.toString();
  if (id == null || id.isEmpty || text == null) return null;
  return {
    'id': id,
    'from': role,
    'text': text,
    'session': raw['session']?.toString(),
    'createdAt': raw['createdAt']?.toString(),
    'status': 'sent',
  };
}

void mergePharmacyMessage(
  List<Map<String, dynamic>> messages,
  Map<String, dynamic> incoming,
) {
  final index = messages.indexWhere((item) => item['id'] == incoming['id']);
  if (index < 0) {
    messages.add(incoming);
  } else {
    if (messages[index]['status'] == 'sent' && incoming['status'] != 'sent') {
      return;
    }
    messages[index] = {...messages[index], ...incoming};
  }
  messages.sort((a, b) {
    final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '');
    final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '');
    return aTime == null || bTime == null ? 0 : aTime.compareTo(bTime);
  });
}

class PharmacyChatSendException implements Exception {
  final String message;
  const PharmacyChatSendException(this.message);
}

Future<Map<String, dynamic>> sendPharmacyMessage({
  required String apiUrl,
  required String token,
  required String sessionId,
  required String text,
  required String clientMessageId,
}) async {
  final response = await http
      .post(
        Uri.parse('$apiUrl/api/chat/send'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sessionId': sessionId,
          'message': text,
          'clientMessageId': clientMessageId,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (response.statusCode == 401) {
    throw const PharmacyChatSendException(
      'Please sign in again to send messages.',
    );
  }
  if (response.statusCode == 402) {
    throw const PharmacyChatSendException(
      'Pharmacist chat access is required.',
    );
  }
  if (response.statusCode == 403) {
    throw const PharmacyChatSendException(
      'You cannot send messages to this consultation.',
    );
  }
  if (response.statusCode == 409) {
    throw const PharmacyChatSendException(
      'This consultation cannot accept this message. Refresh the chat.',
    );
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw const PharmacyChatSendException(
      'Message not confirmed. Tap Retry when connected.',
    );
  }
  final data = jsonDecode(response.body);
  final message = data is Map && data['success'] == true
      ? pharmacyMessage(data['message'])
      : null;
  if (message == null ||
      message['session'] != sessionId ||
      message['text'] != text.trim() ||
      message['from'] == 'system') {
    throw const PharmacyChatSendException(
      'Message not confirmed. Tap Retry when connected.',
    );
  }
  return message;
}
