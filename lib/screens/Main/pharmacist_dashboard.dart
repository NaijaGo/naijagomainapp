import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../widgets/pharmacy_ui.dart';
import 'chat_screen.dart';

Future<String?> _getPharmacistAuthToken() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  } catch (e) {
    debugPrint('Error retrieving pharmacist JWT token: $e');
    return null;
  }
}

class PharmacistDashboard extends StatefulWidget {
  const PharmacistDashboard({super.key});

  @override
  State<PharmacistDashboard> createState() => _PharmacistDashboardState();
}

class _PharmacistDashboardState extends State<PharmacistDashboard> {
  final String _apiUrl = 'https://naijago-backend.onrender.com';
  final List<Map<String, dynamic>> _incomingRequests = [];

  io.Socket? _socket;
  bool _isOnline = false;
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  Future<void> _connectSocket() async {
    if (mounted) {
      setState(() {
        _isConnecting = true;
      });
    }

    final token = await _getPharmacistAuthToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _isOnline = false;
      });
      _showNotification(
        'Authentication failed',
        'Please sign in again to access pharmacist tools.',
        isError: true,
      );
      return;
    }

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
      if (!mounted) return;
      setState(() {
        _isOnline = true;
        _isConnecting = false;
      });
    });

    _socket!.on('incoming_chat_request', (data) {
      final String sessionId = (data['sessionId'] ?? '').toString();
      if (sessionId.isEmpty) return;

      if (_incomingRequests.any((req) => req['sessionId'] == sessionId)) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _incomingRequests.insert(0, {
          'sessionId': sessionId,
          'userId': (data['userId'] ?? '').toString(),
          'textPreview': (data['textPreview'] ?? 'No preview available.').toString(),
          'createdAt': data['createdAt'] != null
              ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now(),
        });
      });

      _showNotification(
        'New consultation request',
        (data['textPreview'] ?? 'A customer is waiting for pharmacist support.')
            .toString(),
      );
    });

    _socket!.onDisconnect((_) {
      if (!mounted) return;
      setState(() {
        _isOnline = false;
        _isConnecting = false;
      });
    });

    _socket!.onError((err) {
      debugPrint('Pharmacist socket error: $err');
      if (!mounted) return;
      setState(() {
        _isOnline = false;
        _isConnecting = false;
      });
    });
  }

  Future<void> _refreshDashboard() async {
    if (_socket?.connected != true) {
      await _connectSocket();
    } else if (mounted) {
      setState(() {});
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  void _claimSession(String sessionId) {
    if (!_isOnline || _socket == null) {
      _showNotification(
        'Offline',
        'You must be online to claim a consultation.',
        isError: true,
      );
      return;
    }

    _socket!.emitWithAck(
      'pharmacist_claim_session',
      {'sessionId': sessionId},
      ack: (response) {
        final Map<String, dynamic> data = response.isNotEmpty ? response[0] : {};

        if (data['success'] == true) {
          if (!mounted) return;
          setState(() {
            _incomingRequests.removeWhere((req) => req['sessionId'] == sessionId);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Consultation claimed successfully.'),
            ),
          );

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                sessionId: sessionId,
                isPharmacistView: true,
              ),
            ),
          );
        } else {
          final message = (data['message'] ??
                  'This consultation may already be assigned to another pharmacist.')
              .toString();

          _showNotification('Claim failed', message, isError: true);

          if (message.contains('already claimed') && mounted) {
            setState(() {
              _incomingRequests.removeWhere((req) => req['sessionId'] == sessionId);
            });
          }
        }
      },
    );
  }

  void _showNotification(
    String title,
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        backgroundColor: isError ? PharmacyUi.danger : PharmacyUi.deepNavy,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatReceivedTime(DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} hr ago';
    }
    return DateFormat('MMM d, h:mm a').format(value);
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = _isConnecting
        ? 'Connecting'
        : _isOnline
            ? 'Online'
            : 'Offline';
    final statusColor = _isConnecting
        ? PharmacyUi.warning
        : _isOnline
            ? PharmacyUi.success
            : PharmacyUi.danger;

    return Theme(
      data: PharmacyUi.theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pharmacist Workspace'),
          actions: [
            IconButton(
              tooltip: 'Reconnect',
              onPressed: _connectSocket,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshDashboard,
          color: PharmacyUi.deepNavy,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: [
              PharmacyHero(
                badge: 'Healthcare operations',
                title: 'Pharmacy dashboard',
                subtitle:
                    'Manage incoming consultation demand, stay ready for live claims, and move patients into the right support flow fast.',
                icon: Icons.local_pharmacy_rounded,
                stats: [
                  PharmacyStat(
                    label: 'Queue size',
                    value: '${_incomingRequests.length}',
                  ),
                  PharmacyStat(
                    label: 'Connection',
                    value: statusLabel,
                  ),
                  PharmacyStat(
                    label: 'Mode',
                    value: _isOnline ? 'Accepting consults' : 'Standby',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PharmacyPanel(
                title: 'Readiness status',
                subtitle:
                    'Keep your consultation workspace available so patients can be handed over quickly from AI support.',
                child: Row(
                  children: [
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _isOnline
                            ? Icons.health_and_safety_outlined
                            : Icons.portable_wifi_off_outlined,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isOnline
                                ? 'You are live and can claim consultation requests as they arrive.'
                                : 'Reconnect to begin receiving and claiming live pharmacy consultations.',
                            style: const TextStyle(
                              color: PharmacyUi.mutedText,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PharmacyPanel(
                title: 'Pending consultation requests',
                subtitle:
                    'New pharmacy support sessions appear here the moment they are escalated.',
                child: _incomingRequests.isEmpty
                    ? Column(
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined,
                            size: 72,
                            color: PharmacyUi.deepNavy.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No active requests right now.',
                            style: TextStyle(
                              color: PharmacyUi.deepNavy,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Stay connected and new patient escalations will appear here automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: PharmacyUi.mutedText,
                              height: 1.5,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < _incomingRequests.length; i++) ...[
                            _buildRequestCard(_incomingRequests[i]),
                            if (i != _incomingRequests.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              PharmacyPanel(
                title: 'Care handling reminders',
                subtitle:
                    'A few operational habits help consultations feel safe, fast, and trustworthy.',
                child: const Column(
                  children: [
                    _PharmacyReminder(
                      icon: Icons.medication_outlined,
                      text:
                          'Clarify dosage concerns and check for allergy or interaction risks before recommending next steps.',
                    ),
                    SizedBox(height: 12),
                    _PharmacyReminder(
                      icon: Icons.schedule_outlined,
                      text:
                          'Claim only the sessions you can actively manage so patients do not wait in a silent consultation.',
                    ),
                    SizedBox(height: 12),
                    _PharmacyReminder(
                      icon: Icons.fact_check_outlined,
                      text:
                          'Keep answers concise, professional, and action-focused when handing over from AI support.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final userId = (request['userId'] as String?) ?? '';
    final preview = (request['textPreview'] as String?) ?? 'No preview available.';
    final createdAt = request['createdAt'] as DateTime? ?? DateTime.now();
    final sessionId = (request['sessionId'] as String?) ?? '';

    final shortUserId = userId.length > 8 ? '${userId.substring(0, 8)}...' : userId;
    final shortSessionId =
        sessionId.length > 8 ? '${sessionId.substring(0, 8)}...' : sessionId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PharmacyUi.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PharmacyUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: PharmacyUi.deepNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: PharmacyUi.deepNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortUserId.isEmpty ? 'Patient session' : 'Patient $shortUserId',
                      style: const TextStyle(
                        color: PharmacyUi.deepNavy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session $shortSessionId',
                      style: const TextStyle(
                        color: PharmacyUi.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: PharmacyUi.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatReceivedTime(createdAt),
                  style: const TextStyle(
                    color: PharmacyUi.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            preview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PharmacyUi.deepNavy,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showNotification('Request preview', preview);
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _claimSession(sessionId),
                  icon: const Icon(Icons.medical_services_outlined),
                  label: const Text('Claim'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PharmacyReminder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PharmacyReminder({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: PharmacyUi.deepNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: PharmacyUi.deepNavy, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: PharmacyUi.deepNavy,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
