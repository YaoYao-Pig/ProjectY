"""Run inside the connected Blender instance; leaves existing scenes untouched."""
import bpy
import bmesh
import json
import math
from pathlib import Path

root = Path('D:/Program/Unity/Project Y/Art/TownMissionMarker')
for folder in ('Source', 'Export', 'Previews', 'Integration'):
    (root / folder).mkdir(parents=True, exist_ok=True)
assert 'TownMissionMarker' not in bpy.data.scenes, 'Marker scene already exists; edit it explicitly.'
previous_scene = bpy.context.window.scene
scene = bpy.data.scenes.new('TownMissionMarker')
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
bpy.context.window.scene = scene
collection = bpy.data.collections.new('TownMissionMarker')
scene.collection.children.link(collection)

vertices, faces = [], []
def prism(profile, center, bevel):
    # Flat face, bevel band, thick side: an actual closed solid, not a billboard.
    count = len(profile)
    start = len(vertices)
    for depth, inset in ((-.065, bevel), (-.045, 0), (.045, 0), (.065, bevel)):
        for x, z in profile:
            dx, dz = x - center[0], z - center[1]
            distance = math.sqrt(dx * dx + dz * dz)
            factor = (distance - inset) / distance
            vertices.append((center[0] + dx * factor, depth, center[1] + dz * factor))
    faces.append(tuple(start + i for i in reversed(range(count))))
    for ring in range(3):
        for i in range(count):
            j = (i + 1) % count
            faces.append((start + ring * count + i, start + ring * count + j,
                          start + (ring + 1) * count + j, start + (ring + 1) * count + i))
    faces.append(tuple(start + 3 * count + i for i in range(count)))

prism([(-.072, .255), (.072, .255), (.145, .80), (-.145, .80)], (0, .53), .016)
prism([(math.cos(i * math.tau / 8 + math.pi / 8) * .105,
        .105 + math.sin(i * math.tau / 8 + math.pi / 8) * .105) for i in range(8)], (0, .105), .015)
mesh = bpy.data.meshes.new('TownMissionMarker_Mesh')
mesh.from_pydata(vertices, [], faces)
mesh.update()
bm = bmesh.new()
bm.from_mesh(mesh)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh)
bm.free()
uv = mesh.uv_layers.new(name='MarkerUV')
for poly in mesh.polygons:
    for loop_index in poly.loop_indices:
        co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
        uv.data[loop_index].uv = ((co.x + .15) / .30, co.z / .8)
obj = bpy.data.objects.new('TownMissionMarker', mesh)
collection.objects.link(obj)
material = bpy.data.materials.new('TownMissionMarker_Gold')
material.diffuse_color = (1.0, .66, .08, 1)
shader = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
shader.inputs['Base Color'].default_value = material.diffuse_color
shader.inputs['Metallic'].default_value = .15
shader.inputs['Roughness'].default_value = .38
mesh.materials.append(material)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
mesh.calc_loop_triangles()
assert obj.matrix_world.determinant() > 0
assert len(mesh.uv_layers) == 1
report = {'object': obj.name, 'vertices': len(mesh.vertices), 'triangles': len(mesh.loop_triangles),
          'dimensionsMeters': list(obj.dimensions), 'origin': list(obj.location),
          'front': '-Y in Blender, +Z after Unity prefab axis conversion', 'materialSlots': len(mesh.materials)}
(root / 'Integration' / 'blender-model.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
bpy.data.libraries.write(str(root / 'Source' / 'TownMissionMarker.blend'), {scene}, fake_user=True)
print(json.dumps(report))
