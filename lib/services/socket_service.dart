// lib/services/socket_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  io.Socket? socket;

  Future<void> connect(String baseUrl) async {
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

  void dispose() {
    socket?.disconnect();
    socket = null;
  }
}

