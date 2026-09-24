"""Author isolated equipment masters through Blender MCP; never replace another scene."""
import bpy, math, json, runpy
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/Program/Unity/Project Y/Art/EquipmentDemo')
assert 'EquipmentDemo_Source' not in bpy.data.scenes, 'Equipment source already exists; edit it explicitly'
for folder in ['Source', 'Staging', 'Integration', 'Previews']: (ROOT / folder).mkdir(parents=True, exist_ok=True)
previous = bpy.context.scene
scene = bpy.data.scenes.new('EquipmentDemo_Source')
bpy.context.window.scene = scene
scene.unit_settings.scale_length = 1
masters = bpy.data.collections.new('EquipmentDemo_Masters'); scene.collection.children.link(masters)
helper = runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py')
Mesh = helper['MeshBuilder']; palette = helper['PALETTE']
palette.update(EqBronze='b29a65', EqIron='424e52', EqCyan='55c3be', EqAmber='e0a756')
for key in ['EqBronze','EqIron','EqCyan','EqAmber']:
    name = 'M_MapLP_' + key
    assert name not in bpy.data.materials
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    sockets = {s.identifier: s for s in node.inputs}
    assert all(k in sockets for k in ['Base Color','Metallic','Roughness'])
    color = tuple(helper['srgb_linear'](int(palette[key][i:i+2],16)/255) for i in [0,2,4]) + (1,)
    sockets['Base Color'].default_value = color; sockets['Metallic'].default_value = .15
    sockets['Roughness'].default_value = .65; mat.diffuse_color = color; mat['palette_srgb'] = '#' + palette[key]
objects = []
def finish(m, name):
    obj = m.finish('Equip_' + name, masters); objects.append(obj); return obj
def beam(m, a, b, radius, material, sides=8, taper=1):
    a,b=Vector(a),Vector(b); axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)))
    if u.length < .01: u=axis.cross(Vector((0,1,0)))
    u.normalize();v=axis.cross(u)
    points=[tuple(c+r*radius*(math.cos(i*2*math.pi/sides)*u+math.sin(i*2*math.pi/sides)*v))
        for c,r in [(a,1),(b,taper)] for i in range(sides)]
    faces=[tuple(reversed(range(sides))),tuple(range(sides,sides*2))]
    faces += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    m.part(points,faces,material)
def ring(m, z, radius, thickness, height, material, sides=10):
    for i in range(sides):
        a=2*math.pi*i/sides;b=2*math.pi*(i+1)/sides
        beam(m,(math.cos(a)*radius,math.sin(a)*radius,z),(math.cos(b)*radius,math.sin(b)*radius,z),thickness,material,4)
def crystal(m, x,y,z, radius,height,material):
    points=[(x,y,z)] + [(x+radius*math.cos(i*math.pi/3),y+radius*math.sin(i*math.pi/3),z+height*.28) for i in range(6)] + [(x,y,z+height)]
    m.part(points,[(0,1+(i+1)%6,1+i) for i in range(6)]+[(7,1+i,1+(i+1)%6) for i in range(6)],material)

# The grip is the origin. Separate rune meshes retain their own socket-local origins.
m=Mesh();beam(m,(0,0,-.79),(0,0,.99),.045,'Timber',10)
for z in [-.77,-.24,.19,.73,.94]: beam(m,(0,0,z),(0,0,z+.055),.067,'EqBronze',10)
for z in [-.12,-.04,.04,.12]: ring(m,z,.047,.006,.01,'TimberLight')
for angle in [0,2*math.pi/3,4*math.pi/3]:
    x,y=math.cos(angle),math.sin(angle)
    beam(m,(x*.04,y*.04,.87),(x*.16,y*.16,1.05),.023,'EqBronze',6)
    beam(m,(x*.16,y*.16,1.05),(x*.13,y*.13,1.21),.020,'EqBronze',6)
ring(m,1.03,.145,.018,.03,'EqIron',12);crystal(m,0,0,.99,.062,.18,'WaterDeep')
finish(m,'Staff')
m=Mesh();ring(m,.02,.105,.018,.04,'EqBronze',12)
for x,y,z,h in [(-.105,0,0,.31),(.105,0,0,.31),(0,-.065,.03,.39)]:
    beam(m,(0,0,-.04),(x,y,.035),.023,'EqIron',6);crystal(m,x,y,z,.064,h,'EqCyan')
finish(m,'RuneScatter')
m=Mesh()
for z in [-.09,.09]: ring(m,z,.068,.020,.035,'EqBronze',10)
for x in [-.075,.075]: beam(m,(x,0,-.09),(x,0,.09),.016,'EqIron',6)
crystal(m,0,-.082,-.11,.042,.25,'EqAmber');finish(m,'RunePrecision')

# Fictional industrial rifle: wood stock, brass breech, faceted barrel and detachable box magazine.
m=Mesh();m.box((0,-.16,.15),(.17,.49,.20),'EqIron')
m.box((0,.31,.11),(.14,.35,.20),'Timber');m.box((0,.49,.11),(.18,.055,.24),'EqIron')
beam(m,(0,.04,.10),(0,.09,-.20),.063,'Timber',6)
beam(m,(0,-.39,.18),(0,-1.03,.18),.042,'EqIron',10)
beam(m,(0,-.99,.18),(0,-1.12,.18),.063,'EqIron',10)
beam(m,(0,-1.115,.18),(0,-1.13,.18),.033,'Window',10)
for y in [-.44,-.55,-.66]: beam(m,(0,y,.18),(0,y-.04,.18),.064,'EqBronze',10)
m.box((0,-.48,.085),(.12,.25,.11),'TimberLight')
m.box((0,-.15,.274),(.11,.18,.045),'EqBronze')
crystal(m,0,-.16,.29,.035,.10,'EqCyan')
for x in [-.092,.092]: m.box((x,-.13,.15),(.02,.17,.12),'EqBronze')
m.box((0,-.76,.26),(.03,.028,.10),'EqIron');m.box((0,.025,.282),(.07,.04,.06),'EqIron')
finish(m,'Rifle')
m=Mesh();m.box((0,0,-.12),(.105,.17,.24),'EqIron');m.box((0,0,-.235),(.125,.19,.035),'EqBronze')
for z in [-.07,-.12,-.17]:m.box((-.057,0,z),(.012,.125,.012),'TimberLight')
finish(m,'Magazine')
m=Mesh();m.box((0,0,.11),(.35,.25,.22),'Window');m.box((0,-.132,.13),(.17,.012,.09),'EqBronze')
for x in [-.10,0,.10]:
    beam(m,(x,0,.16),(x,0,.35),.032,'EqBronze',8);crystal(m,x,0,.32,.032,.06,'RockLight')
finish(m,'Ammunition')
for opened in [False,True]:
    m=Mesh();m.box((0,0,.20),(.82,.51,.40),'Timber')
    for x in [-.31,.31]:
        m.box((x,0,.21),(.055,.54,.42),'EqIron')
    m.box((0,-.276,.28),(.12,.045,.16),'EqBronze')
    if not opened:
        m.box((0,0,.44),(.84,.54,.10),'TimberLight')
        for x in [-.31,.31]:m.box((x,0,.48),(.055,.55,.06),'EqIron')
    else:
        m.box((0,.22,.66),(.84,.10,.54),'TimberLight')
        m.box((0,0,.407),(.69,.38,.02),'EqIron')
        for x in [-.31,.31]:m.box((x,.16,.66),(.055,.03,.54),'EqIron')
    finish(m,'ChestOpen' if opened else 'Chest')

# Reusable rigid arm rig: the original head/legs/torso proportions, with separate arm segments.
m=Mesh()
for x in [-.17,.17]:
    m.box((x,-.045,.235),(.25,.43,.22),'Timber');beam(m,(x,0,.34),(x,0,.82),.105,'Window')
start=len(m.vertices);beam(m,(0,0,.76),(0,0,1.30),.29,'Window',8)
m.vertices[start:]=[(x*.31/.29,y*.175/.29,z) for x,y,z in m.vertices[start:]]
m.box((0,0,1.32),(.18,.17,.16),'PlasterShade')
beam(m,(0,0,1.36),(0,0,1.78),.225,'PlasterShade',8,.86)
m.box((0,-.215,1.565),(.10,.085,.13),'PlasterShade')
for x in [-.093,.093]:m.box((x,-.203,1.615),(.048,.022,.035),'Timber')
finish(m,'PawnCore')
m=Mesh();beam(m,(0,0,0),(0,0,1),1,'Window',8,.84);finish(m,'UpperArm')
m=Mesh();beam(m,(0,0,0),(0,0,1),1,'PlasterShade',8,.86);finish(m,'Forearm')
m=Mesh();m.box((0,0,0),(.18,.18,.17),'PlasterShade');finish(m,'Hand')
bpy.context.view_layer.update()
report=[]
for obj in objects:
    assert all(p.area>1e-9 and not p.use_smooth for p in obj.data.polygons)
    report.append({'name':obj.name,'dimensions_blender_xyz':list(obj.dimensions),'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'materials':[m.name for m in obj.data.materials]})
(ROOT/'Integration/models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(ROOT/'Integration/palette.json').write_text(json.dumps({k:palette[k] for k in ['EqBronze','EqIron','EqCyan','EqAmber']},indent=2),encoding='utf-8')
bpy.data.libraries.write(str(ROOT/'Source/EquipmentDemo.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print(json.dumps({'scene':scene.name,'models':len(report),'triangles':sum(x['triangles'] for x in report),'source':str(ROOT/'Source/EquipmentDemo.blend')}))
