import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../constants.dart';
import '../../services/analytics_service.dart';
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
  final String? initialConsultationTopic;

  const ChatScreen({
    super.key,
    this.sessionId,
    this.isPharmacistView = false,
    this.assignedPharmacistName,
    this.initialConsultationTopic,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  final String _apiUrl = baseUrl;

  io.Socket? _socket;
  Timer? _joinTimeoutTimer;
  String? _socketAuthToken;
  String? _sessionId;
  bool _isAssignedToPharmacist = false;
  String? _pharmacistName;
  bool _isTyping = false;
  bool _globalPharmacistOnline = false;
  bool _isBootstrapping = true;
  bool _sentInitialConsultationTopic = false;
  bool _isLoadingSubscriptionPlans = false;
  bool _isPurchasingSubscription = false;
  bool _isLoadingPharmacists = false;
  bool _hasLoadedPharmacistChoices = false;
  String? _selectedPharmacistId;
  List<Map<String, dynamic>> _subscriptionPlans = [];
  List<Map<String, dynamic>> _pharmacistChoices = [];
  double _walletBalance = 0;

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

    final token = await _getAuthToken();
    if (token == null) {
      _addSystemMessage('Authentication failed. Please log in again.');
      setState(() {
        _isBootstrapping = false;
      });
      return;
    }

    await _loadPharmacistsForChoice(token);
  }

  Future<void> _loadPharmacistsForChoice(String token) async {
    setState(() {
      _isBootstrapping = false;
      _isLoadingPharmacists = true;
      _hasLoadedPharmacistChoices = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/api/chat/pharmacists/online'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pharmacists = data['pharmacists'];
        _pharmacistChoices = pharmacists is List
            ? pharmacists
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
        _globalPharmacistOnline = _pharmacistChoices.isNotEmpty;

        if (_pharmacistChoices.isEmpty) {
          _addSystemMessage(
            'No pharmacist is available right now. Please check back shortly.',
          );
        }
      } else {
        _addSystemMessage('Could not load available pharmacists.');
      }
    } catch (_) {
      _addSystemMessage('Network error while loading pharmacists.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPharmacists = false);
      }
    }
  }

  Future<void> _choosePharmacist(Map<String, dynamic> pharmacist) async {
    final id = pharmacist['id']?.toString() ?? '';
    if (id.isEmpty) return;

    _selectedPharmacistId = id;
    _pharmacistName = pharmacist['name']?.toString();
    setState(() => _isBootstrapping = true);
    await _startChatSessionAndConnect(pharmacistId: id);
  }

  Future<void> _startChatSessionAndConnect({String? pharmacistId}) async {
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
        body: jsonEncode({
          if (pharmacistId != null && pharmacistId.isNotEmpty)
            'pharmacistId': pharmacistId,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        _sessionId = data['_id']?.toString();
        _isAssignedToPharmacist = data['pharmacist'] != null;
        _pharmacistChoices.clear();
        const AnalyticsService().track(
          eventType: 'pharmacy_consultation_start',
          source: 'chat_screen',
          targetType: 'chat_session',
          targetId: _sessionId,
          metadata: {'assignedToPharmacist': _isAssignedToPharmacist},
        );
        _connectSocket(token);
      } else if (res.statusCode == 402) {
        _addSystemMessage(
          'Pharmacist chat requires an active subscription or one-time chat pass.',
        );
        if (mounted) {
          setState(() => _isBootstrapping = false);
        }
        await _loadSubscriptionPlansAndPrompt(token);
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

  Future<void> _loadSubscriptionPlansAndPrompt(String token) async {
    if (_isLoadingSubscriptionPlans || widget.isPharmacistView) {
      return;
    }

    setState(() => _isLoadingSubscriptionPlans = true);
    try {
      final plansResponse = await http.get(
        Uri.parse('$_apiUrl/api/pharmacist/subscription/plans'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final statusResponse = await http.get(
        Uri.parse('$_apiUrl/api/pharmacist/subscription/status'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (plansResponse.statusCode == 200) {
        final decoded = jsonDecode(plansResponse.body);
        final plans = decoded['plans'];
        _subscriptionPlans = plans is List
            ? plans
                  .whereType<Map>()
                  .map((plan) => Map<String, dynamic>.from(plan))
                  .toList()
            : [];
      }

      if (statusResponse.statusCode == 200) {
        final decoded = jsonDecode(statusResponse.body);
        _walletBalance =
            (decoded['walletBalance'] as num?)?.toDouble() ?? _walletBalance;
      }

      if (!mounted) return;
      _showSubscriptionSheet(token);
    } catch (e) {
      _addSystemMessage('Could not load pharmacist subscription plans.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSubscriptionPlans = false);
      }
    }
  }

  Future<void> _purchaseSubscription(String token, String planType) async {
    if (_isPurchasingSubscription) return;

    setState(() => _isPurchasingSubscription = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/pharmacist/subscription/purchase'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'planType': planType}),
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _walletBalance =
            (data['walletBalance'] as num?)?.toDouble() ?? _walletBalance;
        if (mounted) {
          Navigator.of(context).maybePop();
        }
        _addSystemMessage('Pharmacist chat access is active. Connecting now.');
        setState(() => _isBootstrapping = true);
        await _startChatSessionAndConnect(pharmacistId: _selectedPharmacistId);
      } else {
        _addSystemMessage(
          data['message']?.toString() ??
              'Unable to purchase pharmacist chat access.',
        );
      }
    } catch (e) {
      _addSystemMessage('Network error while purchasing pharmacist access.');
    } finally {
      if (mounted) {
        setState(() => _isPurchasingSubscription = false);
      }
    }
  }

  void _showSubscriptionSheet(String token) {
    if (_subscriptionPlans.isEmpty) {
      _addSystemMessage('No pharmacist subscription plan is currently active.');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                color: PharmacyUi.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: PharmacyUi.border),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose pharmacist access',
                      style: TextStyle(
                        color: PharmacyUi.deepNavy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Wallet balance: ${_formatNaira(_walletBalance)}',
                      style: const TextStyle(
                        color: PharmacyUi.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._subscriptionPlans.map((plan) {
                      final planType = plan['planType']?.toString() ?? '';
                      final price = (plan['price'] as num?)?.toDouble() ?? 0;
                      final durationDays =
                          (plan['durationDays'] as num?)?.toInt() ?? 0;
                      final canAfford = _walletBalance >= price;
                      final label = plan['label']?.toString() ?? planType;
                      final subtitle = planType == 'one_time'
                          ? 'One consultation session'
                          : '$durationDays days of pharmacist chat access';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: PharmacyUi.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PharmacyUi.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      color: PharmacyUi.deepNavy,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      color: PharmacyUi.mutedText,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatNaira(price),
                                  style: const TextStyle(
                                    color: PharmacyUi.teal,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 34,
                                  child: ElevatedButton(
                                    onPressed:
                                        (!canAfford ||
                                            _isPurchasingSubscription)
                                        ? null
                                        : () async {
                                            await _purchaseSubscription(
                                              token,
                                              planType,
                                            );
                                            if (mounted &&
                                                _isPurchasingSubscription) {
                                              setSheetState(() {
                                                _isPurchasingSubscription =
                                                    false;
                                              });
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: PharmacyUi.deepNavy,
                                      foregroundColor: PharmacyUi.card,
                                      disabledBackgroundColor: PharmacyUi
                                          .mutedText
                                          .withValues(alpha: .18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      canAfford ? 'Buy' : 'Top up',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatNaira(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final remaining = rounded.length - i;
      buffer.write(rounded[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '₦$buffer';
  }

  void _connectSocket(String token) {
    _joinTimeoutTimer?.cancel();
    _socketAuthToken = token;
    _socket?.dispose();
    _socket = io.io(
      _apiUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();
    _joinTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_isBootstrapping) return;
      _addSystemMessage(
        'Live chat is taking too long to connect. Please check your network and try again.',
      );
      setState(() {
        _isBootstrapping = false;
      });
    });

    _socket!.onConnect((_) {
      _joinTimeoutTimer?.cancel();
      if (_sessionId == null) {
        _addSystemMessage(
          'Could not join consultation because the session ID is missing.',
        );
        if (mounted) {
          setState(() {
            _isBootstrapping = false;
          });
        }
        return;
      }

      _joinTimeoutTimer = Timer(const Duration(seconds: 12), () {
        if (!mounted || !_isBootstrapping) return;
        _addSystemMessage(
          'Chat connected slowly. You can type your message while we keep trying to sync the chat history.',
        );
        setState(() {
          _isBootstrapping = false;
        });
      });

      _socket!.emitWithAck(
        'join_chat',
        {'sessionId': _sessionId, 'authToken': _socketAuthToken},
        ack: (response) {
          _joinTimeoutTimer?.cancel();
          final data = _ackPayload(response);
          if (data['success'] == true) {
            final List<dynamic> messages = data['messages'] ?? [];
            final session = data['session'] ?? {};

            if (!mounted) return;
            setState(() {
              _isAssignedToPharmacist =
                  widget.isPharmacistView || session['pharmacist'] != null;
              _messages.clear();
              for (final msg in messages) {
                if (_isAiSocketMessage(msg)) {
                  continue;
                }
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
                  : 'Chat history loaded. Your messages will be available for a pharmacist to review.',
            );
            _sendInitialConsultationTopicIfNeeded();
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

    _socket!.onConnectError((err) {
      debugPrint('Socket connect error: $err');
      if (!mounted || !_isBootstrapping) return;
      _joinTimeoutTimer?.cancel();
      _addSystemMessage(
        'Could not connect to live chat right now. Please check your network and try again.',
      );
      setState(() {
        _isBootstrapping = false;
      });
    });

    _socket!.on('pharmacistStatus', (data) {
      if (!mounted || widget.isPharmacistView) return;
      setState(() {
        _globalPharmacistOnline = data['online'] ?? false;
      });
    });

    _socket!.on('new_message', (data) {
      if (_isAiSocketMessage(data)) {
        return;
      }

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
      _scheduleSocketReconnect();
    });

    _socket!.onError((err) {
      debugPrint('Socket error: $err');
      if (!mounted || !_isBootstrapping) return;
      _joinTimeoutTimer?.cancel();
      _addSystemMessage('Chat connection failed. Please try again.');
      setState(() {
        _isBootstrapping = false;
      });
    });
  }

  Map<String, dynamic> _ackPayload(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _formatSocketMessage(Map<String, dynamic> data) {
    String sender = 'user';
    if (data['senderType'] == 'pharmacist') {
      sender = 'pharmacist';
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

  bool _isAiSocketMessage(dynamic data) {
    return data is Map && data['senderType']?.toString().toLowerCase() == 'ai';
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
    if (text.isEmpty || _sessionId == null) {
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

    if (_socket?.connected != true) {
      _scheduleSocketReconnect();
      await _sendMessageViaRest(text);
      return;
    }

    var handled = false;
    final fallbackTimer = Timer(const Duration(seconds: 8), () async {
      if (handled || !mounted) return;
      handled = true;
      _scheduleSocketReconnect();
      await _sendMessageViaRest(text);
    });

    _socket!.emitWithAck(
      'send_chat_message',
      {'sessionId': _sessionId, 'text': text, 'authToken': _socketAuthToken},
      ack: (response) async {
        if (handled) return;
        handled = true;
        fallbackTimer.cancel();
        final data = _ackPayload(response);

        if (!mounted) return;
        if (data['success'] != true) {
          _scheduleSocketReconnect();
          await _sendMessageViaRest(text);
          return;
        }

        setState(() => _isTyping = false);
        _scrollToBottom();
      },
    );
  }

  Future<void> _sendMessageViaRest(String text) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;

    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Missing token');
      }

      final response = await http.post(
        Uri.parse('$_apiUrl/api/chat/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'sessionId': sessionId, 'message': text}),
      );

      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() => _isTyping = false);
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'from': 'system',
          'text':
              'Message failed to send. Please check your connection and try again.',
          'id': 'local-fail-${DateTime.now().millisecondsSinceEpoch}',
        });
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  void _scheduleSocketReconnect() {
    final socket = _socket;
    if (socket == null || socket.connected) return;

    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || socket.connected) return;
      try {
        socket.connect();
      } catch (error) {
        debugPrint('Pharmacy chat reconnect failed: $error');
      }
    });
  }

  void _sendInitialConsultationTopicIfNeeded() {
    final topic = widget.initialConsultationTopic?.trim();
    if (widget.isPharmacistView ||
        _sentInitialConsultationTopic ||
        topic == null ||
        topic.isEmpty ||
        _sessionId == null ||
        _socket?.connected != true) {
      return;
    }

    _sentInitialConsultationTopic = true;
    final text = 'I need pharmacist guidance for: $topic';

    setState(() {
      _appendMessageIfNew({
        'from': _myRole,
        'text': text,
        'id': 'local-topic-${DateTime.now().millisecondsSinceEpoch}',
      });
      _isTyping = true;
    });
    _scrollToBottom();

    _socket!.emitWithAck(
      'send_chat_message',
      {'sessionId': _sessionId, 'text': text, 'authToken': _socketAuthToken},
      ack: (response) {
        final data = _ackPayload(response);
        if (!mounted) return;
        setState(() {
          if (data['success'] != true) {
            _messages.add({
              'from': 'system',
              'text':
                  'Consultation topic could not be sent automatically. Please type your medicine question.',
              'id': 'local-topic-fail-${DateTime.now().millisecondsSinceEpoch}',
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
        : widget.isPharmacistView
        ? 'Customer'
        : '';

    final Color bubbleColor = isMine
        ? (widget.isPharmacistView ? PharmacyUi.teal : PharmacyUi.deepNavy)
        : isPharmacist
        ? PharmacyUi.mint
        : PharmacyUi.card;

    final Color textColor = isMine ? PharmacyUi.card : PharmacyUi.deepNavy;
    final Border? border = isMine
        ? null
        : Border.all(
            color: isPharmacist
                ? PharmacyUi.teal.withValues(alpha: 0.18)
                : PharmacyUi.border,
          );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (senderLabel.isNotEmpty && !isMine)
            Padding(
              padding: const EdgeInsets.only(
                top: 8,
                left: 12,
                right: 12,
                bottom: 2,
              ),
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
              style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
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
          'Your consultation is now with a live pharmacist for more specific help.';
      icon = Icons.medical_services_outlined;
      accent = PharmacyUi.success;
    } else if (_globalPharmacistOnline) {
      badge = 'Pharmacist available';
      title = 'A pharmacist can join shortly';
      subtitle =
          'Send your question now. An available pharmacist can review and respond in this consultation.';
      icon = Icons.support_agent_outlined;
      accent = PharmacyUi.warning;
    } else {
      badge = 'Awaiting pharmacist';
      title = 'Pharmacist consultation';
      subtitle =
          'Send your medicine question here. A pharmacist will reply when available.';
      icon = Icons.local_pharmacy_outlined;
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
              color: widget.isPharmacistView
                  ? PharmacyUi.teal
                  : PharmacyUi.deepNavy,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.isPharmacistView
                ? 'Sending your response...'
                : _isAssignedToPharmacist
                ? 'Pharmacist is typing...'
                : 'Sending your message...',
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

  Widget _buildPharmacistChooser() {
    if (_isLoadingPharmacists) {
      return const Center(
        child: CircularProgressIndicator(color: PharmacyUi.deepNavy),
      );
    }

    if (_pharmacistChoices.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: PharmacyUi.panelDecoration(radius: 20),
            child: Column(
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    color: PharmacyUi.mint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.local_pharmacy_outlined,
                    color: PharmacyUi.teal,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No pharmacist available',
                  style: TextStyle(
                    color: PharmacyUi.deepNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Available pharmacists will appear here by distance when they come online.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PharmacyUi.mutedText, height: 1.45),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final token = await _getAuthToken();
                    if (token != null) await _loadPharmacistsForChoice(token);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: _pharmacistChoices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pharmacist = _pharmacistChoices[index];
        final name = pharmacist['name']?.toString() ?? 'Pharmacist';
        final distance =
            pharmacist['distanceLabel']?.toString() ?? 'Distance unavailable';
        final phone = pharmacist['phoneNumber']?.toString() ?? '';

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _choosePharmacist(pharmacist),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: PharmacyUi.panelDecoration(radius: 20),
            child: Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: PharmacyUi.mint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: PharmacyUi.teal,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PharmacyUi.deepNavy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone.isEmpty ? distance : '$distance • $phone',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PharmacyUi.mutedText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: PharmacyUi.deepNavy),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    final canSend =
        _controller.text.trim().isNotEmpty &&
        _sessionId != null &&
        !_isBootstrapping;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
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
    _joinTimeoutTimer?.cancel();
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
          title: Text(
            widget.isPharmacistView ? 'Live Consultation' : 'Pharmacy Support',
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _buildConversationHeader(),
              ),
              Expanded(
                child:
                    _sessionId == null &&
                        !widget.isPharmacistView &&
                        (_isLoadingPharmacists || _hasLoadedPharmacistChoices)
                    ? _buildPharmacistChooser()
                    : _isBootstrapping
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
              if (_sessionId != null || widget.isPharmacistView) ...[
                _buildSafetyBanner(),
                _buildComposer(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
