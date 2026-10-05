import 'package:flutter/material.dart';

import 'deck.dart';
import 'file_browser.dart';
import 'grunge.dart';
import 'theme.dart';

/// Both decks' playlists side by side. Opened by holding the mixer's
/// PLAYLISTS button.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key, required this.a, required this.b});

  final Deck a;
  final Deck b;

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
                          shape: BoxShape.circle, boxShadow: YL.shadow),
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
                        color: YL.ink),
                  ),
                ),
                Text(
                  'tap = load  -  hold + drag = reorder',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: YL.inkSoft),
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
          builder: (context, _) => Column(
            children: [
              _ListHeader(deck: deck),
              Divider(height: 1, color: YL.line),
              Expanded(
                child: deck.playlist.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Empty. Tap + to pick songs from your phone.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: YL.inkSoft, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: deck.playlist.length,
                        onReorder: deck.reorderPlaylist,
                        proxyDecorator: (child, _, __) => Material(
                            color: YL.card, elevation: 4, child: child),
                        itemBuilder: (context, i) => _TrackRow(
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
            child: Text(deck.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${deck.playlist.length} song${deck.playlist.length == 1 ? '' : 's'}',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: YL.ink),
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FileBrowserScreen(deck: deck)),
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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err)));
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
              child: current
                  ? Icon(Icons.graphic_eq_rounded, size: 18, color: deck.color)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: YL.inkSoft),
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
