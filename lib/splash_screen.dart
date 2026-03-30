import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'widgets/tech_glow_background.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashFinished;

  const SplashScreen({super.key, required this.onSplashFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _hasFinished = false;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 10), _finishSplash);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finishSplash() {
    if (_hasFinished || !mounted) {
      return;
    }

    _hasFinished = true;
    _timer?.cancel();
    widget.onSplashFinished();
  }

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    const softText = Color(0xFFD9E2F2);

    return Scaffold(
      body: TechGlowBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 10,
                right: 16,
                child: TextButton(
                  onPressed: _finishSplash,
                  style: TextButton.styleFrom(
                    foregroundColor: white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    backgroundColor: white.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(color: white.withValues(alpha: 0.12)),
                    ),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                            width: 172,
                            height: 172,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  white.withValues(alpha: 0.14),
                                  white.withValues(alpha: 0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: white.withValues(alpha: 0.16),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.20),
                                  blurRadius: 36,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/bg-erased_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 700.ms)
                          .scale(
                            begin: const Offset(0.88, 0.88),
                            end: const Offset(1.0, 1.0),
                            curve: Curves.easeOutBack,
                            duration: 950.ms,
                          )
                          .slideY(
                            begin: 0.16,
                            end: 0.0,
                            curve: Curves.easeOutCubic,
                            duration: 950.ms,
                          ),
                      const SizedBox(height: 26),
                      const Text(
                            'NaijaGo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 700.ms)
                          .slideY(begin: 0.20, end: 0.0, duration: 700.ms),
                      const SizedBox(height: 10),
                      const Text(
                        'Shop smart. Buy with confidence.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: softText,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          letterSpacing: 0.2,
                        ),
                      ).animate().fadeIn(delay: 850.ms, duration: 700.ms),
                      const SizedBox(height: 34),
                      Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(white),
                            ),
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .fadeIn(delay: 1200.ms, duration: 500.ms)
                          .shimmer(
                            duration: 1400.ms,
                            color: white.withValues(alpha: 0.20),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
