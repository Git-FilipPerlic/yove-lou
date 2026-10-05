# yove lou - feature list

Code name: **yove lou** (all reminders / check-ins use this name).
Goal: a CDJ-style imitator that plays **two tracks at the same time**, built in Flutter, designed for a phone held **horizontally**.

Design: three themes, switched with the palette button on the mixer.
- **Grunge** (default): graphite panels, scratch / dust texture, corner screws, amber LCD time, vinyl jog wheel. Signal red (A), electric blue (B), yellow cue.
- **Classic**: clean, flat, white-dominant. Soft shadows, round corners, blue (A) and coral (B).
- **Pearl & Peach**: pearl white with glossy peach, lower contrast.

## v0.3 - what is in the code now
**Decks (A / B)**
- [x] Two independent decks, each with its own audio player
- [x] Play / pause
- [x] CUE (CDJ behaviour): paused = set the cue point here ("SET"), playing = jump back to the cue and pause ("BACK")
- [x] Hold CUE to preview: plays from the cue while held, snaps back on release; press PLAY while holding to keep playing
- [x] Jog wheel: drag in a circle to scrub; rotates with the song (33 rpm look)
- [x] Real waveform from the audio (loudness of the first 12 min), in two parts: a zoomed strip that scrolls around the playhead (8 s window, drag sideways to scrub) and a thin overview bar of the whole song (tap / drag to seek)
- [x] Beat grid on the zoomed strip: a line on every beat, a thick line on every 4th; follows BPM x2 / /2 fixes
- [x] Elapsed + remaining time
- [x] Long song titles scroll to and fro (marquee) instead of being cut with "..."
- [x] 4 hot-cue pads (tap = set / jump, hold = clear)
- [x] Manual loop: IN -> OUT -> clear
- [x] Tempo fader +/-8 % (double-tap to reset)
- [x] BPM + first-beat detection (native Android decoder, fitted over up to 4 min, exact on test tracks), shown on each deck and following the tempo fader; BPM x2 / /2 in the hold menu to fix half- or double-time readings (your fix is remembered per song)
- [x] Analysis results (BPM, beat grid, waveform) are cached on the device, so a song is analysed only once; later loads are instant
- [x] SYNC: the deck follows the other deck's tempo (also at half / double time) and lines the beats up once when both are playing; stays on until pressed again or the tempo fader is moved
- [x] Taller CUE / IN / SYNC buttons (easier to hit mid-mix)

**Mixer**
- [x] Channel faders A / B, master fader, crossfader (double-tap to centre)
- [x] Theme button (cycles Grunge, Classic, Pearl & Peach)
- [x] Help button ("?"): short guide as small cards in two columns
- [x] Crossfader and master volume are remembered

**Loading music**
- [x] In-app file browser (explorer style, matches the active theme): folders and audio files only, back button, compact rows (about 5 visible in landscape)
- [x] One top row: back, deck chip, breadcrumb path (stays on the current folder), sort button (name / newest first), search (filters the current folder as you type)
- [x] Opens in the folder you were in last time
- [x] Multi-select: tap songs to tick them, "All / None" per folder, ticks survive moving between folders
- [x] Adding songs that are already in the playlist says how many were skipped
- [x] ADD TO A / B (queue them) or ADD + LOAD (queue and load the first one)
- [x] Hold a song = load it on the deck right now
- [x] Needs "All files access" permission (asked on first use)

**Playlists**
- [x] Each deck has its own playlist
- [x] PLAYLISTS button on the mixer: **hold** to open both playlists side by side (a plain tap only shows a hint)
- [x] Tap a song = load it, hold + drag = reorder, X = remove, bin = clear, + = add more songs
- [x] Current song is highlighted
- [x] When a song ends, the next one in the playlist is loaded and cued (does not autoplay)
- [x] Play next: skip icon on every song moves it right after the song on the deck
- [x] **Sets**: SAVE SET names the current pair of playlists (A + B); SETS lists them with song counts, tap to load onto both decks, bin to delete (deleted files are skipped when loading)

**Saved on the device**
- [x] Playlists (songs whose file was deleted are skipped) and named sets
- [x] Theme choice
- [x] What is on each deck: loaded song, position, cue, hot cues, loop, tempo and channel volume (loaded but not playing after a restart)
- [x] Crossfader / master volume, last browser folder, per-song BPM x2 / /2 fix
- [x] Analysis cache (in the app cache folder; Android may clear it, then songs are analysed again)

**Hold menu** (long-press the jog wheel or deck header): add songs, set cue, loop in/out, reset tempo, clear cues, BPM x2, BPM /2, eject. Labels stay on one line.

**Phone layout:** landscape-only, immersive mode, SafeArea around notch / camera cut-out / gesture bar.

## Not saved yet
SYNC state, a song that was playing (it comes back paused), per-song cues / loops for songs that are not on a deck.

## Known limits
- Very long files (for example a 2 h mix) take over a minute to analyse, and analysis runs one song at a time; the overview waveform covers only the first 12 min.
- Beat 1 (bar start) is not detected, the grid cannot be shifted yet.
- UI is English only. "All files access" is restricted on Google Play (fine for sideloading).

## Part of perfundo
The decks also live inside the **perfundo** app (a copy of the event app): a DJ switch at the top right of the large-play-button screen opens them. perfundo keeps its own copy of the code in `lib/yove/` and its own saved data (keys start with `yove_`).

## Next (suggested order)
1. Beat grid tools: shift the grid, mark which beat is beat 1 (bar start), re-detect, tempo changes within a song
2. Colour-coded frequency waveform and waveform for songs longer than 12 min
3. Master-tempo / key lock
4. Beat loops (1/2/4/8/16 beats) and loop roll
5. Library extras: sort by BPM / key, BPM and song length in the lists, deck menu shortcut to the playlists, per-deck playlist saves
6. Per-track cues / hot cues / loops (local DB)
7. 3-band EQ (hi / mid / low) + kill switches per channel (Android equalizer or custom DSP)
8. Filter knob (HPF / LPF sweep) per channel
9. Level meters per channel and master
10. Cue-to-headphones (needs split output: phone speaker/BT = master, wired headphones = cue)
11. Option to autoplay the next playlist song

## Researched pro-player features (backlog)
**Transport:** play/pause, CUE, cue-preview (hold CUE), previous/next track, search (fast scan), jog modes (vinyl / CDJ), slip mode, reverse, brake/start effect on stop/play.
**Cue & loop:** main cue, hot cues (8), memory cues, loop in/out, auto beat loop, loop halve/double, loop move, saved loops, quantize (snap to beat grid).
**Tempo:** pitch fader with range switch (6 / 10 / 16 / wide), master tempo (key lock), tempo reset, BPM tap, sync + quantize.
**Mixer:** channel gain/trim, 3-4 band EQ, filter, channel fader curve, crossfader curve + reverse (hamster), master + booth level, headphone mix/level, auto-mix / auto-fade.
**FX:** echo, reverb, flanger, phaser, gate, roll, brake, spinback, FX wet/dry, beat-synced FX.
**Pads / sampler:** hot cue, roll, slicer, sampler slots, scratch pad.
**Library:** folders, playlists, history, key (Camelot) + BPM display, compatible-song suggestions, search, ratings, colour tags.
**Display:** zoomed + overview waveform, colour-coded frequency waveform, beat grid, key display, remaining/elapsed toggle, album art on the jog.
**Extras:** record the mix to a file, MIDI / USB controller input, video decks (VirtualDJ-style), Ableton Link-style sync, cloud/streaming sources, more themes.

## UX notes (landscape phone)
- Keep all controls inside SafeArea: the notch / punch-hole, rounded corners and the bottom gesture bar are danger zones.
- Immersive mode hides status + nav bar; swipe from the edge to peek them.
- Prefer **hold -> menu** over swipe gestures (decision from the owner). Swipes only where it is natural: jog drag, faders, waveform scrub. Risky screens (playlists) open with a hold so they can't be hit by accident mid-mix.
- Minimum touch target about 44 dp for anything used while performing.
- Dislikes green and brown (owner): keep them out of the default theme.
- Android only has one audio output route by default, so true headphone cueing is a stretch goal.
