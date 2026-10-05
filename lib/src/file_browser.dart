import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'deck.dart';
import 'theme.dart';

const _root = '/storage/emulated/0';
const _audioExt = {'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus'};

/// Explorer-style browser: folders and audio files only.
/// Tapping a song loads it into [deck] and closes the browser.
class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key, required this.deck});

  final Deck deck;

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  String _path = _root;
  bool _hasAccess = false;
  bool _loading = true;
  String? _error;
  List<Directory> _folders = [];
  List<File> _files = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _requestAccess();
  }

  Future<void> _requestAccess() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (!mounted) return;
    _hasAccess = status.isGranted;
    if (_hasAccess) {
      await _open(_path);
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _open(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await Directory(path).list(followLinks: false).toList();
      final folders = <Directory>[];
      final files = <File>[];
      for (final e in entries) {
        final name = _name(e.path);
        if (name.startsWith('.')) continue; // hidden
        if (e is Directory) {
          folders.add(e);
        } else if (e is File && _audioExt.contains(_ext(name))) {
          files.add(e);
        }
      }
      int byName(FileSystemEntity a, FileSystemEntity b) =>
          _name(a.path).toLowerCase().compareTo(_name(b.path).toLowerCase());
      folders.sort(byName);
      files.sort(byName);
      if (!mounted) return;
      setState(() {
        _path = path;
        _folders = folders;
        _files = files;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Cannot open this folder';
      });
    }
  }

  Future<void> _loadFile(File file) async {
    final err = await widget.deck.loadPath(file.path, _name(file.path));
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      Navigator.of(context).pop();
    }
  }

  List<Track> get _selectedTracks => [
        for (final p in _selected) Track(p, _name(p))
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void _toggle(File f) => setState(() {
        if (!_selected.remove(f.path)) _selected.add(f.path);
      });

  void _selectAllHere() => setState(() {
        final all = _files.map((f) => f.path);
        if (all.every(_selected.contains)) {
          _selected.removeAll(all);
        } else {
          _selected.addAll(all);
        }
      });

  void _addSelected({required bool loadFirst}) {
    final tracks = _selectedTracks;
    if (tracks.isEmpty) return;
    final deck = widget.deck;
    final added = deck.addToPlaylist(tracks);
    setState(_selected.clear);
    final msg =
        'Added $added to deck ${deck.name} playlist (${deck.playlist.length} total)';
    if (loadFirst) {
      _loadFile(File(tracks.first.path));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    }
  }

  void _up() {
    if (_path == _root) return;
    final parent = _path.substring(0, _path.lastIndexOf('/'));
    _open(parent.length < _root.length ? _root : parent);
  }

  static String _name(String path) => path.split('/').last;

  static String _ext(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// Breadcrumb segments as (label, full path).
  List<(String, String)> get _crumbs {
    final crumbs = <(String, String)>[('Phone', _root)];
    var acc = _root;
    for (final part in _path
        .substring(_root.length)
        .split('/')
        .where((s) => s.isNotEmpty)) {
      acc = '$acc/$part';
      crumbs.add((part, acc));
    }
    return crumbs;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.deck.color;
    return PopScope(
      canPop: _path == _root,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _up();
      },
      child: Scaffold(
        body: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            children: [
              _Header(
                color: color,
                deckName: widget.deck.name,
                onBack: () =>
                    _path == _root ? Navigator.of(context).pop() : _up(),
              ),
              const SizedBox(height: 10),
              if (_hasAccess) _Breadcrumbs(crumbs: _crumbs, onTap: _open),
              const SizedBox(height: 10),
              Expanded(child: _body(color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(Color color) {
    if (!_hasAccess) {
      return _Card(
        child: _Message(
          icon: Icons.lock_outline_rounded,
          text: 'yove lou needs access to your files to load songs.',
          action: 'Allow access',
          onAction: () async {
            await openAppSettings();
            _requestAccess();
          },
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _Card(
          child: _Message(icon: Icons.error_outline_rounded, text: _error!));
    }
    if (_folders.isEmpty && _files.isEmpty) {
      return const _Card(
          child: _Message(
              icon: Icons.folder_off_outlined,
              text: 'No songs or folders here'));
    }
    final list = _Card(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          for (final d in _folders)
            _Row(
              icon: Icons.folder_rounded,
              iconColor: YL.inkSoft,
              title: _name(d.path),
              subtitle: 'Folder',
              onTap: () => _open(d.path),
            ),
          for (final f in _files)
            _Row(
              icon: Icons.music_note_rounded,
              iconColor: color,
              title: _name(f.path).replaceAll(RegExp(r'\.[^.]+$'), ''),
              subtitle: _ext(_name(f.path)).toUpperCase(),
              selected: _selected.contains(f.path),
              onTap: () => _toggle(f),
              onLongPress: () => _loadFile(f),
            ),
        ],
      ),
    );
    return Column(
      children: [
        Expanded(child: list),
        if (_files.isNotEmpty || _selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SelectBar(
            deckName: widget.deck.name,
            color: color,
            count: _selected.length,
            allHere: _files.isNotEmpty &&
                _files.every((f) => _selected.contains(f.path)),
            onSelectAll: _selectAllHere,
            onAdd: () => _addSelected(loadFirst: false),
            onAddLoad: () => _addSelected(loadFirst: true),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.color, required this.deckName, required this.onBack});

  final Color color;
  final String deckName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 12),
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: YL.fill(color, radius: 9),
          child: Text(deckName,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Add songs to deck $deckName',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15, color: YL.ink),
          ),
        ),
      ],
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.crumbs, required this.onTap});

  final List<(String, String)> crumbs;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0)
              Icon(Icons.chevron_right_rounded, size: 18, color: YL.inkSoft),
            InkWell(
              borderRadius: BorderRadius.circular(YL.r(10)),
              onTap: () => onTap(crumbs[i].$2),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: i == crumbs.length - 1 ? YL.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(YL.r(10)),
                ),
                child: Text(
                  crumbs[i].$1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: i == crumbs.length - 1 ? YL.ink : YL.inkSoft,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: YL.card,
        borderRadius: BorderRadius.circular(YL.radius),
        boxShadow: YL.shadow,
      ),
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected,
    this.onLongPress,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// null = a folder; true/false = a song that can be ticked.
  final bool? selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 56,
        color: selected == true ? iconColor.withValues(alpha: 0.12) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: YL.ink)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: YL.inkSoft)),
                  ],
                ),
              ),
              if (selected == null)
                Icon(Icons.chevron_right_rounded, color: YL.line)
              else
                Icon(
                  selected!
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected! ? iconColor : YL.line,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(
      {required this.icon, required this.text, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: YL.inkSoft),
            const SizedBox(height: 10),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: YL.ink, fontWeight: FontWeight.w600)),
            if (action != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: YL.card,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration:
              BoxDecoration(shape: BoxShape.circle, boxShadow: YL.shadow),
          child: Icon(icon, color: YL.ink),
        ),
      ),
    );
  }
}

/// Bottom bar: select-all, how many are ticked, and the add actions.
class _SelectBar extends StatelessWidget {
  const _SelectBar({
    required this.deckName,
    required this.color,
    required this.count,
    required this.allHere,
    required this.onSelectAll,
    required this.onAdd,
    required this.onAddLoad,
  });

  final String deckName;
  final Color color;
  final int count;
  final bool allHere;
  final VoidCallback onSelectAll;
  final VoidCallback onAdd;
  final VoidCallback onAddLoad;

  @override
  Widget build(BuildContext context) {
    final has = count > 0;
    return Row(
      children: [
        TextButton(
          onPressed: onSelectAll,
          child: Text(allHere ? 'Clear folder' : 'Select all'),
        ),
        Expanded(
          child: Text(
            has ? '$count selected' : 'Tap = select  -  hold = load now',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: has ? YL.ink : YL.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _BarButton(
            label: 'ADD TO $deckName',
            color: color,
            filled: false,
            onTap: has ? onAdd : null),
        const SizedBox(width: 8),
        _BarButton(
            label: 'ADD + LOAD',
            color: color,
            filled: true,
            onTap: has ? onAddLoad : null),
      ],
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    final c = on ? color : YL.inkSoft;
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: Container(
        decoration: YL.fill(filled ? c : c.withValues(alpha: 0.14), radius: 12),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(YL.r(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(YL.r(12)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : c,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
