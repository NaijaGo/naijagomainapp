import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignedFile {
  final String fileUrl;
  final String uploadUrl;
  SignedFile({required this.fileUrl, required this.uploadUrl});
}

class FileUploader {
  final String baseUrl;
  final String token;
  FileUploader({required this.baseUrl, required this.token});

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<SignedFile> getSignedUrl({
    required String filename,
    required String contentType,
    required int size,
    String purpose = 'dispute',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/uploads/sign'),
      headers: _authHeaders,
      body: jsonEncode({
        'filename': filename,
        'contentType': contentType,
        'size': size,
        'purpose': purpose,
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception('Failed to sign upload: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    return SignedFile(fileUrl: data['fileUrl'], uploadUrl: data['uploadUrl']);
  }

  Future<void> uploadToS3({
    required String uploadUrl,
    required File file,
    required String contentType,
  }) async {
    final bytes = await file.readAsBytes();
    final putRes = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (putRes.statusCode >= 400) {
      throw Exception('S3 upload failed: ${putRes.statusCode} ${putRes.body}');
    }
  }
}
