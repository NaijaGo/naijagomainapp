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
      backgroundColor: AppTheme.softGrey,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _finishSplash,
                          child: const Text('Skip'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.deepForest,
                                borderRadius: BorderRadius.circular(32),
                              ),
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Semantics(
                                      label: 'NaijaGo',
                                      image: true,
                                      child: AspectRatio(
                                        aspectRatio: 2.6,
                                        child: Image.asset(
                                          'assets/naijago-brand.jpg',
                                          fit: BoxFit.contain,
                                          excludeFromSemantics: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppTheme.sageAccent,
                                    size: 58,
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      for (final asset in [
                                        'assets/categories/groceries.jpg',
                                        'assets/categories/fashion_women.jpg',
                                        'assets/categories/smartphones.jpg',
                                      ])
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Image.asset(
                                                asset,
                                                height: 76,
                                                fit: BoxFit.cover,
                                                excludeFromSemantics: true,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            const Text(
                              'Your neighbourhood. Delivered.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.deepForest,
                                fontSize: 28,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.6,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Discover local businesses. Shop with confidence.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.mutedText,
                                fontSize: 15,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                key: const ValueKey('entrance-continue'),
                                onPressed: _finishSplash,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Continue'),
                                    SizedBox(width: 12),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const SizedBox(
                              width: 76,
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                color: AppTheme.forestGreen,
                                backgroundColor: AppTheme.borderGrey,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'LOCAL SHOPPING, MADE SIMPLE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.mutedText,
                                fontSize: 10,
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
            );
          },
        ),
      ),
    ),
  );
}
