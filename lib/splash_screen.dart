import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';

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
      body: DecoratedBox(
        key: const ValueKey('entrance-blue-gradient'),
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.15, -0.2),
            radius: 1.1,
            colors: [Colors.white, AppTheme.blueSurface, AppTheme.blueAccent],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextButton(
                    onPressed: _finishSplash,
                    child: const Text('Skip'),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            label: 'NaijaGo',
                            image: true,
                            child: Image.asset(
                              'assets/naijago-logo-transparent.png',
                              width: 270,
                              height: 110,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Your neighbourhood. Delivered.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.deepForest,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Discover local businesses. Shop with confidence.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.deepForest,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('entrance-continue'),
                      onPressed: _finishSplash,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.deepForest,
                        side: BorderSide(
                          color: AppTheme.deepForest.withValues(alpha: .25),
                        ),
                        minimumSize: const Size(156, 44),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Continue'),
                    ),
                    const SizedBox(height: 18),
                    const SizedBox(
                      width: 68,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: AppTheme.forestGreen,
                        backgroundColor: Color(0x55FFFFFF),
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'LOCAL SHOPPING, MADE SIMPLE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.deepForest,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
