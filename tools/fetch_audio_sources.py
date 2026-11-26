"""Download the GDD's openly licensed audio into an ignored source cache; never execute downloads."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urljoin, urlparse
import json
import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[1] / '.tmp/audio-refresh'
ROOT.mkdir(parents=True, exist_ok=True)
CACHE = ROOT / 'sources'
CACHE.mkdir(exist_ok=True)
SOURCES = {
    'rpg': ('https://kenney.nl/assets/rpg-audio', '.zip'),
    'impact': ('https://kenney.nl/assets/impact-sounds', '.zip'),
    'interface': ('https://kenney.nl/assets/interface-sounds', '.zip'),
    'scifi': ('https://kenney.nl/assets/sci-fi-sounds', '.zip'),
    'menu': ('https://opengameart.org/content/post-apocalypse-more-music-inside', 'vault.mp3'),
    'day': ('https://opengameart.org/content/ambience-of-a-fallen-age', 'ruins_of_an_ancient_culture_.wav'),
    'night_early': ('https://opengameart.org/content/ruok-apocalyptic-loopstracks', 'loop_g.wav'),
    'night_late': ('https://opengameart.org/content/ruok-apocalyptic-loopstracks', 'loop_d.wav'),
    'boss': ('https://opengameart.org/content/colossal-boss-battle-theme', '.zip'),
    'final': ('https://opengameart.org/content/determined-pursuit-epic-orchestra-loop', '.mp3'),
    'loss': ('https://opengameart.org/content/bittersweet', 'bittersweet.mp3'),
}

def fetch(entry):
    key, (page, pattern) = entry
    session = requests.Session()
    session.headers['User-Agent'] = 'HoldTilDawn-AudioImport/1.0'
    html_file = CACHE / (key + '.html')
    if not html_file.exists():
        response = session.get(page, timeout=45)
        response.raise_for_status()
        html_file.write_text(response.text, encoding='utf-8')
    soup = BeautifulSoup(html_file.read_text(encoding='utf-8'), 'html.parser')
    links = [urljoin(page, a['href']) for a in soup.select('a[href]')
             if pattern in a['href'].lower() or pattern in a.get_text().lower()]
    if 'kenney.nl' in page:
        token = soup.select_one('[data-download-id]')['data-download-id']
        response = session.get('https://kenney.nl/download-link/' + token, headers={'Referer': page}, timeout=45)
        response.raise_for_status()
        links = [response.json()['url']]
    if not links and key == 'final':
        links = [urljoin(page, a['href']) for a in soup.select('a[href]')
                 if any(ext in a['href'].lower() for ext in ['.ogg', '.wav', '.zip'])]
    if not links:
        raise RuntimeError(f'No {pattern} file on {page}')
    url = links[0]
    if urlparse(url).hostname not in ('kenney.nl', 'www.kenney.nl', 'opengameart.org', 'www.opengameart.org'):
        raise RuntimeError(f'Unexpected asset host: {url}')
    suffix = '.zip' if 'kenney.nl' in page else Path(urlparse(url).path).suffix
    target = CACHE / (key + suffix)
    if not target.exists():
        with session.get(url, timeout=(20, 120), stream=True) as response:
            response.raise_for_status()
            with target.with_suffix(suffix + '.part').open('wb') as out:
                for chunk in response.iter_content(1024 * 1024):
                    out.write(chunk)
        target.with_suffix(suffix + '.part').replace(target)
    print(f'OK {key}: {target.stat().st_size / 1048576:.1f} MiB', flush=True)
    return key, {'page': page, 'url': url, 'file': str(target)}

if __name__ == '__main__':
    results = {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {key: pool.submit(fetch, (key, spec)) for key, spec in SOURCES.items()}
        for key, future in futures.items():
            try:
                name, result = future.result()
                results[name] = result
            except Exception as exc:
                print(f'UNAVAILABLE {key}: {exc}', flush=True)
    (ROOT / 'downloads.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    if len(results) != len(SOURCES):
        raise SystemExit('Some required sources are missing; fix the reported download and retry before building.')
