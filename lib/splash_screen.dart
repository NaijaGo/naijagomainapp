import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    if (_hasFinished || !mounted) return;
    _hasFinished = true;
    _timer?.cancel();
    widget.onSplashFinished();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 16,
              child: TextButton(
                onPressed: _finishSplash,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF102B5C),
                ),
                child: const Text('Skip'),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'NaijaGo',
                        image: true,
                        child: AspectRatio(
                          aspectRatio: 2.6,
                          child: ClipRect(
                            child: Image.asset(
                              'assets/naijago-brand.jpg',
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Your neighbourhood. Delivered.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF102B5C),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Discover local businesses. Shop with confidence.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 36),
                      const SizedBox(
                        width: 92,
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius: BorderRadius.all(Radius.circular(3)),
                          color: Color(0xFF008348),
                          backgroundColor: Color(0xFFE8F3EE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Text(
                'LOCAL SHOPPING, MADE SIMPLE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
