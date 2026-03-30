import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class TechGlowBackground extends StatelessWidget {
  final Widget child;
  final bool showCommerceIcons;

  const TechGlowBackground({
    super.key,
    required this.child,
    this.showCommerceIcons = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF020133),
            Color(0xFF03024C),
            Color(0xFF08237F),
            Color(0xFF010124),
          ],
          stops: [0.0, 0.38, 0.74, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: _MarketplaceAtmosphere()),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MarketplaceGridPainter(
                  minorGridColor: Color(0x14FFFFFF),
                  majorGridColor: Color(0x22C9DAFF),
                  nodeColor: Color(0x3861F3AE),
                  particleColor: Color(0x26F5F9FF),
                  railBlue: Color(0x423B82F6),
                  railGreen: Color(0x4561F3AE),
                ),
              ),
            ),
          ),
          Positioned(
            top: -150,
            right: -70,
            child: _GlowOrb(
              size: 360,
              color: const Color(0xFF61F3AE).withValues(alpha: 0.25),
            ),
          ),
          Positioned(
            bottom: -210,
            left: -120,
            child: _GlowOrb(
              size: 420,
              color: const Color(0xFF3B82F6).withValues(alpha: 0.20),
            ),
          ),
          Positioned(
            top: 190,
            left: -90,
            child: _GlowOrb(
              size: 240,
              color: const Color(0xFF61F3AE).withValues(alpha: 0.11),
            ),
          ),
          Positioned(
            top: 76,
            left: -140,
            child: _AmbientBeam(
              width: 390,
              height: 150,
              rotation: -0.22,
              glowColor: const Color(0xFF3B82F6).withValues(alpha: 0.16),
              highlightColor: const Color(0xFF61F3AE).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            top: 110,
            right: -110,
            child: _AmbientBeam(
              width: 430,
              height: 128,
              rotation: -0.50,
              glowColor: const Color(0xFF61F3AE).withValues(alpha: 0.18),
              highlightColor: const Color(0xFF3B82F6).withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -40,
            child: _AmbientBeam(
              width: 320,
              height: 120,
              rotation: 0.26,
              glowColor: const Color(0xFF3B82F6).withValues(alpha: 0.13),
              highlightColor: const Color(0xFF61F3AE).withValues(alpha: 0.10),
            ),
          ),
          if (showCommerceIcons) ...const [
            _CommerceIcon(
              icon: Icons.shopping_cart_outlined,
              top: 110,
              left: 28,
              size: 74,
            ),
            _CommerceIcon(
              icon: Icons.storefront_outlined,
              top: 220,
              right: 30,
              size: 92,
            ),
            _CommerceIcon(
              icon: Icons.local_shipping_outlined,
              bottom: 210,
              left: 32,
              size: 76,
            ),
            _CommerceIcon(
              icon: Icons.credit_card_outlined,
              bottom: 130,
              right: 48,
              size: 66,
            ),
            _CommerceIcon(
              icon: Icons.phone_android_outlined,
              bottom: 320,
              right: 112,
              size: 54,
            ),
          ],
          child,
        ],
      ),
    );
  }
}

class _MarketplaceAtmosphere extends StatelessWidget {
  const _MarketplaceAtmosphere();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.18),
                radius: 1.02,
                colors: [
                  const Color(0xFF61F3AE).withValues(alpha: 0.10),
                  const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.34, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF61F3AE).withValues(alpha: 0.07),
                  Colors.transparent,
                  const Color(0xFF3B82F6).withValues(alpha: 0.10),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.30),
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: color.a * 0.42),
            color.withValues(alpha: color.a * 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 0.64, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: color, blurRadius: size * 0.48, spreadRadius: 10),
        ],
      ),
    );
  }
}

class _AmbientBeam extends StatelessWidget {
  final double width;
  final double height;
  final double rotation;
  final Color glowColor;
  final Color highlightColor;

  const _AmbientBeam({
    required this.width,
    required this.height,
    required this.rotation,
    required this.glowColor,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              glowColor,
              highlightColor,
              Colors.transparent,
            ],
            stops: const [0.0, 0.22, 0.68, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: glowColor.a * 0.55),
              blurRadius: 120,
              spreadRadius: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommerceIcon extends StatelessWidget {
  final IconData icon;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;

  const _CommerceIcon({
    required this.icon,
    required this.size,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Icon(
          icon,
          size: size,
          color: Colors.white.withValues(alpha: 0.026),
        ),
      ),
    );
  }
}

class _MarketplaceGridPainter extends CustomPainter {
  final Color minorGridColor;
  final Color majorGridColor;
  final Color nodeColor;
  final Color particleColor;
  final Color railBlue;
  final Color railGreen;

  const _MarketplaceGridPainter({
    required this.minorGridColor,
    required this.majorGridColor,
    required this.nodeColor,
    required this.particleColor,
    required this.railBlue,
    required this.railGreen,
  });

  static const List<Offset> _networkPoints = [
    Offset(0.15, 0.18),
    Offset(0.34, 0.23),
    Offset(0.58, 0.20),
    Offset(0.80, 0.28),
    Offset(0.26, 0.49),
    Offset(0.49, 0.58),
    Offset(0.72, 0.66),
    Offset(0.18, 0.80),
    Offset(0.44, 0.84),
    Offset(0.84, 0.82),
  ];

  static const List<_ParticleSpec> _particles = [
    _ParticleSpec(0.07, 0.11, 1.4, 0.48),
    _ParticleSpec(0.22, 0.16, 1.1, 0.32),
    _ParticleSpec(0.30, 0.34, 1.7, 0.46),
    _ParticleSpec(0.43, 0.12, 1.3, 0.34),
    _ParticleSpec(0.57, 0.26, 1.5, 0.44),
    _ParticleSpec(0.66, 0.16, 1.1, 0.28),
    _ParticleSpec(0.82, 0.14, 1.8, 0.54),
    _ParticleSpec(0.14, 0.40, 1.2, 0.30),
    _ParticleSpec(0.37, 0.44, 1.8, 0.42),
    _ParticleSpec(0.60, 0.48, 1.3, 0.28),
    _ParticleSpec(0.74, 0.41, 1.5, 0.36),
    _ParticleSpec(0.88, 0.50, 1.1, 0.26),
    _ParticleSpec(0.10, 0.72, 1.8, 0.48),
    _ParticleSpec(0.28, 0.70, 1.2, 0.30),
    _ParticleSpec(0.53, 0.78, 1.6, 0.40),
    _ParticleSpec(0.66, 0.74, 1.1, 0.26),
    _ParticleSpec(0.78, 0.86, 1.5, 0.34),
    _ParticleSpec(0.91, 0.78, 1.2, 0.24),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    _paintRails(canvas, size);
    _paintNetwork(canvas, size);
    _paintParticles(canvas, size);
  }

  void _paintGrid(Canvas canvas, Size size) {
    const minorGap = 34.0;
    const majorFrequency = 4;

    for (var column = 0, x = 0.0; x <= size.width; column++, x += minorGap) {
      final ratio = size.width == 0 ? 0.0 : x / size.width;
      final isMajor = column % majorFrequency == 0;
      final fade = (1.0 - (ratio * 0.22)).clamp(0.72, 1.0);
      final base = isMajor ? majorGridColor : minorGridColor;
      final paint = Paint()
        ..color = base.withValues(alpha: base.a * fade)
        ..strokeWidth = isMajor ? 1.1 : 0.8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (var row = 0, y = 0.0; y <= size.height; row++, y += minorGap) {
      final ratio = size.height == 0 ? 0.0 : y / size.height;
      final isMajor = row % majorFrequency == 0;
      final fade = (1.0 - (ratio * 0.18)).clamp(0.74, 1.0);
      final base = isMajor ? majorGridColor : minorGridColor;
      final paint = Paint()
        ..color = base.withValues(alpha: base.a * fade)
        ..strokeWidth = isMajor ? 1.1 : 0.8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintRails(Canvas canvas, Size size) {
    final primaryRail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.04, size.height * 0.82),
        Offset(size.width * 0.92, size.height * 0.10),
        [
          railBlue.withValues(alpha: 0.0),
          railBlue,
          railGreen,
          railGreen.withValues(alpha: 0.0),
        ],
        const [0.0, 0.28, 0.72, 1.0],
      );

    final secondaryRail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.14, size.height * 0.20),
        Offset(size.width * 0.90, size.height * 0.72),
        [
          railGreen.withValues(alpha: 0.0),
          railBlue.withValues(alpha: railBlue.a * 0.65),
          railGreen.withValues(alpha: railGreen.a * 0.88),
          railBlue.withValues(alpha: 0.0),
        ],
        const [0.0, 0.30, 0.68, 1.0],
      );

    final routeA = Path()
      ..moveTo(size.width * 0.02, size.height * 0.74)
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.64,
        size.width * 0.42,
        size.height * 0.44,
        size.width * 0.62,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.28,
        size.width * 0.86,
        size.height * 0.18,
        size.width * 0.98,
        size.height * 0.12,
      );

    final routeB = Path()
      ..moveTo(size.width * 0.10, size.height * 0.18)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.14,
        size.width * 0.36,
        size.height * 0.22,
        size.width * 0.48,
        size.height * 0.32,
      )
      ..cubicTo(
        size.width * 0.60,
        size.height * 0.42,
        size.width * 0.74,
        size.height * 0.56,
        size.width * 0.94,
        size.height * 0.68,
      );

    canvas.drawPath(routeA, primaryRail);
    canvas.drawPath(routeB, secondaryRail);

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24)
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.14, size.height * 0.16),
        Offset(size.width * 0.94, size.height * 0.74),
        [
          railBlue.withValues(alpha: 0.0),
          railBlue.withValues(alpha: railBlue.a * 0.18),
          railGreen.withValues(alpha: railGreen.a * 0.24),
          railGreen.withValues(alpha: 0.0),
        ],
        const [0.0, 0.32, 0.72, 1.0],
      );

    canvas.drawPath(routeB, haloPaint);
  }

  void _paintNetwork(Canvas canvas, Size size) {
    final points = _networkPoints
        .map((point) => Offset(size.width * point.dx, size.height * point.dy))
        .toList(growable: false);

    final linkPaint = Paint()
      ..color = nodeColor.withValues(alpha: nodeColor.a * 0.58)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke;

    final softLinkPaint = Paint()
      ..color = nodeColor.withValues(alpha: nodeColor.a * 0.22)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    void drawLink(int startIndex, int endIndex, double arcLift) {
      final start = points[startIndex];
      final end = points[endIndex];
      final control = Offset(
        (start.dx + end.dx) / 2,
        math.min(start.dy, end.dy) - arcLift,
      );
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(path, softLinkPaint);
      canvas.drawPath(path, linkPaint);
    }

    drawLink(0, 1, 18);
    drawLink(1, 2, 18);
    drawLink(2, 3, 20);
    drawLink(1, 4, 24);
    drawLink(4, 5, 16);
    drawLink(5, 6, 16);
    drawLink(4, 7, 18);
    drawLink(5, 8, 18);
    drawLink(6, 9, 14);

    final nodePaint = Paint()..color = nodeColor;
    final ringPaint = Paint()
      ..color = nodeColor.withValues(alpha: nodeColor.a * 0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final radius = i.isEven ? 2.5 : 2.0;
      canvas.drawCircle(point, radius, nodePaint);
      canvas.drawCircle(point, 8.5, ringPaint);

      if (i % 3 == 0) {
        canvas.drawCircle(
          point,
          14,
          Paint()
            ..color = nodeColor.withValues(alpha: nodeColor.a * 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );
      }
    }
  }

  void _paintParticles(Canvas canvas, Size size) {
    for (final particle in _particles) {
      final center = Offset(
        size.width * particle.dx,
        size.height * particle.dy,
      );
      canvas.drawCircle(
        center,
        particle.radius,
        Paint()
          ..color = particleColor.withValues(
            alpha: particleColor.a * particle.opacity,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarketplaceGridPainter oldDelegate) {
    return oldDelegate.minorGridColor != minorGridColor ||
        oldDelegate.majorGridColor != majorGridColor ||
        oldDelegate.nodeColor != nodeColor ||
        oldDelegate.particleColor != particleColor ||
        oldDelegate.railBlue != railBlue ||
        oldDelegate.railGreen != railGreen;
  }
}

class _ParticleSpec {
  final double dx;
  final double dy;
  final double radius;
  final double opacity;

  const _ParticleSpec(this.dx, this.dy, this.radius, this.opacity);
}
