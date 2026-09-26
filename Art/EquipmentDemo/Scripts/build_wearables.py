"""Create only the missing inventory wearables; preserve all existing Blender scenes and source assets."""
import bpy, math, json, runpy
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y')
assert 'InventoryWearables_Source' not in bpy.data.scenes
scene=bpy.data.scenes.new('InventoryWearables_Source')
scene.unit_settings.scale_length=1
collection=bpy.data.collections.new('InventoryWearables_Masters');scene.collection.children.link(collection)
helpers=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/mesh_helpers.py'))
helpers['PALETTE'].update(EqBronze='b29a65',EqIron='424e52',EqAmber='e0a756',EqCyan='55c3be')
Mesh=helpers['MeshBuilder'];objects=[]
for key in ['EqBronze','EqIron','EqAmber','EqCyan','Timber','Window']:
    assert 'M_MapLP_'+key in bpy.data.materials
def finish(m,name):
    obj=m.finish('Equip_'+name,collection);obj['purpose']='inventory wearable, mount-local origin';objects.append(obj)
def tube(m,z0,z1,cx,r0,r1,depth,material):
    n=8;verts=[]
    for z,r in [(z0,r0),(z1,r1)]:
        for i in range(n):
            a=math.tau*i/n;verts.append((cx+r*math.cos(a),depth*math.sin(a),z))
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    m.part(verts,faces,material)
for name,gem in [('RingStrength','EqAmber'),('RingIntellect','EqCyan')]:
    m=Mesh();verts=[];n,k=16,6
    # Band in XZ plane, so it wraps the rigid hand rather than sitting as a flat disc.
    for i in range(n):
        a=math.tau*i/n
        for j in range(k):
            b=math.tau*j/k;r=.057+.011*math.cos(b)
            verts.append((r*math.cos(a),.011*math.sin(b),r*math.sin(a)))
    m.part(verts,[(i*k+j,((i+1)%n)*k+j,((i+1)%n)*k+(j+1)%k,i*k+(j+1)%k) for i in range(n) for j in range(k)],'EqBronze')
    m.box((0,-.007,.064),(.048,.035,.020),'EqIron')
    m.part([(-.028,-.017,.072),(.028,-.017,.072),(.028,.017,.072),(-.028,.017,.072),(0,0,.112)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],gem)
    finish(m,name)
m=Mesh()
for x in [-.17,.17]:
    tube(m,-.32,.21,x,.116,.14,.137,'Window')
    m.box((x,-.135,-.12),(.145,.025,.18),'Timber')
    m.box((x,-.152,-.12),(.105,.018,.12),'EqIron')
m.box((0,0,.24),(.65,.36,.10),'Timber')
m.box((0,-.16,.24),(.09,.035,.085),'EqBronze')
finish(m,'Trousers')
m=Mesh()
for x in [-.17,.17]:
    tube(m,0,.29,x,.13,.118,.14,'Timber')
    m.box((x,-.045,.005),(.27,.47,.25),'Timber')
    m.box((x,-.045,-.125),(.28,.48,.04),'EqIron')
    m.box((x,-.15,.205),(.21,.025,.065),'EqIron')
    m.box((x,-.17,.205),(.052,.020,.068),'EqBronze')
finish(m,'Boots')
bpy.context.window.scene=scene;bpy.context.view_layer.update()
report=[]
for obj in objects:
    obj.data.calc_loop_triangles()
    report.append(dict(name=obj.name,triangles=len(obj.data.loop_triangles),dimensions=list(obj.dimensions),materials=[m.name for m in obj.data.materials]))
(ROOT/'Art/EquipmentDemo/Integration/wearable-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(ROOT/'Art/EquipmentDemo/Source/InventoryWearables.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print(json.dumps(report))
