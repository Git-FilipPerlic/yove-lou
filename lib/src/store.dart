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

  /// Folder the file browser was last in.
  static String? get lastFolder => _p?.getString('last_folder');

  static void saveLastFolder(String path) => _p?.setString('last_folder', path);

  /// What a deck had loaded (song, position, cues, loop, tempo, volume).
  static Map<String, dynamic>? loadSession(String deckName) {
    final raw = _p?.getString('session_$deckName');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static void saveSession(String deckName, Map<String, dynamic>? data) {
    if (data == null) {
      _p?.remove('session_$deckName');
    } else {
      _p?.setString('session_$deckName', jsonEncode(data));
    }
  }

  /// Crossfader and master volume.
  static Map<String, dynamic>? loadMixer() {
    final raw = _p?.getString('mixer');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static void saveMixer(double crossfader, double master) => _p?.setString(
    'mixer',
    jsonEncode({'crossfader': crossfader, 'master': master}),
  );

  // ------------------------------------------------------------------ sets
  // A "set" is a named pair of playlists (deck A + deck B).

  static Map<String, dynamic> _sets() {
    final raw = _p?.getString('sets');
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static List<String> setNames() =>
      _sets().keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  /// How many songs a saved set holds on each deck (A, B).
  static (int, int) setCounts(String name) {
    final s = _sets()[name];
    if (s is! Map) return (0, 0);
    return (
      (s['A'] is List ? (s['A'] as List).length : 0),
      (s['B'] is List ? (s['B'] as List).length : 0),
    );
  }

  static void saveSet(String name, List<Track> a, List<Track> b) {
    List<Map<String, String>> enc(List<Track> l) => [
          for (final t in l) {'path': t.path, 'name': t.name}
        ];
    final all = _sets();
    all[name] = {'A': enc(a), 'B': enc(b)};
    _p?.setString('sets', jsonEncode(all));
  }

  static void deleteSet(String name) {
    final all = _sets()..remove(name);
    _p?.setString('sets', jsonEncode(all));
  }

  /// The songs of a saved set; files deleted since are dropped.
  static (List<Track>, List<Track>)? loadSet(String name) {
    final s = _sets()[name];
    if (s is! Map) return null;
    List<Track> dec(Object? raw) {
      final out = <Track>[];
      if (raw is! List) return out;
      for (final m in raw) {
        try {
          final path = m['path'] as String;
          if (File(path).existsSync()) out.add(Track(path, m['name'] as String));
        } catch (_) {}
      }
      return out;
    }

    return (dec(s['A']), dec(s['B']));
  }

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
    _p?.setStringList('playlist_$deckName', [
      for (final t in tracks) jsonEncode({'path': t.path, 'name': t.name}),
    ]);
  }
}
