import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../constants.dart'; // Make sure baseUrl is defined here

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  String? _resendMessage;
  bool _isSuccess = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  // Resend verification email API call
  Future<void> _resendVerificationEmail() async {
    if (_cooldownSeconds > 0) return;

    setState(() {
      _isResending = true;
      _resendMessage = null;
      _isSuccess = false;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email.trim()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _isSuccess = true;
          _resendMessage =
              data['message'] ??
              'New verification email sent! Check your inbox/spam.';
        });

        // Start cooldown
        _startCooldown(90); // 90 seconds = 1.5 minutes
      } else {
        setState(() {
          _resendMessage =
              data['message'] ?? 'Failed to resend. Please try again later.';
        });
      }
    } catch (e) {
      setState(() {
        _resendMessage = 'Network error. Please check your connection.';
      });
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  void _startCooldown(int seconds) {
    _cooldownSeconds = seconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 0) {
          _cooldownSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: color.primary,
      appBar: AppBar(
        title: Text(
          'Verify Your Email',
          style: TextStyle(color: color.onPrimary),
        ),
        backgroundColor: color.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: color.onPrimary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_outlined, size: 100, color: color.onPrimary),
              const SizedBox(height: 30),

              Text(
                'A verification email has been sent to:',
                textAlign: TextAlign.center,
                style: TextStyle(color: color.onPrimary, fontSize: 20),
              ),
              const SizedBox(height: 10),

              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color.onPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Please check your inbox (and spam/junk folder) and click the link to activate your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color.onPrimary.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 40),

              // ── RESEND SECTION ──
              if (_resendMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _resendMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isSuccess ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              ElevatedButton(
                onPressed: (_isResending || _cooldownSeconds > 0)
                    ? null
                    : _resendVerificationEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.onPrimary,
                  foregroundColor: color.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  disabledBackgroundColor: color.onPrimary.withValues(
                    alpha: 0.6,
                  ),
                ),
                child: _isResending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                      )
                    : Text(
                        _cooldownSeconds > 0
                            ? 'Resend in ${_cooldownSeconds}s'
                            : "Didn't receive the email? Resend",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Back to Login
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.onPrimary,
                  foregroundColor: color.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Back to Login',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
