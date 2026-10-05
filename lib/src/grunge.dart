import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Full-screen worn texture: specks, scratches and a dark vignette.
/// Drawn once (seeded, so it never flickers) and ignores touches.
class GrungeOverlay extends StatelessWidget {
  const GrungeOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(child: CustomPaint(painter: _GrungePainter())),
      ),
    );
  }
}

class _GrungePainter extends CustomPainter {
  const _GrungePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    const bone = Color(0xFFE0E0E4);

    // dust specks, light and dark
    for (var i = 0; i < 900; i++) {
      final light = rnd.nextBool();
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.4 + rnd.nextDouble() * 1.1,
        Paint()
          ..color = (light ? bone : Colors.black)
              .withValues(alpha: 0.04 + rnd.nextDouble() * 0.07),
      );
    }

    // scratches: thin, mostly horizontal-ish
    for (var i = 0; i < 40; i++) {
      final start =
          Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final angle =
          (rnd.nextDouble() - 0.5) * 0.9 + (rnd.nextBool() ? 0 : math.pi);
      final len = 18 + rnd.nextDouble() * 110;
      canvas.drawLine(
        start,
        start + Offset(math.cos(angle) * len, math.sin(angle) * len),
        Paint()
          ..strokeWidth = 0.5 + rnd.nextDouble() * 0.6
          ..color = bone.withValues(alpha: 0.04 + rnd.nextDouble() * 0.07),
      );
    }

    // a few grimy blotches
    for (var i = 0; i < 6; i++) {
      final c =
          Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = 40 + rnd.nextDouble() * 90;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.black.withValues(alpha: 0.10),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // vignette
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.05,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.38)],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GrungePainter oldDelegate) => false;
}

/// Four small screws in the corners of a panel (grunge look only).
class ScrewFrame extends StatelessWidget {
  const ScrewFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!YL.grunge) return child;
    return Stack(
      children: [
        child,
        for (final a in const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ])
          Align(
            alignment: a,
            child: const Padding(padding: EdgeInsets.all(3), child: _Screw()),
          ),
      ],
    );
  }
}

class _Screw extends StatelessWidget {
  const _Screw();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 6,
      height: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF55555B),
          border: Border.all(color: Colors.black54, width: 0.8),
        ),
      ),
    );
  }
}
