"""Run through Blender MCP. Build isolated metre-scale forest and animal masters."""
import bpy
import json
import math
import runpy
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/Program/Unity/Project Y')
OUT = ROOT / 'Art/ForestAnimals'
helpers = runpy.run_path(str(ROOT / 'Art/MapLowPoly/Scripts/mesh_helpers.py'))
Mesh = helpers['MeshBuilder']
PALETTE = helpers['PALETTE']
PALETTE.update(AnimalChestnut='946445', AnimalMane='40372e', AnimalCream='dfd3b8',
               AnimalFeather='c7b99a', AnimalComb='ab5341', AnimalBeak='c3954f',
               AnimalEye='282a26', AnimalFur='a99b88', AnimalEar='bd9280',
               ForestGround='567747', ForestSoil='645842', ForestLeaf='557c43',
               ForestLeafLight='71934e', ForestPine='3f6b57', ForestBark='66594a')
scene = bpy.data.scenes.get('ForestAnimals_Source')
assert scene is None, 'ForestAnimals_Source already exists; inspect before rebuilding'
previous_scene = bpy.context.window.scene
scene = bpy.data.scenes.new('ForestAnimals_Source')
bpy.context.window.scene = scene
scene.unit_settings.scale_length = 1
collection = bpy.data.collections.new('ForestAnimals_Masters')
scene.collection.children.link(collection)
for key, color in PALETTE.items():
    name = 'M_MapLP_' + key
    if name in bpy.data.materials:
        continue
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    rgba = tuple(helpers['srgb_linear'](int(color[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1,)
    node = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = rgba
    node.inputs['Roughness'].default_value = .88
    node.inputs['Metallic'].default_value = 0
    material.diffuse_color = rgba
    material['palette_srgb'] = '#' + color


def ellipsoid(mesh, center, scale, material, rings=4, sides=8, tilt=0):
    vertices = []
    for j in range(rings + 1):
        phi = math.pi * j / rings
        for i in range(sides):
            theta = math.tau * (i + .25) / sides
            x = math.sin(phi) * math.cos(theta) * scale[0]
            y = math.sin(phi) * math.sin(theta) * scale[1]
            z = math.cos(phi) * scale[2]
            vertices.append((center[0]+x, center[1]+y*math.cos(tilt)-z*math.sin(tilt),
                             center[2]+y*math.sin(tilt)+z*math.cos(tilt)))
    faces = [(j*sides+i, j*sides+(i+1)%sides, (j+1)*sides+(i+1)%sides, (j+1)*sides+i)
             for j in range(rings) for i in range(sides)]
    mesh.part(vertices, faces, material)


def tube(mesh, start, end, radius, material, tip=None, sides=7):
    a, b = Vector(start), Vector(end)
    axis = (b-a).normalized()
    u = axis.cross(Vector((0, 0, 1)))
    if u.length < .01:
        u = axis.cross(Vector((0, 1, 0)))
    u.normalize()
    v = axis.cross(u)
    tip = radius if tip is None else tip
    vertices = [tuple(p + r*(u*math.cos(i*math.tau/sides) + v*math.sin(i*math.tau/sides)))
                for p, r in ((a, radius), (b, tip)) for i in range(sides)]
    faces = [tuple(reversed(range(sides))), tuple(range(sides, sides*2))]
    faces += [(i, (i+1)%sides, (i+1)%sides+sides, i+sides) for i in range(sides)]
    mesh.part(vertices, faces, material)


def horse():
    m = Mesh()
    ellipsoid(m, (0, .02, 1.02), (.39, .75, .38), 'AnimalChestnut')
    for x in (-.25, .25):
        for y in (-.47, .50):
            tube(m, (x, y, .98), (x, y+.07, .13), .095, 'AnimalChestnut', tip=.07)
            m.box((x, y+.03, .075), (.19, .25, .15), 'AnimalMane')
    ellipsoid(m, (0, -.51, 1.42), (.25, .31, .62), 'AnimalChestnut', tilt=.35)
    ellipsoid(m, (0, -.88, 1.80), (.23, .37, .25), 'AnimalChestnut', tilt=.3)
    ellipsoid(m, (0, -1.13, 1.66), (.22, .23, .18), 'AnimalMane')
    for x in (-.14, .14):
        ellipsoid(m, (x, -.74, 2.04), (.075, .10, .23), 'AnimalChestnut', rings=3, sides=6)
        ellipsoid(m, (x*1.57, -.97, 1.86), (.027, .06, .055), 'AnimalEye', rings=3, sides=6)
    tube(m, (0, -.30, 1.19), (0, -.48, 1.91), .105, 'AnimalMane', tip=.085)
    tube(m, (0, .70, 1.09), (0, 1.01, .52), .105, 'AnimalMane', tip=.13)
    m.box((0, -1.004, 1.94), (.075, .025, .16), 'AnimalCream')
    return m


def chicken():
    m = Mesh()
    ellipsoid(m, (0, .06, .77), (.46, .55, .48), 'AnimalCream')
    for x in (-.43, .43):
        ellipsoid(m, (x, .08, .80), (.13, .36, .30), 'AnimalFeather', tilt=-.3)
    ellipsoid(m, (0, -.37, 1.13), (.24, .24, .42), 'AnimalCream')
    ellipsoid(m, (0, -.46, 1.42), (.23, .23, .24), 'AnimalCream')
    tube(m, (0, -.65, 1.40), (0, -.91, 1.36), .13, 'AnimalBeak', tip=.015, sides=5)
    for y, z in [(-.58, 1.66), (-.43, 1.70), (-.29, 1.63)]:
        ellipsoid(m, (0, y, z), (.07, .115, .13), 'AnimalComb', rings=3, sides=6)
    ellipsoid(m, (0, -.62, 1.21), (.085, .10, .18), 'AnimalComb', rings=3, sides=6)
    for x in (-.213, .213):
        ellipsoid(m, (x, -.54, 1.47), (.025, .048, .05), 'AnimalEye', rings=3, sides=6)
    for x in (-.18, .18):
        tube(m, (x, -.06, .44), (x, -.10, .075), .045, 'AnimalBeak')
        for dx in (-.12, 0, .12):
            tube(m, (x, -.10, .06), (x+dx, -.34, .035), .03, 'AnimalBeak', tip=.018, sides=5)
    for x, tilt in [(-.19, -.65), (0, -.75), (.19, -.6)]:
        ellipsoid(m, (x, .59, 1.12), (.14, .16, .49), 'AnimalMane', tilt=tilt)
    return m


def rabbit():
    m = Mesh()
    ellipsoid(m, (0, .11, .55), (.46, .61, .45), 'AnimalFur')
    ellipsoid(m, (0, -.47, .85), (.33, .33, .32), 'AnimalCream')
    for x in (-.32, .32):
        ellipsoid(m, (x, .42, .32), (.24, .32, .29), 'AnimalFur')
        ellipsoid(m, (x, .05, .105), (.17, .36, .105), 'AnimalCream')
    for x in (-.19, .19):
        tube(m, (x, -.29, .54), (x, -.40, .15), .085, 'AnimalCream', tip=.065)
        ellipsoid(m, (x, -.48, .09), (.10, .23, .09), 'AnimalCream')
        ellipsoid(m, (x, -.39, 1.38), (.12, .105, .47), 'AnimalFur', tilt=-.1)
        ellipsoid(m, (x, -.481, 1.41), (.073, .03, .34), 'AnimalEar', tilt=-.1)
    for x in (-.291, .291):
        ellipsoid(m, (x, -.59, .93), (.026, .064, .066), 'AnimalEye', rings=3, sides=6)
    ellipsoid(m, (0, -.781, .80), (.065, .055, .05), 'AnimalEar', rings=3, sides=6)
    ellipsoid(m, (0, .74, .62), (.20, .20, .20), 'AnimalCream', rings=3)
    return m


def oak():
    m = Mesh()
    tube(m, (0, 0, 0), (.13, .04, 3.5), .28, 'ForestBark', tip=.16)
    for a, b in [((.06, 0, 1.7), (-.9, .1, 3.5)), ((.08, 0, 2.2), (1, -.3, 3.8))]:
        tube(m, a, b, .13, 'ForestBark', tip=.05)
    for i, (x,y,z,s) in enumerate([(-.82,.13,3.6,1.1),(.76,-.34,3.85,1.15),(.16,.68,4.05,1.1),(-.12,-.32,4.6,1.16)]):
        ellipsoid(m, (x,y,z), (s,s*.91,s*.85), 'ForestLeafLight' if i==3 else 'ForestLeaf', rings=3, sides=7)
    return m


def pine():
    m = Mesh()
    tube(m, (0,0,0), (0,0,5.3), .20, 'ForestBark', tip=.05)
    for z, r, h in [(1.2,1.45,1.6),(2.2,1.14,1.6),(3.2,.84,1.6),(4.2,.52,1.3)]:
        tube(m,(0,0,z),(0,0,z+h),r,'ForestPine',tip=.025,sides=8)
    return m


def fern():
    m = Mesh()
    for i in range(9):
        a=i*2.4; x,y=math.cos(a),math.sin(a); w=.16
        m.part([(0,0,.02),(x*.5-y*w,y*.5+x*w,.28),(x*.85,y*.85,.52),
                (x*.5+y*w,y*.5-x*w,.28),(x*.45,y*.45,.40)],
               [(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)], 'ForestLeafLight' if i%3==0 else 'ForestLeaf')
    return m


def ground():
    m=Mesh();m.hex_prism(1,-1,0,'ForestGround','ForestSoil');return m


makers={'Horse':horse,'Chicken':chicken,'Rabbit':rabbit,'ForestOak':oak,'ForestPine':pine,'ForestFern':fern,'ForestGround':ground}
manifest=[]
for name, make in makers.items():
    obj=make().finish('FA_'+name,collection)
    obj.data.calc_loop_triangles()
    manifest.append({'name':name,'object':obj.name,'dimensions':list(obj.dimensions),
                     'triangles':len(obj.data.loop_triangles),'materials':[m.name for m in obj.data.materials]})
for folder in ('Source','Staging','Integration','Previews'):
    (OUT/folder).mkdir(parents=True,exist_ok=True)
bpy.data.libraries.write(str(OUT/'Source/ForestAnimals.blend'),{scene},fake_user=True)
(OUT/'Integration/models.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
bpy.context.window.scene=previous_scene
print(json.dumps({'source':str(OUT/'Source/ForestAnimals.blend'),'models':manifest}))
