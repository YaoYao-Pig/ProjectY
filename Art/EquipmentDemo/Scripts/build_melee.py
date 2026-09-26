"""Seven grip-local modular equipment meshes, authored through Blender MCP."""
import bpy, math, json, runpy
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y/Art/EquipmentDemo')
assert 'EquipmentMelee_Source' not in bpy.data.scenes
scene=bpy.data.scenes.new('EquipmentMelee_Source'); bpy.context.window.scene=scene
scene.unit_settings.scale_length=1
collection=bpy.data.collections.new('EquipmentMelee_Masters');scene.collection.children.link(collection)
helpers=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py')
helpers['PALETTE'].update(EqIron='424e52',EqBronze='b29a65',EqCyan='55c3be',EqAmber='e0a756')
Mesh=helpers['MeshBuilder']
for key in ['EqIron','EqBronze','EqCyan','EqAmber','RockLight','RockDark','Timber','Window']:
    assert 'M_MapLP_'+key in bpy.data.materials
objects=[]
def beam(m,a,b,r,material,sides=8,taper=1):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)))
    if u.length<.01:u=axis.cross(Vector((0,1,0)))
    u.normalize();v=axis.cross(u)
    points=[tuple(c+r*k*(math.cos(i*2*math.pi/sides)*u+math.sin(i*2*math.pi/sides)*v)) for c,k in [(a,1),(b,taper)] for i in range(sides)]
    m.part(points,[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]+[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)],material)
def blade(m,stations,depth,colors):
    vertices=[]
    for z,width in stations: vertices.extend([(-width/2,0,z),(0,-depth,z),(width/2,0,z),(0,depth,z)])
    faces=[(3,2,1,0)];materials=[colors[0]]
    for j in range(len(stations)-1):
        for i in range(4):faces.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i));materials.append(colors[i%len(colors)])
    last=(len(stations)-1)*4;faces.append(tuple(range(last,last+4)));materials.append(colors[0]);m.part(vertices,faces,materials)
def grip(m,low,high,royal):
    beam(m,(0,0,low),(0,0,high),.047 if low>-.3 else .057,'Window' if royal else 'Timber')
    z=low+.04
    while z<high:
        beam(m,(0,0,z),(0,0,z+.012),.049 if low>-.3 else .06,'EqBronze' if royal else 'EqIron');z+=.048
    beam(m,(0,0,low-.07),(0,0,low+.02),.072,'EqBronze' if royal else 'EqIron',6,.7)
def finish(m,name):
    o=m.finish('Equip_'+name,collection);objects.append(o)
    o['purpose']='grip-local weapon / detachable thruster';o['front_axis_blender']='-Y'
for name,tip,width,low,guard,royal,kind in [
 ('SwordIron',1.16,.145,-.15,.16,False,0),('SwordKnight',1.36,.18,-.17,.19,True,0),
 ('GreatswordMercenary',1.62,.24,-.32,.23,False,1),('GreatswordRoyal',1.88,.29,-.35,.25,True,1),
 ('ColossalSiege',1.92,.43,-.42,.26,False,2),('ColossalObsidian',2.12,.49,-.45,.29,True,2)]:
    m=Mesh();grip(m,low,guard,royal);depth=.032+kind*.016
    stations=[(guard+.035,width*.65),(guard+.16,width),(tip-.22,width*.8),(tip,.004)]
    if kind==2:stations=[(guard+.03,width*.65),(guard+.23,width),(tip-.14,width*.95),(tip,width*.37)]
    colors=['RockLight','RockDark'] if not (kind==2 and royal) else ['EqIron','Window']
    blade(m,stations,depth,colors)
    span=.27+kind*.13
    for sign in [-1,1]:
        beam(m,(0,0,guard),(sign*span,0,guard+(.06 if royal else -.045)),.035+kind*.01,'EqBronze' if royal else 'EqIron',6,.7)
        if royal:beam(m,(sign*span,0,guard+.06),(sign*(span+.015),0,guard+.13),.025,'EqBronze',6,.7)
    if royal:
        m.box((0,-depth-.012,guard+.15),(.09,.025,.15),'EqBronze')
        blade(m,[(guard+.12,.04),(guard+.18,.065),(guard+.25,.002)],.014,['EqCyan'])
        # An inset down the front ridge differentiates the elite silhouettes.
        m.box((0,-depth-.006,(tip+guard+.40)/2),(.027,.012,(tip-guard-.50)),'EqCyan' if kind==2 else 'EqBronze')
    if kind==2:
        # Rear mounting rail matches Unity (0,.50,-.09); no extra gameplay slots.
        m.box((0,.066,.50),(.22,.05,.32),'EqBronze' if royal else 'EqIron')
        for x in [-.145,.145]:
            m.box((x,0,guard+.24),(.085,.13,.28),'EqBronze' if royal else 'EqIron')
    finish(m,name)
m=Mesh();m.box((0,.025,0),(.27,.075,.24),'EqIron')
for x in [-.12,.12]:
    beam(m,(x,.12,-.09),(x,.12,.20),.072,'EqBronze',8)
    beam(m,(x,.12,.12),(x,.12,.23),.087,'EqIron',8,1.15)
    beam(m,(x,.12,.228),(x,.12,.235),.064,'Window',8)
    beam(m,(x,.12,.234),(x,.12,.25),.040,'EqAmber',8,.65)
    beam(m,(x,.12,-.14),(x,.12,-.085),.065,'EqIron',8)
m.box((0,.145,.025),(.12,.09,.10),'EqIron');m.box((0,.195,.025),(.07,.018,.055),'EqCyan')
finish(m,'Thruster')
bpy.context.view_layer.update()
report=[]
for o in objects:
    o.data.calc_loop_triangles();report.append({'name':o.name,'vertices':len(o.data.vertices),'triangles':len(o.data.loop_triangles),'dimensions_blender_xyz':list(o.dimensions),'materials':[m.name for m in o.data.materials]})
(ROOT/'Integration/melee-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(ROOT/'Source/EquipmentMelee.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print(json.dumps(report))
