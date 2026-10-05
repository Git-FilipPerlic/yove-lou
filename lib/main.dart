import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/deck.dart';
import 'src/grunge.dart';
import 'src/mixer_screen.dart';
import 'src/store.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  // Bring back the saved colour theme, and remember future changes.
  final saved = Store.themeName;
  YL.palette.value = YL.palettes
      .firstWhere((p) => p.name == saved, orElse: () => YL.palette.value);
  YL.palette.addListener(() => Store.saveTheme(YL.palette.value.name));
  // The app is designed for a phone held horizontally.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Hide status/navigation bars (swipe from the edge to peek them).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const YoveLouApp());
}

class YoveLouApp extends StatefulWidget {
  const YoveLouApp({super.key});

  @override
  State<YoveLouApp> createState() => _YoveLouAppState();
}

class _YoveLouAppState extends State<YoveLouApp> {
  late final Deck a = Deck(name: 'A');
  late final Deck b = Deck(name: 'B');
  late final Mixer mixer = Mixer(a, b);

  @override
  void initState() {
    super.initState();
    a.restorePlaylist(Store.loadPlaylist(a.name));
    b.restorePlaylist(Store.loadPlaylist(b.name));
  }

  @override
  void dispose() {
    a.dispose();
    b.dispose();
    mixer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the colour palette changes.
    return ValueListenableBuilder<YLPalette>(
      valueListenable: YL.palette,
      builder: (context, palette, _) => MaterialApp(
        title: 'yove lou',
        debugShowCheckedModeBanner: false,
        theme: YL.themeFor(palette),
        // Worn texture sits on top of every screen in the grunge look.
        builder: (context, child) => Stack(
          children: [child!, if (palette.grunge) const GrungeOverlay()],
        ),
        home: MixerScreen(a: a, b: b, mixer: mixer),
      ),
    );
  }
}
