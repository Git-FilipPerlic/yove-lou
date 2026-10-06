import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// What the Android analyzer (BpmDetector.kt) learned about a song.
class Analysis {
  const Analysis({
    required this.bpm,
    required this.firstBeat,
    required this.env,
    required this.envRate,
  });

  /// Tempo, or null if it could not be worked out.
  final double? bpm;

  /// Seconds from the start of the song to the first beat.
  final double? firstBeat;

  /// Loudness 0..1, [envRate] values per second (covers the first 12 min).
  final Float32List env;
  final int envRate;
}

class Bpm {
  static const _channel = MethodChannel('yove_lou/bpm');

  /// Analyses an audio file, or returns null if it cannot be read.
  /// Results are cached on the device, so a song is only analysed once
  /// (until the file changes or Android clears the cache).
  static Future<Analysis?> analyze(String path) async {
    final cached = _readCache(path);
    if (cached != null) return cached;
    final fresh = await _analyzeNative(path);
    if (fresh != null) _writeCache(path, fresh);
    return fresh;
  }

  static final _seen = <String, double?>{};

  /// Tempo of a song that was analysed before, or null (nothing is analysed
  /// here — it only looks at the small cache file). Used by the playlists.
  static double? cachedBpm(String path) {
    final known = _seen[path];
    if (known != null) return known;
    try {
      final meta = _cacheBase(path, 'json');
      if (meta == null || !meta.existsSync()) return null;
      final m = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
      final v = (m['bpm'] as num?)?.toDouble();
      if (v != null) _seen[path] = v;
      return v;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ cache
  // Two small files per song in the app cache folder: <key>.json (tempo,
  // first beat, rate) and <key>.env (loudness curve, one byte per value).

  static File? _cacheBase(String path, String ext) {
    try {
      final f = File(path);
      final key =
          '$path|${f.lengthSync()}|${f.lastModifiedSync().millisecondsSinceEpoch}';
      var h = 0xcbf29ce484222325; // FNV-1a
      for (final c in key.codeUnits) {
        h = ((h ^ c) * 0x100000001b3) & 0x7fffffffffffffff;
      }
      final dir = Directory('${Directory.systemTemp.path}/yl_analysis');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return File('${dir.path}/${h.toRadixString(16)}.$ext');
    } catch (_) {
      return null;
    }
  }

  static Analysis? _readCache(String path) {
    try {
      final meta = _cacheBase(path, 'json');
      final envFile = _cacheBase(path, 'env');
      if (meta == null || envFile == null) return null;
      if (!meta.existsSync() || !envFile.existsSync()) return null;
      final m = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
      final bytes = envFile.readAsBytesSync();
      final env = Float32List(bytes.length);
      for (var i = 0; i < bytes.length; i++) {
        env[i] = bytes[i] / 255;
      }
      return Analysis(
        bpm: (m['bpm'] as num?)?.toDouble(),
        firstBeat: (m['firstBeat'] as num?)?.toDouble(),
        env: env,
        envRate: m['envRate'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  static void _writeCache(String path, Analysis a) {
    try {
      final meta = _cacheBase(path, 'json');
      final envFile = _cacheBase(path, 'env');
      if (meta == null || envFile == null) return;
      final bytes = Uint8List(a.env.length);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = (a.env[i].clamp(0.0, 1.0) * 255).round();
      }
      envFile.writeAsBytesSync(bytes);
      meta.writeAsStringSync(
        jsonEncode({
          'bpm': a.bpm,
          'firstBeat': a.firstBeat,
          'envRate': a.envRate,
        }),
      );
    } catch (_) {
      // cache is only a speed-up
    }
  }

  static Future<Analysis?> _analyzeNative(String path) async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('analyze', {
        'path': path,
      });
      if (m == null) return null;
      final bytes = m['env'] as Uint8List;
      final data = ByteData.sublistView(bytes);
      final env = Float32List(bytes.length ~/ 4);
      for (var i = 0; i < env.length; i++) {
        env[i] = data.getFloat32(i * 4, Endian.little);
      }
      return Analysis(
        bpm: (m['bpm'] as num?)?.toDouble(),
        firstBeat: (m['firstBeat'] as num?)?.toDouble(),
        env: env,
        envRate: m['envRate'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}
