import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'deck.dart';
import 'file_browser.dart';
import 'grunge.dart';
import 'theme.dart';

/// Opens the in-app file browser; picking a song loads it into [deck].
Future<void> pickTrack(BuildContext context, Deck deck) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => FileBrowserScreen(deck: deck)),
  );
}

/// Long-press ("hold") menu for a deck.
Future<void> showDeckMenu(BuildContext context, Deck deck) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      void run(VoidCallback f) {
        Navigator.of(ctx).pop();
        f();
      }

      final items = <_MenuItem>[
        _MenuItem(Icons.folder_open_rounded, 'Add songs',
            () => run(() => pickTrack(context, deck))),
        _MenuItem(
            Icons.flag_rounded, 'Set cue here', () => run(deck.setCueHere)),
        _MenuItem(
            Icons.repeat_rounded,
            deck.hasLoopPoints ? 'Clear loop' : 'Loop in / out',
            () => run(deck.loopPress)),
        _MenuItem(Icons.speed_rounded, 'Reset tempo',
            () => run(() => deck.setTempo(0))),
        _MenuItem(Icons.grid_view_rounded, 'Clear hot cues',
            () => run(deck.clearAllHotCues)),
        _MenuItem(Icons.eject_rounded, 'Eject', () => run(deck.eject)),
      ];

      return Dialog(
        backgroundColor: YL.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(YL.radius)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Deck ${deck.name}${deck.isLoaded ? ' - ${deck.title}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: YL.ink),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final i in items) _MenuTile(item: i, color: deck.color)
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item, required this.color});
  final _MenuItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: YL.bg,
      borderRadius: BorderRadius.circular(YL.r(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(YL.r(14)),
        onTap: item.onTap,
        child: SizedBox(
          width: 104,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: YL.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================ deck panel ==

class DeckPanel extends StatelessWidget {
  const DeckPanel({super.key, required this.deck});
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: YL.panel(),
      child: ScrewFrame(
        child: AnimatedBuilder(
          animation: deck,
          builder: (context, _) => Column(
            children: [
              _Header(deck: deck),
              const SizedBox(height: 6),
              SizedBox(height: 38, child: WaveStrip(deck: deck)),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(width: 62, child: _TransportButtons(deck: deck)),
                    const SizedBox(width: 8),
                    Expanded(child: Center(child: _Jog(deck: deck))),
                    const SizedBox(width: 6),
                    SizedBox(width: 34, child: _TempoSlider(deck: deck)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(height: 32, child: _HotCuePads(deck: deck)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.deck});
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final tempoPct = deck.tempo * 100;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pickTrack(context, deck),
      onLongPress: () => showDeckMenu(context, deck),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: YL.fill(deck.color, radius: 9),
            child: Text(deck.name,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deck.isLoaded ? deck.title : 'NO TRACK',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: YL.grunge ? 11 : 13,
                    color: deck.isLoaded ? YL.ink : YL.inkSoft,
                  ),
                ),
                Text(
                  '${YL.grunge ? '' : 'tempo '}${tempoPct >= 0 ? '+' : ''}${tempoPct.toStringAsFixed(1)}%'
                  '${deck.loopActive ? '   LOOP' : ''}',
                  style: TextStyle(
                      fontSize: YL.grunge ? 9 : 10,
                      color: YL.inkSoft,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Time readout: an inset amber "LCD" in the grunge look.
          ValueListenableBuilder<Duration>(
            valueListenable: deck.position,
            builder: (context, pos, _) => Container(
              padding: YL.grunge
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
                  : EdgeInsets.zero,
              decoration: YL.grunge
                  ? BoxDecoration(
                      color: YL.plate,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.black, width: 1.5),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtTime(pos),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: YL.grunge ? YL.cueOrange : YL.ink,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  Text(fmtTime(deck.duration - pos, tenths: false),
                      style: TextStyle(
                          fontSize: 10,
                          color: YL.grunge
                              ? YL.cueOrange.withValues(alpha: 0.55)
                              : YL.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- transport --

class _TransportButtons extends StatelessWidget {
  const _TransportButtons({required this.deck});
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          // Sub-label tells you what the press will do right now.
          child: _PillButton(
            label: 'CUE',
            sub: deck.playing ? 'back' : 'set',
            color: YL.cueOrange,
            filled: false,
            onTap: deck.cuePress,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 2,
          child: _PillButton(
            icon: deck.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: deck.color,
            filled: true,
            onTap: deck.togglePlay,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _PillButton(
            label: deck.loopActive
                ? 'LOOP'
                : (deck.loopIn != null ? 'OUT?' : 'IN'),
            color: YL.ink,
            filled: deck.loopActive,
            onTap: deck.loopPress,
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    this.label,
    this.sub,
    this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final String? label;
  final String? sub;
  final IconData? icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Container(
      decoration: YL.fill(filled ? color : color.withValues(alpha: 0.12)),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(YL.r(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(YL.r(14)),
          onTap: onTap,
          child: Center(
            child: icon != null
                ? Icon(icon, color: fg, size: 30)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label!,
                            style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.8)),
                        if (sub != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(sub!.toUpperCase(),
                                style: TextStyle(
                                    color: fg,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6)),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ tempo --

class _TempoSlider extends StatelessWidget {
  const _TempoSlider({required this.deck});
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => deck.setTempo(0),
      child: RotatedBox(
        quarterTurns: 3,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: YL.line,
            inactiveTrackColor: YL.line,
            thumbColor: deck.color,
          ),
          // Up = faster, like a real pitch fader pushed away from you.
          child: Slider(
            value: deck.tempo,
            min: -Deck.tempoRange,
            max: Deck.tempoRange,
            onChanged: deck.setTempo,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- jog --

class _Jog extends StatefulWidget {
  const _Jog({required this.deck});
  final Deck deck;

  @override
  State<_Jog> createState() => _JogState();
}

class _JogState extends State<_Jog> {
  static const _msPerTurn = 1800; // 33 rpm
  double? _lastAngle;

  double _angle(Offset p, Size s) =>
      math.atan2(p.dy - s.height / 2, p.dx - s.width / 2);

  @override
  Widget build(BuildContext context) {
    final deck = widget.deck;
    return LayoutBuilder(builder: (context, c) {
      final side = math.min(c.maxWidth, c.maxHeight);
      final size = Size(side, side);
      return GestureDetector(
        onLongPress: () => showDeckMenu(context, deck),
        onPanStart: (d) => _lastAngle = _angle(d.localPosition, size),
        onPanUpdate: (d) {
          final a = _angle(d.localPosition, size);
          var delta = a - (_lastAngle ?? a);
          if (delta > math.pi) delta -= 2 * math.pi;
          if (delta < -math.pi) delta += 2 * math.pi;
          _lastAngle = a;
          deck.nudge(Duration(
              milliseconds: (delta / (2 * math.pi) * _msPerTurn).round()));
        },
        onPanEnd: (_) => _lastAngle = null,
        child: SizedBox(
          width: side,
          height: side,
          child: ValueListenableBuilder<Duration>(
            valueListenable: deck.position,
            builder: (context, pos, _) => CustomPaint(
              painter: _JogPainter(
                angle: pos.inMilliseconds / _msPerTurn * 2 * math.pi,
                color: deck.color,
                playing: deck.playing,
                loaded: deck.isLoaded,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _JogPainter extends CustomPainter {
  _JogPainter({
    required this.angle,
    required this.color,
    required this.playing,
    required this.loaded,
  });

  final double angle;
  final Color color;
  final bool playing;
  final bool loaded;

  /// Captured so the wheel repaints when the colour theme changes.
  final YLPalette palette = YL.palette.value;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // soft drop shadow
    canvas.drawCircle(
      c + const Offset(0, 4),
      r - 2,
      Paint()
        ..color = (YL.grunge ? Colors.black : const Color(0xFF1B1F2A))
            .withValues(alpha: YL.grunge ? 0.55 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // plate
    canvas.drawCircle(c, r - 2, Paint()..color = YL.plate);
    // rim
    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = playing ? 4 : 2.5
        ..color = playing ? color : YL.line,
    );
    // grooves: a few rings, or dense vinyl-style rings when grunge
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = YL.line;
    if (YL.grunge) {
      for (var i = 0; i < 9; i++) {
        canvas.drawCircle(c, r * (0.40 + i * 0.058), groove);
      }
      // machined tick marks around the edge, like a real jog dial
      final tick = Paint()
        ..strokeWidth = 1.2
        ..color = YL.inkSoft.withValues(alpha: 0.7);
      for (var i = 0; i < 60; i++) {
        final a = i / 60 * 2 * math.pi;
        final long = i % 5 == 0;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
            c + dir * (r - (long ? 12 : 9)), c + dir * (r - 5), tick);
      }
    } else {
      for (var i = 1; i <= 3; i++) {
        canvas.drawCircle(c, (r - 6) * (0.45 + i * 0.16), groove);
      }
    }

    // rotating marker + label disc
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(loaded ? angle : 0);
    final label = r * 0.34;
    canvas.drawCircle(
        Offset.zero, label, Paint()..color = color.withValues(alpha: 0.14));
    canvas.drawCircle(Offset.zero, 3, Paint()..color = color);
    canvas.drawLine(
      Offset(0, -label),
      Offset(0, -(r - 10)),
      Paint()
        ..color = color
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JogPainter o) =>
      o.angle != angle ||
      o.playing != playing ||
      o.color != color ||
      o.loaded != loaded ||
      o.palette != palette;
}

// ------------------------------------------------------------------- wave --

class WaveStrip extends StatelessWidget {
  const WaveStrip({super.key, required this.deck});
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      void seek(double dx) =>
          deck.seekFraction((dx / c.maxWidth).clamp(0.0, 1.0));
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => seek(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(YL.r(10)),
          child: ColoredBox(
            color: YL.bg,
            child: ValueListenableBuilder<Duration>(
              valueListenable: deck.position,
              builder: (context, pos, _) => CustomPaint(
                size: Size.infinite,
                painter: _WavePainter(deck: deck, position: pos),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.deck, required this.position});
  final Deck deck;
  final Duration position;

  @override
  void paint(Canvas canvas, Size size) {
    final total = deck.duration.inMilliseconds;
    if (!deck.isLoaded || total == 0 || deck.wave.isEmpty) {
      canvas.drawLine(
        Offset(8, size.height / 2),
        Offset(size.width - 8, size.height / 2),
        Paint()
          ..color = YL.line
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    double x(Duration d) => d.inMilliseconds / total * size.width;

    // loop region
    if (deck.hasLoopPoints) {
      canvas.drawRect(
        Rect.fromLTRB(x(deck.loopIn!), 0, x(deck.loopOut!), size.height),
        Paint()
          ..color = (deck.loopActive ? deck.color : YL.inkSoft)
              .withValues(alpha: 0.16),
      );
    }

    // bars
    final n = deck.wave.length;
    final bw = size.width / n;
    final playedX = x(position);
    final played = Paint()..color = deck.color;
    final rest = Paint()..color = YL.waveRest;
    for (var i = 0; i < n; i++) {
      final h = deck.wave[i] * (size.height - 8);
      final left = i * bw;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(left + bw / 2, size.height / 2),
          width: math.max(1, bw - 1.2),
          height: h,
        ),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, left + bw / 2 <= playedX ? played : rest);
    }

    // cue + hot cues
    if (deck.cue != null) {
      canvas.drawRect(
        Rect.fromLTWH(x(deck.cue!) - 1, 0, 2, size.height),
        Paint()..color = YL.cueOrange,
      );
    }
    for (var i = 0; i < Deck.hotCueCount; i++) {
      final h = deck.hotCues[i];
      if (h == null) continue;
      canvas.drawCircle(Offset(x(h), 5), 3.5, Paint()..color = YL.padColors[i]);
    }

    // playhead
    canvas.drawRect(
      Rect.fromLTWH(playedX - 1, 0, 2, size.height),
      Paint()..color = YL.ink,
    );
  }

  @override
  bool shouldRepaint(_WavePainter o) => true;
}

// --------------------------------------------------------------- hot cues --

class _HotCuePads extends StatelessWidget {
  const _HotCuePads({required this.deck});
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < Deck.hotCueCount; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _Pad(
              index: i,
              color: YL.padColors[i],
              time: deck.hotCues[i],
              onTap: () => deck.hotCueTap(i),
              onHold: () => deck.clearHotCue(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({
    required this.index,
    required this.color,
    required this.time,
    required this.onTap,
    required this.onHold,
  });

  final int index;
  final Color color;
  final Duration? time;
  final VoidCallback onTap;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    final set = time != null;
    return Material(
      color: set ? color : color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(YL.r(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(YL.r(12)),
        onTap: onTap,
        onLongPress: onHold, // hold = clear
        child: Center(
          child: Text(
            set ? fmtTime(time!, tenths: false) : '${index + 1}',
            style: TextStyle(
              color: set ? Colors.white : color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
