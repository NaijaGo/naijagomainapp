import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class ExploreException implements Exception {
  const ExploreException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExploreService {
  ExploreService({http.Client? client, Future<String?> Function()? tokenReader})
    : _client = client ?? http.Client(),
      _tokenReader = tokenReader ?? _readToken;
  final http.Client _client;
  final Future<String?> Function() _tokenReader;
  static Future<String?> _readToken() async =>
      (await SharedPreferences.getInstance()).getString('jwt_token');

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    final token = authenticated ? await _tokenReader() : null;
    if (authenticated && (token == null || token.isEmpty)) {
      throw const ExploreException('Please sign in to use Explore.');
    }
    final uri = Uri.parse(
      '$baseUrl/api/explore/$path',
    ).replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body);
      final data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = data['message'];
        throw ExploreException(
          response.statusCode < 500 &&
                  message is String &&
                  message.length <= 200
              ? message
              : 'Unable to connect to Explore. Check your internet and try again.',
        );
      }
      return data;
    } on ExploreException {
      rethrow;
    } catch (_) {
      throw const ExploreException(
        'Unable to connect to Explore. Check your internet and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> config() =>
      request('config', authenticated: false);
  void dispose() => _client.close();
}
