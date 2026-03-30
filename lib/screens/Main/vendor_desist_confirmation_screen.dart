import 'package:flutter/material.dart';

const Color deepNavyBlue = Color(0xFF03024C);
const Color whiteBackground = Colors.white;
const Color _vendorBlue = Color(0xFF0D2E91);
const Color _vendorSurface = Color(0xFFF4F7FB);
const Color _vendorBorder = Color(0xFFD8E1F0);
const Color _vendorTextMuted = Color(0xFF5B6886);
const Color _vendorDanger = Color(0xFFC64848);
const Color _vendorDangerSoft = Color(0xFFFCEAEA);

class VendorDesistConfirmationScreen extends StatelessWidget {
  const VendorDesistConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _vendorSurface,
      appBar: AppBar(
        title: const Text('Leave Vendor Program'),
        backgroundColor: _vendorSurface,
        foregroundColor: deepNavyBlue,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: whiteBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _vendorBorder),
                  boxShadow: [
                    BoxShadow(
                      color: deepNavyBlue.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_vendorDanger, _vendorBlue],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: whiteBackground,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Vendor Access Warning',
                            style: TextStyle(
                              color: whiteBackground,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Are you sure you want to leave the vendor program?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: deepNavyBlue,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This removes your seller access on NaijaGo. You will not be able to add products, manage orders, or use the vendor dashboard until you apply again.',
                      style: TextStyle(
                        color: _vendorTextMuted,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _vendorDangerSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _vendorDanger.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DesistBullet(
                            icon: Icons.storefront_outlined,
                            text:
                                'Your vendor tools will be turned off immediately.',
                          ),
                          SizedBox(height: 12),
                          _DesistBullet(
                            icon: Icons.inventory_2_outlined,
                            text:
                                'You will stop managing products from this account.',
                          ),
                          SizedBox(height: 12),
                          _DesistBullet(
                            icon: Icons.refresh_rounded,
                            text:
                                'You can apply to become a vendor again later.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 420;

                        final cancelButton = OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: deepNavyBlue,
                            side: const BorderSide(color: _vendorBorder),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Keep Vendor Access',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );

                        final confirmButton = ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Yes, Leave Program'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _vendorDanger,
                            foregroundColor: whiteBackground,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: cancelButton,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: confirmButton,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: cancelButton),
                            const SizedBox(width: 12),
                            Expanded(child: confirmButton),
                          ],
                        );
                      },
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

class _DesistBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DesistBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: whiteBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _vendorDanger, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: deepNavyBlue,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
