import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../constants.dart';
import '../../widgets/tech_glow_background.dart';
import 'email_verification_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, this.initialReferralCode});

  final String? initialReferralCode;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _errorMessage;

  static const Color primaryNavy = Color(0xFF102B5C);
  static const Color deepNavy = Color(0xFF081A3A);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color secondaryBlack = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color borderGrey = Color(0xFFE5E7EB);
  static const Color white = Colors.white;
  static const Color brandSoftText = Color(0xFFF4F8FF);
  static const Color brandMutedText = Color(0xFFD5E0F2);

  @override
  void initState() {
    super.initState();
    _referralCodeController.text = widget.initialReferralCode?.trim() ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String email = _emailController.text.trim();
    final String phoneNumber = _phoneNumberController.text.trim();
    final String password = _passwordController.text;
    final String referralCode = _referralCodeController.text.trim();

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/register');
      final Map<String, String> requestBody = <String, String>{
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phoneNumber,
        'password': password,
      };

      if (referralCode.isNotEmpty) {
        requestBody['referralCode'] = referralCode;
      }

      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestBody),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message'] ?? 'Registration successful!',
            ),
            backgroundColor: secondaryBlack,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(email: email),
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              responseData['message'] ??
              'Registration failed. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
      debugPrint('Registration network error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryNavy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: dangerRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: dangerRed, width: 1.4),
      ),
    );
  }

  Widget _buildTopIntro() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [deepNavy, primaryNavy],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset('assets/bg-erased_logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 18),
        const Text(
          'Create your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: brandSoftText,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Join NaijaGo and start shopping from trusted vendors across Nigeria.',
          textAlign: TextAlign.center,
          style: TextStyle(color: brandMutedText, fontSize: 14.5, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildErrorBox() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: dangerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dangerRed.withValues(alpha: 0.18)),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(
          color: dangerRed,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNameRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _firstNameController,
            decoration: _inputDecoration(
              label: 'First name',
              icon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter first name';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _lastNameController,
            decoration: _inputDecoration(
              label: 'Last name',
              icon: Icons.badge_outlined,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter last name';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(22),
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
              'Sign up details',
              style: TextStyle(
                color: secondaryBlack,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Fill in your information below to continue.',
              style: TextStyle(color: mutedText, fontSize: 13.5),
            ),
            const SizedBox(height: 18),

            _buildErrorBox(),

            _buildNameRow(),
            const SizedBox(height: 14),

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
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _phoneNumberController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                label: 'Phone number',
                icon: Icons.phone_outlined,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (!RegExp(r'^(?:\+234|0)[789]\d{9}$').hasMatch(value)) {
                  return 'Please enter a valid Nigerian phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _referralCodeController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDecoration(
                label: 'Referral code (optional)',
                icon: Icons.card_giftcard_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }
                if (value.trim().length < 4) {
                  return 'Enter a valid referral code';
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
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters long';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: _inputDecoration(
                label: 'Confirm password',
                icon: Icons.lock_reset_outlined,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: mutedText,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 18,
                    color: primaryNavy,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A verification email will be sent after registration.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: mutedText,
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
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerUser,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: primaryNavy,
                  foregroundColor: white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(white),
                        ),
                      )
                    : const Text(
                        'Create account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(color: mutedText, fontSize: 14),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Login',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: white,
        surfaceTintColor: Colors.transparent,
      ),
      body: TechGlowBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    _buildTopIntro(),
                    const SizedBox(height: 28),
                    _buildFormCard(),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text(
                        'Your account is secured with email verification.',
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
        ),
      ),
    );
  }
}
