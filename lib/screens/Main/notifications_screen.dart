import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tech_glow_background.dart';

const Color whiteBackground = Colors.white;
const Color brandSoftText = Color(0xFFF4F8FF);
const Color brandMutedText = Color(0xFFD5E0F2);
const Color highlightGreen = Color(0xFF61F3AE);

class NotificationsScreen extends StatefulWidget {
  final List<dynamic> notifications;

  const NotificationsScreen({super.key, required this.notifications});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<dynamic> _displayNotifications;
  final Set<String> _markingIds = <String>{};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNotifications = List<dynamic>.from(widget.notifications);
    _sortNotifications();
  }

  int get _unreadCount => _displayNotifications
      .where((notification) => notification['read'] != true)
      .length;

  int get _readCount => _displayNotifications.length - _unreadCount;

  Future<void> _markNotificationAsRead(String notificationId) async {
    if (notificationId.isEmpty || _markingIds.contains(notificationId)) {
      return;
    }

    setState(() {
      _markingIds.add(notificationId);
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _markingIds.remove(notificationId);
        _errorMessage = 'Authentication token not found. Please log in again.';
      });
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/auth/notifications/mark-read/$notificationId'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        setState(() {
          _markLocalNotificationAsRead(notificationId);
          _markingIds.remove(notificationId);
        });
        _showSnack('Notification marked as read.');
        return;
      }

      final responseData = response.body.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(response.body) as Map)
          : <String, dynamic>{};

      setState(() {
        _markingIds.remove(notificationId);
        _errorMessage =
            responseData['message']?.toString() ??
            'Failed to mark notification as read.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _markingIds.remove(notificationId);
        _errorMessage = 'An error occurred: $error';
      });
    }
  }

  void _markLocalNotificationAsRead(String notificationId) {
    final index = _displayNotifications.indexWhere(
      (notification) => notification['_id']?.toString() == notificationId,
    );

    if (index != -1) {
      _displayNotifications[index]['read'] = true;
    }
  }

  void _sortNotifications() {
    _displayNotifications.sort((a, b) {
      final first =
          _parseCreatedAt(a['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final second =
          _parseCreatedAt(b['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return second.compareTo(first);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TechGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Notifications',
            style: TextStyle(color: brandSoftText),
          ),
          iconTheme: const IconThemeData(color: brandSoftText),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _buildSummaryCard(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(),
            ],
            const SizedBox(height: 18),
            if (_displayNotifications.isEmpty)
              _buildEmptyState()
            else
              ..._displayNotifications.map(_buildNotificationCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.deepNavy,
            AppTheme.primaryNavy,
            const Color(0xFF0E7C66),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vendor alerts at a glance',
            style: TextStyle(
              color: whiteBackground,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _unreadCount == 0
                ? 'You are all caught up. New store activity will show up here.'
                : 'You have $_unreadCount unread notification${_unreadCount == 1 ? '' : 's'} waiting for your attention.',
            style: TextStyle(
              color: brandMutedText.withValues(alpha: 0.96),
              fontSize: 14.2,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHeroMetric(label: 'Unread', value: '$_unreadCount'),
              _buildHeroMetric(label: 'Read', value: '$_readCount'),
              _buildHeroMetric(
                label: 'Total',
                value: '${_displayNotifications.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: brandMutedText.withValues(alpha: 0.92),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: whiteBackground,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return _buildSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.dangerRed.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.error_outline, color: AppTheme.dangerRed),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Something needs attention',
                  style: TextStyle(
                    color: AppTheme.secondaryBlack,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return _buildSurfaceCard(
      padding: const EdgeInsets.all(28),
      child: const Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 54,
            color: AppTheme.mutedText,
          ),
          SizedBox(height: 14),
          Text(
            'You\'re all caught up',
            style: TextStyle(
              color: AppTheme.secondaryBlack,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'New vendor alerts, sales updates, and wallet activity will appear here as they happen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.mutedText,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(dynamic rawNotification) {
    final notification = Map<String, dynamic>.from(rawNotification as Map);
    final notificationId = notification['_id']?.toString() ?? '';
    final isRead = notification['read'] == true;
    final isMarking =
        notificationId.isNotEmpty && _markingIds.contains(notificationId);
    final presentation = _notificationPresentation(
      notification['type']?.toString() ?? 'general',
    );
    final createdAt = _parseCreatedAt(notification['createdAt']);
    final message =
        notification['message']?.toString().trim().isNotEmpty == true
        ? notification['message'].toString().trim()
        : 'Notification details unavailable.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: !isRead && !isMarking && notificationId.isNotEmpty
            ? () => _markNotificationAsRead(notificationId)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: whiteBackground.withValues(alpha: isRead ? 0.92 : 0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isRead
                  ? Colors.white.withValues(alpha: 0.70)
                  : presentation.accent.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: presentation.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(presentation.icon, color: presentation.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: const TextStyle(
                            color: AppTheme.secondaryBlack,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildTag(
                              label: presentation.label,
                              backgroundColor: presentation.accent.withValues(
                                alpha: 0.12,
                              ),
                              textColor: presentation.accent,
                            ),
                            _buildTag(
                              label: _formatDate(createdAt),
                              backgroundColor: const Color(0xFFF3F6FA),
                              textColor: AppTheme.mutedText,
                            ),
                            if (!isRead)
                              _buildTag(
                                label: isMarking ? 'Updating...' : 'Unread',
                                backgroundColor: highlightGreen.withValues(
                                  alpha: 0.12,
                                ),
                                textColor: const Color(0xFF0E8A61),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildTrailingStatus(
                    notificationId: notificationId,
                    isRead: isRead,
                    isMarking: isMarking,
                  ),
                ],
              ),
              if (!isRead && notificationId.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  isMarking
                      ? 'Marking this notification as read...'
                      : 'Tap anywhere on this card to mark it as read.',
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 12.8,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingStatus({
    required String notificationId,
    required bool isRead,
    required bool isMarking,
  }) {
    if (isMarking) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: AppTheme.primaryNavy,
        ),
      );
    }

    if (isRead || notificationId.isEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: highlightGreen.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Color(0xFF0E8A61),
          size: 18,
        ),
      );
    }

    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: AppTheme.accentBlue,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTag({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12.3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSurfaceCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: whiteBackground.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }

  _NotificationPresentation _notificationPresentation(String type) {
    switch (type) {
      case 'product_sold':
        return const _NotificationPresentation(
          icon: Icons.shopping_bag_outlined,
          label: 'Product sold',
          accent: AppTheme.accentBlue,
        );
      case 'payment_received':
        return const _NotificationPresentation(
          icon: Icons.payments_outlined,
          label: 'Payment received',
          accent: Color(0xFF10B981),
        );
      case 'wallet_deposit':
        return const _NotificationPresentation(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Wallet deposit',
          accent: Color(0xFF0EA5E9),
        );
      case 'wallet_withdrawal':
        return const _NotificationPresentation(
          icon: Icons.send_outlined,
          label: 'Wallet withdrawal',
          accent: Color(0xFFF59E0B),
        );
      case 'vendor_status_update':
        return const _NotificationPresentation(
          icon: Icons.store_outlined,
          label: 'Vendor update',
          accent: highlightGreen,
        );
      default:
        return const _NotificationPresentation(
          icon: Icons.info_outline,
          label: 'General update',
          accent: AppTheme.primaryNavy,
        );
    }
  }

  DateTime? _parseCreatedAt(dynamic rawValue) {
    if (rawValue is String && rawValue.trim().isNotEmpty) {
      return DateTime.tryParse(rawValue.trim())?.toLocal();
    }
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Time unavailable';
    }

    return DateFormat('dd MMM • hh:mm a').format(date);
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotificationPresentation {
  final IconData icon;
  final String label;
  final Color accent;

  const _NotificationPresentation({
    required this.icon,
    required this.label,
    required this.accent,
  });
}
