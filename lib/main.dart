// lib/main.dart

import 'dart:async';
import 'dart:convert'; // For json.decode()

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http; // For http requests
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './auth/screens/registration_screen.dart';
import 'providers/cart_provider.dart';
import './screens/Main/main_app_navigator.dart';
import './splash_screen.dart';

const Color _lightPrimaryColor = Color.fromARGB(255, 3, 2, 76);
const Color _lightSecondaryColor = Color(0xFFADFF2F);
const Color _lightAccentColor = Color(0xFFF0F2F5);

const Color _darkPrimaryColor = Color.fromARGB(255, 144, 202, 249);
const Color _darkSecondaryColor = Color(0xFF64FFDA);
const Color _darkBackgroundColor = Color(0xFF121212);
const Color _darkSurfaceColor = Color(0xFF1E1E1E);
final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: _lightPrimaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.white),
  ),
  colorScheme: const ColorScheme.light(
    primary: _lightPrimaryColor,
    onPrimary: Colors.white,
    secondary: _lightSecondaryColor,
    onSecondary: _lightPrimaryColor,
    surface: Colors.white,
    onSurface: _lightPrimaryColor,
    error: Colors.red,
    onError: Colors.white,
  ),
  cardColor: _lightAccentColor,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _lightPrimaryColor,
      foregroundColor: Colors.white,
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: _lightPrimaryColor),
    bodyMedium: TextStyle(color: _lightPrimaryColor),
    titleLarge: TextStyle(color: _lightPrimaryColor),
    headlineLarge: TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
  ),
  iconTheme: const IconThemeData(color: _lightPrimaryColor),
  splashColor: _lightSecondaryColor.withValues(alpha: 0.5),
  highlightColor: _lightSecondaryColor.withValues(alpha: 0.3),
  fontFamily: 'Roboto',
);

final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: _darkBackgroundColor,
  cardColor: _darkSurfaceColor,
  appBarTheme: const AppBarTheme(
    backgroundColor: _darkSurfaceColor,
    foregroundColor: Colors.white,
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.white),
  ),
  colorScheme: const ColorScheme.dark(
    primary: _darkPrimaryColor,
    onPrimary: _darkBackgroundColor,
    secondary: _darkSecondaryColor,
    onSecondary: _darkBackgroundColor,
    surface: _darkSurfaceColor,
    onSurface: Colors.white,
    error: Colors.redAccent,
    onError: _darkBackgroundColor,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _darkPrimaryColor,
      foregroundColor: _darkBackgroundColor,
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white70),
    titleLarge: TextStyle(color: Colors.white),
    headlineLarge: TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
  ),
  iconTheme: const IconThemeData(color: Colors.white),
  splashColor: _darkSecondaryColor.withValues(alpha: 0.5),
  highlightColor: _darkSecondaryColor.withValues(alpha: 0.3),
  fontFamily: 'Roboto',
);

class ThemeChanger extends StatefulWidget {
  final Widget child;

  const ThemeChanger({super.key, required this.child});

  @override
  State<ThemeChanger> createState() => ThemeChangerState();

  static ThemeChangerState of(BuildContext context) {
    return context.findAncestorStateOfType<ThemeChangerState>()!;
  }
}

class ThemeChangerState extends State<ThemeChanger> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    _saveThemeMode(themeMode);
  }

  Future<void> _saveThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _appNavigatorKey,
      themeMode: _themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      home: widget.child,
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentThemePreference();
  }

  Future<void> _loadCurrentThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _onToggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });

    ThemeChanger.of(
      context,
    ).changeTheme(value ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Dark Mode'),
            trailing: Switch(value: _isDarkMode, onChanged: _onToggleTheme),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

class NaijaGoApp extends StatefulWidget {
  const NaijaGoApp({super.key});

  @override
  State<NaijaGoApp> createState() => _NaijaGoAppState();
}

class _NaijaGoAppState extends State<NaijaGoApp> {
  final AppLinks _appLinks = AppLinks();
  late Future<bool> _isLoggedInFuture;
  StreamSubscription<Uri>? _referralLinkSubscription;
  bool _showSplash = true;
  bool _hasAttemptedNotificationPrompt = false;
  String? _pendingReferralCode;
  String? _lastHandledReferralCode;

  @override
  void initState() {
    super.initState();
    _initializeOneSignal();
    _initializeReferralLinks();
    _isLoggedInFuture = _checkLoginStatus();
  }

  @override
  void dispose() {
    _referralLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeOneSignal() async {
    _setupNotificationClickHandler();
    _setupUserTracking();
  }

  Future<void> _maybeRequestNotificationPermission() async {
    if (_hasAttemptedNotificationPrompt) {
      return;
    }

    _hasAttemptedNotificationPrompt = true;

    try {
      final canRequest = await OneSignal.Notifications.canRequest();
      if (!canRequest || !mounted) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) {
        return;
      }

      await OneSignal.Notifications.requestPermission(false);
    } catch (error) {
      debugPrint('Unable to request OneSignal permission: $error');
    }
  }

  Future<void> _initializeReferralLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      _queueReferralCodeFromUri(initialUri);
    } catch (error) {
      debugPrint('Unable to read initial referral link: $error');
    }

    _referralLinkSubscription = _appLinks.uriLinkStream.listen(
      _queueReferralCodeFromUri,
      onError: (Object error) {
        debugPrint('Unable to listen for referral links: $error');
      },
    );
  }

  void _queueReferralCodeFromUri(Uri? uri) {
    final referralCode = _extractReferralCode(uri);
    if (referralCode == null || referralCode.isEmpty) {
      return;
    }
    if (_pendingReferralCode == referralCode ||
        _lastHandledReferralCode == referralCode) {
      return;
    }

    _pendingReferralCode = referralCode;
    _openPendingReferralSignupIfReady();
  }

  String? _extractReferralCode(Uri? uri) {
    if (uri == null) {
      return null;
    }

    final rawCode =
        uri.queryParameters['ref'] ??
        uri.queryParameters['referralCode'] ??
        uri.queryParameters['inviteCode'] ??
        uri.queryParameters['code'];
    if (rawCode == null || rawCode.trim().isEmpty) {
      return null;
    }

    final normalizedCode = rawCode
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    return normalizedCode.isEmpty ? null : normalizedCode;
  }

  Future<void> _openPendingReferralSignupIfReady() async {
    final referralCode = _pendingReferralCode;
    if (!mounted ||
        _showSplash ||
        referralCode == null ||
        referralCode.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (!mounted) {
      return;
    }
    if (token != null && token.isNotEmpty) {
      _pendingReferralCode = null;
      return;
    }

    final navigator = _appNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    _pendingReferralCode = null;
    _lastHandledReferralCode = referralCode;

    await navigator.push(
      MaterialPageRoute(
        builder: (_) => RegistrationScreen(initialReferralCode: referralCode),
      ),
    );
  }

  void _setupNotificationClickHandler() {
    OneSignal.Notifications.addClickListener((event) {
      final notification = event.notification;
      final additionalData = notification.additionalData;

      if (additionalData != null) {
        debugPrint('Notification clicked with data: $additionalData');

        if (additionalData['product_id'] != null) {
          debugPrint('Navigate to product: ${additionalData['product_id']}');
        }

        if (additionalData['type'] == 'abandoned_cart') {
          debugPrint('Navigate to cart');
        }
      }
    });
  }

  Future<void> _setupUserTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null) {
      final userData = await _getUserDataFromBackend(token);
      if (userData != null) {
        // SDK v5.x FIX: Changed from setExternalUserId() to login()
        await OneSignal.login(userData['id']);

        await OneSignal.User.addTags({
          'user_id': userData['id'],
          'email': userData['email'],
          'total_purchases': userData['totalPurchases']?.toString() ?? '0',
          'last_purchase': userData['lastPurchaseDate'] ?? 'never',
          'customer_tier': userData['customerTier'] ?? 'new',
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _getUserDataFromBackend(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://naijago-backend.onrender.com/api/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return token != null;
  }

  void handleSplashFinished() {
    setState(() {
      _showSplash = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPendingReferralSignupIfReady();
      _maybeRequestNotificationPermission();
    });
  }

  void handleLoginSuccess() {
    setState(() {
      _isLoggedInFuture = Future.value(true);
    });
    _setupUserTracking();
  }

  void handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('order_count');

    // SDK v5.x FIX: Changed from removeExternalUserId() to logout()
    await OneSignal.logout();

    setState(() {
      _isLoggedInFuture = Future.value(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        Widget homeScreen;
        if (_showSplash) {
          homeScreen = SplashScreen(onSplashFinished: handleSplashFinished);
        } else {
          homeScreen = MainAppNavigator(onLogout: handleLogout);
        }

        return homeScreen;
      },
    );
  }
}

Future<void> _loadEnvironmentConfig() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('Unable to load .env configuration: $error');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _loadEnvironmentConfig();

  // Initialize OneSignal early (before runApp)
  try {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    // SDK v5.x FIX: Removed 'await' from initialize() since it returns void
    OneSignal.initialize('76438b8d-4b39-49eb-805c-11eb934f5a66');
  } catch (error) {
    debugPrint('Unable to initialize OneSignal at startup: $error');
  }
  // CRITICAL FIX: REMOVED permission request from here - moved to NaijaGoApp initState()

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CartProvider())],
      child: const ThemeChanger(child: NaijaGoApp()),
    ),
  );
}
