import 'dart:convert';

import 'package:flutter/foundation.dart';

dynamic _decodeJson(String source) => jsonDecode(source);

Future<dynamic> decodeJsonInBackground(String source) {
  if (source.length < 50000) {
    return Future.value(jsonDecode(source));
  }
  return compute(_decodeJson, source);
}

Future<List<dynamic>> decodeJsonListInBackground(String source) async {
  final decoded = await decodeJsonInBackground(source);
  return decoded is List ? decoded : <dynamic>[];
}

Future<Map<String, dynamic>> decodeJsonMapInBackground(String source) async {
  final decoded = await decodeJsonInBackground(source);
  return decoded is Map<String, dynamic>
      ? decoded
      : Map<String, dynamic>.from(decoded as Map);
}
