import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/review.dart';

class ReviewService {
  Future<Map<String, dynamic>> _request(String path, {String method = 'GET',
      Map<String, dynamic>? body, bool authenticated = false}) async {
    final token = authenticated
        ? (await SharedPreferences.getInstance()).getString('jwt_token') : null;
    if (authenticated && (token == null || token.isEmpty)) {
      throw Exception('Please sign in to manage or report reviews.');
    }
    final client = http.Client();
    try {
      final request = http.Request(method, Uri.parse('$baseUrl/api/reviews$path'))
        ..headers.addAll({'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token'});
      if (body != null) request.body = jsonEncode(body);
      final response = await client.send(request).then(http.Response.fromStream)
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw Exception('Reviews are temporarily unavailable.');
      final data = Map<String, dynamic>.from(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.statusCode < 500
            ? data['message'] ?? 'Unable to update this review.'
            : 'Reviews are temporarily unavailable. Please try again.');
      }
      return data;
    } finally { client.close(); }
  }

  Future<({List<Review> reviews, bool hasMore})> list(String productId, int page) async {
    final result = await _request('?productId=${Uri.encodeQueryComponent(productId)}&page=$page&limit=20');
    return (reviews: (result['reviews'] as List? ?? const []).whereType<Map>()
        .map((row) => Review.fromJson(Map<String, dynamic>.from(row))).toList(),
        hasMore: result['hasMore'] == true);
  }
  Future<void> report(String id, String reason) async {
    await _request('/$id/report', method: 'POST', authenticated: true, body: {'reason': reason});
  }
  Future<void> delete(String id) async {
    await _request('/$id', method: 'DELETE', authenticated: true);
  }
  Future<void> edit(String id, double rating, String comment) async {
    await _request('/$id', method: 'PUT', authenticated: true, body: {'rating': rating, 'comment': comment});
  }
}
