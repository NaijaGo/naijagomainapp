import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ionicons/ionicons.dart';
import 'package:naija_go/auth/screens/login_screen.dart';
import 'package:naija_go/providers/cart_provider.dart';
import 'package:naija_go/screens/Main/notifications_screen.dart';
import 'package:naija_go/screens/vendor/add_product_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
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
import 'vendor_screen.dart';

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
                      Ionicons.lock_closed_outline,
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
                            'Login gives you access to your cart, orders, account, and vendor features.',
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
                      icon: const Icon(Ionicons.log_in_outline),
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

  bool _isApprovedVendor = false;
  String _vendorStatus = 'loading';
  DateTime? _rejectionDate;
  double _vendorWalletBalance = 0.0;
  double _appWalletBalance = 0.0;
  double _userWalletBalance = 0.0;
  int _totalProducts = 0;
  int _productsSold = 0;
  int _productsUnsold = 0;
  int _followersCount = 0;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserStatus();
  }

  @override
  void dispose() {
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
            _onItemTapped(4);
          },
        ),
      ),
    );
    _fetchUserStatus();
  }

  List<Widget> get _widgetOptions {
    const homeScreen = HomeScreen();
    const categoriesScreen = CategoriesScreen(showAppBar: false);

    final protectedCartScreen = GuestPlaceholderScreen(
      title: 'Shopping Cart',
      message: 'Log in to manage your cart, wishlist, and orders with ease.',
      onLoginTapped: _navigateToLogin,
    );

    final protectedVendorScreen = GuestPlaceholderScreen(
      title: 'Vendor Access',
      message:
          'Log in to apply as a vendor, manage your store, and track your business performance.',
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
          ? VendorScreen(
              isApprovedVendor: _isApprovedVendor,
              vendorStatus: _vendorStatus,
              rejectionDate: _rejectionDate,
              vendorWalletBalance: _vendorWalletBalance,
              appWalletBalance: _appWalletBalance,
              userWalletBalance: _userWalletBalance,
              totalProducts: _totalProducts,
              productsSold: _productsSold,
              productsUnsold: _productsUnsold,
              followersCount: _followersCount,
              notifications: _notifications,
              onRefresh: _fetchUserStatus,
            )
          : protectedVendorScreen,
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
        _isApprovedVendor = false;
        _vendorStatus = 'guest';
        _vendorWalletBalance = 0.0;
        _appWalletBalance = 0.0;
        _userWalletBalance = 0.0;
        _totalProducts = 0;
        _productsSold = 0;
        _productsUnsold = 0;
        _followersCount = 0;
        _notifications = [];
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
        final Map<String, dynamic> userData = jsonDecode(userResponse.body);

        final isApproved =
            userData['isVendor'] == true &&
            userData['vendorStatus'] == 'approved';

        final status = userData['vendorStatus'] ?? 'none';
        final vendorBalance =
            (userData['vendorWalletBalance'] as num?)?.toDouble() ?? 0.0;
        final appBalance =
            (userData['appWalletBalance'] as num?)?.toDouble() ?? 0.0;
        final userBalance =
            (userData['userWalletBalance'] as num?)?.toDouble() ?? 0.0;
        final rejectionDate =
            (status == 'rejected' && userData['vendorRejectionDate'] != null)
            ? DateTime.parse(userData['vendorRejectionDate'])
            : null;
        final notifications = userData['notifications'] ?? [];
        final followers = userData['followersCount'] ?? 0;

        int totalProds = 0;
        int productsSold = 0;
        int productsUnsold = 0;

        if (isApproved) {
          final statsUrl = Uri.parse('$baseUrl/api/vendor/stats');
          final statsResponse = await http.get(
            statsUrl,
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
          );

          if (statsResponse.statusCode == 200) {
            final Map<String, dynamic> statsData = jsonDecode(
              statsResponse.body,
            );
            totalProds = statsData['totalProducts'] ?? 0;
            productsSold = statsData['productsSold'] ?? 0;
            productsUnsold = statsData['productsUnsold'] ?? 0;
          }
        }

        setState(() {
          _isLoggedIn = true;
          _isApprovedVendor = isApproved;
          _vendorStatus = status;
          _vendorWalletBalance = vendorBalance;
          _appWalletBalance = appBalance;
          _userWalletBalance = userBalance;
          _rejectionDate = rejectionDate;
          _notifications = notifications;
          _followersCount = followers;
          _totalProducts = totalProds;
          _productsSold = productsSold;
          _productsUnsold = productsUnsold;
        });
      } else {
        final responseData = jsonDecode(userResponse.body);
        setState(() {
          _errorMessage =
              responseData['message'] ?? 'Failed to fetch user status.';
          _isLoggedIn = false;
          _isApprovedVendor = false;
          _vendorStatus = 'none';
        });

        if (userResponse.statusCode == 401) {
          await prefs.remove('jwt_token');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred while fetching user status.';
        _isLoggedIn = false;
        _isApprovedVendor = false;
        _vendorStatus = 'none';
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
        return _isLoggedIn && _isApprovedVendor ? 'Vendor Dashboard' : 'Vendor';
      case 4:
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
    final unreadCount = _notifications.where((n) => n['read'] == false).length;

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
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(
                Ionicons.cart_outline,
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
        if (_isApprovedVendor && _selectedIndex == 3)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppUi.secondaryBlack,
                ),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          NotificationsScreen(notifications: _notifications),
                    ),
                  );
                  _fetchUserStatus();
                },
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
                      unreadCount.toString(),
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
              icon: Icon(Ionicons.home_outline),
              activeIcon: Icon(Ionicons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Ionicons.cart_outline),
              activeIcon: Icon(Ionicons.cart),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Ionicons.grid_outline),
              activeIcon: Icon(Ionicons.grid),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Ionicons.storefront_outline),
              activeIcon: Icon(Ionicons.storefront),
              label: 'Vendor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Ionicons.person_outline),
              activeIcon: Icon(Ionicons.person),
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
      floatingActionButton: _selectedIndex == 3 && _isApprovedVendor
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddProductScreen(),
                  ),
                );
                _fetchUserStatus();
              },
              backgroundColor: AppUi.primaryNavy,
              foregroundColor: AppUi.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Product',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
