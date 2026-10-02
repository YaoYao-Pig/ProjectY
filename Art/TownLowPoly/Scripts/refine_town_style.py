"""Incremental authored architecture; run named steps through Blender MCP.

Retains existing door/cutaway geometry and exports to existing FBX paths. New farm
pieces use the ordinary town-dressing contract, without new interaction rules.
"""
import bpy
import json
import math
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'Art/TownStylized'
H = runpy.run_path(str(ROOT / 'Art/MapLowPoly/Scripts/mesh_helpers.py'))
Mesh = H['MeshBuilder']
H['PALETTE'].update(InteriorBrick='896455', InteriorSlate='485b67', InteriorWood='806951',
                    InteriorLinen='cdbd98', InteriorGlow='cb803d', HarvestGold='b7a16a', HarvestShade='938154')
for key, color in json.loads((ROOT / 'Art/TownInteriorLowPoly/Integration/palette.json').read_text(encoding='utf-8')).items():
    H['PALETTE'][key.removeprefix('M_MapLP_')] = color.lstrip('#')


def cylinder(m, x, y, z, radius, height, key, sides=10, top=None):
    top = radius if top is None else top
    verts = [(x + r * math.cos(i * math.tau / sides), y + r * math.sin(i * math.tau / sides), h)
             for h, r in [(z, radius), (z + height, top)] for i in range(sides)]
    faces = [tuple(reversed(range(sides))), tuple(range(sides, sides * 2))]
    faces += [(i, (i + 1) % sides, (i + 1) % sides + sides, i + sides) for i in range(sides)]
    m.part(verts, faces, key)


def seed(obj):
    m = Mesh()
    keys = [mat.name.split('.')[0].removeprefix('M_MapLP_') for mat in obj.data.materials]
    m.part([tuple(v.co) for v in obj.data.vertices], [tuple(p.vertices) for p in obj.data.polygons],
           [keys[p.material_index] for p in obj.data.polygons])
    return m


def replace(obj, m):
    assert obj.get('style_revision') != 'ink_town_1', 'Already refined: ' + obj.name
    temp = m.finish(obj.name + '_DetailBuild', obj.users_collection[0])
    old = obj.data; obj.data = temp.data
    bpy.data.objects.remove(temp, do_unlink=True)
    if old.users == 0:
        bpy.data.meshes.remove(old)
    obj['style_revision'] = 'ink_town_1'


def roof_detail(m, cx, hx, hy, eave, peak, roof='RoofShade'):
    # Broad roof courses, ridge caps and verge beams remain readable after pixelation.
    for side in [-1, 1]:
        m.beam((cx + side * hx, -hy - .015, eave), (cx, -hy - .015, peak), .13, .13, 'Timber')
        for t in [.22, .45, .68]:
            m.box((cx + side * hx * (1 - t), 0, eave + (peak - eave) * t + .025),
                  (.10, hy * 2, .065), roof)
    m.box((cx, 0, peak + .025), (.17, hy * 2 + .03, .12), roof)


def refine_walktown():
    scene = bpy.data.scenes['WalkTown_Source']; bpy.context.window.scene = scene
    heights = {'Tavern': 6.35, 'Guild': 6.75, 'Forge': 3.2, 'Shop': 3.2}
    for kind, height in heights.items():
        obj = bpy.data.objects['WalkTown_' + kind + '_Cover']; m = seed(obj)
        if obj.get('style_revision') == 'ink_town_1': continue
        front = -3.76
        for x in [-6.95, -4.85, 2.95, 5.75]:
            m.beam((x, front, 1.18), (x + .75, front, 2.03), .12, .10)
        for x in [-7.75, 7.75]:
            for y in [-2.65, 0, 2.65]:
                m.box((x, y, 2.13), (.19, .17, 2.16), 'Timber')
            m.box((x, 0, 3.10), (.22, 7.17, .17), 'TimberLight')
        if height > 4:
            for x in [-7.65, -4.65, -1.65, 1.65, 4.65]:
                m.beam((x, front, 3.36), (x + 1.10, front, 4.01), .13, .10)
            m.box((0, front, 3.34), (15.73, .22, .18), 'TimberLight')
        roof = 'InteriorSlate' if kind in ['Forge', 'Guild'] else 'RoofShade'
        eave, peak = (3.42, 5.15) if kind == 'Forge' else (3.44, 5.38) if kind == 'Shop' else (height + .22, height + 2.15)
        roof_detail(m, 0, 7.97, 3.83, eave, peak, roof)
        # Chimney caps and stone corner quoins, contained inside the original lot envelope.
        for x in [-7.7, 7.7]:
            for z in [1.25, 1.65, 2.05, 2.45, 2.85]:
                m.box((x, -3.65, z), (.28, .24, .17), 'Stone')
        if kind == 'Forge':
            for z in [3.5, 4.3, 5.1, 5.9, 6.7]:
                m.box((4.5, .61, z), (1.37, .11, .12), 'Stone')
        replace(obj, m)
    for variant, heights in [('A', [3.15, 6.25, 3.3]), ('B', [6.4, 3.25, 6.1]), ('C', [3.2, 6.6, 6.2])]:
        obj = bpy.data.objects['WalkTown_Row' + variant]; m = seed(obj)
        if obj.get('style_revision') == 'ink_town_1': continue
        left = -5.6
        for i, (width, height) in enumerate(zip([3.6, 4.0, 3.6], heights)):
            cx = left + width / 2; depth = 5.25 + (i % 2) * .25; y = -depth / 2 - .17
            m.beam((cx - width / 2 + .2, y, 2.42), (cx - .27, y, 3.00), .105, .095)
            m.beam((cx + width / 2 - .2, y, 2.42), (cx + .27, y, 3.00), .105, .095)
            if height > 4:
                for side in [-1, 1]:
                    m.beam((cx + side * (width / 2 - .18), y, 3.32), (cx + side * .33, y, 3.95), .115, .10)
                    # Window shutters frame the opening without filling it with dense lines.
                    for dx in [-.56, .56]:
                        m.box((cx + side * width * .24 + dx, y - .035, 4.70), (.19, .075, 1.12), 'TimberLight')
            roof_detail(m, cx, width / 2 + .10, depth / 2 + .16, height + .12, height + 1.55,
                        'InteriorSlate' if (i + ord(variant)) % 3 == 0 else 'RoofShade')
            m.box((cx + width * .27, .9, height + 1.30), (.58, .61, .13), 'Stone')
            left += width
        replace(obj, m)
    print(json.dumps({'refined': 7, 'doorAndInteriorGeometryUnchanged': True}))


def refine_castle():
    scene = bpy.data.scenes['MapLP_CastleStudio']; bpy.context.window.scene = scene
    obj = bpy.data.objects['Building_Castle']; m = seed(obj)
    # Follow the exact seven-hex platform boundary, including its concave corners.
    edges = {}
    for q, r in [(0,0),(1,0),(0,1),(-1,1),(-1,0),(0,-1),(1,-1)]:
        cx, cy = math.sqrt(3) * (q + r / 2), 1.5 * r
        ring = [(round(cx + math.cos(math.pi / 6 + i * math.pi / 3), 6),
                 round(cy + math.sin(math.pi / 6 + i * math.pi / 3), 6)) for i in range(6)]
        for i in range(6):
            key = tuple(sorted((ring[i], ring[(i + 1) % 6])))
            edges[key] = edges.get(key, 0) + 1
    for (a, b), count in edges.items():
        if count != 1: continue
        for inner, outer, low, high, key in [(.60,.96,.035,.08,'WaterDeep'),(.96,.99,0,.14,'Stone')]:
            polygon = [(a[0]*inner,a[1]*inner),(b[0]*inner,b[1]*inner),(b[0]*outer,b[1]*outer),(a[0]*outer,a[1]*outer)]
            verts = [(x,y,z) for z in [low,high] for x,y in polygon]
            m.part(verts, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)], key)
    # Bridge planks, chains and gate braces use the existing closed decorative gate.
    for i in range(8):
        m.box((0, -1.46 - i * .065, .205), (.67, .059, .06), 'TimberLight')
    for side in [-1, 1]:
        m.beam((side * .33, -1.93, .22), (side * .34, -1.36, .75), .018, .018, 'RockDark')
    for x in [-1.23, 1.23]:
        cylinder(m, x, 1.15, 2.57, .40, .065, 'Timber', 8)
        cylinder(m, x, 1.15, 2.635, .43, .69, 'RoofShade', 8, .012)
        cylinder(m, x, 1.15, 3.32, .025, .09, 'TimberLight', 6)
        for z in [.53, .84, 1.15]:
            m.box((x, -.337 - 1.15, z), (.08, .012, .16), 'Window')
    roof_start = len(m.vertices)
    roof_detail(m, 0, .81, .79, 2.39, 3.25)
    m.vertices[roof_start:] = [(x, y + .25, z) for x, y, z in m.vertices[roof_start:]]
    replace(obj, m)
    print(json.dumps({'castleBounds': list(obj.dimensions), 'footprintRadius': 1}))


def farm_scene():
    assert 'TownFarm_Studio' not in bpy.data.scenes, 'Farm source already exists; inspect rather than recreate.'
    s = bpy.data.scenes.new('TownFarm_Studio'); s.unit_settings.system = 'METRIC'; s.unit_settings.scale_length = 1
    c = bpy.data.collections.new('TownFarm_Masters'); s.collection.children.link(c)
    bpy.context.window.scene = s
    return s, c


def create_farm():
    scene, collection = farm_scene()
    m = Mesh()
    cylinder(m, 0, 0, 0, 1.43, .32, 'Stone', 10)
    cylinder(m, 0, 0, .32, 1.34, 1.1, 'Stone', 10, 1.24)
    cylinder(m, 0, 0, 1.42, 1.24, 3.50, 'Plaster', 10, .88)
    for z, radius in [(1.43, 1.27), (3.28, 1.06), (4.90, .96)]:
        cylinder(m, 0, 0, z, radius, .13, 'TimberLight', 10)
    cylinder(m, 0, 0, 5.03, 1.18, 1.23, 'RoofShade', 10, .035)
    m.box((0, -1.29, 1.15), (.78, .06, 1.73), 'Timber')
    for x in [-.45, .45]: m.box((x, -1.33, 1.15), (.12, .15, 1.86), 'Stone')
    m.box((0, -1.33, 2.13), (1.03, .15, .14), 'Stone')
    for z in [2.72, 4.02]: m.box((0, -1.06 if z < 3 else -.97, z), (.38, .05, .52), 'Window')
    for i in range(4):
        a = math.pi / 9 + i * math.pi / 2
        u = (math.sin(a), math.cos(a)); v = (math.cos(a), -math.sin(a))
        def pt(r, offset=0, y=-1.48): return (u[0] * r + v[0] * offset, y, 4.55 + u[1] * r + v[1] * offset)
        m.beam(pt(.16), pt(2.77), .10, .15, 'Timber')
        start = len(m.vertices)
        # Sail fabric as a thick closed tapered panel, framed by four broad spars.
        front = [pt(.87, .03, -1.56), pt(2.69, .03, -1.56), pt(2.69, .61, -1.56), pt(.87, .38, -1.56)]
        back = [(x, y + .05, z) for x, y, z in front]
        m.part(front + back, [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)], 'InteriorLinen')
        for r in [1.0, 1.5, 2.0, 2.5]: m.beam(pt(r, -.04, -1.60), pt(r, .56, -1.60), .045, .06, 'TimberLight')
    m.box((0, -1.59, 4.55), (.40, .34, .40), 'TimberLight')
    m.vertices = [(x * .98, y, z) for x, y, z in m.vertices]
    m.finish('Town_Windmill', collection)

    m = Mesh()
    m.box((0, 0, .13), (4.74, 3.35, .26), 'Stone')
    m.box((0, 0, 1.64), (4.55, 3.12, 3.08), 'TimberLight')
    for x in [-2.23, -1.15, 0, 1.15, 2.23]:
        m.box((x, -1.61, 1.60), (.12, .13, 2.98), 'Timber')
    for z in [.37, 2.55, 3.1]: m.box((0, -1.62, z), (4.62, .15, .14), 'Timber')
    m.box((0, -1.71, 1.29), (1.74, .09, 2.28), 'Timber')
    for side in [-1, 1]:
        m.beam((side * .80, -1.79, .25), (0, -1.79, 2.32), .12, .10, 'TimberLight')
        m.box((side * 1.71, -1.67, 2.06), (.44, .07, .56), 'Window')
    m.ridge_roof(2.48, 1.84, 3.25, 4.51)
    roof_detail(m, 0, 2.48, 1.84, 3.25, 4.51)
    for side in [-1, 1]:
        cylinder(m, side * 1.78, -1.72, .1, .39, .54, 'HarvestGold', 8, .33)
        m.box((side * 1.78, -1.72, .33), (.81, .055, .06), 'HarvestShade')
    m.box((0, -1.89, 3.55), (.47, .08, .43), 'Window')
    m.finish('Town_Granary', collection)

    m = Mesh()
    m.box((0, 0, .055), (6.15, 1.70, .11), 'Earth')
    for row in range(4):
        y = -.56 + row * .36
        m.box((0, y, .13), (5.9, .16, .12), 'Timber')
        for col in range(19):
            x = -2.82 + col * .31; h = .59 + ((row * 7 + col * 3) % 5) * .04
            m.beam((x, y, .17), (x + .055, y, h), .025, .025, 'HarvestShade')
            cylinder(m, x + .055, y, h - .02, .055, .15, 'HarvestGold', 4, .009)
    for y in [-.88, .88]:
        for x in [-3.0, -1.5, 0, 1.5, 3.0]: m.box((x, y, .50), (.07, .07, .94), 'Timber')
        for z in [.36, .73]: m.box((0, y, z), (6.09, .06, .07), 'TimberLight')
    m.box((2.0, 0, .83), (.055, .055, 1.66), 'Timber')
    m.box((2.0, 0, 1.35), (.83, .055, .065), 'Timber')
    m.box((2.0, -.015, 1.20), (.41, .17, .49), 'RoofShade')
    cylinder(m, 2.0, -.015, 1.45, .16, .25, 'HarvestGold', 8, .14)
    cylinder(m, 2.0, -.015, 1.67, .26, .055, 'HarvestShade', 8)
    cylinder(m, 2.0, -.015, 1.72, .15, .18, 'HarvestShade', 8, .11)
    # Three inline hexes have shallow inward corners between cells; keep the fences inside them.
    m.vertices = [(x, y * .78, z) for x, y, z in m.vertices]
    m.finish('Town_WheatGarden', collection)
    print(json.dumps({'created': ['Town_Windmill', 'Town_Granary', 'Town_WheatGarden']}))


def save_export():
    for folder in ['Source', 'Staging', 'Integration', 'Previews']:
        (OUT / folder).mkdir(parents=True, exist_ok=True)
    scenes = {'WalkTown_Source': 'WalkableTownRefined.blend', 'MapLP_CastleStudio': 'CastleRefined.blend', 'TownFarm_Studio': 'TownFarm.blend'}
    exporter = runpy.run_path(str(ROOT / 'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
    report = []
    for scene_name, filename in scenes.items():
        s = bpy.data.scenes[scene_name]; bpy.context.window.scene = s
        bpy.data.libraries.write(str(OUT / 'Source' / filename), {s}, fake_user=True, compress=True)
        for obj in s.objects:
            if not (obj.get('style_revision') == 'ink_town_1' or obj.name.startswith('Town_Windmill') or obj.name.startswith('Town_Granary') or obj.name.startswith('Town_WheatGarden')):
                continue
            # Use canonical material names when a second source scene loaded duplicates.
            for slot in obj.material_slots:
                canonical = slot.material.name.split('.')[0]
                slot.material = bpy.data.materials[canonical]
            result = exporter(obj.name, str(OUT / 'Staging' / (obj.name + '.fbx')), overwrite=True)
            obj.data.calc_loop_triangles()
            report.append({'name': obj.name, 'dimensions': list(obj.dimensions), 'triangles': len(obj.data.loop_triangles),
                           'bytes': result['bytes'], 'materials': [mat.name for mat in obj.data.materials]})
    (OUT / 'Integration/models.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    palette = {m.name: m.get('palette_srgb') for m in bpy.data.materials if m.name.startswith('M_MapLP_') and '.' not in m.name and m.get('palette_srgb')}
    (OUT / 'Integration/palette.json').write_text(json.dumps(palette, indent=2), encoding='utf-8')
    print(json.dumps(report))
