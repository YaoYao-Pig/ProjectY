"""Validate the actual Blender meshes against all authored floor/door navigation edges."""
import json, math
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path('D:/Program/Unity/Project Y')
OUT = ROOT / 'Art/TownOpenBuildings'
models = {row['name']: row for row in json.loads((OUT / 'Integration/models.json').read_text(encoding='utf-8'))}
assets = {row['id']: row for row in json.loads((ROOT / 'Config/Tables/Map/MapAssetTable.json').read_text(encoding='utf-8'))['rows']}
lots = {row['id']: row for row in json.loads((ROOT / 'Config/Tables/MapArea/MapAreaTownLotTable.json').read_text(encoding='utf-8'))['rows']}
interiors = json.loads((ROOT / 'Config/Tables/MapArea/MapAreaTownInteriorTable.json').read_text(encoding='utf-8'))['rows']
directions = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]
report = []
def position(cell):
    q, r = cell
    return Vector((math.sqrt(3) * 1.5 * (q + r / 2), 0, 2.25 * r))
for row in interiors:
    if row['id'] not in [14, 15, 16, 18, 19, 31, 32]:
        continue
    lot = lots[row['id']]
    cells = set(zip(row['interiorQ'], row['interiorR']))
    edges = set()
    for cell in cells:
        for dq, dr in directions:
            other = (cell[0] + dq, cell[1] + dr)
            if other in cells:
                edges.add(tuple(sorted((cell, other))))
    for q, r, iq, ir in zip(row['doorQ'], row['doorR'], row['doorInsideQ'], row['doorInsideR']):
        edges.add(tuple(sorted(((q, r), (iq, ir)))))
    trees = []
    for aid in [lot['assetId'], row['coverAssetId']]:
        name = Path(assets[aid]['prefabPath']).stem
        mesh = bpy.data.objects[models[name]['object']].data
        scale = lot['scale']
        trees.append((name, BVHTree.FromPolygons([(-v.co.x * scale, v.co.z * scale, -v.co.y * scale) for v in mesh.vertices], [list(p.vertices) for p in mesh.polygons])))
    failures = []; checked = 0
    for a, b in sorted(edges):
        start, end = position(a), position(b)
        forward = (end - start).normalized(); side = Vector((-forward.z, 0, forward.x))
        for height in [.18, 1.0, 1.78]:
            for offset in [-.69, 0, .69]:
                origin = start + side * offset + Vector((0, height, 0)); checked += 1
                for name, tree in trees:
                    hit = tree.ray_cast(origin, forward, (end - start).length)
                    if hit[0] is not None:
                        failures.append(dict(model=name, edge=[list(a), list(b)], height=height, offset=offset, hit=list(hit[0])))
    report.append(dict(lotId=lot['id'], name=lot['name'], edges=len(edges), rays=checked, failures=failures))
(OUT / 'Integration/geometry-check.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps([dict(lotId=r['lotId'], rays=r['rays'], failures=len(r['failures']), first=r['failures'][:2]) for r in report], ensure_ascii=False))
assert len(report) == 7 and all(not row['failures'] for row in report), 'Building geometry intersects a character navigation corridor'
