"""One-time addition of three art-only town props; preserve existing recipe settings."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
tables = ROOT / 'Config/Tables'

def load(group, name):
    path = tables / group / (name + '.json')
    return path, json.loads(path.read_text(encoding='utf-8-sig'))

asset_path, assets = load('Map', 'MapAssetTable')
prop_path, props = load('MapArea', 'MapAreaPropTable')
pool_path, pools = load('MapArea', 'MapAreaTownDressingTable')
assert not {113, 114, 115} & {row['id'] for row in assets['rows']}, 'New asset IDs already used'
assert not {41, 42, 43} & {row['id'] for row in props['rows']}, 'New prop IDs already used'
seven = [(0, 0), (1, 0), (0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1)]
specs = [('Town_Windmill', '乡村风车磨坊', 7.17005, '#c9b994', seven),
         ('Town_Granary', '木构谷仓与草捆', 4.595, '#8c7558', seven),
         ('Town_WheatGarden', '围栏麦田与稻草人', 1.9, '#b7a16a', [(-1, 0), (0, 0), (1, 0)])]
kit = []
for i, (name, label, height, color, footprint) in enumerate(specs):
    aid, pid = 113 + i, 41 + i
    assets['rows'].append(dict(id=aid, name=label, prefabPath='Assets/DynamicAsset/TownStylized/Models/' + name + '.fbx',
                               previewShape='workshop' if i == 0 else 'house' if i == 1 else 'rock',
                               previewColor=color, referenceHeight=height, footprintRadius=1 if i < 2 else 0, tintMaterial=''))
    props['rows'].append(dict(id=pid, name=label, assetId=aid, blocksSight=i < 2, scale=1, scaleMode='meters',
                              footprintQ=[p[0] for p in footprint], footprintR=[p[1] for p in footprint], placement='island'))
    kit.append(dict(name=name, assetId=aid, propId=pid, footprint=footprint))
for row in pools['rows']:
    if row['id'] in (1, 2):
        row['propIds'] = [41, 42, 43] + row['propIds']
assets['rows'].sort(key=lambda row: row['id'])
for path, data in [(asset_path, assets), (prop_path, props), (pool_path, pools)]:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
(ROOT / 'Art/TownStylized/Integration/kit.json').write_text(json.dumps(kit, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Added 3 town art props to existing town/village dressing pools; count and path rules preserved.')
