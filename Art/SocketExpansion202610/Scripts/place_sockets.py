"""Place only this expansion's sockets using measured Unity root-local weapon bounds."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOCKETS = ROOT / 'Config/Tables/Equipment/EquipmentSocketTable.json'
WEAPONS = ROOT / 'Config/Tables/Equipment/EquipmentWeaponTable.json'
BOUNDS = ROOT / 'Art/SocketExpansion202610/Integration/weapon-bounds.json'

def load(path):
    return json.loads(path.read_text(encoding='utf-8'))

document = load(SOCKETS)
weapons = {row['id']: row for row in load(WEAPONS)['rows']}
bounds = {row['id']: row for row in load(BOUNDS)}
rows = {row['id']: row for row in document['rows']}
new_ids = set(range(201, 274))
assert new_ids <= rows.keys()
before = {key: dict(row) for key, row in rows.items() if key not in new_ids}
tool_edges = {
    70: [0.30, 0.80, 0.07], 71: [0.30, 0.96, 0.07],
    72: [0.33, 1.11, 0.065], 73: [0.0, 1.24, 0.036], 74: [0.16, 0.65, 0.028],
}
for weapon_id, weapon in weapons.items():
    added = [rows[key] for key in weapon['socketIds'] if key in new_ids]
    if not added:
        continue
    geometry = bounds[weapon_id]
    low, high = geometry['min'], geometry['max']
    sides = {'left': 0, 'right': 0}
    for key in weapon['socketIds']:
        if key not in new_ids:
            sides[rows[key]['calloutSide']] += 1
    for row in added:
        kind = row['kind']
        if kind == 'grip':
            position = [0, low[1] * 0.36, 0.044]
        elif kind == 'pommel':
            position = [0, low[1] + 0.014, 0]
        elif kind == 'muzzle':
            position = [0, 0.18, high[2] - 0.018]
        elif kind == 'stock':
            position = [0.069, 0.11, -0.35]
        elif kind == 'bowlimb':
            position = [0.15, high[1] * 0.69, 0.035]
        elif kind == 'bowstring':
            position = [high[0] - 0.01, low[1] * 0.38, 0.012]
        elif kind == 'edge':
            position = tool_edges.get(weapon_id, [0, high[1] * 0.63, 0.036])
        elif kind == 'rail':
            position = [-0.105, 0.18, 0.12] if weapon['kind'] == 'gun' else [-0.06, 0.23, 0]
        else:
            raise AssertionError(f'Unexpected newly added kind: {kind}')
        row['position'] = [round(value, 6) for value in position]
        row['rotation'] = [0, 0, 0]
        side = min(sides, key=sides.get)
        row['calloutSide'] = side
        sides[side] += 1
    assert max(sides.values()) <= 2, (weapon_id, sides)
assert all(rows[key] == row for key, row in before.items()), 'Existing socket data changed'
SOCKETS.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Placed 73 new sockets on 30 weapons; existing socket data preserved; at most two callouts per side.')
