"""Incremental face/hair art revision. Keeps body meshes, module IDs and the shared rest rig.

Call load_source(), refine_heads(), refine_hair(), save_and_export() separately in Blender MCP.
The previous PawnCustomization.blend remains available as the authored baseline.
"""
import bpy
import bmesh
import math
import json
import runpy
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
BASE = runpy.run_path(str(ROOT / 'Scripts/build_modules.py'))
Geometry = BASE['Geometry']
ROLES = BASE['ROLES']
W = {'Head': 1}


def load_source():
    assert 'PawnCustomization_Studio' not in bpy.data.scenes, 'Source already loaded; inspect before retrying.'
    with bpy.data.libraries.load(str(ROOT / 'Source/PawnCustomization.blend'), link=False) as (source, target):
        target.scenes = ['PawnCustomization_Studio']
    bpy.context.window.scene = bpy.data.scenes['PawnCustomization_Studio']
    print(json.dumps({'scene': bpy.context.scene.name, 'objects': len(bpy.context.scene.objects)}))


def apply_geometry(name, g):
    obj = bpy.data.objects[name]
    assert obj.get('owned_customization') and obj.parent.name == 'CustomizationRig'
    mesh = bpy.data.meshes.new(name + '_Refined')
    mesh.from_pydata(g.vertices, [], g.faces)
    for role in ROLES:
        mesh.materials.append(bpy.data.materials['PC_' + role])
    for p, material in zip(mesh.polygons, g.materials):
        p.material_index = material
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free()
    uv = mesh.uv_layers.new(name='UVMap')
    for p in mesh.polygons:
        for index in p.loop_indices:
            v = mesh.vertices[mesh.loops[index].vertex_index].co
            uv.data[index].uv = (v.x + .5, v.z / 2)
    old = obj.data; obj.data = mesh
    obj.vertex_groups.clear()
    for bone in obj.parent.data.bones:
        obj.vertex_groups.new(name=bone.name)
    for i, weights in enumerate(g.weights):
        for bone, weight in weights.items():
            obj.vertex_groups[bone].add([i], weight, 'REPLACE')
    if old.users == 0:
        bpy.data.meshes.remove(old)
    obj['style_revision'] = 'ink_anime_1'
    return obj


def patch(g, coords, role):
    # Thin, closed facial inlay, never a floating box protruding from the face.
    front = [g.vertex(p, W) for p in coords]
    back = [g.vertex((p[0], p[1] + .004, p[2]), W) for p in coords]
    g.face(tuple(front), role); g.face(tuple(reversed(back)), role)
    for i in range(len(front)):
        j = (i + 1) % len(front)
        g.face((front[i], front[j], back[j], back[i]), role)


def almond(g, x, y, z, width, height, role, tilt=0):
    points = [(-.5, 0), (-.28, .43), (.1, .5), (.5, .1), (.29, -.4), (-.14, -.46)]
    patch(g, [(x + a * width, y + abs(a) * .011, z + b * height + a * tilt) for a, b in points], role)


def make_head(race, sex, variant):
    g = Geometry(); female = sex == 'female'
    width = {'human': .181, 'elf': .17, 'goblin': .187, 'dragon': .183, 'orc': .201}[race]
    width *= 1.018 if variant else .99
    jaw = width * (.61 if female else .70) * (1.04 if variant else 1)
    # Twelve-sided cranium, tapered jaw and a distinct chin; preserve the helmet envelope.
    g.rings([((0, .006, 1.368), .077, .071, W), ((0, -.013, 1.418), jaw * .73, .101, W),
             ((0, -.006, 1.452), jaw, .123, W), ((0, .004, 1.515), width * .92, .149, W),
             ((0, .003, 1.585), width, .162, W), ((0, .010, 1.655), width * .98, .161, W),
             ((0, .012, 1.717), .149, .134, W), ((0, .013, 1.758), .083, .085, W)], 'Skin', sides=12)
    for side in [-1, 1]:
        if race in ['elf', 'goblin']:
            tip = side * (.29 if race == 'goblin' else .267)
            g.spike((side * .155, .013, 1.573), (tip, .035, 1.659 if race == 'elf' else 1.626), .052)
            g.spike((side * .181, -.012, 1.584), (tip * .95, .009, 1.64 if race == 'elf' else 1.615), .018, 'Mouth')
        elif race != 'dragon':
            g.rings([((side * .17, .018, 1.541), .019, .025, W),
                     ((side * .183, .018, 1.572), .026, .031, W),
                     ((side * .174, .018, 1.609), .016, .021, W)], 'Skin', sides=6)
        x = side * (.076 if race != 'orc' else .085)
        eye_y = -.153 if race != 'orc' else -.151
        eye_width = .077 if female else .073
        eye_height = .042 if female else .035
        tilt = side * (.011 if race in ['elf', 'dragon'] else .007)
        # A narrow dark socket/upper lid, white almond, colored iris and tiny catchlight.
        almond(g, x, eye_y, 1.581, eye_width + .014, eye_height + .012, 'Iris', tilt)
        almond(g, x, eye_y - .005, 1.580, eye_width, eye_height, 'EyeWhite', tilt)
        almond(g, x - side * .004, eye_y - .010, 1.580, .031, eye_height * .88, 'Iris')
        almond(g, x - side * .010, eye_y - .015, 1.589, .009, .010, 'EyeWhite')
        patch(g, [(x - .036, eye_y + .002, 1.623 - side * .003),
                  (x + .034, eye_y + .002, 1.628 + side * .003),
                  (x + .030, eye_y - .001, 1.637 + side * .003),
                  (x - .033, eye_y - .001, 1.632 - side * .003)], 'Hair')
        if race == 'orc':
            g.spike((side * .085, -.137, 1.453), (side * .082, -.171, 1.508), .017, 'Horn')
        if race == 'dragon':
            g.spike((side * .127, .035, 1.701), (side * .185, .102, 1.836 if variant else 1.806), .042, 'Horn')
            g.spike((side * .168, .065, 1.575), (side * .239, .103, 1.631), .030, 'Skin')
    if race == 'dragon':
        g.rings([((0, -.050, 1.45), .094, .125, W), ((0, -.064, 1.484), .118, .157, W),
                 ((0, -.053, 1.530), .093, .141, W)], 'Skin', sides=10)
        for side in [-1, 1]:
            almond(g, side * .046, -.218, 1.51, .018, .011, 'Mouth')
        patch(g, [(-.065, -.219, 1.475), (0, -.227, 1.469), (.065, -.219, 1.475), (0, -.227, 1.480)], 'Mouth')
    else:
        nose = .208 if race == 'goblin' else .189 if race == 'orc' else .175
        # Small wedge, with the bridge recessed into the head instead of a pyramidal beak.
        points = [(-.019, -.145, 1.57), (.019, -.145, 1.57), (.018, -.153, 1.525),
                  (0, -nose, 1.532), (-.018, -.153, 1.525)]
        patch(g, points, 'Skin')
        patch(g, [(-.030, -.129, 1.477), (0, -.139, 1.474), (.030, -.129, 1.477),
                  (0, -.139, 1.480)], 'Mouth')
    obj = apply_geometry('head_' + race + '_' + sex + '_' + str(variant), g)
    # Retain restrained planar shading; only the cranium gets a smoother cheek transition.
    for p in list(obj.data.polygons)[:86]:
        p.use_smooth = True
    return obj


def strand(g, start, mid, tip, width, depth=.03):
    # Sculpted tapered lock: broad root, bent highlight plane, pointed tip.
    rows = [(start, width, depth), (mid, width * .8, depth * .76), (tip, .002, .003)]
    rings = []
    for center, w, d in rows:
        x, y, z = center
        rings.append([g.vertex((x - w / 2, y, z), W), g.vertex((x, y - d, z + d * .24), W),
                      g.vertex((x + w / 2, y, z), W), g.vertex((x, y + d * .6, z), W)])
    g.face(tuple(reversed(rings[0])), 'Hair')
    for a, b in zip(rings, rings[1:]):
        for i in range(4):
            g.face((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]), 'Hair')
    g.face(tuple(rings[-1]), 'Hair')


def make_hair(style):
    g = Geometry()
    g.rings([((0, .025, 1.68), .187, .152, W), ((0, .021, 1.727), .171, .151, W),
             ((0, .023, 1.770), .134, .122, W), ((0, .021, 1.797), .063, .061, W)], 'Hair', sides=12)
    if style == 0:
        for i in range(5):
            x = -.114 + i * .054
            strand(g, (x, -.087, 1.745), (x + .021, -.133, 1.720), (x + .030, -.166, 1.647 + .009 * (i % 2)), .064)
        for side in [-1, 1]:
            strand(g, (side * .146, -.018, 1.735), (side * .177, -.025, 1.685), (side * .169, -.041, 1.622), .058)
    elif style == 1:
        for i in range(6):
            x = -.125 + i * .047
            strand(g, (x + .036, -.067, 1.776 - abs(x) * .15), (x + .012, -.13, 1.722),
                   (x - .035, -.176, 1.628 + abs(x + .035) * .35), .069, .035)
        for side in [-1, 1]:
            strand(g, (side * .152, .023, 1.737), (side * .187, -.01, 1.671), (side * .168, -.045, 1.555), .072)
            strand(g, (side * .154, .092, 1.724), (side * .178, .120, 1.665), (side * .164, .113, 1.593), .067)
    else:
        for i in range(6):
            x = -.132 + i * .052
            strand(g, (x, -.08, 1.758), (x, -.149, 1.704), (x + .01, -.175, 1.639 + .014 * (i % 2)), .065)
        for side in [-1, 1]:
            strand(g, (side * .147, .028, 1.748), (side * .189, -.018, 1.625), (side * .170, -.060, 1.467), .079, .042)
            strand(g, (side * .160, .079, 1.731), (side * .194, .090, 1.59), (side * .177, .089, 1.454), .079, .040)
        for i in range(5):
            x = -.13 + i * .065
            strand(g, (x, .127, 1.73), (x * 1.1, .179, 1.606), (x, .169, 1.48 + .018 * (i % 2)), .078, .035)
    return apply_geometry('hair_' + str(style), g)


def refine_heads():
    result = []
    for race in ['human', 'elf', 'goblin', 'dragon', 'orc']:
        for sex in ['male', 'female']:
            for variant in range(2):
                obj = make_head(race, sex, variant)
                result.append({'name': obj.name, 'vertices': len(obj.data.vertices)})
    print(json.dumps(result))


def refine_hair():
    print(json.dumps([{'name': make_hair(i).name} for i in range(3)]))


def save_and_export():
    scene = bpy.data.scenes['PawnCustomization_Studio']
    modules = [o for o in scene.objects if o.get('owned_customization')]
    assert len(modules) == 29
    for obj in modules:
        assert all(abs(sum(g.weight for g in v.groups) - 1) < 1e-5 for v in obj.data.vertices)
    path = ROOT / 'Source/PawnCustomizationStylized.blend'
    bpy.data.libraries.write(str(path), {scene}, fake_user=True)
    BASE['export']()
    report = {'source': str(path), 'modules': len(modules), 'changedHeads': 20, 'changedHair': 3,
              'bones': len(bpy.data.objects['CustomizationRig'].data.bones), 'bodyAndRestRigUnchanged': True}
    (ROOT / 'Integration/stylized-source.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))
