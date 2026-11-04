import concurrent.futures
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
catalog = root / 'Luma/Assets.xcassets'
manifest = json.loads((root / 'Design/asset-manifest.json').read_text())

def fetch(pair):
    name, item = pair
    folder = catalog / ('Figma' + name[:-4] + '.imageset')
    folder.mkdir(parents=True, exist_ok=True)
    subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location', item['url'], '-o', str(folder / name)], check=True)
    ET.parse(folder / name)
    (folder / 'Contents.json').write_text(json.dumps({
        'images': [{'filename': name, 'idiom': 'universal'}],
        'info': {'author': 'xcode', 'version': 1},
        'properties': {'preserves-vector-representation': True}
    }))
    return name

with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    print('Downloaded', len(list(pool.map(fetch, manifest.items()))), 'Figma assets')

colors = json.loads((root.parent / 'luma-premium/design/tokens.json').read_text())['colors']
colors['AccentColor'] = colors['accent']
for name, value in colors.items():
    folder = catalog / (name + '.colorset')
    folder.mkdir(parents=True, exist_ok=True)
    rgb = {key: str(int(value[i:i+2], 16) / 255) for key, i in [('red', 1), ('green', 3), ('blue', 5)]}
    (folder / 'Contents.json').write_text(json.dumps({
        'colors': [{'idiom': 'universal', 'color': {'color-space': 'srgb', 'components': dict(rgb, alpha='1.000')}}],
        'info': {'author': 'xcode', 'version': 1}
    }))
(catalog / 'Contents.json').write_text('{"info":{"author":"xcode","version":1}}')
