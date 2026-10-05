import 'package:flutter/services.dart';

/// Asks the Android side (BpmDetector.kt) for a song's tempo.
class Bpm {
  static const _channel = MethodChannel('yove_lou/bpm');

  /// BPM of the audio file, or null if it could not be worked out.
  static Future<double?> detect(String path) async {
    try {
      return await _channel.invokeMethod<double>('detect', {'path': path});
    } catch (_) {
      return null;
    }
  }
}
