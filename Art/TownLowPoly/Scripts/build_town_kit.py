"""通过 Blender MCP 制作可近看的一组城镇外观；不覆盖大地图微缩建筑。"""
import bpy, math, json, runpy, ast
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y/Art/TownLowPoly')
for name in ['Source','Staging','Previews','Integration']: (ROOT/name).mkdir(parents=True,exist_ok=True)
assert 'TownLP_Studio' not in bpy.data.scenes,'城镇源作品已存在，请定向编辑'
scene=bpy.data.scenes.new('TownLP_Studio');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
masters=bpy.data.collections.new('TownLP_Masters');scene.collection.children.link(masters)
helpers=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py');MeshBuilder=helpers['MeshBuilder']
tree=ast.parse(Path('D:/Program/Unity/Project Y/Art/PawnLowPoly/Scripts/build_pawn_common.py').read_text(encoding='utf-8'))
for fn in tree.body:
    if isinstance(fn,ast.FunctionDef) and fn.name in ['prism','beam']:exec(compile(ast.Module(body=[fn],type_ignores=[]),'pawn_primitives','exec'))
objects=[]
def finish(m,name):
    obj=m.finish(name,masters);objects.append(obj);return obj
def facade(m,width,depth,height,door_x=0):
    # 实际进场放大 1.5 倍：门高 2.4 米，门宽 1.65 米；门前交互不伪装成可穿越洞口。
    m.box((0,0,.12),(width+.16,depth+.16,.24),'Stone')
    m.box((0,0,height/2+.2),(width,depth,height),'Plaster')
    y=-depth/2-.04
    for x in [-width/2,width/2]:m.box((x,y,height/2+.2),(.12,.12,height+.1),'Timber')
    for z in [.25,height*.55,height+.2]:m.box((0,y,z),(width+.13,.13,.13),'Timber')
    m.box((door_x,y-.025,.95),(1.08,.11,1.55),'Timber')
    for x in [door_x-.6,door_x+.6]:m.box((x,y-.065,1),(.14,.16,1.72),'Stone')
    m.box((door_x,y-.06,1.85),(1.34,.17,.18),'Stone')
    m.box((door_x-.33,y-.09,.98),(.08,.04,.08),'Roof')
    m.box((door_x,y-.3,.10),(1.5,.58,.20),'Stone')
    for x in [-width*.32,width*.32]:
        for z in ([2.75] if height>3 else [1.4]):
            m.box((x,y-.02,z),(.78,.09,.79),'Window')
            m.box((x,y-.08,z),(.07,.07,.82),'TimberLight')
            m.box((x,y-.08,z),(.84,.07,.07),'TimberLight')
            m.box((x,y-.1,z-.46),(1.0,.25,.12),'Timber')
    # 侧窗让街头环绕观察时仍有建筑结构。
    for x in [-width/2-.02,width/2+.02]:
        for yy in [-depth*.25,depth*.25]:m.box((x,yy,height*.64),(.07,.60,.76),'Window')
def roof(m,w,d,eave,peak):m.ridge_roof(w/2+.19,d/2+.18,eave,peak)
def barrel(m,x,y,z=0,scale=1):
    prism(m,x,y,z,.25*scale,.25*scale,.7*scale,'Timber',8,.92)
    for h in [.12,.55]:prism(m,x,y,z+h*scale,.265*scale,.265*scale,.05*scale,'RockDark',8)
def sign(m,x,y,z,kind):
    m.box((x,y+.19,z+.32),(.10,.1,.80),'Timber');m.box((x,y,z+.65),(.10,.60,.09),'Timber')
    m.box((x,y-.13,z),(.84,.12,.64),'TimberLight')
    # 标识使用几何图形；设施文字由游戏 UI 本地化显示。
    if kind=='mug':m.box((x-.07,y-.205,z),(.30,.06,.35),'Plaster');m.box((x+.17,y-.2,z),(.12,.06,.22),'Plaster')
    elif kind=='hammer':m.box((x,y-.205,z-.03),(.065,.06,.4),'Timber');m.box((x,y-.205,z+.15),(.39,.06,.13),'Stone')
    elif kind=='coin':prism(m,x,y-.22,z-.18,.17,.04,.36,'City',8)
    else:
        m.beam((x-.2,y-.2,z-.18),(x+.2,y-.2,z+.20),.08,.07,'Plaster')
        m.beam((x+.2,y-.2,z-.18),(x-.2,y-.2,z+.20),.08,.07,'Plaster')

m=MeshBuilder();facade(m,5.25,3.5,3.3);roof(m,5.25,3.5,3.6,4.85)
m.box((1.6,.5,4.1),(.52,.6,2),'Rock');m.box((1.6,.5,5.12),(.66,.72,.18),'Stone')
sign(m,-1.55,-1.96,2.05,'mug');barrel(m,2.15,-1.95,scale=.85)
finish(m,'Town_Tavern')
m=MeshBuilder();facade(m,4.2,3.4,2.6,door_x=-.55);roof(m,4.2,3.4,2.9,4)
# 铁匠铺正面侧院是可读的炉台、铁砧与木棚，保持在配置占地内。
m.box((1.45,-1.78,.55),(.90,.75,1.1),'RockDark');m.box((1.45,-2.17,.55),(.58,.05,.50),'Timber')
m.box((1.45,-2.21,.44),(.44,.03,.18),'Roof');m.box((1.45,-1.63,2.45),(.52,.50,3.3),'Rock')
m.box((-.3,-2.0,.5),(.40,.40,1),'Timber');m.box((-.3,-2.0,1.06),(.74,.36,.16),'RockDark')
sign(m,-1.58,-1.93,2.06,'hammer');finish(m,'Town_Smithy')
m=MeshBuilder();facade(m,4.7,3.4,3.05);roof(m,4.7,3.4,3.36,4.45)
# 低饱和分色雨棚和货架区别商店与住宅。
for i in range(5):m.box((-1.7+i*.85,-1.94,2.25),(.84,.52,.12),'Window' if i%2==0 else 'PlasterShade')
for x in [-1.7,1.7]:
    m.box((x,-1.94,.53),(.83,.4,1.05),'TimberLight')
    for dx in [-.22,.22]:prism(m,x+dx,-1.96,1.07,.12,.12,.19,'Shore',6)
sign(m,-1.5,-2.07,2.82,'coin');finish(m,'Town_Shop')
m=MeshBuilder();facade(m,5.5,3.65,3.6);roof(m,5.5,3.65,3.9,5.3)
for x in [-2.0,2.0]:m.box((x,-1.92,2.64),(.49,.12,1.45),'Window')
m.box((2.12,-1.98,1.12),(.96,.16,.9),'Timber');m.box((2.12,-2.08,1.12),(.72,.04,.65),'Plaster')
sign(m,-1.58,-2.02,2.15,'guild');finish(m,'Town_Guild')
m=MeshBuilder();prism(m,0,0,0,1.35,1.35,.20,'Stone',12)
prism(m,0,0,.2,1.17,1.17,.26,'RockLight',12);prism(m,0,0,.46,1.04,1.04,.025,'Water',12)
prism(m,0,0,.49,.25,.25,.77,'Stone',8,.8);prism(m,0,0,1.24,.64,.64,.17,'RockLight',10,.75)
prism(m,0,0,1.41,.43,.43,.025,'Water',10);prism(m,0,0,1.44,.11,.11,.20,'Stone',8)
finish(m,'Town_Fountain')
for name,w,d,h in [('HouseA',4.3,3.4,2.65),('HouseB',4.75,3.45,3.1)]:
    m=MeshBuilder();facade(m,w,d,h);roof(m,w,d,h+.3,h+1.42)
    for x in [-w*.24,w*.24]:m.beam((x-.45,-d/2-.12,h*.59),(x+.45,-d/2-.12,h+.15),.09,.07)
    m.box((1.25,.70,h+1.05),(.43,.50,1.25),'Rock')
    finish(m,'Town_'+name)
m=MeshBuilder()
for x in [-1.0,1.0]:
    for y in [-.55,.55]:m.box((x,y,.96),(.12,.12,1.92),'Timber')
m.box((0,0,.69),(2.1,1.25,.24),'TimberLight')
for i in range(5):m.box((-.92+i*.46,0,1.98),(.47,1.55,.13),'RoofShade' if i%2==0 else 'Plaster')
for x in [-.68,0,.68]:
    m.box((x,0,.93),(.52,.70,.23),'Timber')
    for yy in [-.15,.15]:prism(m,x,yy,1.05,.15,.15,.18,'Grass',6)
finish(m,'Town_MarketStall')
m=MeshBuilder();m.box((0,0,.60),(1.08,1.15,.13),'TimberLight')
for x in [-.52,.52]:m.box((x,0,.80),(.10,1.2,.46),'Timber')
m.box((0,.56,.80),(1.1,.10,.46),'Timber')
for x in [-.65,.65]:
    # 轮轴沿 X；几何环在 YZ 平面。
    verts=[(x+dx,math.cos(i*math.pi/4)*.36,.43+math.sin(i*math.pi/4)*.36) for dx in [-.065,.065] for i in range(8)]
    m.part(verts,[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)],'Timber')
    m.box((x*.65,-.83,.58),(.08,.67,.08),'Timber')
barrel(m,0,.05,.68,.7);finish(m,'Town_Handcart')
m=MeshBuilder();m.box((0,.15,.05),(1.6,1.0,.10),'Stone')
m.box((-.55,.22,1.05),(.10,.10,2.1),'Timber');m.box((-.55,.22,2.1),(.36,.36,.44),'Plaster')
prism(m,-.55,.22,2.3,.31,.31,.25,'Timber',4,.05)
m.box((.23,.1,.45),(1.15,.48,.12),'TimberLight');m.box((.23,.29,.75),(1.15,.10,.44),'Timber')
for x in [-.18,.62]:m.box((x,.12,.22),(.10,.35,.44),'Timber')
finish(m,'Town_LanternBench')

# 两种通用 NPC 是独立 body 部件，复用角色 Rig 与圆底座；降低手臂，避免空握武器姿势。
for artisan in [False,True]:
    m=MeshBuilder()
    for x in [-.17,.17]:
        m.box((x,-.045,.235),(.25,.43,.22),'Timber');beam(m,(x,0,.34),(x,0,.82),.105,'TimberLight' if artisan else 'Window')
    prism(m,0,0,.76,.31,.175,.57,'TimberLight' if artisan else 'RoofShade',8,1.05)
    m.box((0,0,1.31),(.18,.17,.16),'PlasterShade');prism(m,0,0,1.36,.245,.205,.42,'PlasterShade',8,.86)
    m.box((0,-.215,1.565),(.10,.085,.13),'PlasterShade')
    for x in [-.093,.093]:m.box((x,-.203,1.615),(.048,.022,.035),'Timber')
    for side in [-1,1]:
        beam(m,(side*.29,0,1.25),(side*.38,-.03,.98),.10,'TimberLight' if artisan else 'RoofShade')
        beam(m,(side*.38,-.03,.98),(side*.40,-.13,.76),.08,'PlasterShade')
        m.box((side*.40,-.13,.75),(.17,.19,.17),'PlasterShade')
    if artisan:
        m.box((0,-.20,.9),(.45,.08,.66),'Timber');m.box((0,-.25,1.15),(.50,.04,.08),'PlasterShade')
        prism(m,0,0,1.74,.255,.22,.10,'Timber',8,.80)
        beam(m,(.42,-.13,.72),(.42,-.13,1.05),.03,'Timber');m.box((.42,-.13,1.07),(.26,.10,.11),'RockDark')
    else:
        prism(m,0,0,1.70,.34,.29,.08,'TimberLight',10);prism(m,0,0,1.78,.24,.20,.18,'TimberLight',8,.6)
        m.box((0,-.20,.84),(.62,.06,.10),'Timber');m.box((.25,-.21,.76),(.18,.16,.24),'TimberLight')
    finish(m,'NPC_Artisan' if artisan else 'NPC_Resident')

export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
bpy.context.view_layer.update();report=[]
for obj in objects:
    assert all(p.area>1e-9 and not p.use_smooth for p in obj.data.polygons)
    report.append(dict(name=obj.name,dimensions_blender_xyz=list(obj.dimensions),triangles=sum(len(p.vertices)-2 for p in obj.data.polygons),materials=[m.name for m in obj.data.materials],export=export(obj.name,str(ROOT/'Staging'/(obj.name+'.fbx')))))
(ROOT/'Integration/town-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
display=bpy.data.collections.new('TownLP_Display');scene.collection.children.link(display)
for i,source in enumerate(objects):
    obj=source.copy();display.objects.link(obj);obj.location=((i%4-1.5)*7,(i//4)*6,0)
masters.hide_render=True;masters.hide_viewport=True
scene.world=bpy.data.scenes['PawnLP_Studio'].world.copy()
for name,loc,energy,size in [('Town_Key',(-6,-8,16),2200,10),('Town_Fill',(8,10,13),1600,8)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);display.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((0,5,0))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Town_Camera');cam=bpy.data.objects.new('Town_Camera',data);display.objects.link(cam)
cam.location=(16,-24,25);cam.rotation_euler=(Vector((0,5,1))-cam.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=33;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.view_settings.view_transform='AgX';scene.render.resolution_x=1800;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ROOT/'Previews/town-kit.png')
bpy.data.libraries.write(str(ROOT/'Source/TownKit.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print(json.dumps(dict(models=len(report),preview=scene.render.filepath)))
