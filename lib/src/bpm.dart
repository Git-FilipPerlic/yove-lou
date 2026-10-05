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
  static Future<Analysis?> analyze(String path) async {
    try {
      final m = await _channel
          .invokeMapMethod<String, dynamic>('analyze', {'path': path});
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
