import 'package:flutter/material.dart';

/// Quiet canvas for account pages; keeps content and actions in the foreground.
class AccountPageBackground extends StatelessWidget {
  const AccountPageBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: const Color(0xFFF5F7FB), child: child);
}
