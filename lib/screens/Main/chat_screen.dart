import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../widgets/pharmacy_ui.dart';

Future<String?> _getAuthToken() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  } catch (e) {
    debugPrint('Error retrieving JWT token: $e');
    return null;
  }
}

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  final bool isPharmacistView;
  final String? assignedPharmacistName;

  const ChatScreen({
    super.key,
    this.sessionId,
    this.isPharmacistView = false,
    this.assignedPharmacistName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  final String _apiUrl = 'https://naijago-backend.onrender.com';

  io.Socket? _socket;
  String? _sessionId;
  bool _isAssignedToPharmacist = false;
  String? _pharmacistName;
  bool _isTyping = false;
  bool _globalPharmacistOnline = false;
  bool _isBootstrapping = true;

  String get _myRole => widget.isPharmacistView ? 'pharmacist' : 'user';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleComposerChanged);
    _bootstrapConversation();
  }

  void _handleComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _bootstrapConversation() async {
    _pharmacistName = widget.assignedPharmacistName;

    if (widget.isPharmacistView) {
      if (widget.sessionId == null) {
        _addSystemMessage('No consultation session was supplied.');
        setState(() {
          _isBootstrapping = false;
        });
        return;
      }

      _sessionId = widget.sessionId;
      _isAssignedToPharmacist = true;
      final token = await _getAuthToken();
      if (token == null) {
        _addSystemMessage('Authentication failed. Please log in again.');
        setState(() {
          _isBootstrapping = false;
        });
        return;
      }
      _connectSocket(token);
      return;
    }

    await _startChatSessionAndConnect();
  }

  Future<void> _startChatSessionAndConnect() async {
    final token = await _getAuthToken();
    if (token == null) {
      _addSystemMessage('Authentication failed. Please log in again.');
      setState(() {
        _isBootstrapping = false;
      });
      return;
    }

    final sessionUri = Uri.parse('$_apiUrl/api/chat/start');
    try {
      final res = await http.post(
        sessionUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        _sessionId = data['_id']?.toString();
        _isAssignedToPharmacist = data['pharmacist'] != null;
        _connectSocket(token);
      } else {
        _addSystemMessage(
          'Failed to start chat session. Status: ${res.statusCode}.',
        );
        setState(() {
          _isBootstrapping = false;
        });
      }
    } catch (_) {
      _addSystemMessage('Network error: Could not connect to chat service.');
      setState(() {
        _isBootstrapping = false;
      });
    }
  }

  void _connectSocket(String token) {
    _socket?.dispose();
    _socket = io.io(
      _apiUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      if (_sessionId == null) {
        _addSystemMessage('Could not join consultation because the session ID is missing.');
        if (mounted) {
          setState(() {
            _isBootstrapping = false;
          });
        }
        return;
      }

      _socket!.emitWithAck(
        'join_chat',
        {'sessionId': _sessionId},
        ack: (response) {
          final Map<String, dynamic> data = response.isNotEmpty ? response[0] : {};
          if (data['success'] == true) {
            final List<dynamic> messages = data['messages'] ?? [];
            final session = data['session'] ?? {};

            if (!mounted) return;
            setState(() {
              _isAssignedToPharmacist =
                  widget.isPharmacistView || session['pharmacist'] != null;
              _messages.clear();
              for (final msg in messages) {
                _appendMessageIfNew(_formatSocketMessage(msg));
              }
              _isBootstrapping = false;
            });

            _scrollToBottom();
            _addSystemMessage(
              widget.isPharmacistView
                  ? 'You joined this consultation as the assigned pharmacist.'
                  : _isAssignedToPharmacist
                      ? 'Chat history loaded. A pharmacist is now supporting this conversation.'
                      : 'Chat history loaded. The AI assistant is currently supporting you.',
            );
          } else {
            _addSystemMessage(
              'Failed to join chat room: ${data['error'] ?? 'Unknown error'}',
            );
            if (mounted) {
              setState(() {
                _isBootstrapping = false;
              });
            }
          }
        },
      );
    });

    _socket!.on('pharmacistStatus', (data) {
      if (!mounted || widget.isPharmacistView) return;
      setState(() {
        _globalPharmacistOnline = data['online'] ?? false;
      });
    });

    _socket!.on('new_message', (data) {
      final formattedMessage = _formatSocketMessage(data);
      if (formattedMessage['from'] == _myRole) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _appendMessageIfNew(formattedMessage);
      });
      _scrollToBottom();
    });

    _socket!.on('pharmacist_joined', (data) {
      final String name = (data['name'] ?? 'A certified pharmacist').toString();
      if (!mounted) return;
      setState(() {
        _isAssignedToPharmacist = true;
        _pharmacistName = name;
        _isTyping = false;
      });
    });

    _socket!.onDisconnect((_) {
      if (!mounted) return;
      setState(() {
        _globalPharmacistOnline = false;
      });
    });

    _socket!.onError((err) => debugPrint('Socket error: $err'));
  }

  Map<String, dynamic> _formatSocketMessage(Map<String, dynamic> data) {
    String sender = 'user';
    if (data['senderType'] == 'pharmacist') {
      sender = 'pharmacist';
    } else if (data['senderType'] == 'ai') {
      sender = 'ai';
    } else if (data['senderType'] == 'system') {
      sender = 'system';
    }

    return {
      'from': sender,
      'text': (data['text'] ?? '').toString(),
      'id': data['id']?.toString(),
      'createdAt': data['createdAt']?.toString(),
    };
  }

  void _appendMessageIfNew(Map<String, dynamic> message) {
    final id = message['id'];
    if (id != null && _messages.any((msg) => msg['id'] == id)) {
      return;
    }
    _messages.add(message);
  }

  void _addSystemMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add({
        'from': 'system',
        'text': text,
        'id': 'local-sys-${DateTime.now().millisecondsSinceEpoch}',
      });
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sessionId == null || _socket?.connected != true) {
      return;
    }

    setState(() {
      _appendMessageIfNew({
        'from': _myRole,
        'text': text,
        'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
      });
      _controller.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    _socket!.emitWithAck(
      'send_chat_message',
      {'sessionId': _sessionId, 'text': text},
      ack: (response) {
        final Map<String, dynamic> data = response.isNotEmpty ? response[0] : {};

        if (!mounted) return;
        setState(() {
          if (data['success'] == true && data['aiReply'] != null && !widget.isPharmacistView) {
            _appendMessageIfNew(_formatSocketMessage(data['aiReply']));
          } else if (data['success'] != true) {
            _messages.add({
              'from': 'system',
              'text': 'Message failed to send.',
              'id': 'local-fail-${DateTime.now().millisecondsSinceEpoch}',
            });
          }
          _isTyping = false;
        });
        _scrollToBottom();
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isSystem = msg['from'] == 'system';
    final isPharmacist = msg['from'] == 'pharmacist';
    final isAI = msg['from'] == 'ai';
    final isMine = msg['from'] == _myRole;

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: PharmacyUi.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PharmacyUi.border),
          ),
          child: Text(
            msg['text'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PharmacyUi.mutedText,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final senderLabel = isPharmacist
        ? 'Pharmacist'
        : isAI
            ? 'AI Assistant'
            : widget.isPharmacistView
                ? 'Customer'
                : '';

    final Color bubbleColor = isMine
        ? (widget.isPharmacistView ? PharmacyUi.teal : PharmacyUi.deepNavy)
        : isPharmacist
            ? PharmacyUi.mint
            : isAI
                ? const Color(0xFFE9EEF7)
                : PharmacyUi.card;

    final Color textColor = isMine ? PharmacyUi.card : PharmacyUi.deepNavy;
    final Border? border = isMine
        ? null
        : Border.all(
            color: isPharmacist ? PharmacyUi.teal.withValues(alpha: 0.18) : PharmacyUi.border,
          );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (senderLabel.isNotEmpty && !isMine)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 2),
              child: Text(
                senderLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: isPharmacist ? PharmacyUi.teal : PharmacyUi.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              border: border,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
            ),
            child: Text(
              msg['text'],
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationHeader() {
    late final String badge;
    late final String title;
    late final String subtitle;
    late final IconData icon;
    late final Color accent;

    if (widget.isPharmacistView) {
      badge = 'Live consultation';
      title = 'Pharmacist support in progress';
      subtitle =
          'You are handling this consultation directly. Keep your responses clear, safe, and action-focused.';
      icon = Icons.local_pharmacy_rounded;
      accent = PharmacyUi.success;
    } else if (_isAssignedToPharmacist) {
      badge = 'Pharmacist assigned';
      title = _pharmacistName != null
          ? '$_pharmacistName is with you now'
          : 'A pharmacist has joined your conversation';
      subtitle =
          'Your consultation has moved from AI support to a live pharmacist for more specific help.';
      icon = Icons.medical_services_outlined;
      accent = PharmacyUi.success;
    } else if (_globalPharmacistOnline) {
      badge = 'Pharmacist available';
      title = 'AI support is active';
      subtitle =
          'A pharmacist is online and can join if your consultation needs escalation.';
      icon = Icons.support_agent_outlined;
      accent = PharmacyUi.warning;
    } else {
      badge = 'AI support';
      title = 'Pharmacy assistant';
      subtitle =
          'You are currently chatting with the AI assistant while we monitor pharmacist availability.';
      icon = Icons.smart_toy_outlined;
      accent = PharmacyUi.deepNavy;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PharmacyUi.panelDecoration(radius: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: PharmacyUi.deepNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: PharmacyUi.mutedText,
                    height: 1.45,
                  ),
                ),
                if (_sessionId != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Session ${_sessionId!.length > 8 ? '${_sessionId!.substring(0, 8)}...' : _sessionId!}',
                    style: const TextStyle(
                      color: PharmacyUi.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.isPharmacistView ? PharmacyUi.teal : PharmacyUi.deepNavy,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.isPharmacistView
                ? 'Sending your response...'
                : _isAssignedToPharmacist
                    ? 'Pharmacist is typing...'
                    : 'AI is thinking...',
            style: const TextStyle(color: PharmacyUi.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyBanner() {
    final text = widget.isPharmacistView
        ? 'Keep guidance professional and avoid requesting unnecessary personal information.'
        : 'Please do not share highly sensitive personal or payment information in this chat.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: PharmacyUi.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PharmacyUi.warning.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: PharmacyUi.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: PharmacyUi.deepNavy,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final canSend =
        _controller.text.trim().isNotEmpty && _socket?.connected == true && !_isBootstrapping;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: PharmacyUi.panelDecoration(radius: 22),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.isPharmacistView
                        ? 'Write your guidance...'
                        : 'Type a message...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: canSend ? _sendMessage : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: canSend ? PharmacyUi.deepNavy : PharmacyUi.border,
                  shape: BoxShape.circle,
                  boxShadow: canSend
                      ? [
                          BoxShadow(
                            color: PharmacyUi.deepNavy.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: PharmacyUi.card,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleComposerChanged);
    _controller.dispose();
    _scrollController.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PharmacyUi.theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isPharmacistView ? 'Live Consultation' : 'Pharmacy Support'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _buildConversationHeader(),
              ),
              Expanded(
                child: _isBootstrapping
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: PharmacyUi.deepNavy,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isTyping && index == _messages.length) {
                            return _buildTypingIndicator();
                          }
                          return _buildBubble(_messages[index]);
                        },
                      ),
              ),
              _buildSafetyBanner(),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }
}
