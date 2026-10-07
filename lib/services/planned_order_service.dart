import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class PlannedOrderException implements Exception {
  const PlannedOrderException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class PlannedOrderService {
  PlannedOrderService({
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
    var stage = 'authentication';
    final token = authenticated ? await _tokenReader() : null;
    if (authenticated && (token == null || token.isEmpty)) {
      throw const PlannedOrderException(
        'Please sign in to use planned orders.',
      );
    }
    try {
      stage = 'request';
      final operation =
          http.Request(
              method,
              Uri.parse(
                '$baseUrl/api/planned-orders/$path',
              ).replace(queryParameters: query),
            )
            ..headers.addAll({
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            });
      if (body != null) operation.body = jsonEncode(body);
      stage = 'response';
      final response = await _client
          .send(operation)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 25));
      stage = 'decode';
      if (path == 'config' && response.statusCode == 404) {
        throw const PlannedOrderException(
          'Group and recurring orders are not available on this server yet. Normal checkout is available.',
          code: 'PLANNED_ORDERS_NOT_DEPLOYED',
        );
      }
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = data['message'];
        throw PlannedOrderException(
          (response.statusCode < 500 ||
                  (response.statusCode == 503 &&
                      data['code'] == 'PLANNED_ORDERS_DISABLED')) &&
                  message is String &&
                  message.length <= 220
              ? message
              : 'Planned orders are unavailable. Check your connection and try again.',
          code: data['code']?.toString(),
        );
      }
      return data;
    } on PlannedOrderException {
      rethrow;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Planned order request failed safely at $stage: ${error.runtimeType}',
        );
      }
      throw const PlannedOrderException(
        'Planned orders are unavailable. Check your connection and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> config() =>
      request('config', authenticated: false);
  Future<Map<String, dynamic>> groups({String? before}) =>
      request('groups', query: {'before': ?before, 'limit': '20'});
  Future<Map<String, dynamic>> group(String id) => request('groups/$id');
  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> input) =>
      request('groups', method: 'POST', body: input);
  Future<Map<String, dynamic>> joinGroup(String token) =>
      request('groups/join', method: 'POST', body: {'token': token.trim()});
  Future<Map<String, dynamic>> rotateGroupInvite(
    String id, {
    required int revision,
  }) => request(
    'groups/$id/invite',
    method: 'POST',
    body: {'revision': revision},
  );
  Future<Map<String, dynamic>> editGroup(
    String id, {
    required int revision,
    required List<Map<String, dynamic>> items,
  }) => request(
    'groups/$id/items',
    method: 'PUT',
    body: {'revision': revision, 'items': items},
  );
  Future<Map<String, dynamic>> controlGroup(
    String id, {
    required int revision,
    required String action,
  }) => request(
    'groups/$id/control',
    method: 'POST',
    body: {'revision': revision, 'action': action},
  );
  Future<Map<String, dynamic>> recurring({String? before}) =>
      request('recurring', query: {'before': ?before, 'limit': '20'});
  Future<Map<String, dynamic>> recurringPlan(String id) =>
      request('recurring/$id');
  Future<Map<String, dynamic>> createRecurring(Map<String, dynamic> input) =>
      request('recurring', method: 'POST', body: input);
  Future<Map<String, dynamic>> editRecurring(
    String id, {
    required int revision,
    required Map<String, dynamic> input,
  }) => request(
    'recurring/$id',
    method: 'PUT',
    body: {...input, 'revision': revision},
  );
  Future<Map<String, dynamic>> controlRecurring(
    String id, {
    required int revision,
    required String action,
  }) => request(
    'recurring/$id/control',
    method: 'POST',
    body: {'revision': revision, 'action': action},
  );
  Future<Map<String, dynamic>> controlOccurrence(
    String id, {
    required int revision,
    required String action,
    Map<String, dynamic>? input,
  }) => request(
    'occurrences/$id/control',
    method: 'POST',
    body: {...?input, 'revision': revision, 'action': action},
  );
  Future<Map<String, dynamic>> quoteGroup(String id, {required int revision}) =>
      request('groups/$id/quote', method: 'POST', body: {'revision': revision});
  Future<Map<String, dynamic>> checkoutGroup(
    String id, {
    required int revision,
    required String approvalToken,
    required String paymentMethod,
  }) => request(
    'groups/$id/checkout',
    method: 'POST',
    body: {
      'revision': revision,
      'approvalToken': approvalToken,
      'paymentMethod': paymentMethod,
    },
  );
  Future<Map<String, dynamic>> quoteOccurrence(
    String id, {
    required int revision,
  }) => request(
    'occurrences/$id/quote',
    method: 'POST',
    body: {'revision': revision},
  );
  Future<Map<String, dynamic>> checkoutOccurrence(
    String id, {
    required int revision,
    required String approvalToken,
    required String paymentMethod,
  }) => request(
    'occurrences/$id/checkout',
    method: 'POST',
    body: {
      'revision': revision,
      'approvalToken': approvalToken,
      'paymentMethod': paymentMethod,
    },
  );
  void dispose() => _client.close();
}

class PlannedOrderDestination {
  const PlannedOrderDestination(this.kind, this.id);
  final String kind;
  final String id;
}

class PlannedOrderIntent {
  static final changed = ValueNotifier<int>(0);
  static PlannedOrderDestination? _pending;
  static PlannedOrderDestination? parse(Map data) {
    final type = data['type']?.toString();
    final related = data['relatedModel']?.toString();
    final nested = data['plannedOrder'] is Map
        ? Map<String, dynamic>.from(data['plannedOrder'] as Map)
        : <String, dynamic>{};
    final nestedKind = nested['kind']?.toString();
    final id =
        (type == 'recurring_order_update'
                ? (data['planId'] ??
                      nested['id'] ??
                      data['recordId'] ??
                      data['relatedId'])
                : (nested['id'] ?? data['recordId'] ?? data['relatedId']))
            ?.toString();
    if (id == null || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id)) return null;
    if (nestedKind == 'group' ||
        type == 'group_order_update' ||
        related == 'GroupOrder') {
      return PlannedOrderDestination('group', id);
    }
    if (nestedKind == 'recurring' ||
        type == 'recurring_order_update' ||
        related == 'RecurringPlan' ||
        related == 'RecurringOccurrence') {
      return PlannedOrderDestination('recurring', id);
    }
    return null;
  }

  static void receive(Map? data) {
    if (data == null) return;
    final value = parse(data);
    if (value == null) return;
    _pending = value;
    changed.value++;
  }

  static PlannedOrderDestination? take() {
    final value = _pending;
    _pending = null;
    return value;
  }

  static void clear() => _pending = null;
}
