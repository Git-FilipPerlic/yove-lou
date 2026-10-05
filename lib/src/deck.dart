import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'store.dart';
import 'theme.dart';

/// One CDJ-style deck: wraps a single [AudioPlayer].
///
/// Heavy-frequency data (playback position) lives in [position] so only the
/// widgets that care about it rebuild; everything else uses [notifyListeners].
class Deck extends ChangeNotifier {
  Deck({required this.name}) {
    _subs.add(_player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        final next = (currentIndex ?? -1) + 1;
        if (currentIndex != null && next < playlist.length) {
          // Queue advances: next song is loaded and cued, ready to play.
          loadPath(playlist[next].path, playlist[next].name);
        } else {
          _player.seek(Duration.zero);
        }
      }
      notifyListeners();
    }));
    _subs.add(_player.durationStream.listen((d) {
      duration = d ?? Duration.zero;
      notifyListeners();
    }));
    _subs.add(_player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 30),
          maxPeriod: const Duration(milliseconds: 60),
        )
        .listen(_onPosition));
  }

  static const int hotCueCount = 4;
  static const double tempoRange = 0.08; // +/- 8 %

  final String name; // "A" / "B"

  /// Follows the active palette, so it updates when the theme changes.
  Color get color => name == 'A' ? YL.deckA : YL.deckB;

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  String? path;

  /// Songs queued for this deck. [currentIndex] is the one on the deck now.
  final List<Track> playlist = [];
  int? currentIndex;
  String title = '';
  Duration duration = Duration.zero;
  List<double> wave = const [];

  Duration? cue;
  final List<Duration?> hotCues = List.filled(hotCueCount, null);

  Duration? loopIn;
  Duration? loopOut;
  bool loopActive = false;

  double tempo = 0; // -0.08 .. +0.08
  double channelVolume = 0.85;
  double _crossGain = 1;

  bool get isLoaded => path != null;
  bool get playing => _player.playing;
  bool get hasLoopPoints => loopIn != null && loopOut != null;

  // ---------------------------------------------------------------- loading

  Future<String?> loadPath(String filePath, String fileName) async {
    try {
      await _player.pause();
      await _player.setFilePath(filePath);
      path = filePath;
      final qi = playlist.indexWhere((t) => t.path == filePath);
      currentIndex = qi < 0 ? null : qi;
      title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      wave = _fakeWave(filePath.hashCode);
      cue = null;
      loopIn = loopOut = null;
      loopActive = false;
      for (var i = 0; i < hotCueCount; i++) {
        hotCues[i] = null;
      }
      await setTempo(0);
      _applyVolume();
      position.value = Duration.zero;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Cannot open this file: $e';
    }
  }

  Future<void> eject() async {
    await _player.stop();
    path = null;
    title = '';
    duration = Duration.zero;
    wave = const [];
    cue = null;
    loopIn = loopOut = null;
    loopActive = false;
    position.value = Duration.zero;
    notifyListeners();
  }

  // --------------------------------------------------------------- playlist

  /// Adds songs to the end of the queue, skipping ones already in it.
  int addToPlaylist(Iterable<Track> tracks) {
    var added = 0;
    for (final t in tracks) {
      if (playlist.any((x) => x.path == t.path)) continue;
      playlist.add(t);
      added++;
    }
    final qi = playlist.indexWhere((t) => t.path == path);
    currentIndex = qi < 0 ? null : qi;
    _playlistChanged();
    return added;
  }

  /// Puts back the playlist saved on the device (at app start).
  void restorePlaylist(List<Track> saved) {
    playlist
      ..clear()
      ..addAll(saved);
    notifyListeners();
  }

  void _playlistChanged() {
    Store.savePlaylist(name, playlist);
    notifyListeners();
  }

  Future<String?> loadFromPlaylist(int i) =>
      loadPath(playlist[i].path, playlist[i].name);

  void removeFromPlaylist(int i) {
    final current = currentIndex;
    playlist.removeAt(i);
    if (current != null) {
      if (i == current) {
        currentIndex = null; // still playing, but no longer queued
      } else if (i < current) {
        currentIndex = current - 1;
      }
    }
    _playlistChanged();
  }

  void reorderPlaylist(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final current = currentIndex == null ? null : playlist[currentIndex!];
    playlist.insert(newIndex, playlist.removeAt(oldIndex));
    if (current != null) currentIndex = playlist.indexOf(current);
    _playlistChanged();
  }

  void clearPlaylist() {
    playlist.clear();
    currentIndex = null;
    _playlistChanged();
  }

  // -------------------------------------------------------------- transport

  void togglePlay() {
    if (!isLoaded) return;
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    notifyListeners();
  }

  /// CDJ behaviour: while playing -> return to cue and pause;
  /// while paused -> set the cue point here.
  void cuePress() {
    if (!isLoaded) return;
    if (_player.playing) {
      _player.pause();
      _player.seek(cue ?? Duration.zero);
    } else {
      cue = position.value;
    }
    notifyListeners();
  }

  void setCueHere() {
    if (!isLoaded) return;
    cue = position.value;
    notifyListeners();
  }

  void seekTo(Duration d) {
    if (!isLoaded) return;
    final clamped = Duration(
      milliseconds: d.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    _player.seek(clamped);
    position.value = clamped;
  }

  void nudge(Duration delta) => seekTo(position.value + delta);

  void seekFraction(double f) {
    seekTo(Duration(milliseconds: (duration.inMilliseconds * f).round()));
  }

  // ------------------------------------------------------------------ loops

  /// Cycles: set IN -> set OUT (loop on) -> clear.
  void loopPress() {
    if (!isLoaded) return;
    if (loopIn == null) {
      loopIn = position.value;
    } else if (loopOut == null) {
      if (position.value - loopIn! > const Duration(milliseconds: 100)) {
        loopOut = position.value;
        loopActive = true;
      }
    } else {
      clearLoop();
      return;
    }
    notifyListeners();
  }

  void clearLoop() {
    loopIn = loopOut = null;
    loopActive = false;
    notifyListeners();
  }

  void _onPosition(Duration p) {
    position.value = p;
    if (loopActive && hasLoopPoints && p >= loopOut!) {
      _player.seek(loopIn);
    }
  }

  // --------------------------------------------------------------- hot cues

  /// Tap: set if empty, otherwise jump.
  void hotCueTap(int i) {
    if (!isLoaded) return;
    final c = hotCues[i];
    if (c == null) {
      hotCues[i] = position.value;
      notifyListeners();
    } else {
      seekTo(c);
    }
  }

  void clearHotCue(int i) {
    hotCues[i] = null;
    notifyListeners();
  }

  void clearAllHotCues() {
    for (var i = 0; i < hotCueCount; i++) {
      hotCues[i] = null;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ tempo/mixer

  Future<void> setTempo(double v) async {
    tempo = v.clamp(-tempoRange, tempoRange);
    notifyListeners();
    try {
      await _player.setSpeed(1 + tempo);
    } catch (_) {}
  }

  void setChannelVolume(double v) {
    channelVolume = v.clamp(0.0, 1.0);
    _applyVolume();
    notifyListeners();
  }

  void setCrossGain(double g) {
    _crossGain = g;
    _applyVolume();
  }

  void _applyVolume() {
    _player.setVolume((channelVolume * _crossGain).clamp(0.0, 1.0));
  }

  // ------------------------------------------------------------------ misc

  /// Placeholder waveform (deterministic per file) until real decoding lands.
  static List<double> _fakeWave(int seed) {
    final r = math.Random(seed);
    final p1 = r.nextDouble() * 6, p2 = r.nextDouble() * 6;
    return List.generate(160, (i) {
      final t = i / 160;
      final env =
          0.55 + 0.25 * math.sin(t * 9 + p1) + 0.15 * math.sin(t * 23 + p2);
      return (env * (0.55 + 0.45 * r.nextDouble())).clamp(0.08, 1.0);
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    position.dispose();
    super.dispose();
  }
}

/// Two decks + crossfader + master.
class Mixer extends ChangeNotifier {
  Mixer(this.a, this.b) {
    _apply();
  }

  final Deck a;
  final Deck b;

  double crossfader = 0.5; // 0 = A, 1 = B
  double master = 1.0;

  void setCrossfader(double v) {
    crossfader = v.clamp(0.0, 1.0);
    _apply();
    notifyListeners();
  }

  void setMaster(double v) {
    master = v.clamp(0.0, 1.0);
    _apply();
    notifyListeners();
  }

  void _apply() {
    // Full volume at the centre, fades the far side out.
    final ga = math.min(1.0, 2 * (1 - crossfader));
    final gb = math.min(1.0, 2 * crossfader);
    a.setCrossGain(ga * master);
    b.setCrossGain(gb * master);
  }
}

String fmtTime(Duration d, {bool tenths = true}) {
  final neg = d.isNegative;
  final ms = d.inMilliseconds.abs();
  final m = ms ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  final t = (ms % 1000) ~/ 100;
  final base =
      '${neg ? '-' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return tenths ? '$base.$t' : base;
}

/// A song waiting in a deck's playlist.
class Track {
  const Track(this.path, this.name);

  final String path;
  final String name;

  String get title => name.replaceAll(RegExp(r'\.[^.]+$'), '');
}
