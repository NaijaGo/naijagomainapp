import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:naija_go/auth/screens/login_screen.dart';
import 'package:naija_go/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../services/socket_service.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'categories_screen.dart'
    hide
        accentGreen,
        borderGrey,
        lightGrey,
        primaryNavy,
        secondaryBlack,
        softGrey,
        white;
import 'home_screen.dart';
import 'notifications_screen.dart';

class AppUi {
  static const Color primaryNavy = Color(0xFF102B5C);
  static const Color deepNavy = Color(0xFF081A3A);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color dangerRed = Color(0xFFEF4444);

  static const Color softGrey = Color(0xFFF5F7FB);
  static const Color white = Colors.white;
  static const Color secondaryBlack = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color borderGrey = Color(0xFFE5E7EB);
}

class GuestPlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onLoginTapped;

  const GuestPlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
    required this.onLoginTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppUi.softGrey,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: AppUi.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppUi.deepNavy, AppUi.primaryNavy],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppUi.secondaryBlack,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppUi.mutedText,
                      fontSize: 14.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: AppUi.primaryNavy,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Login gives you access to your cart, orders, account, and saved preferences.',
                            style: TextStyle(
                              color: AppUi.mutedText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: onLoginTapped,
                      icon: const Icon(Icons.login),
                      label: const Text(
                        'Log in / Register',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppUi.primaryNavy,
                        foregroundColor: AppUi.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainAppNavigator extends StatefulWidget {
  final VoidCallback onLogout;

  const MainAppNavigator({super.key, required this.onLogout});

  @override
  State<MainAppNavigator> createState() => _MainAppNavigatorState();
}

class _MainAppNavigatorState extends State<MainAppNavigator>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _errorMessage;
  List<dynamic> _notifications = [];
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserStatus();
  }

  @override
  void dispose() {
    _socketService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUserStatus();
    }
  }

  Future<void> _navigateToLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          onLoginSuccess: () {
            Navigator.of(context).pop();
            _fetchUserStatus();
            _onItemTapped(3);
          },
        ),
      ),
    );
    _fetchUserStatus();
  }

  List<Widget> get _widgetOptions {
    final homeScreen = HomeScreen(onReturnToDashboard: _returnToDashboard);
    final categoriesScreen = CategoriesScreen(
      showAppBar: false,
      onReturnToDashboard: _returnToDashboard,
    );

    final protectedCartScreen = GuestPlaceholderScreen(
      title: 'Shopping Cart',
      message: 'Log in to manage your cart, wishlist, and orders with ease.',
      onLoginTapped: _navigateToLogin,
    );

    final protectedAccountScreen = GuestPlaceholderScreen(
      title: 'My Account',
      message: 'Log in to view your profile, addresses, orders, and settings.',
      onLoginTapped: _navigateToLogin,
    );

    return <Widget>[
      homeScreen,
      _isLoggedIn
          ? CartScreen(onOrderSuccess: _fetchUserStatus)
          : protectedCartScreen,
      categoriesScreen,
      _isLoggedIn
          ? AccountScreen(onLogout: widget.onLogout)
          : protectedAccountScreen,
    ];
  }

  Future<void> _fetchUserStatus() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    try {
      final userUrl = Uri.parse('$baseUrl/api/auth/me');
      final userResponse = await http.get(
        userUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (userResponse.statusCode == 200) {
        final responseData = jsonDecode(userResponse.body);
        final notifications = responseData['notifications'] as List? ?? [];
        final userId = responseData['_id']?.toString();
        setState(() {
          _isLoggedIn = true;
          _notifications = _dedupeNotifications([
            ...notifications,
            ..._notifications,
          ]);
        });
        unawaited(_connectUserNotifications(userId));
      } else {
        final responseData = jsonDecode(userResponse.body);
        setState(() {
          _errorMessage =
              responseData['message'] ?? 'Failed to fetch user status.';
          _isLoggedIn = false;
          _notifications = [];
        });

        if (userResponse.statusCode == 401) {
          await prefs.remove('jwt_token');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred while fetching user status.';
        _isLoggedIn = false;
        _notifications = [];
      });
      debugPrint('MainAppNavigator fetch error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'NaijaGo';
      case 1:
        return 'Cart';
      case 2:
        return 'Categories';
      case 3:
        return 'Account';
      default:
        return 'NaijaGo';
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _returnToDashboard() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _onItemTapped(0);
  }

  Future<void> _connectUserNotifications(String? userId) async {
    if (userId == null || userId.isEmpty) return;

    await _socketService.connect(baseUrl);

    void handlePayload(dynamic payload) {
      if (!mounted) return;

      final normalizedPayload = payload is List && payload.isNotEmpty
          ? payload.first
          : payload;
      final data = normalizedPayload is Map
          ? Map<String, dynamic>.from(normalizedPayload)
          : <String, dynamic>{'message': normalizedPayload.toString()};
      final message = _socketNotificationMessage(
        data,
        fallback: 'You have a new order update.',
      );

      setState(() {
        _notifications = _dedupeNotifications([
          {
            '_id': DateTime.now().microsecondsSinceEpoch.toString(),
            'type': data['type']?.toString() ?? 'order_update',
            'message': message,
            'read': false,
            'createdAt': DateTime.now().toIso8601String(),
          },
          ..._notifications,
        ]);
      });

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: 'Open', onPressed: _openNotifications),
        ),
      );
      unawaited(_playUserAlert());
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (mounted) return _fetchUserStatus();
        }),
      );
    }

    for (final event in [
      'user_$userId',
      'order_update',
      'order_claimed',
      'order_picked_up',
      'order_delivered',
      'pharmacy_chat_message',
    ]) {
      _socketService.off(event);
      _socketService.on(event, handlePayload);
    }
  }

  Future<void> _playUserAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 320));
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (_) {
      // Some targets do not support alert sounds or haptics.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            NotificationsScreen(notifications: _notifications),
      ),
    );
    await _fetchUserStatus();
  }

  List<dynamic> _dedupeNotifications(Iterable<dynamic> rawItems) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final raw in rawItems) {
      final item = _notificationMap(raw);
      if (item.isEmpty) continue;
      final key = _notificationFingerprint(item);
      if (key.isEmpty || seen.add(key)) {
        result.add(item);
      }
    }

    result.sort((a, b) {
      final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '');
      return (bDate ?? DateTime(0)).compareTo(aDate ?? DateTime(0));
    });

    return result;
  }

  Map<String, dynamic> _notificationMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  String _notificationFingerprint(Map<String, dynamic> item) {
    final nestedData = _notificationMap(item['data']);
    final type =
        item['type']?.toString() ?? nestedData['type']?.toString() ?? '';
    final relatedId =
        item['relatedId']?.toString() ??
        item['orderId']?.toString() ??
        nestedData['relatedId']?.toString() ??
        nestedData['orderId']?.toString() ??
        '';
    final message = (item['message']?.toString() ?? '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    final id = item['_id']?.toString() ?? item['id']?.toString() ?? '';

    if (message.isNotEmpty) return '$type|$relatedId|$message';
    return id;
  }

  String _socketNotificationMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final title = data['title']?.toString().trim() ?? '';
    final message = data['message']?.toString().trim() ?? '';

    if (title.isNotEmpty &&
        message.isNotEmpty &&
        !message.toLowerCase().startsWith('${title.toLowerCase()}:')) {
      return '$title: $message';
    }

    return message.isNotEmpty ? message : fallback;
  }

  Widget _buildLoadingState() {
    return Container(
      color: AppUi.softGrey,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppUi.primaryNavy),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Loading your experience...',
              style: TextStyle(
                color: AppUi.mutedText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: AppUi.softGrey,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                color: AppUi.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppUi.dangerRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppUi.dangerRed,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(
                      color: AppUi.secondaryBlack,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Unable to load data right now.',
                    style: const TextStyle(
                      color: AppUi.mutedText,
                      fontSize: 14.5,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _fetchUserStatus,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppUi.primaryNavy,
                        foregroundColor: AppUi.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Try again',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(CartProvider cartProvider) {
    final unreadCount = _notifications
        .where((notification) => notification['read'] != true)
        .length;

    return AppBar(
      backgroundColor: AppUi.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      title: Text(
        _getAppBarTitle(_selectedIndex),
        style: const TextStyle(
          color: AppUi.secondaryBlack,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppUi.borderGrey.withValues(alpha: 0.7),
        ),
      ),
      actions: [
        if (_isLoggedIn)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppUi.secondaryBlack,
                ),
                onPressed: _openNotifications,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppUi.dangerRed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(
                Icons.shopping_cart_outlined,
                color: AppUi.secondaryBlack,
              ),
              onPressed: () => _onItemTapped(1),
            ),
            if (cartProvider.itemCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppUi.dangerRed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    cartProvider.itemCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppUi.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: AppUi.white,
          selectedItemColor: AppUi.primaryNavy,
          unselectedItemColor: AppUi.mutedText,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppUi.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppUi.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppUi.softGrey,
      appBar: _buildAppBar(cartProvider),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
