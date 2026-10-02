"""Mine kit. Execute inside the existing Blender via MCP; preserves other scenes."""
import bpy, math, json, runpy, bmesh
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path('D:/Program/Unity/Project Y')
BASE = ROOT / 'Art/AssetExpansion202610/Mine'
assert 'AE202610_Mine' not in bpy.data.scenes
scene = bpy.data.scenes.new('AE202610_Mine')
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
bpy.context.window.scene = scene
masters = bpy.data.collections.new('AE202610_Mine_Masters')
scene.collection.children.link(masters)
for directory in ['Source', 'Staging', 'Previews', 'UnityPreviews']:
    (BASE / directory).mkdir(parents=True, exist_ok=True)

def linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4

palette = [
    ('Mine_Stone', '827e73'), ('Mine_StoneLight', 'a49b87'),
    ('Mine_StoneDark', '585b56'), ('Mine_Timber', '685342'),
    ('Mine_TimberEnd', '897256'), ('Mine_Plank', '9b815d'),
    ('Mine_Iron', '444e50'), ('Mine_Rust', '856449'),
    ('Mine_Copper', 'ac7b50'), ('Mine_Verdigris', '648c83'),
    ('Mine_Dark', '252e2d'), ('Mine_Lamp', 'caa464'),
]
materials = []
for name, hx in palette:
    assert name not in bpy.data.materials, name
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    color = tuple(linear(int(hx[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1,)
    mat.diffuse_color = color
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = color
    node.inputs['Roughness'].default_value = .88
    node.inputs['Metallic'].default_value = 0
    mat['palette_srgb'] = '#' + hx
    materials.append(mat)

class Model:
    def __init__(self, name):
        self.name, self.vertices, self.faces, self.colors = name, [], [], []

    def mesh(self, vertices, faces, material):
        start = len(self.vertices)
        self.vertices.extend(vertices)
        self.faces.extend(tuple(start + i for i in face) for face in faces)
        self.colors.extend([material] * len(faces))

    def box(self, center, size, material, rotation=None):
        x, y, z = [v / 2 for v in size]
        vertices = [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),
                    (-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
        rotation = rotation or Matrix.Identity(3)
        vertices = [rotation @ Vector(v) + Vector(center) for v in vertices]
        self.mesh(vertices, [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)], material)

    def beam(self, start, end, width, depth, material):
        direction = Vector(end) - Vector(start)
        rotation = direction.to_track_quat('Z', 'Y').to_matrix()
        self.box((Vector(start)+Vector(end))/2, (width, depth, direction.length), material, rotation)

    def cylinder(self, center, radius, length, material, axis='Z', count=8):
        rotation = Matrix.Identity(3) if axis == 'Z' else Matrix.Rotation(math.pi / 2, 3, 'Y')
        vertices = [rotation @ Vector((radius*math.cos(i*2*math.pi/count),radius*math.sin(i*2*math.pi/count),z))+Vector(center)
                    for z in (-length/2, length/2) for i in range(count)]
        faces = [tuple(reversed(range(count))),tuple(range(count,count*2))]
        faces.extend((i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count))
        self.mesh(vertices, faces, material)

    def rock(self, center, size, material, turn=0):
        # Eight chunky bevelled corners, intentionally broad flat faces.
        x,y,z=[v/2 for v in size]
        ring=[(-.66,-1),(.64,-1),(1,-.57),(1,.65),(.56,1),(-.63,1),(-1,.48),(-1,-.64)]
        vertices=[(a*x,b*y,-z) for a,b in ring]
        vertices += [(a*x*.84,b*y*.86,z*.63) for a,b in ring]
        vertices += [(-.34*x,-.34*y,z),(.42*x,-.34*y,z),(.40*x,.43*y,z),(-.36*x,.4*y,z)]
        faces=[tuple(reversed(range(8)))]
        faces += [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
        faces += [(8,9,17,16),(9,10,11,18,17),(11,12,13,19,18),(13,14,15,16,19),(15,8,16),(16,17,18,19)]
        rotation=Matrix.Rotation(turn,3,'Z')
        self.mesh([rotation@Vector(v)+Vector(center) for v in vertices],faces,material)

    def finish(self):
        mesh=bpy.data.meshes.new(self.name+'_Mesh')
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        for mat in materials: mesh.materials.append(mat)
        for polygon, color in zip(mesh.polygons,self.colors):
            polygon.material_index=color
            polygon.use_smooth=False
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
        uv=mesh.uv_layers.new(name='UVMap')
        for polygon in mesh.polygons:
            axis=max(range(3),key=lambda i:abs(polygon.normal[i]))
            axes=[i for i in range(3) if i!=axis]
            for index in polygon.loop_indices:
                point=mesh.vertices[mesh.loops[index].vertex_index].co
                uv.data[index].uv=(point[axes[0]],point[axes[1]])
        obj=bpy.data.objects.new(self.name,mesh);masters.objects.link(obj)
        obj['front_axis_blender']='-Y';obj['unit']='metre';obj['origin']='ground centre'
        return obj

objects=[]
# Single-hex world marker: exposed cliff portal and rails descending into darkness.
m=Model('Mine_Entrance')
m.box((0,.22,.68),(1.10,.40,1.2),10)
for x in (-.57,.57):
    m.rock((x,.15,.47),(.40,.83,.94),0, -.06 if x<0 else .06)
    m.rock((x*.88,.20,1.09),(.43,.70,.51),1)
m.rock((0,.26,1.34),(1.19,.77,.52),0)
for x in (-.40,.40):
    m.box((x,-.18,.60),(.15,.20,1.13),3)
    m.box((x,-.295,.62),(.165,.035,.14),6)
m.box((0,-.18,1.18),(.99,.24,.18),4)
for y in (-.66,-.38,-.10,.17):m.box((0,y,.045),(.67,.10,.065),4)
for x in (-.21,.21):m.box((x,-.25,.085),(.065,1.16,.06),7)
m.rock((-.61,-.38,.16),(.25,.33,.32),2)
m.rock((.57,-.40,.11),(.26,.28,.22),1)
m.box((.30,-.32,.85),(.11,.09,.16),11)
objects.append(m.finish())

# Structural arch: side posts sit outside the 3.5m walk-through centre.
m=Model('Mine_TimberSupport')
for x in (-1.93,1.93):
    m.box((x,0,1.36),(.36,.40,2.72),3)
    m.box((x,0,.09),(.43,.49,.18),2)
    for z in (.40,2.43):m.box((x,0,z),(.39,.435,.16),6)
    m.beam((x,0,2.03),(x*.67,0,2.77),.23,.25,4)
m.box((0,0,2.83),(4.25,.50,.34),4)
m.box((0,-.259,2.83),(1.03,.035,.18),3)
objects.append(m.finish())

m=Model('Mine_Rail')
length=math.sqrt(3)
for y in (-.63,0,.63):m.box((0,y,.035),(1.15,.22,.07),4)
for x in (-.42,.42):
    m.box((x,0,.075),(.12,length,.04),7)
    m.box((x,0,.12),(.075,length,.05),6)
    for y in (-.63,0,.63):m.box((x+.07,y,.08),(.05,.065,.03),6)
objects.append(m.finish())

m=Model('Mine_Cart')
for y in (-.57,.57):
    m.cylinder((0,y,.21),.06,1.19,6,'X')
    for x in (-.55,.55):
        m.cylinder((x,y,.21),.21,.20,6,'X')
        m.cylinder((x*1.16,y,.21),.078,.025,7,'X')
m.box((0,0,.29),(1.05,1.51,.15),6)
m.box((0,0,.40),(1.10,1.67,.10),3)
for x in (-.53,.53):
    m.box((x,0,.69),(.12,1.8,.54),4)
    m.box((x,0,.98),(.16,1.8,.08),6)
    for y in (-.65,.65):m.box((x*1.12,y,.71),(.045,.10,.54),7)
for y in (-.84,.84):
    m.box((0,y,.69),(.94,.12,.54),3)
    m.box((0,y,.98),(.90,.12,.08),6)
for x,y,z,w in [(-.22,-.38,.66,.45),(.22,-.11,.66,.46),(-.10,.33,.70,.48)]:m.rock((x,y,z),(w,w,.43),2)
m.rock((.04,.29,.87),(.21,.24,.18),8,.3)
objects.append(m.finish())

m=Model('Mine_OreCluster')
m.rock((-.19,.03,.44),(1.08,1.16,.88),0,.10)
m.rock((.40,.17,.32),(.62,.96,.64),2,-.12)
m.rock((-.36,.34,.86),(.65,.70,.68),1,-.1)
for p,s,c,r in [((-.21,-.53,.52),(.39,.29,.35),8,.1),((.17,-.38,.62),(.31,.33,.27),9,-.3),
                ((-.46,-.10,.99),(.30,.31,.30),8,.5),((.46,-.24,.37),(.31,.29,.27),9,-.2),
                ((-.05,.43,.78),(.27,.23,.35),9,.2)]:m.rock(p,s,c,r)
m.rock((.47,-.47,.13),(.50,.42,.26),0,.1)
objects.append(m.finish())

m=Model('Mine_Workstation')
# Low work shelter, a broad bench, two boxes, ore trays and a hanging pick.
for x in (-1.12,1.12):
    m.box((x,.47,.85),(.14,.15,1.70),3)
    m.beam((x,.47,1.20),(x*.70,.47,1.60),.12,.12,4)
m.box((0,.45,1.65),(2.56,.18,.15),4)
for x in (-1.13,-.68,-.23,.23,.68,1.13):m.box((x,.09,1.74),(.44,1.43,.12),5)
m.box((0,.21,.85),(2.25,.72,.16),4)
for x in (-.96,.96):
    for y in (-.04,.48):m.box((x,y,.42),(.13,.13,.84),3)
m.box((0,.26,.25),(2.16,.58,.10),5)
for x,y,z,size in [(-.72,-.56,.29,(.55,.51,.58)),(.74,-.57,.24,(.61,.55,.48))]:
    m.box((x,y,z),size,4)
    for side in (-1,1):m.box((x+side*size[0]*.30,y,z),(.07,size[1]+.015,size[2]+.02),3)
m.box((-.53,.23,.97),(.63,.43,.13),3)
for x,y,c in [(-.72,.12,8),(-.40,.25,9),(-.58,.35,8)]:m.rock((x,y,1.05),(.22,.20,.17),c)
m.beam((.72,.50,1.01),(.72,.50,1.49),.055,.055,4)
m.beam((.44,.49,1.45),(.72,.49,1.54),.065,.055,6)
m.beam((.72,.49,1.54),(.99,.49,1.45),.065,.055,6)
objects.append(m.finish())

metadata=[
    dict(asset_id=900,role='world entrance',single_hex_radius=1),
    dict(asset_id=901,role='walk-through structural timber',clear_opening_width=3.5,clear_central_height=2.45,collision='placement footprint excludes centre'),
    dict(asset_id=902,role='floor rail segment',forward_unity='+Z',length=length),
    dict(asset_id=903,role='loaded minecart'),
    dict(asset_id=904,role='copper and verdigris ore deposit'),
    dict(asset_id=905,role='miners work shelter'),
]
pipeline=runpy.run_path(str(ROOT/'Art/AssetExpansion202610/shared_pipeline.py'))
rows=pipeline['finish_batch']('Mine',scene,objects,metadata)
print(json.dumps([dict(name=r['name'],blender_xyz=r['dimensions_blender_xyz'],triangles=r['triangles'],nonmanifold=r['nonmanifold_edges']) for r in rows]))
