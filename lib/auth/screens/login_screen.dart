import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tech_glow_background.dart';
import 'forgot_password_screen.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final LocalAuthentication auth = LocalAuthentication();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _passwordStorageKey = 'user_password';

  static const Color primaryNavy = AppTheme.primaryNavy;
  static const Color deepNavy = AppTheme.deepNavy;
  static const Color dangerRed = AppTheme.dangerRed;
  static const Color secondaryBlack = AppTheme.secondaryBlack;
  static const Color mutedText = AppTheme.mutedText;
  static const Color borderGrey = AppTheme.borderGrey;
  static const Color white = AppTheme.cardWhite;
  static const Color brandSoftText = Color(0xFFF4F8FF);
  static const Color brandMutedText = Color(0xFFD5E0F2);

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _canCheckBiometrics = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('user_email');

    if (!mounted || savedEmail == null || savedEmail.isEmpty) {
      return;
    }

    _emailController.text = savedEmail;
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await auth.canCheckBiometrics;
      if (!mounted) {
        return;
      }
      setState(() {
        _canCheckBiometrics = canCheck;
      });
    } catch (_) {}
  }

  Future<String> _getDeviceFingerprint() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      final platform = Theme.of(context).platform;

      if (platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.id}-${androidInfo.model}';
      } else if (platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.identifierForVendor ?? 'unknown_ios_vendor'}-${iosInfo.model}';
      }
    } catch (e) {
      debugPrint('Error getting device fingerprint: $e');
    }

    return 'unknown-device';
  }

  Future<String?> _getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final securePassword = await _secureStorage.read(
        key: _passwordStorageKey,
      );
      if (securePassword != null && securePassword.isNotEmpty) {
        return securePassword;
      }
    } catch (e) {
      debugPrint('Error reading secure password: $e');
    }

    final legacyPassword = prefs.getString(_passwordStorageKey);
    if (legacyPassword == null || legacyPassword.isEmpty) {
      return null;
    }

    try {
      await _secureStorage.write(
        key: _passwordStorageKey,
        value: legacyPassword,
      );
      await prefs.remove(_passwordStorageKey);
    } catch (e) {
      debugPrint('Error migrating legacy password storage: $e');
    }

    return legacyPassword;
  }

  Future<void> _persistPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      await _secureStorage.write(key: _passwordStorageKey, value: password);
      await prefs.remove(_passwordStorageKey);
    } catch (e) {
      debugPrint('Error writing secure password: $e');
    }
  }

  Future<String?> _getOneSignalPlayerId() async {
    try {
      final String? pushId = OneSignal.User.pushSubscription.id;
      if (pushId != null && pushId.isNotEmpty) {
        return pushId;
      }
    } catch (e) {
      debugPrint('Error getting OneSignal push subscription ID: $e');
    }
    return null;
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    await _loginRequest(email, password);
  }

  Future<void> _loginWithFingerprint() async {
    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'Scan your fingerprint or Face ID to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) {
        return;
      }

      if (authenticated) {
        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString('user_email');
        final savedPassword = await _getSavedPassword();

        if (!mounted) {
          return;
        }

        if (savedEmail != null &&
            savedEmail.isNotEmpty &&
            savedPassword != null &&
            savedPassword.isNotEmpty) {
          await _loginRequest(savedEmail, savedPassword);
        } else {
          _showSnack('No saved login found. Please login normally first.');
        }
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnack('Biometric error: $e');
    }
  }

  Future<void> _loginRequest(String email, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final deviceFingerprint = await _getDeviceFingerprint();
    final oneSignalPlayerId = await _getOneSignalPlayerId();

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/login');

      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'email': email,
          'password': password,
          'deviceFingerprint': deviceFingerprint,
          'oneSignalPlayerId': oneSignalPlayerId ?? '',
        }),
      );

      final Map<String, dynamic> responseData =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final String token = responseData['token'] as String;
        final Map<String, dynamic> userData = Map<String, dynamic>.from(
          responseData['user'] as Map,
        );
        final String userId = (userData['id'] ?? userData['_id'] ?? '')
            .toString();
        final String userEmail = (userData['email'] ?? email).toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('device_fingerprint', deviceFingerprint);
        await prefs.setString('user', json.encode(userData));
        await prefs.setString('user_email', userEmail);
        await _persistPassword(password);

        if (oneSignalPlayerId != null) {
          await prefs.setString('oneSignal_player_id', oneSignalPlayerId);
        }

        if (userId.isNotEmpty) {
          try {
            await OneSignal.login(userId);
            await OneSignal.User.addTags({
              'user_id': userId,
              'email': userEmail,
              'last_login': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            debugPrint('Error linking OneSignal: $e');
          }
        }

        if (!mounted) {
          return;
        }
        _showSnack(responseData['message']?.toString() ?? 'Login successful!');
        widget.onLoginSuccess();
      } else if (response.statusCode == 403 &&
          responseData['message'] ==
              'New device detected. Please check your email to verify this device.') {
        _showSnack(responseData['message'].toString());
      } else {
        setState(() {
          _errorMessage =
              responseData['message']?.toString() ??
              'Login failed. Please check your credentials.';
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
      debugPrint('Login network error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: secondaryBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: mutedText),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: white,
      labelStyle: const TextStyle(color: mutedText, fontSize: 14),
      hintStyle: const TextStyle(color: mutedText, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: primaryNavy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: dangerRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: dangerRed, width: 1.4),
      ),
    );
  }

  Widget _buildTrustBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 18, color: primaryNavy),
          SizedBox(width: AppSpacing.sm - 2),
          Expanded(
            child: Text(
              'Verified device protection is enabled on your account.',
              style: TextStyle(
                fontSize: 12.5,
                color: mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepNavy,
      body: TechGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (AppSpacing.xl * 2),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.sm - 2),
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: white.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xl,
                                    ),
                                    border: Border.all(
                                      color: white.withValues(alpha: 0.16),
                                      width: 1.1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.10,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/bg-erased_logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Welcome back',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: brandSoftText,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm - 2),
                                const Text(
                                  'Sign in to continue shopping from trusted vendors across Nigeria.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: brandMutedText,
                                    fontSize: 14.5,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                            decoration: BoxDecoration(
                              color: white,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Login to NaijaGo',
                                    style: TextStyle(
                                      color: secondaryBlack,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  const Text(
                                    'Enter your email and password below.',
                                    style: TextStyle(
                                      color: mutedText,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildTrustBanner(),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _inputDecoration(
                                      label: 'Email address',
                                      icon: Icons.mail_outline_rounded,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!RegExp(
                                        r'^[^@]+@[^@]+\.[^@]+',
                                      ).hasMatch(value)) {
                                        return 'Please enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    decoration: _inputDecoration(
                                      label: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _isPasswordVisible
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: mutedText,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isPasswordVisible =
                                                !_isPasswordVisible;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.sm + 2),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: dangerRed.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: dangerRed.withValues(
                                            alpha: 0.18,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: dangerRed,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _loginUser,
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor: primaryNavy,
                                        foregroundColor: white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.md,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(white),
                                              ),
                                            )
                                          : const Text(
                                              'Login',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                  if (_canCheckBiometrics) ...[
                                    const SizedBox(height: AppSpacing.sm + 2),
                                    SizedBox(
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        onPressed: _isLoading
                                            ? null
                                            : _loginWithFingerprint,
                                        icon: const Icon(
                                          Icons.fingerprint_rounded,
                                        ),
                                        label: const Text(
                                          'Login with Fingerprint / Face ID',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: primaryNavy,
                                          side: const BorderSide(
                                            color: borderGrey,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.md,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "Don't have an account? ",
                                        style: TextStyle(
                                          color: mutedText,
                                          fontSize: 14,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const RegistrationScreen(),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          'Register',
                                          style: TextStyle(
                                            color: primaryNavy,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const Center(
                            child: Text(
                              'Secure login protected by device verification.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: brandMutedText,
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
