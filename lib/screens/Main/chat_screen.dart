import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/visible_back_button.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../constants.dart';
import '../../services/analytics_service.dart';
import '../../widgets/pharmacy_ui.dart';
import '../../widgets/pharmacy_chat_widgets.dart';
import '../../services/pharmacy_chat_service.dart';

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
  final io.Socket? Function(String apiUrl, String token)? socketFactory;
  final String? sessionId;
  final bool isPharmacistView;
  final String? assignedPharmacistName;
  final String? initialConsultationTopic;

  const ChatScreen({
    super.key,
    this.socketFactory,
    this.sessionId,
    this.isPharmacistView = false,
    this.assignedPharmacistName,
    this.initialConsultationTopic,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  final String _apiUrl = baseUrl;

  io.Socket? _socket;
  Timer? _joinTimeoutTimer;
  Timer? _historyTimer;
  bool _isForeground = true;
  bool _historyFetching = false;
  bool _historyLoaded = false;
  bool _historyError = false;
  bool _isClosed = false;
  final Set<String> _sendingIds = {};
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _isLiveConnected = false;
  String? _sessionId;
  bool _isAssignedToPharmacist = false;
  String? _pharmacistName;
  bool _isTyping = false;
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
  String? _authenticatedChatRole;

  String get _myRole =>
      _authenticatedChatRole ??
      (widget.isPharmacistView ? 'pharmacist' : 'user');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_handleComposerChanged);
    _bootstrapConversation();
    _historyTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isForeground && !_isLiveConnected && _sessionId != null) {
        unawaited(_refreshHistoryFromRest());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground && _sessionId != null) {
      unawaited(_refreshConversation());
    }
  }

  void _handleComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _bootstrapConversation() async {
    _pharmacistName = widget.assignedPharmacistName;
    final token = await _getAuthToken();
    if (!mounted) return;
    if (token == null) {
      _addSystemMessage('Authentication failed. Please log in again.');
      setState(() => _isBootstrapping = false);
      return;
    }
    _sessionId = widget.sessionId;
    if (_sessionId == null && !widget.isPharmacistView) {
      try {
        final response = await http
            .get(
              Uri.parse('$_apiUrl/api/chat/active'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 12));
        if (!mounted) return;
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['session'] is Map) {
            _sessionId = data['session']['_id']?.toString();
          }
        }
      } catch (_) {
        /* Older servers can still use the existing start flow. */
      }
    }
    if (_sessionId != null) {
      await _refreshHistoryFromRest(token: token);
      if (mounted) _connectSocket(token);
      return;
    }
    if (widget.isPharmacistView) {
      _addSystemMessage('No consultation session was supplied.');
      setState(() => _isBootstrapping = false);
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

    // Keep a live presence connection open while the customer is choosing.
    // Otherwise newly-online pharmacists are not visible until a manual reload.
    if (mounted && _sessionId == null) {
      _connectSocket(token);
    }
  }

  Future<void> _choosePharmacist(Map<String, dynamic> pharmacist) async {
    if (_isBootstrapping || !mounted) return;
    final id = pharmacist['id']?.toString() ?? '';
    if (id.isEmpty) return;

    _selectedPharmacistId = id;
    _pharmacistName = pharmacist['name']?.toString();
    setState(() => _isBootstrapping = true);
    await _startChatSessionAndConnect(pharmacistId: id);
  }

  Future<void> _startChatSessionAndConnect({String? pharmacistId}) async {
    final token = await _getAuthToken();
    if (!mounted) return;
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

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
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
        await _refreshHistoryFromRest(token: token);
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
      if (!mounted) return;
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
    if (!mounted) return;
    _joinTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.dispose();
    _isLiveConnected = false;
    final socket = widget.socketFactory != null
        ? widget.socketFactory!(_apiUrl, token)
        : io.io(
            _apiUrl,
            io.OptionBuilder()
                .setTransports(['websocket', 'polling'])
                .disableAutoConnect()
                .enableForceNew()
                .setAuth({'token': token})
                .build(),
          );
    _socket = socket;
    if (socket == null) return;
    socket.onConnect((_) {
      if (!mounted || _socket != socket) return;
      _reconnectTimer?.cancel();
      _reconnectAttempt = 0;
      if (_sessionId == null) return;
      _joinTimeoutTimer = Timer(const Duration(seconds: 12), () {
        if (mounted && _socket == socket) {
          setState(() => _isLiveConnected = false);
        }
      });
      socket.emitWithAck(
        'join_chat',
        {'sessionId': _sessionId, 'authToken': token},
        ack: (response) {
          if (!mounted || _socket != socket) return;
          _joinTimeoutTimer?.cancel();
          final data = _ackPayload(response);
          if (data['success'] != true ||
              data['session'] is! Map ||
              data['session']['_id']?.toString() != _sessionId) {
            setState(() => _isLiveConnected = false);
            return;
          }
          _applyHistory(data);
          setState(() => _isLiveConnected = true);
          _scrollToBottom();
          _sendInitialConsultationTopicIfNeeded();
        },
      );
    });
    socket.on('new_message', (raw) {
      if (!mounted || _socket != socket) return;
      final message = pharmacyMessage(raw);
      if (message == null || message['session'] != _sessionId) return;
      setState(() {
        _appendMessageIfNew(message);
        _isTyping = _messages.any((item) => item['status'] == 'pending');
      });
      _scrollToBottom();
    });
    socket.on('pharmacist_joined', (data) {
      if (!mounted || _socket != socket || data is! Map) return;
      setState(() {
        _isAssignedToPharmacist = true;
        _pharmacistName = data['name']?.toString();
      });
      unawaited(_refreshHistoryFromRest());
    });
    socket.on('pharmacistStatus', (data) {
      if (!mounted ||
          _socket != socket ||
          widget.isPharmacistView ||
          data is! Map) {
        return;
      }
      _updatePharmacistChoices(data);
    });
    void disconnected(dynamic _) {
      if (!mounted || _socket != socket) return;
      setState(() => _isLiveConnected = false);
      _scheduleSocketReconnect();
    }

    socket.onDisconnect(disconnected);
    socket.onConnectError(disconnected);
    socket.onError(disconnected);
    socket.connect();
  }

  void _updatePharmacistChoices(Map data) {
    final pharmacists = data['pharmacists'];
    if (pharmacists is List && _sessionId == null) {
      setState(() {
        _pharmacistChoices = pharmacists
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _hasLoadedPharmacistChoices = true;
      });
    }
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

  void _appendMessageIfNew(Map<String, dynamic> message) {
    mergePharmacyMessage(_messages, message);
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
    if (text.isEmpty ||
        text.length > 5000 ||
        _sessionId == null ||
        _isClosed ||
        !_historyLoaded) {
      return;
    }
    _controller.clear();
    await _queueMessage(text);
  }

  Future<void> _queueMessage(String text) async {
    final message = {
      'id': newPharmacyMessageId(),
      'from': _myRole,
      'text': text,
      'session': _sessionId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
    };
    setState(() {
      _appendMessageIfNew(message);
      _isTyping = true;
    });
    _scrollToBottom();
    await _deliverMessage(message);
  }

  Future<void> _deliverMessage(Map<String, dynamic> message) async {
    final id = message['id'].toString();
    if (_sendingIds.contains(id) || _isClosed || _sessionId == null) return;
    _sendingIds.add(id);
    setState(() {
      mergePharmacyMessage(_messages, {...message, 'status': 'pending'});
      _isTyping = true;
    });
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw const PharmacyChatSendException(
          'Please sign in again to send messages.',
        );
      }
      final confirmed = await sendPharmacyMessage(
        apiUrl: _apiUrl,
        token: token,
        sessionId: _sessionId!,
        text: message['text'].toString(),
        clientMessageId: id,
      );
      if (!mounted) return;
      setState(() {
        // Older servers may return a generated ID. Replace the local row too.
        if (confirmed['id'] != id) {
          _messages.removeWhere((item) => item['id'] == id);
        }
        _appendMessageIfNew(confirmed);
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => mergePharmacyMessage(_messages, {...message, 'status': 'failed'}),
      );
      if (_messages.any(
        (item) => item['id'] == id && item['status'] == 'failed',
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is PharmacyChatSendException
                  ? error.message
                  : 'Message not confirmed. Tap Retry when connected.',
            ),
          ),
        );
      }
    } finally {
      _sendingIds.remove(id);
      if (mounted) {
        setState(
          () =>
              _isTyping = _messages.any((item) => item['status'] == 'pending'),
        );
        _scrollToBottom();
      }
    }
  }

  void _scheduleSocketReconnect({bool immediate = false}) {
    final socket = _socket;
    if (socket == null ||
        socket.connected ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    final delay = immediate ? 0 : (1 << _reconnectAttempt.clamp(0, 5).toInt());
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delay.clamp(0, 30).toInt()), () {
      if (mounted && _isForeground && _socket == socket && !socket.connected) {
        socket.connect();
      }
    });
  }

  void _applyHistory(Map<String, dynamic> data) {
    final session = data['session'];
    if (session is! Map || session['_id']?.toString() != _sessionId) return;
    setState(() {
      _isClosed = session['status'] == 'closed';
      _isAssignedToPharmacist = session['pharmacist'] != null;
      if (data['actorRole'] == 'user' || data['actorRole'] == 'pharmacist') {
        _authenticatedChatRole = data['actorRole'];
      }
      _pharmacistName = data['pharmacistName']?.toString() ?? _pharmacistName;
      for (final raw
          in (data['messages'] is List ? data['messages'] as List : const [])) {
        final message = pharmacyMessage(raw);
        if (message != null && message['session'] == _sessionId) {
          _appendMessageIfNew(message);
        }
      }
      _historyLoaded = true;
      _historyError = false;
      _isBootstrapping = false;
      _isTyping = _messages.any((item) => item['status'] == 'pending');
    });
  }

  Future<void> _refreshHistoryFromRest({String? token}) async {
    final sessionId = _sessionId;
    if (sessionId == null || !mounted || _historyFetching) return;
    _historyFetching = true;
    try {
      final authToken = token ?? await _getAuthToken();
      if (authToken == null) throw const FormatException();
      final response = await http
          .get(
            Uri.parse('$_apiUrl/api/chat/$sessionId/messages'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted || _sessionId != sessionId) return;
      if (response.statusCode != 200) throw const FormatException();
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data['session'] is! Map ||
          data['session']['_id']?.toString() != sessionId) {
        throw const FormatException();
      }
      _applyHistory(data);
      _scrollToBottom();
      _sendInitialConsultationTopicIfNeeded();
    } catch (_) {
      if (mounted) {
        setState(() {
          _historyError = true;
          _isBootstrapping = false;
        });
      }
    } finally {
      _historyFetching = false;
    }
  }

  Future<void> _refreshConversation() async {
    await _refreshHistoryFromRest();
    if (!mounted) return;
    final token = await _getAuthToken();
    if (mounted && token != null && !_isLiveConnected) _connectSocket(token);
  }

  void _sendInitialConsultationTopicIfNeeded() {
    final topic = widget.initialConsultationTopic?.trim();
    if (widget.isPharmacistView ||
        _sentInitialConsultationTopic ||
        topic == null ||
        topic.isEmpty ||
        !_historyLoaded ||
        _isClosed) {
      return;
    }
    _sentInitialConsultationTopic = true;
    unawaited(_queueMessage('I need pharmacist guidance for: $topic'));
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

  Widget _buildBubble(Map<String, dynamic> message) => PharmacyMessageBubble(
    key: ValueKey('chat-message-${message['id']}'),
    message: message,
    myRole: _myRole,
    onRetry: _isClosed || _sendingIds.contains(message['id'])
        ? null
        : () => _deliverMessage(message),
  );

  Widget _buildConversationHeader() => PharmacyChatHeader(
    title: widget.isPharmacistView
        ? 'Customer consultation'
        : _pharmacistName ?? 'Pharmacy Support',
    subtitle: _isClosed
        ? 'Consultation closed'
        : _sessionId == null
        ? 'Choose a pharmacist to start your consultation'
        : _isAssignedToPharmacist
        ? (_myRole == 'pharmacist'
              ? 'Private conversation with your customer'
              : 'Messages with your assigned pharmacist')
        : 'Waiting for a pharmacist to join',
  );
  Widget _buildConnectionStatus() => Container(
    key: const ValueKey('chat-connection-status'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: _isLiveConnected ? PharmacyUi.mint : Colors.white,
    child: Text(
      _isClosed
          ? 'Consultation closed'
          : _historyError
          ? 'Could not refresh messages. Tap Refresh to try again.'
          : _isLiveConnected
          ? 'Live chat connected'
          : 'Live chat reconnecting. Messages use the server connection.',
      style: const TextStyle(color: PharmacyUi.mutedText, fontSize: 12),
    ),
  );
  Widget _buildTypingIndicator() => const Padding(
    padding: EdgeInsets.all(8),
    child: Text(
      'Sending message...',
      style: TextStyle(color: PharmacyUi.mutedText, fontSize: 12),
    ),
  );

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
        !_isBootstrapping &&
        _historyLoaded &&
        !_isClosed &&
        _controller.text.trim().length <= 5000;

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
                  key: const ValueKey('chat-composer'),
                  enabled: _historyLoaded && !_isClosed,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 5000,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    counterText: '',
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
            Semantics(
              label: 'Send message',
              button: true,
              enabled: canSend,
              child: InkWell(
                key: const ValueKey('chat-send'),
                borderRadius: BorderRadius.circular(30),
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
                              color: PharmacyUi.deepNavy.withValues(
                                alpha: 0.25,
                              ),
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
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleComposerChanged);
    _joinTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _historyTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PharmacyUi.theme.copyWith(
        appBarTheme: PharmacyUi.theme.appBarTheme.copyWith(
          titleTextStyle: PharmacyUi.theme.textTheme.titleLarge?.copyWith(
            color: PharmacyUi.card,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              key: const ValueKey('chat-refresh'),
              tooltip: 'Refresh messages',
              onPressed: _refreshConversation,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          leading: const VisibleBackButton(),
          title: Text(
            widget.isPharmacistView ? 'Live Consultation' : 'Pharmacy Support',
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: _buildConversationHeader(),
                ),
              if (_sessionId != null) _buildConnectionStatus(),
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
                if (MediaQuery.viewInsetsOf(context).bottom == 0)
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
