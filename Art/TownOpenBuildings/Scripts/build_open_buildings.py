"""Incrementally open the seven active decorative town buildings in Blender.

This file only defines functions when loaded with runpy.run_path. The caller owns
Blender execution and Unity import. Example, one short modelling unit at a time:

    module = runpy.run_path(PATH)
    module['build'](models=['RowA', 'RowB', 'RowC'])
    module['build'](models=['Gatehouse', 'Pavilion'])
    module['build'](models=['Windmill', 'Granary'])

All authored geometry belongs to a new scene/collection. Existing live objects,
source meshes, materials, selection, active scene, and the current .blend path
are preserved. Re-running a model replaces only this script's owned copies.
"""
import json
import math
import runpy
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'Art/TownOpenBuildings'
SCENE = 'OpenBuildings_Source'
COLLECTION = 'OpenBuildings_Masters'
OWNER = 'ProjectY_OpenBuildings_1'
CUT = 1.05

DEFINITIONS = {
    'RowA': ('WalkTown_RowA', 'Art/TownStylized/Source/WalkableTownRefined.blend'),
    'RowB': ('WalkTown_RowB', 'Art/TownStylized/Source/WalkableTownRefined.blend'),
    'RowC': ('WalkTown_RowC', 'Art/TownStylized/Source/WalkableTownRefined.blend'),
    'Gatehouse': ('Royal_Gatehouse', 'Art/RoyalTownLowPoly/Source/RoyalTown.blend'),
    'Pavilion': ('Royal_Pavilion', 'Art/RoyalTownLowPoly/Source/RoyalTown.blend'),
    'Windmill': ('Town_Windmill', 'Art/TownStylized/Source/TownFarm.blend'),
    'Granary': ('Town_Granary', 'Art/TownStylized/Source/TownFarm.blend'),
}


def _helpers():
    helpers = runpy.run_path(str(ROOT / 'Art/MapLowPoly/Scripts/mesh_helpers.py'))
    for relative in ['Art/TownInteriorLowPoly/Integration/palette.json',
                     'Art/RoyalTownLowPoly/Integration/palette.json',
                     'Art/TownStylized/Integration/palette.json']:
        palette = json.loads((ROOT / relative).read_text(encoding='utf-8-sig'))
        for name, color in palette.items():
            if color:
                helpers['PALETTE'][name.removeprefix('M_MapLP_')] = color.lstrip('#')
    return helpers


def _material_key(material):
    # Library appends may suffix a material name; reuse the established palette.
    return material.name.split('.')[0].removeprefix('M_MapLP_')


def _source(name, relative):
    live = bpy.data.objects.get(name)
    if live is not None:
        assert live.type == 'MESH' and live.get('open_buildings_owner') != OWNER
        return live, False
    path = ROOT / relative
    assert path.is_file(), str(path)
    with bpy.data.libraries.load(str(path), link=False) as (available, requested):
        assert name in available.objects, 'Source object missing: ' + name
        requested.objects = [name]
    obj = requested.objects[0]
    assert obj is not None and obj.type == 'MESH'
    return obj, True


def _parts(obj):
    """Recover source primitive islands without executing an initialization script."""
    mesh = obj.data
    parent = list(range(len(mesh.vertices)))

    def root(index):
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index

    for face in mesh.polygons:
        first = root(face.vertices[0])
        for index in face.vertices[1:]:
            parent[root(index)] = first
    grouped = {}
    for face in mesh.polygons:
        grouped.setdefault(root(face.vertices[0]), []).append(face)
    result = []
    for faces in grouped.values():
        indices = sorted({index for face in faces for index in face.vertices})
        vertices = [tuple(mesh.vertices[index].co) for index in indices]
        remap = {index: i for i, index in enumerate(indices)}
        result.append({
            'vertices': vertices,
            'faces': [tuple(remap[index] for index in face.vertices) for face in faces],
            'materials': [_material_key(mesh.materials[face.material_index]) for face in faces],
            'min': tuple(min(v[axis] for v in vertices) for axis in range(3)),
            'max': tuple(max(v[axis] for v in vertices) for axis in range(3)),
        })
    return result


def _clip(polygon, distance):
    """Retain the positive half-space of a convex polygon."""
    if not polygon:
        return []
    result = []
    previous = polygon[-1]
    before = distance(previous)
    for point in polygon:
        after = distance(point)
        if (before >= -1e-8) != (after >= -1e-8):
            t = before / (before - after)
            result.append(tuple(a + (b - a) * t for a, b in zip(previous, point)))
        if after >= -1e-8:
            result.append(point)
        previous, before = point, after
    # Avoid duplicate vertices when an authored face lies on the clipping plane.
    clean = []
    for point in result:
        if not clean or sum((a - b) ** 2 for a, b in zip(clean[-1], point)) > 1e-14:
            clean.append(point)
    if len(clean) > 1 and sum((a - b) ** 2 for a, b in zip(clean[0], clean[-1])) < 1e-14:
        clean.pop()
    return clean if len(clean) >= 3 else []


def _append(builder, part, *, bottom=None, top=None, transform=None):
    # Keep one connected mesh per authored primitive. Appending every face as a
    # separate island makes MeshBuilder.finish's normal recalculation ambiguous:
    # even a closed source cylinder can acquire inward-facing isolated faces.
    vertices, faces, materials, lookup = [], [], [], {}

    def vertex(point):
        key = tuple(round(value, 8) for value in point)
        if key not in lookup:
            lookup[key] = len(vertices)
            vertices.append(point)
        return lookup[key]

    for face, material in zip(part['faces'], part['materials']):
        polygon = [part['vertices'][index] for index in face]
        if transform:
            polygon = [transform(point) for point in polygon]
        if bottom is not None:
            polygon = _clip(polygon, lambda point: point[2] - bottom)
        if top is not None:
            polygon = _clip(polygon, lambda point: top - point[2])
        if not polygon:
            continue
        indices = []
        for point in polygon:
            index = vertex(point)
            if not indices or indices[-1] != index:
                indices.append(index)
        if len(indices) > 1 and indices[0] == indices[-1]:
            indices.pop()
        # Clipping exactly through a source vertex can leave a zero-area face.
        normal = [0.0, 0.0, 0.0]
        for a, b in zip(polygon, polygon[1:] + polygon[:1]):
            normal[0] += a[1] * b[2] - a[2] * b[1]
            normal[1] += a[2] * b[0] - a[0] * b[2]
            normal[2] += a[0] * b[1] - a[1] * b[0]
        if len(set(indices)) >= 3 and sum(value * value for value in normal) > 1e-16:
            faces.append(tuple(indices))
            materials.append(material)
    if not faces:
        return

    # A plane cut through a closed source primitive leaves boundary loops. Cap
    # each loop on that exact plane; never bridge independent primitives or fill
    # a doorway, which is authored separately as several closed wall prisms.
    for plane, normal_z in [(bottom, -1), (top, 1)]:
        if plane is None:
            continue
        edges = {}
        for face, material in zip(faces, materials):
            for a, b in zip(face, face[1:] + face[:1]):
                key = tuple(sorted((a, b)))
                count, first_material = edges.get(key, (0, material))
                edges[key] = count + 1, first_material
        boundary = {edge: material for edge, (count, material) in edges.items()
                    if count == 1 and all(abs(vertices[index][2] - plane) < 1e-7 for index in edge)}
        if not boundary:
            continue
        adjacency = {}
        for a, b in boundary:
            adjacency.setdefault(a, []).append(b)
            adjacency.setdefault(b, []).append(a)
        assert all(len(neighbors) == 2 for neighbors in adjacency.values()), 'Cut primitive has an open or branched boundary'
        unused = set(boundary)
        while unused:
            first = min(unused)
            start, current = first
            loop, previous = [start], start
            unused.remove(first)
            while current != start:
                loop.append(current)
                following = next(index for index in adjacency[current] if index != previous)
                edge = tuple(sorted((current, following)))
                assert edge in unused, 'Cut primitive boundary revisited before closure'
                unused.remove(edge)
                previous, current = current, following
            signed = sum(vertices[a][0] * vertices[b][1] - vertices[b][0] * vertices[a][1]
                         for a, b in zip(loop, loop[1:] + loop[:1]))
            assert abs(signed) > 1e-10, 'Cut primitive cap has zero area'
            if signed * normal_z < 0:
                loop.reverse()
            faces.append(tuple(loop))
            materials.append(boundary[first])
    builder.part(vertices, faces, materials)


def _extrude(builder, polygon, bottom, top, material):
    if top - bottom < 1e-7 or len(polygon) < 3:
        return
    signed = sum(a[0] * b[1] - b[0] * a[1]
                 for a, b in zip(polygon, polygon[1:] + polygon[:1]))
    if abs(signed) < 1e-8:
        return
    if signed < 0:
        polygon = list(reversed(polygon))
    count = len(polygon)
    vertices = [(x, y, z) for z in (bottom, top) for x, y in polygon]
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    faces.extend((i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count))
    builder.part(vertices, faces, material)


class Split:
    def __init__(self, mesh_type):
        self.core = mesh_type()
        self.cover = mesh_type()

    def solid(self, polygon, bottom, top, material):
        _extrude(self.core, polygon, bottom, min(top, CUT), material)
        _extrude(self.cover, polygon, max(bottom, CUT), top, material)

    def box(self, center, size, material):
        x, y, z = center
        hx, hy, hz = (v / 2 for v in size)
        self.solid([(x - hx, y - hy), (x + hx, y - hy),
                    (x + hx, y + hy), (x - hx, y + hy)], z - hz, z + hz, material)

    def retained(self, part, transform=None):
        _append(self.core, part, top=CUT, transform=transform)
        _append(self.cover, part, bottom=CUT, transform=transform)


def _wall(split, a, b, thickness, height, material, doors=()):
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy)
    tangent = (dx / length, dy / length)
    normal = (-tangent[1] * thickness / 2, tangent[0] * thickness / 2)
    cuts = [0.0, length]
    for center, width, door_height in doors:
        assert width > 0 and center - width / 2 >= 0 and center + width / 2 <= length
        cuts.extend((center - width / 2, center + width / 2))
    cuts.sort()
    for start, end in zip(cuts, cuts[1:]):
        if end - start < 1e-7:
            continue
        middle = (start + end) / 2
        bottom = 0
        for center, width, door_height in doors:
            if abs(middle - center) < width / 2:
                bottom = door_height
        left = (a[0] + tangent[0] * start, a[1] + tangent[1] * start)
        right = (a[0] + tangent[0] * end, a[1] + tangent[1] * end)
        split.solid([(left[0] - normal[0], left[1] - normal[1]),
                     (right[0] - normal[0], right[1] - normal[1]),
                     (right[0] + normal[0], right[1] + normal[1]),
                     (left[0] + normal[0], left[1] + normal[1])], bottom, height, material)


def _rectangle(split, cx, cy, hx, hy, height, material, doors=None):
    doors = doors or {}
    sides = {
        'front': ((cx - hx, cy - hy), (cx + hx, cy - hy)),
        'back': ((cx - hx, cy + hy), (cx + hx, cy + hy)),
        'left': ((cx - hx, cy - hy), (cx - hx, cy + hy)),
        'right': ((cx + hx, cy - hy), (cx + hx, cy + hy)),
    }
    for key, (a, b) in sides.items():
        _wall(split, a, b, .22, height, material, doors.get(key, ()))


def _front_frame(split, x, y, width, height, material='Timber'):
    for side in (-1, 1):
        split.box((x + side * (width / 2 + .075), y, height / 2), (.14, .18, height), material)
    split.box((x, y, height + .09), (width + .30, .20, .18), material)


def _ring(builder, levels, count, material, phase=0, center=(0, 0)):
    vertices = [(center[0] + radius * math.cos(phase + i * math.tau / count),
                 center[1] + radius * math.sin(phase + i * math.tau / count), z)
                for z, radius in levels for i in range(count)]
    faces = [tuple(reversed(range(count))), tuple(range((len(levels) - 1) * count, len(levels) * count))]
    for level in range(len(levels) - 1):
        for i in range(count):
            faces.append((level * count + i, level * count + (i + 1) % count,
                          (level + 1) * count + (i + 1) % count, (level + 1) * count + i))
    builder.part(vertices, faces, material)


def _row(split, parts):
    # Preserve the refined upper storeys, shutters, roof courses and chimneys.
    # Only the first storey is rebuilt; its three connected rooms keep the row's
    # three facade bays and three real street entrances.
    def deepen(point):
        x, y, z = point
        half_depth = 2.75 if abs(x) < 2.0 else 2.625
        return x, y * 3.1 / half_depth, z

    for part in parts:
        _append(split.cover, part, bottom=3.05, transform=deepen)
    door_x = [-4.388, -.808, 3.406]  # Blender X is the negative of Unity X.
    _rectangle(split, 0, 0, 5.6, 3.1, 3.05, 'PlasterShade',
               {'front': [(x + 5.6, 2.0, 2.4) for x in door_x]})
    split.box((0, 0, -.03), (11.2, 6.2, .06), 'InteriorWood')
    for x in door_x:
        _front_frame(split, x, -3.24, 2.0, 2.4)
    for x in [-5.54, -2.0, 2.0, 5.54]:
        split.box((x, -3.235, 1.525), (.12, .15, 3.05), 'Timber')
    # The ground floor stays connected across bays. No partition/furniture can
    # intrude into the eleven authored cells or any of their connecting edges.
    split.box((0, -3.235, 2.98), (11.2, .17, .14), 'TimberLight')
    for x, width in [(-2.74, .57), (1.40, .62), (5.04, .55)]:
        split.cover.box((x, -3.225, 1.70), (width, .06, .72), 'Window')


def _gatehouse(split, parts):
    # Original low arch posts overlap the new inward-facing tower doors. Rebuild
    # those low sections with the tower shell, keeping the genuine arch above.
    for part in parts:
        center_x = (part['min'][0] + part['max'][0]) / 2
        if abs(center_x) >= 5.5:
            _append(split.cover, part, bottom=3.2)
        else:
            split.retained(part)
    for side in (-1, 1):
        cx = side * 8.8
        doorway = 'right' if side < 0 else 'left'
        _rectangle(split, cx, 0, 2.6, 2.9, 3.2, 'RoyalStone',
                   {doorway: [(2.9, 2.0, 2.4)]})
        split.box((cx, 0, -.03), (5.2, 5.8, .06), 'RoyalIvory')
        # Recessed inward door frame, wholly outside the 2.0-m clear opening.
        inner_x = cx - side * 2.6
        for y in (-1.08, 1.08):
            split.box((inner_x - side * .12, y, 1.2), (.30, .14, 2.4), 'RoyalIvory')
        split.box((inner_x - side * .12, 0, 2.5), (.32, 2.32, .20), 'RoyalIvory')
        for x in [cx - 1.4, cx + 1.4]:
            split.cover.box((x, -3.035, 1.95), (.85, .08, 1.10), 'RoyalGlass')
            split.box((x, -3.075, .52), (.20, .28, 1.04), 'RoyalIvory')


def _pavilion(split, parts, mesh_type):
    for part in parts:
        if part['max'][2] <= .32001:
            split.retained(part, lambda point: (point[0], point[1], point[2] - .32))
        elif part['min'][2] >= 3.89999:
            _append(split.cover, part)
    # Source remains unscaled: the lot's explicit metre scale is 1.5. Shift the
    # two front posts sideways so both approach diagonals clear the pawn's base.
    angles = [22.5, 55, 125, 157.5, 202.5, 235, 305, 337.5]
    for angle in angles:
        radians = math.radians(angle)
        center = (2.55 * math.cos(radians), 2.55 * math.sin(radians))
        part = mesh_type()
        _ring(part, [(0, .25), (.25, .32), (3.7, .19), (3.9, .32)], 8, 'RoyalIvory', center=center)
        split.retained({'vertices': part.vertices, 'faces': part.faces,
                        'materials': [part.material_keys[i] for i in part.face_materials]})


def _windmill(split, parts):
    blades = [part for part in parts if (part['min'][1] + part['max'][1]) / 2 < -1.44]
    assert blades, 'Windmill source has no identifiable blade assembly'
    lift = max(0, 2.45 - min(part['min'][2] for part in blades))
    blade_ids = {id(part) for part in blades}
    for part in parts:
        if id(part) in blade_ids:
            _append(split.cover, part, transform=lambda point: (point[0], point[1], point[2] + lift))
        else:
            _append(split.cover, part, bottom=2.8)
    radius, inside = 1.80, 1.56
    angle = math.radians(240)  # Unity +(.5, .866) maps to Blender -(.5, .866).
    forward = (math.cos(angle), math.sin(angle))
    cross = (-forward[1], forward[0])
    ring = [(radius * math.cos(angle - math.pi / 10 + i * math.tau / 10),
             radius * math.sin(angle - math.pi / 10 + i * math.tau / 10)) for i in range(10)]
    for a, b in zip(ring, ring[1:] + ring[:1]):
        polygon = [a, b, (b[0] * inside / radius, b[1] * inside / radius),
                   (a[0] * inside / radius, a[1] * inside / radius)]
        # Partition the shell footprint by a rectangular doorway before vertical
        # extrusion. Each resulting wall piece is a closed prism with real jambs.
        left = _clip(polygon, lambda p: -1.0 - p[0] * cross[0] - p[1] * cross[1])
        right = _clip(polygon, lambda p: p[0] * cross[0] + p[1] * cross[1] - 1.0)
        middle = _clip(_clip(polygon, lambda p: p[0] * cross[0] + p[1] * cross[1] + 1.0),
                       lambda p: 1.0 - p[0] * cross[0] - p[1] * cross[1])
        back = _clip(middle, lambda p: -p[0] * forward[0] - p[1] * forward[1])
        front = _clip(middle, lambda p: p[0] * forward[0] + p[1] * forward[1])
        for solid in (left, right, back):
            split.solid(solid, 0, 2.45, 'PlasterShade')
        split.solid(front, 2.4, 2.45, 'PlasterShade')
    _extrude(split.core, ring, -.08, 0, 'Stone')
    old_radius = 1.24 - (2.8 - 1.42) * (.36 / 3.5)
    _ring(split.cover, [(2.45, radius), (2.8, old_radius)], 10, 'TimberLight', phase=angle - math.pi / 10)
    # A short porch lintel makes the rotated entrance readable from above.
    center = (forward[0] * 1.40, forward[1] * 1.40)
    for sign in (-1, 1):
        x, y = center[0] + cross[0] * sign * 1.09, center[1] + cross[1] * sign * 1.09
        split.box((x, y, 1.20), (.14, .14, 2.4), 'Timber')


def _granary(split, parts):
    for part in parts:
        if all(key in ('HarvestGold', 'HarvestShade') for key in part['materials']):
            obstructs = (part['min'][0] + part['max'][0]) / 2 < 0
            split.retained(part, lambda point: (point[0], -point[1] if obstructs else point[1], point[2] - .1))
        else:
            _append(split.cover, part, bottom=3.18)
    _rectangle(split, 0, 0, 2.275, 1.56, 3.25, 'TimberLight',
               {'front': [(-.9 + 2.275, 1.9, 2.4)]})
    split.box((0, 0, -.035), (4.74, 3.35, .07), 'Stone')
    _front_frame(split, -.9, -1.69, 1.9, 2.4)
    for x in (-2.23, .25, 2.23):
        split.box((x, -1.69, 1.55), (.12, .13, 3.10), 'Timber')
    split.cover.box((0, -1.69, 3.08), (4.62, .15, .14), 'Timber')
    split.cover.box((1.42, -1.685, 1.80), (.63, .07, .72), 'Window')


def _owned_scene():
    scene = bpy.data.scenes.get(SCENE)
    if scene is None:
        scene = bpy.data.scenes.new(SCENE)
        scene['open_buildings_owner'] = OWNER
    assert scene.get('open_buildings_owner') == OWNER, 'Unowned target scene'
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    collection = bpy.data.collections.get(COLLECTION)
    if collection is None:
        collection = bpy.data.collections.new(COLLECTION)
        collection['open_buildings_owner'] = OWNER
        scene.collection.children.link(collection)
    assert collection.get('open_buildings_owner') == OWNER, 'Unowned target collection'
    assert collection.name in scene.collection.children
    return scene, collection


def _remove_owned(name):
    obj = bpy.data.objects.get(name)
    if obj is None:
        return
    assert obj.get('open_buildings_owner') == OWNER, 'Refusing to replace unowned object: ' + name
    mesh = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    if mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def _report(collection, palette):
    report = []
    for obj in sorted(collection.objects, key=lambda item: item['export_basename']):
        assert obj.get('open_buildings_owner') == OWNER
        obj.data.calc_loop_triangles()
        report.append({'name': obj['export_basename'], 'object': obj.name,
                       'materials': [material.name for material in obj.data.materials],
                       'dimensions': list(obj.dimensions), 'triangles': len(obj.data.loop_triangles),
                       'source': obj['source_building'],
                       'stagedPath': str(OUT / 'Staging' / (obj['export_basename'] + '.fbx'))})
    (OUT / 'Integration/models.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    used = {name for row in report for name in row['materials']}
    colors = {name: '#' + palette[name.removeprefix('M_MapLP_')] for name in sorted(used)}
    (OUT / 'Integration/palette.json').write_text(json.dumps(colors, indent=2), encoding='utf-8')
    return report


def build(models=None, *, export=True, save=True):
    """Build/export the selected groups, preserving the caller's dirty live scene."""
    models = list(DEFINITIONS) if models is None else list(models)
    assert models and len(models) == len(set(models)), 'Specify unique model keys'
    for key in models:
        assert key in DEFINITIONS, 'Unknown building: ' + str(key)
    assert bpy.context.mode == 'OBJECT', 'Leave Edit Mode before modelling a new asset'
    helpers = _helpers()
    mesh_type = helpers['MeshBuilder']
    for folder in ('Source', 'Staging', 'Integration'):
        (OUT / folder).mkdir(parents=True, exist_ok=True)
    scene_before = bpy.context.window.scene
    selected_before = list(bpy.context.selected_objects)
    active_before = bpy.context.view_layer.objects.active
    scene, collection = _owned_scene()
    exporters = runpy.run_path(str(ROOT / 'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))
    done = []
    try:
        bpy.context.window.scene = scene
        for key in models:
            basename, source_path = DEFINITIONS[key]
            source, appended = _source(basename, source_path)
            try:
                assert tuple(source.location) == (0, 0, 0) and tuple(source.rotation_euler) == (0, 0, 0)
                assert tuple(source.scale) == (1, 1, 1) and not source.modifiers
                parts = _parts(source)
            finally:
                if appended:
                    mesh = source.data
                    bpy.data.objects.remove(source, do_unlink=True)
                    if mesh.users == 0:
                        bpy.data.meshes.remove(mesh)
            split = Split(mesh_type)
            if key.startswith('Row'):
                _row(split, parts)
            elif key == 'Gatehouse':
                _gatehouse(split, parts)
            elif key == 'Pavilion':
                _pavilion(split, parts, mesh_type)
            elif key == 'Windmill':
                _windmill(split, parts)
            else:
                _granary(split, parts)
            for suffix, builder in [('', split.core), ('_Cover', split.cover)]:
                export_name = basename + suffix
                owned_name = 'OpenBuildings_' + export_name
                _remove_owned(owned_name)
                assert builder.faces, 'Empty building part: ' + export_name
                obj = builder.finish(owned_name, collection)
                obj['open_buildings_owner'] = OWNER
                obj['export_basename'] = export_name
                obj['source_building'] = key
                bpy.context.view_layer.update()
                if export:
                    exporters['export_map_static_fbx'](obj.name, str(OUT / 'Staging' / (export_name + '.fbx')), overwrite=True)
                done.append(export_name)
        bpy.context.view_layer.update()
        report = _report(collection, helpers['PALETTE'])
        if save:
            bpy.data.libraries.write(str(OUT / 'Source/OpenBuildings.blend'), {scene}, fake_user=True, compress=True)
        print(json.dumps({'built': done, 'models': len(report), 'source': str(OUT / 'Source/OpenBuildings.blend'),
                          'exported': export, 'saved': save}, ensure_ascii=False))
        return report
    finally:
        bpy.context.window.scene = scene_before
        for obj in bpy.context.selected_objects:
            obj.select_set(False)
        for obj in selected_before:
            if obj.name in bpy.context.view_layer.objects:
                obj.select_set(True)
        if active_before is not None and active_before.name in bpy.context.view_layer.objects:
            bpy.context.view_layer.objects.active = active_before
