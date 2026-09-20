import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class ProductRequestException implements Exception {
  const ProductRequestException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ProductRequestService {
  ProductRequestService({
    http.Client? client,
    Future<String?> Function()? tokenReader,
  }) : _client = client ?? http.Client(),
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
      throw const ProductRequestException(
        'Please sign in to request a product.',
      );
    }
    try {
      final req =
          http.Request(
              method,
              Uri.parse(
                '$baseUrl/api/product-requests/$path',
              ).replace(queryParameters: query),
            )
            ..headers.addAll({
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            });
      if (body != null) req.body = jsonEncode(body);
      final response = await _client
          .send(req)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body);
      final data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = data['message'];
        throw ProductRequestException(
          response.statusCode < 500 &&
                  message is String &&
                  message.length <= 220
              ? message
              : 'Requests are unavailable. Check your connection and try again.',
        );
      }
      return data;
    } on ProductRequestException {
      rethrow;
    } catch (_) {
      throw const ProductRequestException(
        'Requests are unavailable. Check your connection and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> config() =>
      request('config', authenticated: false);
  void dispose() => _client.close();
}

class ProductRequestIntent {
  static final changed = ValueNotifier<int>(0);
  static String? _pending;
  static String? parse(Map data) {
    final value = data['type'] == 'product_request'
        ? data['requestId']
        : data['relatedModel'] == 'ProductRequest'
        ? data['relatedId']
        : null;
    return value is String && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value)
        ? value
        : null;
  }

  static void receive(Map? data) {
    if (data == null) return;
    final id = parse(data);
    if (id == null) return;
    _pending = id;
    changed.value++;
  }

  static String? take() {
    final value = _pending;
    _pending = null;
    return value;
  }

  static void clear() => _pending = null;
}
