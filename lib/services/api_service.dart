// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class ApiService {
  // ---- JWT Token Helper ----
  static Future<String?> _getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('jwt_token');
  }

  // ---- Generic API Calls ----
  static Future<http.Response> post(String path, Map body) async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return http.post(Uri.parse('$baseUrl$path'),
        headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> get(String path) async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return http.get(Uri.parse('$baseUrl$path'), headers: headers);
  }

  static Future<http.Response> put(String path, Map body) async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return http.put(Uri.parse('$baseUrl$path'),
        headers: headers, body: jsonEncode(body));
  }

  // ---- Upload (Cloudinary/S3 via backend) ----
  static Future<String> uploadFileToBackend(String filePath,
      {String purpose = 'dispute'}) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl/api/uploads');
    final request = http.MultipartRequest('POST', uri);

    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.fields['purpose'] = purpose;

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200 || res.statusCode == 201) {
      final j = jsonDecode(res.body);
      return j['url'] ?? j['secure_url'] ?? j['path'] ?? '';
    } else {
      throw Exception('Upload failed: ${res.body}');
    }
  }

  // ---- Orders ----
  static Future<List<dynamic>> getUserOrders() async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token'
    };

    var res = await http.get(Uri.parse('$baseUrl/api/orders/my'),
        headers: headers);

    if (res.statusCode == 404) {
      res = await http.get(Uri.parse('$baseUrl/api/orders'), headers: headers);
    }

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch orders: ${res.body}');
  }

  // ---- Disputes ----
  static Future<List<dynamic>> getUserDisputes() async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token'
    };

    final res = await http.get(Uri.parse('$baseUrl/api/disputes'),
        headers: headers);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch disputes: ${res.body}');
  }

  static Future<Map<String, dynamic>> getDisputeById(String id) async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token'
    };

    final res = await http.get(Uri.parse('$baseUrl/api/disputes/$id'),
        headers: headers);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch dispute: ${res.body}');
  }
}