import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

/// Consent-only page statistics. No device identifiers, addresses or search text.
class VisitorAnalyticsService {
  static const consentKey = 'visitor_statistics_consent';
  static const _sessionKey = 'visitor_statistics_session';
  static const _dayKey = 'visitor_statistics_day';
  bool enabled = false;
  bool? consent;
  Future<void> _queue = Future<void>.value();

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      consent = preferences.getBool(consentKey);
      final response = await http
          .get(Uri.parse('$baseUrl/api/analytics/visitor-config'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        enabled = data is Map && data['enabled'] == true;
      }
    } catch (_) {
      enabled = false;
    }
  }

  Future<void> setConsent(bool value) async {
    consent = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(consentKey, value);
    if (!value) {
      await preferences.remove(_sessionKey);
      await preferences.remove(_dayKey);
    }
  }

  Future<void> trackPage(String page) {
    _queue = _queue.then((_) => _trackPage(page));
    return _queue;
  }

  Future<void> _trackPage(String page) async {
    if (!enabled || consent != true) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      // Re-check persisted consent before every event, including async navigation.
      if (preferences.getBool(consentKey) != true) return;
      final day = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      var session = preferences.getString(_sessionKey);
      if (preferences.getInt(_dayKey) != day || session == null) {
        final random = Random.secure();
        session = List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        await preferences.setString(_sessionKey, session);
        await preferences.setInt(_dayKey, day);
      }
      if (consent != true) return;
      final token = preferences.getString('jwt_token');
      final device = kIsWeb
          ? 'web_desktop'
          : switch (defaultTargetPlatform) {
              TargetPlatform.android => 'android',
              TargetPlatform.iOS => 'ios',
              _ => 'other',
            };
      await http
          .post(
            Uri.parse('$baseUrl/api/analytics/visitor'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'sessionId': session,
              'page': page,
              'source': 'customer_app',
              'deviceClass': device,
              'consent': true,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      /* Analytics must never block shopping or expose server errors. */
    }
  }
}
