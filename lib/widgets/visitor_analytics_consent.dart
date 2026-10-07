import 'dart:async';
import 'package:flutter/material.dart';
import '../services/visitor_analytics_service.dart';

class VisitorAnalyticsConsent extends StatefulWidget {
  final String page;
  final Widget child;
  const VisitorAnalyticsConsent({
    super.key,
    required this.page,
    required this.child,
  });
  @override
  State<VisitorAnalyticsConsent> createState() =>
      _VisitorAnalyticsConsentState();
}

class _VisitorAnalyticsConsentState extends State<VisitorAnalyticsConsent> {
  final _service = VisitorAnalyticsService();
  bool _choosing = false;
  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _service.initialize();
    if (!mounted) return;
    setState(() {});
    unawaited(_service.trackPage(widget.page));
  }

  @override
  void didUpdateWidget(VisitorAnalyticsConsent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      unawaited(_service.trackPage(widget.page));
    }
  }

  Future<void> _choose(bool value) async {
    try {
      await _service.setConsent(value);
    } catch (_) {
      // Fail closed if the preference cannot be saved.
      _service.consent = false;
    }
    if (!mounted) return;
    setState(() => _choosing = false);
    if (_service.consent == true) unawaited(_service.trackPage(widget.page));
  }

  @override
  Widget build(BuildContext context) {
    final showChoice =
        _service.enabled && (_service.consent == null || _choosing);
    return Column(
      children: [
        Expanded(child: widget.child),
        if (showChoice)
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Allow anonymous page statistics to improve NaijaGo? We collect a random session, page and device category. No names, contact details, locations or searches. Records expire after 30 days. You can withdraw consent here.',
                    style: TextStyle(fontSize: 12),
                  ),
                  Wrap(
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: () => _choose(false),
                        child: const Text('Decline statistics'),
                      ),
                      TextButton(
                        onPressed: () => _choose(true),
                        child: const Text('Allow statistics'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else if (_service.enabled &&
            (widget.page == 'home' || widget.page == 'account'))
          SizedBox(
            height: 32,
            child: TextButton(
              onPressed: () => setState(() => _choosing = true),
              child: const Text(
                'Visitor privacy choices',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}
