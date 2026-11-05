# Development

- `scripts/`: runtime gameplay, harbor rendering, upgrades and audio.
- `assets/`: current art, fonts, audio and source credits.
- `tests/`: gameplay regressions and recording scripts.
- `tools/audio/`: optional music/foley production tools; Python, Node.js and FFmpeg as needed. ElevenLabs tools read `ELEVENLABS_API_KEY` from the environment.
- `tools/web/`: packaged instructions and credits.
- `tools/export_web.py`: fetches the official Web template if absent, imports, exports, and packages the build.
- `.github/workflows/pages.yml`: imports, tests, exports and deploys on pushes to `main`.

Generated `build/`, `.godot/`, captures, local templates and archived experiments are ignored.

## Run checks

```sh
godot --headless --editor --import --quit
godot --headless -- --upgrade-test
godot --headless --script tests/pause_menu.gd
```

## Preview Web

```sh
python3 tools/export_web.py
python3 tools/serve_web.py 8795
```

Open http://localhost:8795. Click the cover to start. Web pause offers resume/restart; desktop also offers quit.
