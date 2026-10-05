import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'bpm.dart';
import 'store.dart';
import 'theme.dart';

/// One CDJ-style deck: wraps a single [AudioPlayer].
///
/// Heavy-frequency data (playback position) lives in [position] so only the
/// widgets that care about it rebuild; everything else uses [notifyListeners].
class Deck extends ChangeNotifier {
  Deck({required this.name}) {
    _subs.add(
      _player.playerStateStream.listen((s) {
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
      }),
    );
    _subs.add(
      _player.durationStream.listen((d) {
        duration = d ?? Duration.zero;
        notifyListeners();
      }),
    );
    _subs.add(
      _player
          .createPositionStream(
            minPeriod: const Duration(milliseconds: 30),
            maxPeriod: const Duration(milliseconds: 60),
          )
          .listen(_onPosition),
    );
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

  /// What the analyzer found (null until done, or if it could not tell).
  double? detectedBpm;

  /// Your BPM fix for this song: 1 = as detected, 2 = double, 0.5 = half.
  double bpmScale = 1;

  /// Seconds from the start of the song to the first beat.
  double? firstBeat;
  bool bpmBusy = false;

  /// Loudness curve of the song (0..1), [envRate] values per second.
  Float32List env = Float32List(0);
  int envRate = 200;

  /// Tempo of the song at normal speed, after your x2 / /2 fix.
  double? get bpm => detectedBpm == null ? null : detectedBpm! * bpmScale;

  /// BPM you hear now, with the tempo fader applied.
  double? get liveBpm => bpm == null ? null : bpm! * (1 + tempo);

  /// Beat grid is available once tempo and first beat are known.
  bool get hasGrid => bpm != null && firstBeat != null;

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

  // ---------------------------------------------------------------- session
  // The loaded song, position, cues, loop, tempo and volume survive closing
  // the app. Saved a moment after any change, and every 5 s while playing.

  bool _sessionReady = false;
  Timer? _saveTimer;
  Timer? _autosave;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_sessionReady) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 800), _saveSession);
    }
  }

  void _saveSession() {
    final p = path;
    if (p == null) {
      Store.saveSession(name, null);
      return;
    }
    int? ms(Duration? d) => d?.inMilliseconds;
    Store.saveSession(name, {
      'path': p,
      'pos': position.value.inMilliseconds,
      'cue': ms(cue),
      'hot': [for (final h in hotCues) ms(h)],
      'loopIn': ms(loopIn),
      'loopOut': ms(loopOut),
      'loopActive': loopActive,
      'tempo': tempo,
      'volume': channelVolume,
    });
  }

  /// Puts back what this deck had when the app was closed. Call once at
  /// start, after [restorePlaylist]. The song is loaded but not played.
  Future<void> restoreSession() async {
    final s = Store.loadSession(name);
    final p = s?['path'] as String?;
    if (s != null && p != null && File(p).existsSync()) {
      final err = await loadPath(p, p.split('/').last);
      if (err == null) {
        Duration? dur(Object? v) =>
            v is num ? Duration(milliseconds: v.toInt()) : null;
        cue = dur(s['cue']);
        final hot = s['hot'];
        if (hot is List) {
          for (var i = 0; i < hotCueCount && i < hot.length; i++) {
            hotCues[i] = dur(hot[i]);
          }
        }
        loopIn = dur(s['loopIn']);
        loopOut = dur(s['loopOut']);
        loopActive = s['loopActive'] == true && hasLoopPoints;
        channelVolume = (s['volume'] as num?)?.toDouble() ?? channelVolume;
        _applyVolume();
        await setTempo((s['tempo'] as num?)?.toDouble() ?? 0, manual: false);
        final pos = dur(s['pos']);
        if (pos != null) {
          await _player.seek(pos);
          position.value = pos;
        }
      }
    }
    _sessionReady = true;
    _autosave = Timer.periodic(const Duration(seconds: 5), (_) {
      if (playing) _saveSession();
    });
    notifyListeners();
  }

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
      await setTempo(0, manual: false);
      _applyVolume();
      position.value = Duration.zero;
      notifyListeners();
      _findBpm(filePath);
      return null;
    } catch (e) {
      return 'Cannot open this file: $e';
    }
  }

  Future<void> eject() async {
    _previewTimer?.cancel();
    _previewing = false;
    _clearAnalysis();
    syncOn = false;
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

  // ---------------------------------------------------------------- bpm

  void _clearAnalysis() {
    detectedBpm = null;
    firstBeat = null;
    bpmScale = 1;
    bpmBusy = false;
    env = Float32List(0);
  }

  Future<void> _findBpm(String filePath) async {
    _clearAnalysis();
    bpmBusy = true;
    bpmScale = Store.bpmScale(filePath);
    notifyListeners();
    final found = await Bpm.analyze(filePath);
    if (path != filePath) return; // another song was loaded meanwhile
    bpmBusy = false;
    if (found != null) {
      detectedBpm = found.bpm;
      firstBeat = found.firstBeat;
      env = found.env;
      envRate = found.envRate;
      wave = _waveFromEnv();
    }
    if (syncOn) _applySync();
    notifyListeners();
  }

  /// Overview waveform: the loudest point in each slice of the song.
  List<double> _waveFromEnv() {
    const bars = 160;
    final seconds =
        duration.inMilliseconds > 0
            ? duration.inMilliseconds / 1000
            : env.length / envRate;
    return List.generate(bars, (b) {
      final from = (b / bars * seconds * envRate).floor();
      final to = ((b + 1) / bars * seconds * envRate).ceil();
      if (from >= env.length) return 0.08; // past the analysed part
      var peak = 0.0;
      for (var i = from; i < to && i < env.length; i++) {
        if (env[i] > peak) peak = env[i];
      }
      return peak.clamp(0.08, 1.0);
    });
  }

  /// Fix a wrong half-time or double-time reading (the beat grid follows).
  void scaleBpm(double factor) {
    if (detectedBpm == null || path == null) return;
    bpmScale = (bpmScale * factor).clamp(0.25, 4.0);
    Store.saveBpmScale(path!, bpmScale);
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

  /// [newIndex] is the final position (what ReorderableListView.onReorderItem gives).
  void reorderPlaylist(int oldIndex, int newIndex) {
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
    if (_previewing) {
      // PLAY pressed while CUE is held: keep playing after CUE is released.
      _previewing = false;
      notifyListeners();
      return;
    }
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    notifyListeners();
  }

  Timer? _previewTimer;
  bool _previewing = false;

  /// CUE pressed. CDJ behaviour: while playing -> return to cue and pause;
  /// while paused -> set the cue point here. If the button is still held
  /// a moment later, the song plays from the cue until [cueUp].
  void cueDown() {
    if (!isLoaded) return;
    if (_player.playing) {
      _player.pause();
      _player.seek(cue ?? Duration.zero);
    } else {
      cue = position.value;
    }
    notifyListeners();
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 180), () {
      _previewing = true;
      _player.play();
      notifyListeners();
    });
  }

  /// CUE released: stop the preview and snap back to the cue point.
  void cueUp() {
    _previewTimer?.cancel();
    if (!_previewing) return;
    _previewing = false;
    _player.pause();
    _player.seek(cue ?? Duration.zero);
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

  // ------------------------------------------------------------------ sync

  /// The other deck; set by [Mixer].
  Deck? partner;

  /// SYNC is on: this deck follows the other deck's tempo.
  bool syncOn = false;
  double _syncRatio = 1; // 1 = same tempo, 2 = double time, 0.5 = half time

  /// Press SYNC. Sync stays on (and keeps following the other deck) until you
  /// press it again or move this deck's tempo fader. When both decks are
  /// playing the beats are also lined up once. Returns a message when it
  /// could not do the job fully.
  String? toggleSync() {
    if (syncOn) {
      syncOn = false;
      notifyListeners();
      return null;
    }
    final p = partner;
    if (bpm == null) return 'Deck $name has no BPM yet';
    if (p == null || p.liveBpm == null) return 'Deck ${p?.name} has no BPM yet';
    syncOn = true;
    p.syncOn = false; // two decks cannot follow each other
    p.notifyListeners();
    final msg = _applySync();
    if (playing && p.playing) _alignBeats();
    notifyListeners();
    return msg;
  }

  /// Sets the tempo fader so this deck's BPM matches the other deck's.
  /// A 64 BPM song follows a 128 BPM one at half time instead of being
  /// stretched 100 %.
  String? _applySync() {
    final target = partner?.liveBpm;
    final mine = bpm;
    if (target == null || mine == null) return null;
    var best = double.infinity;
    var wanted = 0.0;
    for (final m in const [1.0, 2.0, 0.5]) {
      final t = target * m / mine - 1;
      if (t.abs() < best) {
        best = t.abs();
        wanted = t;
        _syncRatio = m;
      }
    }
    final clamped = wanted.clamp(-tempoRange, tempoRange);
    if ((clamped - tempo).abs() > 1e-4) setTempo(clamped, manual: false);
    return wanted.abs() > tempoRange + 1e-9
        ? 'Out of range: needs ${(wanted * 100).toStringAsFixed(1)} % (max 8 %)'
        : null;
  }

  /// Called when the other deck changes (its tempo fader, a new song, ...).
  void _partnerChanged() {
    if (syncOn) _applySync();
  }

  /// Slide this deck so its beats land on the other deck's beats.
  void _alignBeats() {
    final p = partner;
    if (p == null || !hasGrid || !p.hasGrid || _syncRatio != 1) return;
    double phase(Deck d) {
      final secs = d._player.position.inMicroseconds / 1e6;
      final x = (secs - d.firstBeat!) / (60 / d.bpm!);
      return x - x.floorToDouble();
    }

    var diff = phase(p) - phase(this);
    if (diff > 0.5) diff -= 1;
    if (diff < -0.5) diff += 1;
    final now = _player.position.inMicroseconds;
    seekTo(Duration(microseconds: (now + diff * 60 / bpm! * 1e6).round()));
  }

  // ------------------------------------------------------------ tempo/mixer

  /// [manual] = you moved the fader (or reset it), which ends SYNC. Sync and
  /// song loading pass false.
  Future<void> setTempo(double v, {bool manual = true}) async {
    if (manual) syncOn = false;
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
    _previewTimer?.cancel();
    if (_sessionReady) _saveSession();
    _saveTimer?.cancel();
    _autosave?.cancel();
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
    a.partner = b;
    b.partner = a;
    a.addListener(b._partnerChanged);
    b.addListener(a._partnerChanged);
    final saved = Store.loadMixer();
    crossfader = ((saved?['crossfader'] as num?)?.toDouble() ?? 0.5).clamp(
      0.0,
      1.0,
    );
    master = ((saved?['master'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
    _apply();
  }

  final Deck a;
  final Deck b;

  double crossfader = 0.5; // 0 = A, 1 = B
  double master = 1.0;

  void setCrossfader(double v) {
    crossfader = v.clamp(0.0, 1.0);
    _apply();
    Store.saveMixer(crossfader, master);
    notifyListeners();
  }

  void setMaster(double v) {
    master = v.clamp(0.0, 1.0);
    _apply();
    Store.saveMixer(crossfader, master);
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
