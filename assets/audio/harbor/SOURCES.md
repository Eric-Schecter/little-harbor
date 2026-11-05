# Harbor audio

- ballista.wav, catapult.wav, firepot.wav, hull_hit.wav: generated locally by tools/audio/build_harbor_audio.py. Damped wood resonances, plucked string and short release layers. No gunshot samples.
- water-source.mp3: existing project asset copied from a related nautical prototype (sloop-bow-water-10s-v2.mp3), originally generated using ElevenLabs for that project.
- sailing_loop.wav: 1.2–8.8s of that source, 350ms crossfade seam, mono 44.1kHz. Fixed pitch; one capped shared layer driven by visible moving ships.
- water_hit.wav: 4.60–5.25s of the same source, short fade-in and 180ms fade-out.

Dedicated harbor bus has a limiter. Sixteen independent voice players preserve simultaneous tower shots. Weapon sounds fire when projectiles launch; hull/water impacts fire at delayed damage resolution. Movement ends fade out the loop; menu, pause, workshop, mute, defeat and restart stop the harbor mix.

Actual game recording: captures/harbor-audio-preview.wav. Run `godot --path . --always-on-top -- --audio-preview` to reproduce. Audio lifecycle checks: `godot --headless --path . -- --audio-test`.

## Weapon foley v2 — 2026-11-04

Crossbow release/arrow embedding and catapult release/stone-on-hull impacts now use ElevenLabs-generated foley in `foley-v2/`, replacing the original synthesized ballista/catapult playback paths. Four one-shot source files, prompts and one-attempt generation ledger are stored there. `tools/audio/prepare_weapon_foley.py` removes leading silence, trims to 0.38/0.43/0.57/0.72 seconds, fades edges and normalizes peaks to -2.16dBFS. Precise edits are in `foley-v2/edits.json`.

Damage events carry the firing tower level. Arrow and stone impacts have separate 35ms overlap guards, so simultaneous different weapon hits remain audible. A killing blow still plays its weapon impact, with quieter water layered underneath. Launch sounds sit behind the impacts in the mix. Three subtle fixed playback variations (0.98/1/1.02 pitch) reduce mechanical repetition; the sailing loop stays fixed-pitch.

## Enemy ship cannons

Ship cannon and UI sounds are original local synthesis from `tools/audio/build_original_ui_audio.py`, stored under `ui/`. No reference-game audio remains in the project.

## Specialty foley

Twelve new isolated clips were generated with ElevenLabs `eleven_text_to_sound_v2`: rapid/heavy crossbows, scatter/siege stones, firepots and oil jars, each with distinct launch and impact. Prompts and one-attempt generation ledger: `specialties-v1/generation.json`; onset trimming, fade and normalization: `specialties-v1/edits.json`. Reproduction scripts: `tools/audio/generate_specialty_foley.mjs` and `tools/audio/prepare_specialty_foley.py`. These replace generic weapon sounds for specialized towers; base arrow and stone towers retain their previous natural foley. A volley plays one release cue, and per-specialty impact guards prevent stacked hits from overwhelming the mix.
