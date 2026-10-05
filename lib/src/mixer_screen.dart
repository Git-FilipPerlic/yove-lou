import 'package:flutter/material.dart';

import 'deck.dart';
import 'deck_panel.dart';
import 'grunge.dart';
import 'playlists_screen.dart';
import 'theme.dart';

/// Landscape layout: [ Deck A ] [ Mixer ] [ Deck B ].
/// SafeArea keeps everything out of the notch / camera cut-out zones.
class MixerScreen extends StatelessWidget {
  const MixerScreen({
    super.key,
    required this.a,
    required this.b,
    required this.mixer,
  });

  final Deck a;
  final Deck b;
  final Mixer mixer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: DeckPanel(deck: a)),
            const SizedBox(width: 8),
            SizedBox(width: 150, child: MixerPanel(a: a, b: b, mixer: mixer)),
            const SizedBox(width: 8),
            Expanded(child: DeckPanel(deck: b)),
          ],
        ),
      ),
    );
  }
}

class MixerPanel extends StatelessWidget {
  const MixerPanel(
      {super.key, required this.a, required this.b, required this.mixer});

  final Deck a;
  final Deck b;
  final Mixer mixer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: YL.panel(),
      child: ScrewFrame(
        child: AnimatedBuilder(
          animation: Listenable.merge([a, b, mixer]),
          builder: (context, _) => Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        YL.grunge ? 'YOVE LOU' : 'yove lou',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: YL.grunge ? 11 : 13,
                          letterSpacing: YL.grunge ? 0.5 : 1.2,
                          color: YL.ink,
                        ),
                      ),
                    ),
                  ),
                  _TopIcon(
                    icon: Icons.palette_outlined,
                    onTap: () {
                      // Switch to the next palette in the list.
                      const all = YL.palettes;
                      final i = all.indexOf(YL.palette.value);
                      YL.palette.value = all[(i + 1) % all.length];
                    },
                  ),
                  _TopIcon(
                      icon: Icons.help_outline_rounded,
                      onTap: () => showHelp(context)),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  children: [
                    _Fader(
                      label: 'A',
                      color: a.color,
                      value: a.channelVolume,
                      onChanged: a.setChannelVolume,
                    ),
                    _Fader(
                      label: 'M',
                      color: YL.ink,
                      value: mixer.master,
                      onChanged: mixer.setMaster,
                    ),
                    _Fader(
                      label: 'B',
                      color: b.color,
                      value: b.channelVolume,
                      onChanged: b.setChannelVolume,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _PlaylistsButton(a: a, b: b),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('A',
                      style: TextStyle(
                          color: a.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                  Expanded(
                    child: GestureDetector(
                      onDoubleTap: () => mixer.setCrossfader(0.5),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 11),
                        ),
                        child: Slider(
                          value: mixer.crossfader,
                          onChanged: mixer.setCrossfader,
                        ),
                      ),
                    ),
                  ),
                  Text('B',
                      style: TextStyle(
                          color: b.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// HOLD to open both decks' playlists. A plain tap only shows a hint, so it
/// can't be triggered by accident mid-mix.
class _PlaylistsButton extends StatelessWidget {
  const _PlaylistsButton({required this.a, required this.b});

  final Deck a;
  final Deck b;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: YL.fill(YL.line, radius: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(YL.r(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(YL.r(12)),
          onTap: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('Hold the button to open playlists'),
              duration: Duration(seconds: 1),
            )),
          onLongPress: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PlaylistsScreen(a: a, b: b)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.queue_music_rounded, size: 18, color: YL.ink),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PLAYLISTS',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: YL.ink)),
                    Text('hold  A${a.playlist.length} B${b.playlist.length}',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: YL.inkSoft)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(YL.r(14)),
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icon, size: 18, color: YL.inkSoft),
      ),
    );
  }
}

/// Quick guide to every control. Opened with the "?" button.
Future<void> showHelp(BuildContext context) {
  const rows = [
    (
      'Track name',
      'Tap to open the file browser. Tap songs to tick them, then ADD TO the deck playlist. Hold a song to load it right now.'
    ),
    (
      'PLAYLISTS (hold)',
      'Hold the button on the mixer to see the playlists of both decks. Tap a song to load it, drag to reorder, X to remove. When a song ends, the next one is loaded and ready.'
    ),
    ('Hold deck / jog', 'Menu: loop, set cue, reset tempo, clear pads, eject.'),
    (
      'Waveform',
      'Top strip: close-up around the playhead with the beat grid (thick line = every 4th beat). Drag it sideways to scrub. Bar below: the whole song, tap or drag to jump.'
    ),
    ('PLAY', 'Start or pause the track.'),
    (
      'SYNC',
      'Makes this deck follow the tempo of the other deck. If both are playing, the beats are also lined up. Stays on until you press it again or move this tempo fader. A 64 BPM song follows a 128 BPM one at half time.'
    ),
    (
      'CUE',
      'When paused: set the cue point here. When playing: jump back to the cue and stop. HOLD it to preview: the song plays from the cue and snaps back when you let go. Press PLAY while holding to keep playing.'
    ),
    (
      'IN / OUT',
      'Loop. First press sets the loop start, second sets the end and loops, third clears it.'
    ),
    (
      '1 2 3 4 pads',
      'Tap an empty pad to save this spot, tap a saved pad to jump there, hold to clear it.'
    ),
    ('Jog wheel', 'Drag in a circle to scrub forward and back.'),
    (
      'Tempo fader',
      'Push up for faster, down for slower. Double-tap to reset to normal speed.'
    ),
    (
      'A / M / B faders',
      'Channel volume for A, master volume, channel volume for B.'
    ),
    ('Crossfader', 'Slide between deck A and deck B. Double-tap to centre.'),
    ('Palette icon', 'Cycle the look: Grunge, Classic, Pearl & Peach.'),
  ];
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: YL.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(YL.radius)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How to use yove lou',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: YL.ink)),
              const SizedBox(height: 12),
              for (final (title, text) in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: YL.ink)),
                      Text(text,
                          style: TextStyle(fontSize: 12, color: YL.inkSoft)),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Got it')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Fader extends StatelessWidget {
  const _Fader({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  trackHeight: 5,
                ),
                child: Slider(value: value, onChanged: onChanged),
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
