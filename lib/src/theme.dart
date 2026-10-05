import 'package:flutter/material.dart';

/// One complete colour set. The active one lives in [YL.palette].
class YLPalette {
  const YLPalette({
    required this.name,
    required this.bg,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.plate,
    required this.waveRest,
    required this.deckA,
    required this.deckB,
    required this.cueColor,
    required this.padColors,
    required this.shadowColor,
    this.glossy = false,
    this.grunge = false,
  });

  final String name;
  final Color bg;
  final Color card;
  final Color ink;
  final Color inkSoft;
  final Color line;

  /// Jog wheel plate and inset displays.
  final Color plate;

  /// Un-played part of the waveform.
  final Color waveRest;
  final Color deckA;
  final Color deckB;
  final Color cueColor;
  final List<Color> padColors;
  final Color shadowColor;

  /// Glossy buttons: a light highlight fading into the base colour.
  final bool glossy;

  /// Dark worn hardware: texture overlay, screws, sharp corners, mono font.
  final bool grunge;
}

/// Look and feel. Three palettes; the active one is [palette].
class YL {
  static const grungeDark = YLPalette(
    name: 'Grunge',
    bg: Color(0xFF111113),
    card: Color(0xFF232326),
    ink: Color(0xFFE6E6E8),
    inkSoft: Color(0xFF8E8E96),
    line: Color(0xFF3A3A40),
    plate: Color(0xFF19191C),
    waveRest: Color(0xFF55555C),
    deckA: Color(0xFFE5383B), // signal red
    deckB: Color(0xFF3D8BFF), // electric blue
    cueColor: Color(0xFFF2C230), // warning yellow
    padColors: [
      Color(0xFFF2C230),
      Color(0xFFE5383B),
      Color(0xFF3D8BFF),
      Color(0xFFD44FA8)
    ],
    shadowColor: Colors.black,
    grunge: true,
  );

  static const classic = YLPalette(
    name: 'Classic',
    bg: Color(0xFFF3F4F7),
    card: Colors.white,
    ink: Color(0xFF1B1F2A),
    inkSoft: Color(0xFF8A90A0),
    line: Color(0xFFE6E8EE),
    plate: Color(0xFFF7F8FB),
    waveRest: Color(0xFFC9CDD8),
    deckA: Color(0xFF3D6BFF),
    deckB: Color(0xFFFF5C7A),
    cueColor: Color(0xFFFFA23A),
    padColors: [
      Color(0xFF3D6BFF),
      Color(0xFF22C58B),
      Color(0xFFFFA23A),
      Color(0xFFB05CFF)
    ],
    shadowColor: Color(0xFF1B1F2A),
  );

  /// Pearl white with glossy peach. Lower contrast on purpose.
  static const pearlPeach = YLPalette(
    name: 'Pearl & Peach',
    bg: Color(0xFFF7F4F1),
    card: Color(0xFFFFFDFB),
    ink: Color(0xFF4A3A34),
    inkSoft: Color(0xFFA8978E),
    line: Color(0xFFEEE5DF),
    plate: Color(0xFFFBF6F2),
    waveRest: Color(0xFFE4D6CD),
    deckA: Color(0xFFF0A07E),
    deckB: Color(0xFFD98A78),
    cueColor: Color(0xFFE9B07A),
    padColors: [
      Color(0xFFF0A07E),
      Color(0xFFF5C0A4),
      Color(0xFFD98A78),
      Color(0xFFE9C7B0)
    ],
    shadowColor: Color(0xFF8A6A5C),
    glossy: true,
  );

  static const palettes = [grungeDark, classic, pearlPeach];

  static final ValueNotifier<YLPalette> palette = ValueNotifier(grungeDark);

  static YLPalette get _p => palette.value;

  static Color get bg => _p.bg;
  static Color get card => _p.card;
  static Color get ink => _p.ink;
  static Color get inkSoft => _p.inkSoft;
  static Color get line => _p.line;
  static Color get plate => _p.plate;
  static Color get waveRest => _p.waveRest;
  static Color get deckA => _p.deckA;
  static Color get deckB => _p.deckB;
  static Color get cueOrange => _p.cueColor;
  static List<Color> get padColors => _p.padColors;
  static bool get grunge => _p.grunge;

  /// Corner radius scaled for the active look (grunge is nearly square).
  static double r(double v) => _p.grunge ? v * 0.25 : v;

  static double get radius => r(20);

  /// Fixed-width font for the grunge look; null keeps the default font.
  static String? get fontFamily => _p.grunge ? 'monospace' : null;

  static List<BoxShadow> get shadow => _p.grunge
      ? [
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ]
      : [
          BoxShadow(
            color: _p.shadowColor.withValues(alpha: _p.glossy ? 0.10 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];

  /// Surface for a deck or mixer panel.
  static BoxDecoration panel() => BoxDecoration(
        color: _p.card,
        borderRadius: BorderRadius.circular(radius),
        border: _p.grunge ? Border.all(color: _p.line, width: 2) : null,
        boxShadow: shadow,
      );

  /// Filled surface for buttons and badges. Glossy gets a highlight,
  /// grunge gets a flat hardware button with a dark edge.
  static BoxDecoration fill(Color c, {double radius = 14}) {
    final br = BorderRadius.circular(r(radius));
    if (_p.grunge) {
      return BoxDecoration(
        borderRadius: br,
        color: c,
        border: Border.all(
          color: Color.lerp(c, Colors.black, 0.55)!,
          width: 1.5,
        ),
      );
    }
    return BoxDecoration(
      borderRadius: br,
      color: _p.glossy ? null : c,
      gradient: _p.glossy
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(c, Colors.white, 0.45)!, c],
            )
          : null,
    );
  }

  static ThemeData themeFor(YLPalette p) => ThemeData(
        useMaterial3: true,
        fontFamily: p.grunge ? 'monospace' : null,
        scaffoldBackgroundColor: p.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: p.deckA,
          surface: p.card,
          brightness: p.grunge ? Brightness.dark : Brightness.light,
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          overlayShape: SliderComponentShape.noOverlay,
          activeTrackColor: p.ink,
          inactiveTrackColor: p.line,
          thumbColor: p.grunge ? p.ink : Colors.white,
        ),
      );
}
