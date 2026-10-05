# yove lou - feature list

Code name: **yove lou** (all reminders / check-ins use this name).
Goal: a CDJ-style imitator that plays **two tracks at the same time**, built in Flutter, designed for a phone held **horizontally**.

Design: three themes, switched with the palette button on the mixer.
- **Grunge** (default): graphite panels, scratch / dust texture, corner screws, amber LCD time, vinyl jog wheel. Signal red (A), electric blue (B), yellow cue.
- **Classic**: clean, flat, white-dominant. Soft shadows, round corners, blue (A) and coral (B).
- **Pearl & Peach**: pearl white with glossy peach, lower contrast.

## v0.2 - what is in the code now
**Decks (A / B)**
- [x] Two independent decks, each with its own audio player
- [x] Play / pause
- [x] CUE (CDJ behaviour): paused = set the cue point here ("SET"), playing = jump back to the cue and pause ("BACK")
- [x] Hold CUE to preview: plays from the cue while held, snaps back on release; press PLAY while holding to keep playing
- [x] Jog wheel: drag in a circle to scrub; rotates with the song (33 rpm look)
- [x] Waveform strip with playhead, tap / drag to seek (placeholder wave, not yet real audio data)
- [x] Elapsed + remaining time
- [x] 4 hot-cue pads (tap = set / jump, hold = clear)
- [x] Manual loop: IN -> OUT -> clear
- [x] Tempo fader +/-8 % (double-tap to reset)
- [x] BPM detection (native Android decoder, ~45 s analysed in under a second), shown on each deck and following the tempo fader; BPM x2 / /2 in the hold menu to fix half- or double-time readings; results cached per song

**Mixer**
- [x] Channel faders A / B, master fader, crossfader (double-tap to centre)
- [x] Theme button (cycles Grunge, Classic, Pearl & Peach)
- [x] Help button ("?"): short guide to every control

**Loading music**
- [x] In-app file browser (explorer style, matches the active theme): folders and audio files only, breadcrumb path, back button
- [x] Multi-select: tap songs to tick them, "Select all" per folder, ticks survive moving between folders
- [x] ADD TO A / B (queue them) or ADD + LOAD (queue and load the first one)
- [x] Hold a song = load it on the deck right now
- [x] Needs "All files access" permission (asked on first use)

**Playlists**
- [x] Each deck has its own playlist
- [x] PLAYLISTS button on the mixer: **hold** to open both playlists side by side (a plain tap only shows a hint)
- [x] Tap a song = load it, hold + drag = reorder, X = remove, bin = clear, + = add more songs
- [x] Current song is highlighted
- [x] When a song ends, the next one in the playlist is loaded and cued (does not autoplay)

**Saved on the device**
- [x] Playlists (songs whose file was deleted are skipped)
- [x] Theme choice

**Hold menu** (long-press the jog wheel or deck header): add songs, set cue, loop, reset tempo, clear hot cues, eject.

**Phone layout:** landscape-only, immersive mode, SafeArea around notch / camera cut-out / gesture bar.

## Not saved yet
Loaded song, cue point, hot cues, loops, fader positions. All reset when the app closes.

## Next (suggested order)
1. Real waveform from the audio file (decode peaks in an isolate) + zoomed scrolling waveform
2. Beat grid from the detected BPM (first-beat marker, grid lines on the waveform); better BPM accuracy on live-played music
3. SYNC (match tempo to the other deck) and master-tempo / key lock
4. Beat loops (1/2/4/8/16 beats) and loop roll
5. Library extras: search, sort by BPM / key / title, song length in the list, deck menu shortcut to the playlists
6. Save loaded song, cues / hot cues / loops per track (local DB)
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
