import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class VisibleBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;

  const VisibleBackButton({super.key, this.onPressed, this.tooltip = 'Back'});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 0,
          child: InkWell(
            onTap: onPressed ?? () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderGrey),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.primaryNavy,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
