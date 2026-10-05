import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'deck.dart';

/// Tiny on-device storage: theme choice and each deck's playlist.
/// Every call is a no-op until [init] has run, so tests never touch disk.
class Store {
  static SharedPreferences? _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static String? get themeName => _p?.getString('theme');

  /// Your x2 / /2 fix for a song's BPM (1 = as detected).
  static double bpmScale(String path) => _p?.getDouble('bpmscale_$path') ?? 1;

  static void saveBpmScale(String path, double scale) =>
      _p?.setDouble('bpmscale_$path', scale);

  static void saveTheme(String name) => _p?.setString('theme', name);

  /// Saved songs for a deck. Files that were deleted since are dropped.
  static List<Track> loadPlaylist(String deckName) {
    final raw = _p?.getStringList('playlist_$deckName') ?? const [];
    final tracks = <Track>[];
    for (final s in raw) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        final path = m['path'] as String;
        if (File(path).existsSync()) {
          tracks.add(Track(path, m['name'] as String));
        }
      } catch (_) {
        // skip a corrupt entry
      }
    }
    return tracks;
  }

  static void savePlaylist(String deckName, List<Track> tracks) {
    _p?.setStringList(
      'playlist_$deckName',
      [
        for (final t in tracks) jsonEncode({'path': t.path, 'name': t.name})
      ],
    );
  }
}
