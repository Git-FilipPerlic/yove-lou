# yove lou - feature list

Code name: **yove lou** (all reminders / check-ins use this name).
Goal: a CDJ-style imitator that plays **two tracks at the same time**, built in Flutter, designed for a phone held **horizontally**.

Design: clean, modern, flat, white-dominant. Soft shadows, round corners, one accent colour per deck (A blue, B coral).

## v0.1 - what is in the code now
- [x] Two independent decks (A / B), each with its own audio player
- [x] Load a local audio file per deck (tap the empty header, or hold -> menu -> Load track)
- [x] Play / pause
- [x] CUE (CDJ behaviour: paused = set cue here, playing = jump back to cue and pause)
- [x] Jog wheel: drag in a circle to scrub; rotates with the song (33 rpm look)
- [x] Waveform strip with playhead, tap / drag to seek (placeholder wave, not yet real audio data)
- [x] Elapsed + remaining time
- [x] 4 hot-cue pads (tap = set / jump, hold = clear)
- [x] Manual loop: IN -> OUT -> clear
- [x] Tempo fader +/-8 % (double-tap to reset)
- [x] Channel faders A / B, master fader, crossfader (double-tap to centre)
- [x] **Hold menu** (long-press the jog wheel or deck header): load, set cue, loop, reset tempo, clear hot cues, eject
- [x] Landscape-only, immersive mode, SafeArea around notch / camera cut-out / gesture bar

## Next (suggested order)
1. Real waveform from the audio file (decode peaks in an isolate) + zoomed scrolling waveform
2. BPM detection + beat grid, show BPM per deck
3. SYNC (match tempo to the other deck) and master-tempo / key lock
4. Beat loops (1/2/4/8/16 beats) and loop roll
5. Track library screen (folders, search, sort by BPM / key / title) - like the browser list in VirtualDJ
6. Save cues / hot cues / loops per track (local DB)
7. 3-band EQ (hi / mid / low) + kill switches per channel (Android equalizer or custom DSP)
8. Filter knob (HPF / LPF sweep) per channel
9. Level meters per channel and master
10. Cue-to-headphones (needs split output: phone speaker/BT = master, wired headphones = cue)

## Researched pro-player features (backlog)
**Transport:** play/pause, CUE, cue-preview (hold CUE), previous/next track, search (fast scan), jog modes (vinyl / CDJ), slip mode, reverse, brake/start effect on stop/play.
**Cue & loop:** main cue, hot cues (8), memory cues, loop in/out, auto beat loop, loop halve/double, loop move, saved loops, quantize (snap to beat grid).
**Tempo:** pitch fader with range switch (6 / 10 / 16 / wide), master tempo (key lock), tempo reset, BPM tap, sync + quantize.
**Mixer:** channel gain/trim, 3-4 band EQ, filter, channel fader curve, crossfader curve + reverse (hamster), master + booth level, headphone mix/level, auto-mix / auto-fade.
**FX:** echo, reverb, flanger, phaser, gate, roll, brake, spinback, FX wet/dry, beat-synced FX.
**Pads / sampler:** hot cue, roll, slicer, sampler slots, scratch pad.
**Library:** folders, playlists, history, key (Camelot) + BPM display, compatible-song suggestions, search, ratings, colour tags.
**Display:** zoomed + overview waveform, colour-coded frequency waveform, beat grid, key display, remaining/elapsed toggle, album art on the jog.
**Extras:** record the mix to a file, MIDI / USB controller input, video decks (VirtualDJ-style), Ableton Link-style sync, cloud/streaming sources, themes (white default, dark later).

## UX notes (landscape phone)
- Keep all controls inside SafeArea: the notch / punch-hole, rounded corners and the bottom gesture bar are danger zones.
- Immersive mode hides status + nav bar; swipe from the edge to peek them.
- Prefer **hold -> menu** over swipe gestures (decision from the owner). Swipes only where it is natural: jog drag, faders, waveform scrub.
- Minimum touch target about 44 dp for anything used while performing.
- Android only has one audio output route by default, so true headphone cueing is a stretch goal.
