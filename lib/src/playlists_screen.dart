import 'package:flutter/material.dart';

import 'deck.dart';
import 'file_browser.dart';
import 'grunge.dart';
import 'store.dart';
import 'theme.dart';

/// Both decks' playlists side by side. Opened by holding the mixer's
/// PLAYLISTS button.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key, required this.a, required this.b});

  final Deck a;
  final Deck b;

  void _say(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  /// Names the current pair of playlists and keeps it on the phone.
  Future<void> _saveSet(BuildContext context) async {
    if (a.playlist.isEmpty && b.playlist.isEmpty) {
      _say(context, 'Both playlists are empty - nothing to save');
      return;
    }
    final names = Store.setNames();
    var n = names.length + 1;
    while (names.contains('Set $n')) {
      n++;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: 'Set $n', existing: names),
    );
    if (name == null || !context.mounted) return;
    Store.saveSet(name, a.playlist, b.playlist);
    _say(
      context,
      'Saved "$name" (A ${a.playlist.length}, B ${b.playlist.length})',
    );
  }

  /// Lists the saved sets; tap one to put it on both decks.
  Future<void> _openSets(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _SetsDialog(),
    );
    if (name == null) return;
    final set = Store.loadSet(name);
    if (set == null) return;
    a.setPlaylist(set.$1);
    b.setPlaylist(set.$2);
    if (context.mounted) {
      _say(context, 'Loaded "$name" (A ${set.$1.length}, B ${set.$2.length})');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Material(
                  color: YL.card,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: YL.shadow,
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: YL.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Playlists',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: YL.ink,
                    ),
                  ),
                ),
                Text(
                  'tap = load  -  hold + drag = reorder',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: YL.inkSoft,
                  ),
                ),
                const SizedBox(width: 12),
                _SetButton(
                  icon: Icons.bookmark_add_rounded,
                  label: 'SAVE SET',
                  onTap: () => _saveSet(context),
                ),
                const SizedBox(width: 8),
                _SetButton(
                  icon: Icons.bookmarks_rounded,
                  label: 'SETS',
                  onTap: () => _openSets(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _DeckList(deck: a)),
                  const SizedBox(width: 10),
                  Expanded(child: _DeckList(deck: b)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetButton extends StatelessWidget {
  const _SetButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: YL.card,
      borderRadius: BorderRadius.circular(YL.r(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(YL.r(12)),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(YL.r(12)),
            boxShadow: YL.shadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: YL.ink),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: YL.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Dialog _dialog({required Widget child}) => Dialog(
  backgroundColor: YL.card,
  insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(YL.radius)),
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);

/// Asks for a set name. Pops the name, or null when cancelled.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial, required this.existing});

  final String initial;
  final List<String> existing;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() {
    final name = _c.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final name = _c.text.trim();
    final replaces = widget.existing.contains(name);
    return _dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // One compact block, so it still fits above the keyboard when
            // the phone is held sideways.
            Text(
              replaces
                  ? 'Save set - replaces the one with this name'
                  : 'Save set (decks A + B)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: YL.ink,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    autofocus: true,
                    maxLength: 30,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _ok(),
                    style: TextStyle(color: YL.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      filled: true,
                      fillColor: YL.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(YL.r(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: name.isEmpty ? null : _ok,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved sets. Tap one to load it (pops its name); bin deletes it.
class _SetsDialog extends StatefulWidget {
  const _SetsDialog();

  @override
  State<_SetsDialog> createState() => _SetsDialogState();
}

class _SetsDialogState extends State<_SetsDialog> {
  @override
  Widget build(BuildContext context) {
    final names = Store.setNames();
    return _dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saved sets',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: YL.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
          Text(
            'Tap a set to load it onto both decks (replaces the playlists).',
            style: TextStyle(fontSize: 12, color: YL.inkSoft),
          ),
          const SizedBox(height: 8),
          if (names.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Nothing saved yet. Use SAVE SET first.',
                style: TextStyle(
                  color: YL.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final n in names)
                    () {
                      final (ca, cb) = Store.setCounts(n);
                      return InkWell(
                        borderRadius: BorderRadius.circular(YL.r(10)),
                        onTap: () => Navigator.of(context).pop(n),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  n,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: YL.ink,
                                  ),
                                ),
                              ),
                              Text(
                                'A $ca  B $cb',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: YL.inkSoft,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete set',
                                onPressed: () {
                                  Store.deleteSet(n);
                                  setState(() {});
                                },
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: YL.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DeckList extends StatelessWidget {
  const _DeckList({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: YL.panel(),
      clipBehavior: Clip.antiAlias,
      child: ScrewFrame(
        child: AnimatedBuilder(
          animation: deck,
          builder:
              (context, _) => Column(
                children: [
                  _ListHeader(deck: deck),
                  Divider(height: 1, color: YL.line),
                  Expanded(
                    child:
                        deck.playlist.isEmpty
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'Empty. Tap + to pick songs from your phone.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: YL.inkSoft,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            : ReorderableListView.builder(
                              itemCount: deck.playlist.length,
                              onReorderItem: deck.reorderPlaylist,
                              proxyDecorator:
                                  (child, _, _) => Material(
                                    color: YL.card,
                                    elevation: 4,
                                    child: child,
                                  ),
                              itemBuilder:
                                  (context, i) => _TrackRow(
                                    key: ObjectKey(deck.playlist[i]),
                                    deck: deck,
                                    index: i,
                                  ),
                            ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: YL.fill(deck.color, radius: 9),
            child: Text(
              deck.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${deck.playlist.length} song${deck.playlist.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: YL.ink,
              ),
            ),
          ),
          if (deck.playlist.isNotEmpty)
            IconButton(
              tooltip: 'Clear playlist',
              onPressed: deck.clearPlaylist,
              icon: Icon(Icons.delete_sweep_outlined, color: YL.inkSoft),
            ),
          IconButton(
            tooltip: 'Add songs',
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FileBrowserScreen(deck: deck),
                  ),
                ),
            icon: Icon(Icons.add_circle_rounded, color: deck.color),
          ),
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({super.key, required this.deck, required this.index});

  final Deck deck;
  final int index;

  @override
  Widget build(BuildContext context) {
    final track = deck.playlist[index];
    final current = deck.currentIndex == index;
    return InkWell(
      onTap: () async {
        final err = await deck.loadFromPlaylist(index);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(err)));
        }
      },
      child: Container(
        height: 48,
        color: current ? deck.color.withValues(alpha: 0.14) : null,
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child:
                  current
                      ? Icon(
                        Icons.graphic_eq_rounded,
                        size: 18,
                        color: deck.color,
                      )
                      : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: YL.inkSoft,
                        ),
                      ),
            ),
            Expanded(
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                  color: YL.ink,
                ),
              ),
            ),
            if (!current)
              IconButton(
                tooltip: 'Play next',
                visualDensity: VisualDensity.compact,
                onPressed: () => deck.playNext(index),
                icon: Icon(Icons.skip_next_rounded, size: 20, color: deck.color),
              ),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: () => deck.removeFromPlaylist(index),
              icon: Icon(Icons.close_rounded, size: 18, color: YL.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
