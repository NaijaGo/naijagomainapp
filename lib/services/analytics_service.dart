import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

class AnalyticsService {
  const AnalyticsService();

  Future<void> track({
    required String eventType,
    String? source,
    String? targetType,
    String? targetId,
    String? placement,
    String? city,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final sessionId = prefs.getString('analytics_session_id') ??
          DateTime.now().microsecondsSinceEpoch.toString();
      await prefs.setString('analytics_session_id', sessionId);

      final payload = <String, dynamic>{
        'eventType': eventType,
        'sessionId': sessionId,
      };
      if (source != null) payload['source'] = source;
      if (targetType != null) payload['targetType'] = targetType;
      if (targetId != null) payload['targetId'] = targetId;
      if (placement != null) payload['placement'] = placement;
      if (city != null) payload['city'] = city;
      if (metadata != null) payload['metadata'] = metadata;

      await http.post(
        Uri.parse('$baseUrl/api/analytics/track'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
    } catch (error) {
      debugPrint('Analytics tracking failed: $error');
    }
  }
}
