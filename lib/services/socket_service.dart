// lib/services/socket_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  io.Socket? socket;

  bool get isConnected => socket?.connected ?? false;

  Future<void> connect(String baseUrl) async {
    if (socket != null) {
      if (!isConnected) {
        socket!.connect();
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    socket = io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
      'forceNew': true,
    });

    socket!.connect();

    socket!.onConnect((_) {
      debugPrint('Socket connected');
    });

    socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    socket!.onConnectError((err) {
      debugPrint('Socket connect error: $err');
    });
  }

  void joinDispute(String disputeId) {
    socket?.emit('joinDispute', disputeId);
  }

  void leaveDispute(String disputeId) {
    socket?.emit('leaveDispute', disputeId);
  }

  void sendMessage(String disputeId, String text, List<String> attachments) {
    socket?.emit('sendMessage', {
      'disputeId': disputeId,
      'text': text,
      'attachments': attachments,
    });
  }

  void onMessage(void Function(dynamic) cb) {
    socket?.on('message', cb);
  }

  void on(String event, void Function(dynamic) cb) {
    socket?.on(event, cb);
  }

  void off(String event) {
    socket?.off(event);
  }

  void onConnect(void Function(dynamic) cb) {
    socket?.onConnect(cb);
  }

  void onDisconnect(void Function(dynamic) cb) {
    socket?.onDisconnect(cb);
  }

  void joinOrderTracking(String orderId) {
    socket?.emit('join_order_tracking', {'orderId': orderId});
  }

  void leaveOrderTracking(String orderId) {
    socket?.emit('leave_order_tracking', {'orderId': orderId});
  }

  void dispose() {
    socket?.disconnect();
    socket = null;
  }
}

