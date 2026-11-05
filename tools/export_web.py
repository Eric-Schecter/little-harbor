#!/usr/bin/env python3
"""Export the game, copy launch-page assets, and create the distributable ZIP."""
from pathlib import Path
import hashlib
import shutil
import sys
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/web'
if OUT.exists():
    shutil.rmtree(OUT)
OUT.mkdir(parents=True)
if not (ROOT / '.export_templates/web_nothreads_release.zip').exists():
    subprocess.run([sys.executable, str(ROOT / 'tools/fetch_web_template.py')], cwd=ROOT, check=True)
subprocess.run(['godot', '--headless', '--path', str(ROOT), '--editor', '--import', '--quit'], check=True)
subprocess.run(['godot', '--headless', '--path', str(ROOT), '--export-release', 'Web', str(OUT / 'index.html')], check=True)
# Version the game pack so browser/CDN caches cannot keep an older game.
pack = OUT / 'index.pck'
versioned_pack = 'game-' + hashlib.sha256(pack.read_bytes()).hexdigest()[:16] + '.pck'
pack.rename(OUT / versioned_pack)
page = OUT / 'index.html'
page.write_text(page.read_text().replace('config.canvas=canvas;', f'config.mainPack={versioned_pack!r};config.canvas=canvas;'))
shutil.copy2(ROOT / 'assets/favicon.svg', OUT / 'favicon.svg')
(OUT / '.nojekyll').touch()
shutil.copy2(ROOT / 'assets/harbor/cover-v1.png', OUT / 'cover.png')
for name in ('README.txt', 'THIRD_PARTY.txt'):
    shutil.copy2(ROOT / 'tools/web' / name, OUT / name)
(OUT / 'licenses').mkdir(exist_ok=True)
for source in (ROOT / 'assets/fonts').glob('*LICENSE.txt'):
    shutil.copy2(source, OUT / 'licenses' / source.name)
archive = ROOT / 'build/little-harbor-web.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    for source in sorted(OUT.rglob('*')):
        if source.is_file():
            package.write(source, source.relative_to(OUT))
print(f'Web build: {OUT}\nPackage: {archive}')
