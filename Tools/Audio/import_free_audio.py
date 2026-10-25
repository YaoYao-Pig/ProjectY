"""Import the selected CC0 starter audio; retain source hashes and license evidence."""
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'Assets/GameFramework/Resources/Audio'
PROVENANCE = ROOT / 'Art/Audio'
SOURCES = [
    dict(id='exploration', author='RandomMind', title='Medieval: The Old Tower Inn',
         page='https://opengameart.org/content/medieval-the-old-tower-inn',
         url='https://opengameart.org/sites/default/files/Loop_The_Old_Tower_Inn.wav',
         file='Music/old_tower_inn_loop.wav'),
    dict(id='battle', author='Emma_MA', title='Determined Pursuit (epic orchestra loop)',
         page='https://opengameart.org/content/determined-pursuit-epic-orchestra-loop',
         url='https://opengameart.org/sites/default/files/determined_pursuit_loop.wav',
         file='Music/determined_pursuit_loop.wav'),
    dict(id='impact', author='Kenney', title='Impact Sounds',
         page='https://kenney.nl/assets/impact-sounds',
         url='https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip'),
]
VARIANTS = {
    'hit': ['impactMetal_medium_001', 'impactMetal_medium_002', 'impactMetal_medium_004'],
    'hurt': ['impactSoft_medium_000', 'impactSoft_medium_002', 'impactSoft_medium_003'],
}


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'ProjectY-AudioImport/1.0'})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_bytes() != data:
        raise RuntimeError(f'Refusing to overwrite changed asset: {path}')
    path.write_bytes(data)
    return hashlib.sha256(data).hexdigest()


def main():
    PROVENANCE.mkdir(parents=True, exist_ok=True)
    records = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        payloads = list(pool.map(fetch, [source['url'] for source in SOURCES]))
    for source, data in zip(SOURCES, payloads):
        record = dict(source, license='CC0-1.0', licenseUrl='https://creativecommons.org/publicdomain/zero/1.0/',
                      retrieved='2026-10-25', downloadSha256=hashlib.sha256(data).hexdigest(), files=[])
        if source['id'] == 'impact':
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                license_text = archive.read('License.txt')
                assert b'CC0' in license_text, 'Kenney archive does not declare CC0'
                save(PROVENANCE / 'Kenney-Impact-License.txt', license_text)
                for cue, names in VARIANTS.items():
                    for name in names:
                        path = 'Effects/' + name + '.ogg'
                        content = archive.read('Audio/' + name + '.ogg')
                        digest = save(ASSETS / path, content)
                        record['files'].append(dict(path=path, cue=cue, sha256=digest))
        else:
            assert data[:4] == b'RIFF' and data[8:12] == b'WAVE', 'Expected a WAV source'
            digest = save(ASSETS / source['file'], data)
            record['files'].append(dict(path=source['file'], cue=source['id'], sha256=digest))
        records.append(record)
    catalog = dict(crossFadeSeconds=1.25,
                   music=[dict(cue='exploration', clip='Audio/Music/old_tower_inn_loop', gain=0.8),
                          dict(cue='battle', clip='Audio/Music/determined_pursuit_loop', gain=0.58)],
                   effects=[dict(cue=cue, clips=['Audio/Effects/' + name for name in names],
                                 gain=0.6 if cue == 'hit' else 0.42, cooldownSeconds=0.055,
                                 maxConcurrent=4, pitchMin=0.96, pitchMax=1.04)
                            for cue, names in VARIANTS.items()])
    save(ASSETS / 'catalog.json', (json.dumps(catalog, indent=2) + '\n').encode())
    save(PROVENANCE / 'sources.json', (json.dumps(records, indent=2) + '\n').encode())
    for record in records:
        print(f"{record['id']}: {len(record['files'])} file(s), CC0-1.0")


if __name__ == '__main__':
    main()
