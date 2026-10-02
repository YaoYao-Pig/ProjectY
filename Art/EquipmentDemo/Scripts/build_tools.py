"""Grip-local utility weapons and a dirt mound; run through Blender MCP."""
import bpy, math, runpy, json
from pathlib import Path
from mathutils import Vector

root=Path('D:/Program/Unity/Project Y/Art/EquipmentDemo')
original=bpy.context.window.scene
scene=bpy.data.scenes.get('EquipmentTools_Source') or bpy.data.scenes.new('EquipmentTools_Source')
assert len(scene.objects)==0,'Tool masters already exist; inspect before regenerating'
bpy.context.window.scene=scene
scene.unit_settings.scale_length=1
collection=bpy.data.collections.get('EquipmentTools_Masters')
if collection is None:
    collection=bpy.data.collections.new('EquipmentTools_Masters');scene.collection.children.link(collection)
helpers=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py')
Mesh=helpers['MeshBuilder']
palette=dict(helpers['PALETTE'],EqIron='424e52',EqBronze='b29a65')
helpers['PALETTE'].update(palette)
for key in ['Timber','TimberLight','RockLight','RockDark','Earth','EqIron','EqBronze']:
    if 'M_MapLP_'+key not in bpy.data.materials:
        material=bpy.data.materials.new('M_MapLP_'+key);material.use_nodes=True
        rgb=[int(palette[key][i:i+2],16)/255 for i in (0,2,4)]
        color=tuple(helpers['srgb_linear'](x) for x in rgb)+(1,)
        material.diffuse_color=color
        shader=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        shader.inputs['Base Color'].default_value=color;shader.inputs['Roughness'].default_value=.88

def beam(mesh,a,b,r,material,sides=8):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u)
    points=[tuple(c+r*(math.cos(i*2*math.pi/sides)*u+math.sin(i*2*math.pi/sides)*v)) for c in (a,b) for i in range(sides)]
    mesh.part(points,[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]+[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)],material)
def plate(mesh,points,depth,material):
    n=len(points);vertices=[(x,y,z) for y in (-depth,depth) for x,z in points]
    mesh.part(vertices,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],material)
objects=[]
for name,tip in [('AxeWood',.80),('AxeSteel',.96),('Pickaxe',1.10),('Shovel',1.26),('Crowbar',.72)]:
    m=Mesh()
    if name!='Crowbar':
        beam(m,(0,0,-.25),(0,0,tip),.044,'TimberLight' if name=='AxeWood' else 'Timber')
        for z in [-.20,-.12,-.04]:beam(m,(0,0,z),(0,0,z+.016),.047,'EqIron')
    if name.startswith('Axe'):
        plate(m,[(-.12,tip-.12),(.15,tip-.13),(.42,tip-.30),(.49,tip+.16),(.16,tip+.11),(-.12,tip+.10)],.065,'EqIron')
        plate(m,[(.42,tip-.30),(.49,tip+.16),(.42,tip+.12),(.35,tip-.24)],.069,'RockLight')
        m.box((0,0,tip),(.16,.18,.20),'EqBronze' if name=='AxeSteel' else 'RockDark')
        if name=='AxeSteel':plate(m,[(-.10,tip-.10),(-.33,tip-.17),(-.38,tip+.12),(-.10,tip+.09)],.055,'EqIron')
    elif name=='Pickaxe':
        plate(m,[(-.55,tip-.20),(-.33,tip+.04),(0,tip+.12),(.32,tip+.02),(.58,tip-.23),(.32,tip-.07),(0,tip-.02),(-.32,tip-.06)],.052,'EqIron')
        m.box((0,0,tip),(.17,.17,.22),'RockDark')
    elif name=='Shovel':
        plate(m,[(-.12,tip-.31),(-.23,tip-.18),(-.24,tip+.10),(0,tip+.24),(.24,tip+.10),(.23,tip-.18),(.12,tip-.31)],.032,'EqIron')
        plate(m,[(-.24,tip+.10),(0,tip+.24),(.24,tip+.10),(.19,tip+.04),(0,tip+.17),(-.19,tip+.04)],.036,'RockLight')
        beam(m,(-.11,0,-.28),(.11,0,-.28),.04,'EqIron')
    else:
        points=[(0,0,-.23),(0,0,.58),(.07,0,.72),(.20,0,.76),(.28,0,.70)]
        for a,b in zip(points,points[1:]):beam(m,a,b,.038,'EqIron')
        plate(m,[(-.065,-.21),(-.065,-.34),(.065,-.34),(.065,-.21)],.018,'RockLight')
    objects.append(m.finish('Equip_'+name,collection))
m=Mesh();n=9
points=[(0,0,.48)]+[(1.10*math.cos(i*2*math.pi/n),.85*math.sin(i*2*math.pi/n),0) for i in range(n)]
m.part(points,[(0,i+1,(i+1)%n+1) for i in range(n)]+[tuple(reversed(range(1,n+1)))],'Earth')
objects.append(m.finish('Equip_DirtMound',collection))
exporter=runpy.run_path('D:/Program/Unity/Project Y/.agents/skills/blender-unity/scripts/export_static_fbx.py')
results=[]
for obj in objects:
    results.append(exporter['export_static_fbx']([obj.name],str(root/'Staging'/(obj.name+'.fbx'))))
source=root/'Source/EquipmentTools.blend'
bpy.data.libraries.write(str(source),{scene},fake_user=True)
for i,obj in enumerate(objects):obj.location.x=i*1.5
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_location=Vector((3.5,0,.5));area.spaces.active.region_3d.view_distance=9
print(json.dumps({'source':str(source),'exports':results}))
