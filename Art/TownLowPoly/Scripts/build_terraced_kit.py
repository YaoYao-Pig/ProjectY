"""通过 Blender MCP 制作贴合的高矮联排与上层街桥；保留原 TownKit 源作品。"""
import bpy, math, json, runpy, ast
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y/Art/TownLowPoly')
assert 'TerracedTown_Studio' not in bpy.data.scenes,'作品已存在，后续请定向修改'
scene=bpy.data.scenes.new('TerracedTown_Studio');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
masters=bpy.data.collections.new('TownLP_TerracedMasters');scene.collection.children.link(masters)
helpers=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py');MeshBuilder=helpers['MeshBuilder']
tree=ast.parse((ROOT/'Scripts/build_town_kit.py').read_text(encoding='utf-8'))
for fn in tree.body:
    if isinstance(fn,ast.FunctionDef) and fn.name=='facade':exec(compile(ast.Module(body=[fn],type_ignores=[]),'town_facade','exec'))
objects=[]
def add_house(group,x,w,depth,height,variant):
    h=MeshBuilder();facade(h,w,depth,height)
    # 高层多一圈木梁、窗与局部挑檐；邻接侧墙不留可走缝隙。
    for z in [3.0,4.65]:
        if z+.55<height:
            h.box((0,-depth/2-.07,z-.58),(w+.08,.13,.12),'Timber')
            for xx in [-w*.26,w*.26]:
                h.box((xx,-depth/2-.065,z),(.73,.13,.82),'Window')
                h.box((xx,-depth/2-.14,z),(.06,.08,.83),'TimberLight')
                h.box((xx,-depth/2-.14,z),(.80,.08,.07),'TimberLight')
    if variant%2==0:
        h.box((0,-depth/2-.12,height*.6),(w+.16,.34,.18),'TimberLight')
    h.ridge_roof(w/2+.11,depth/2+.16,height+.22,height+1.25)
    if variant==1:
        # 深灰青屋面穿插于赤陶屋顶之间，仍复用既有低饱和材质。
        h.face_materials=[h.material_keys.index('Window') if h.material_keys[i] in ['Roof','RoofShade'] else i for i in h.face_materials]
    h.box((w*.28,.52,height+.75),(.40,.44,1.12),'Rock')
    if height>4:
        h.box((0,-depth/2-.28,2.15),(1.8,.55,.16),'Timber')
        for xx in [-.81,.81]:h.box((xx,-depth/2-.5,2.47),(.08,.08,.6),'Timber')
        h.box((0,-depth/2-.51,2.73),(1.75,.09,.09),'TimberLight')
    group.part([(vx+x,vy,vz) for vx,vy,vz in h.vertices],h.faces,[h.material_keys[i] for i in h.face_materials])
for name,heights,depths in [('A',[3.0,5.8,4.1],[3.1,3.3,3.0]),('B',[5.0,3.3,6.0],[3.2,3.0,3.3]),('C',[4.4,6.2,3.4],[3.0,3.2,3.1])]:
    m=MeshBuilder();widths=[3.6,4.0,3.6];left=-sum(widths)/2
    for i,w in enumerate(widths):add_house(m,left+w/2,w,depths[i],heights[i],(i+ord(name))%3);left+=w
    obj=m.finish('Town_RowHouses'+name,masters);objects.append(obj)

# 桥面由导航地格生成，模型只提供栏杆、端柱和薄梁。X/Z 为归一跨度，Y 保持米制，桥下完全留空。
m=MeshBuilder()
for side in [-1,1]:
    y=side*.51
    for x in [-.48,-.24,0,.24,.48]:
        m.box((x,y,.52),(.014,.034,1.04),'Timber')
        m.box((x,y,1.05),(.022,.044,.10),'Stone')
    for z in [.23,.96]:m.box((0,y,z),(1.02,.026,.12),'TimberLight')
    m.box((0,side*.38,-.28),(1.02,.08,.22),'Timber')
    for x in [-.48,.48]:m.box((x,side*.45,-.20),(.05,.18,.4),'Stone')
objects.append(m.finish('Town_SkyBridge',masters))
export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
bpy.context.view_layer.update();report=[]
for obj in objects:
    assert all(p.area>1e-9 and not p.use_smooth for p in obj.data.polygons)
    report.append(dict(name=obj.name,dimensions_blender_xyz=list(obj.dimensions),triangles=sum(len(p.vertices)-2 for p in obj.data.polygons),materials=[m.name for m in obj.data.materials],export=export(obj.name,str(ROOT/'Staging'/(obj.name+'.fbx')))))
(ROOT/'Integration/terraced-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
display=bpy.data.collections.new('TerracedTown_Display');scene.collection.children.link(display)
for i,source in enumerate(objects):
    obj=source.copy();display.objects.link(obj);obj.location=((i%2)*15,(i//2)*9,0)
    if i==3:obj.scale=(11,4,1);obj.location.z=1
masters.hide_render=True;masters.hide_viewport=True
scene.world=bpy.data.scenes['TownLP_Studio'].world.copy()
for name,loc,energy,size in [('Terrace_Key',(-5,-8,18),2400,11),('Terrace_Fill',(12,13,17),1800,10)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);display.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((6,4,2))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Terrace_Camera');cam=bpy.data.objects.new('Terrace_Camera',data);display.objects.link(cam)
cam.location=(22,-29,24);cam.rotation_euler=(Vector((7,4,2))-cam.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=34;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.view_settings.view_transform='AgX'
scene.render.resolution_x=1600;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ROOT/'Previews/terraced-kit.png')
bpy.data.libraries.write(str(ROOT/'Source/TerracedTown.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print(json.dumps(dict(models=len(report),preview=scene.render.filepath)))
