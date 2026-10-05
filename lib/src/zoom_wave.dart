import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'deck.dart';
import 'theme.dart';

/// Scrolling close-up of the song around the playhead (centre line), with the
/// beat grid: a thin line on every beat, a thick one on every fourth.
/// Drag sideways to scrub.
class ZoomWave extends StatelessWidget {
  const ZoomWave({super.key, required this.deck});

  final Deck deck;

  /// How many seconds of the song fit across the strip.
  static const windowSeconds = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final pxPerSec = c.maxWidth / windowSeconds;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Drag the song under the playhead, like a record.
        onHorizontalDragUpdate: (d) => deck.nudge(
          Duration(milliseconds: (-d.delta.dx / pxPerSec * 1000).round()),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(YL.r(10)),
          child: ColoredBox(
            color: YL.plate,
            child: ValueListenableBuilder<Duration>(
              valueListenable: deck.position,
              builder: (context, pos, _) => CustomPaint(
                size: Size.infinite,
                painter: _ZoomPainter(deck: deck, position: pos),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _ZoomPainter extends CustomPainter {
  _ZoomPainter({required this.deck, required this.position});

  final Deck deck;
  final Duration position;

  @override
  void paint(Canvas canvas, Size size) {
    const w = ZoomWave.windowSeconds;
    final pos = position.inMilliseconds / 1000;
    final t0 = pos - w / 2; // song time at the left edge
    final pxPerSec = size.width / w;
    double xOf(double t) => (t - t0) * pxPerSec;
    final mid = size.height / 2;

    if (!deck.isLoaded) {
      canvas.drawLine(
        Offset(8, mid),
        Offset(size.width - 8, mid),
        Paint()
          ..color = YL.line
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    // loop region
    if (deck.hasLoopPoints) {
      final a = xOf(deck.loopIn!.inMilliseconds / 1000);
      final b = xOf(deck.loopOut!.inMilliseconds / 1000);
      canvas.drawRect(
        Rect.fromLTRB(a, 0, b, size.height),
        Paint()
          ..color = (deck.loopActive ? deck.color : YL.inkSoft)
              .withValues(alpha: 0.18),
      );
    }

    // loudness bars, one per 2 px: the loudest sample in that slice of time
    final env = deck.env;
    final rate = deck.envRate;
    if (env.isEmpty) {
      canvas.drawLine(
        Offset(0, mid),
        Offset(size.width, mid),
        Paint()
          ..color = YL.waveRest
          ..strokeWidth = 2,
      );
    } else {
      final played = Paint()..color = deck.color;
      final rest = Paint()..color = YL.waveRest;
      const step = 2.0;
      final slice = step / pxPerSec; // seconds per bar
      for (var x = 0.0; x < size.width; x += step) {
        final t = t0 + x / pxPerSec;
        if (t < 0) continue;
        final from = (t * rate).floor();
        final to = math.max(from + 1, ((t + slice) * rate).ceil());
        if (from >= env.length) break;
        var peak = 0.0;
        for (var i = from; i < to && i < env.length; i++) {
          if (env[i] > peak) peak = env[i];
        }
        final h = math.max(2.0, peak * (size.height - 6));
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x + 0.75, mid), width: 1.5, height: h),
          t <= pos ? played : rest,
        );
      }
    }

    // beat grid
    final bpm = deck.bpm;
    final first = deck.firstBeat;
    if (bpm != null && first != null) {
      final beat = 60 / bpm;
      final total = deck.duration.inMilliseconds / 1000;
      var k = ((t0 - first) / beat).ceil();
      final thin = Paint()
        ..color = YL.ink.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      final thick = Paint()
        ..color = YL.ink.withValues(alpha: 0.85)
        ..strokeWidth = 2.2;
      for (;; k++) {
        final t = first + k * beat;
        if (t > t0 + w) break;
        if (t < 0 || (total > 0 && t > total)) continue;
        final x = xOf(t);
        final bar = (((k % 4) + 4) % 4) == 0; // every fourth beat
        canvas.drawLine(
          Offset(x, bar ? 0 : size.height * 0.2),
          Offset(x, bar ? size.height : size.height * 0.8),
          bar ? thick : thin,
        );
      }
    }

    // cue + hot cues
    if (deck.cue != null) {
      final x = xOf(deck.cue!.inMilliseconds / 1000);
      canvas.drawRect(
        Rect.fromLTWH(x - 1, 0, 2, size.height),
        Paint()..color = YL.cueOrange,
      );
    }
    for (var i = 0; i < Deck.hotCueCount; i++) {
      final h = deck.hotCues[i];
      if (h == null) continue;
      canvas.drawCircle(
        Offset(xOf(h.inMilliseconds / 1000), 5),
        3.5,
        Paint()..color = YL.padColors[i],
      );
    }

    // playhead (fixed in the centre): deck colour with a bright core, so it
    // never looks like a beat line
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 2, 0, 4, size.height),
      Paint()..color = deck.color,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 0.5, 0, 1, size.height),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_ZoomPainter o) => true;
}
