"""六类首层可步入建筑；只制作独立集合，保留其他场景和旧模型。"""
import bpy,json,math,runpy
from pathlib import Path
ROOT=Path('D:/Program/Unity/Project Y');OUT=ROOT/'Art/TownExpansionLowPoly'
previous=bpy.context.window.scene
scene=bpy.data.scenes.get('TownExpansion_Source') or bpy.data.scenes.new('TownExpansion_Source')
bpy.context.window.scene=scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
collection=bpy.data.collections.get('TownExpansion_Masters')
if collection is None:collection=bpy.data.collections.new('TownExpansion_Masters');scene.collection.children.link(collection)
helper=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/mesh_helpers.py'));Mesh=helper['MeshBuilder']
helper['PALETTE'].update(InteriorBrick='896455',InteriorSlate='485b67',InteriorWood='806951',InteriorLinen='cdbd98',InteriorGlow='cb803d',
    HerbLeaf='53725a',HerbPurple='907289',Bread='c49b62',RoyalGold='b79c60',ChapelStone='bdb6a5')
for key,color in helper['PALETTE'].items():
    name='M_MapLP_'+key
    if name in bpy.data.materials:continue
    material=bpy.data.materials.new(name);material.use_nodes=True
    rgba=tuple(helper['srgb_linear'](int(color[i:i+2],16)/255) for i in (0,2,4))+(1,)
    material.diffuse_color=rgba;node=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value=rgba;node.inputs['Roughness'].default_value=.88;node.inputs['Metallic'].default_value=0;material['palette_srgb']='#'+color
kit=json.loads((OUT/'Integration/kit-design.json').read_text(encoding='utf-8'))
for item in kit:
    for name in [item['shell'],item['cover']]:
        obj=bpy.data.objects.get(name)
        if obj:
            assert obj.name in collection.objects,'对象不属于本次集合';mesh=obj.data;bpy.data.objects.remove(obj,do_unlink=True)
            if mesh.users==0:bpy.data.meshes.remove(mesh)
def cylinder(m,x,y,z,r,h,key,n=8,top=None):
    top=r if top is None else top
    vs=[(x+a*math.cos(i*math.tau/n),y+a*math.sin(i*math.tau/n),b) for a,b in [(r,z),(top,z+h)] for i in range(n)]
    m.part(vs,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],key)
def append(m,o,x=0,y=0,z=0):m.part([(a+x,b+y,c+z) for a,b,c in o.vertices],o.faces,[o.material_keys[i] for i in o.face_materials])
def roof(m,x,y,w,d,eave,peak,key):
    r=Mesh();r.ridge_roof(w,d,eave,peak)
    for i,mat in enumerate(r.material_keys):
        if mat in ['Roof','RoofShade']:r.material_keys[i]=key
    append(m,r,x,y)
def walls(m,bottom,top,key):
    z=(bottom+top)/2;h=top-bottom;hx,hy=7.75,3.55
    m.box((0,hy,z),(hx*2,.28,h),key)
    for x in [-hx,hx]:m.box((x,0,z),(.28,hy*2,h),key)
    for s in [-1,1]:m.box((s*4.625,-hy,z),(6.25,.28,h),key)
    if top>2.4:
        low=max(bottom,2.4);m.box((0,-hy,(low+top)/2),(3,.28,top-low),key)
def window(m,x,y,z,w=1.05,h=1.15):
    m.box((x,y,z+h/2),(w,.08,h),'Window')
    for dx in [-w/2,0,w/2]:m.box((x+dx,y-.05,z+h/2),(.07,.13,h+.14),'Timber')
    for zz in [z,z+h]:m.box((x,y-.05,zz),(w+.15,.13,.08),'TimberLight')
def bench(m,x,y,w=1.7):
    m.box((x,y,.48),(w,.58,.12),'TimberLight')
    for dx in [-w*.36,w*.36]:m.box((x+dx,y,.24),(.14,.46,.48),'Timber')
    m.box((x,y+.24,.89),(w,.13,.82),'Timber')
def worktable(m,x,y):
    m.box((x,y,.82),(1.7,.95,.14),'TimberLight')
    for dx in [-.65,.65]:
        for dy in [-.3,.3]:m.box((x+dx,y+dy,.39),(.12,.12,.78),'Timber')
def crate(m,x,y,z=0,w=.85):
    m.box((x,y,z+w/2),(w,w,w),'TimberLight')
    for dz in [.1,w-.1]:m.box((x,y-w/2-.02,z+dz),(w+.05,.08,.12),'Timber')
    m.beam((x-w*.4,y-w/2-.06,z+.13),(x+w*.4,y-w/2-.06,z+w-.13),.12,.06,'Timber')
def pot(m,x,y,z=0,leaf=True):
    cylinder(m,x,y,z,.21,.36,'InteriorBrick',8,top=.28);cylinder(m,x,y,z+.32,.29,.08,'InteriorBrick')
    if leaf:
        for dx,dy,h in [(-.16,0,.39),(.12,.1,.55),(0,-.10,.46)]:cylinder(m,x+dx,y+dy,z+.37,.21,h,'HerbLeaf',5,top=.02)
def shelf(m,x,y,kind):
    for z in [.15,.75,1.35,1.95]:m.box((x,y,z),(1.8,.55,.10),'TimberLight')
    for dx in [-.85,.85]:m.box((x+dx,y,1),(.12,.62,2),'Timber')
    for z in [.22,.82,1.42]:
        for j in range(5):
            xx=x-.65+j*.32
            if kind=='Herbalist':cylinder(m,xx,y,z,.11,.25,['Window','HerbPurple','InteriorLinen'][j%3],7,top=.07)
            else:cylinder(m,xx,y,z,.13,.17,'Bread',6,top=.10)
def oven(m,x,y):
    m.box((x,y,.6),(1.7,1.12,1.2),'InteriorBrick');cylinder(m,x,y,1.2,.73,.55,'InteriorBrick',10,top=.35)
    m.box((x,y-.585,.72),(.85,.08,.58),'Timber');m.box((x,y-.63,.60),(.65,.03,.19),'InteriorGlow')
    m.box((x,y-.70,.40),(1.3,.46,.14),'Stone')
def sign(m,kind):
    x,y=-2.1,-3.82;m.box((x,y,2.82),(.12,.74,.12),'Timber');m.box((x,y-.32,2.50),(.95,.10,.52),'TimberLight')
    if kind=='Bakery':
        for dx in [-.2,0,.2]:m.box((x+dx,y-.38,2.51),(.13,.04,.25),'Bread')
    elif kind=='Herbalist':m.beam((x-.22,y-.39,2.34),(x+.19,y-.39,2.68),.18,.04,'HerbLeaf')
    elif kind=='Chapel':cylinder(m,x,y-.4,2.45,.15,.09,'RoyalGold')
    else:m.box((x,y-.39,2.51),(.45,.04,.22),'Stone')
models=[]
for item in kit:
    kind=item['kind'];core,cover=Mesh(),Mesh();stone=kind in ['Chapel','Watchtower']
    # 一层门洞与配置契约一致；立柱、家具仅占用被配置阻挡的区域。
    core.box((0,0,.008),(15.5,7.1,.016),'Stone' if stone else 'InteriorWood')
    walls(core,.02,1.05,'Stone' if stone else 'PlasterShade');walls(cover,1.05,3.2,'ChapelStone' if stone else 'Plaster')
    for x in [-7.75,-5,-2.8,2.8,5,7.75]:
        core.box((x,-3.70,.53),(.17,.16,1.06),'Stone' if stone else 'Timber')
        cover.box((x,-3.70,2.12),(.17,.16,2.14),'Stone' if stone else 'Timber')
    for x in [-6.15,-3.95,3.95,6.15]:window(cover,x,-3.72,1.3)
    for x in [-1.6,1.6]:
        core.box((x,-3.71,.53),(.18,.24,1.06),'Stone');cover.box((x,-3.71,1.78),(.18,.24,1.48),'Stone')
    cover.box((0,-3.71,2.49),(3.38,.26,.18),'Stone');sign(cover,kind)
    if kind=='Bakery':
        roof(cover,-2.25,0,5.85,3.9,3.3,6.0,'Roof');roof(cover,5.0,0,3.0,3.9,3.28,4.4,'RoofShade')
        cover.box((4.2,1.8,4.6),(.85,.95,3.8),'InteriorBrick');cover.box((4.2,1.8,6.57),(1.06,1.14,.22),'Stone')
        for i in range(6):cover.box((-6.4+i*.65,-3.98,2.75),(.66,.7,.12),'InteriorLinen' if i%2 else 'Bread')
    elif kind=='Herbalist':
        roof(cover,2.4,0,5.55,3.9,3.3,6.45,'HerbLeaf');roof(cover,-5.6,0,2.5,3.9,3.28,4.35,'InteriorSlate')
        cover.box((2.5,0,5.6),(1.9,2.1,2.0),'Plaster');roof(cover,2.5,0,1.18,1.25,6.65,8,'HerbLeaf')
        for x in [-6,-4,4.8,6.5]:
            cover.box((x,-3.90,1.16),(1.1,.36,.28),'Timber');pot(cover,x,-3.87,1.30)
    elif kind=='Chapel':
        cover.box((0,0,4.10),(6.4,7.1,1.8),'ChapelStone');roof(cover,0,0,3.5,3.95,5.1,8.15,'InteriorSlate')
        for x in [-5.7,5.7]:roof(cover,x,0,2.35,3.88,3.28,4.4,'InteriorSlate')
        cover.box((-5.5,1,5.4),(2.0,2.4,4.4),'ChapelStone')
        for x in [-6.4,-4.6]:
            for y in [-.05,2.05]:cover.box((x,y,8.10),(.20,.20,1.1),'Stone')
        cylinder(cover,-5.5,1,7.6,.43,.65,'RoyalGold',10,top=.16);roof(cover,-5.5,1,1.3,1.5,8.7,10.9,'InteriorSlate')
        for x in [-2,0,2]:window(cover,x,-3.69,3.45,.75,1.3)
    elif kind=='Warehouse':
        for x in [-4.0,4.0]:roof(cover,x,0,4.0,3.95,3.4,6.0,'InteriorSlate')
        cover.box((3.9,-2.8,4.35),(2.3,1.4,1.9),'TimberLight');window(cover,3.9,-3.54,3.7,1.6,1.5)
        cover.box((3.9,-4.0,5.55),(.23,1.3,.23),'Timber');cover.box((3.9,-4.48,4.58),(.045,.045,1.7),'RockDark')
        cylinder(cover,3.9,-4.48,3.58,.19,.2,'RockDark',8)
    elif kind=='Stable':
        roof(cover,0,0,8.1,3.94,3.3,5.7,'TimberLight')
        for x in [-6,-3,0,3,6]:
            cover.beam((x-.7,-3.82,3.25),(x,-3.82,3.8),.14,.15,'Timber');cover.beam((x,-3.82,3.8),(x+.7,-3.82,3.25),.14,.15,'Timber')
        cover.box((0,0,5.9),(1.7,1.7,.55),'Timber');roof(cover,0,0,1.05,1.05,6.23,7.2,'RoofShade')
    else:
        for x in [-5.4,5.4]:roof(cover,x,0,2.75,3.85,3.35,4.6,'InteriorSlate')
        cover.box((0,0,7.45),(5.1,5.2,8.5),'Stone');cover.box((0,0,11.9),(5.6,5.7,.45),'ChapelStone')
        for z in [4.5,7.6,10.2]:
            for x in [-1.2,1.2]:window(cover,x,-2.65,z,.48,1.15)
        for x in [-2.45,-1.2,0,1.2,2.45]:
            for y in [-2.6,2.6]:cover.box((x,y,12.6),(.68,.54,1.1),'Stone')
        for y in [-1.3,0,1.3]:
            for x in [-2.55,2.55]:cover.box((x,y,12.6),(.54,.68,1.1),'Stone')
        cover.box((1.4,0,13.1),(.10,.10,3),'Timber');cover.box((.78,0,13.9),(1.25,.07,.85),'HerbPurple')
    for i,(q,r) in enumerate(item['fixtures']):
        x,y=-math.sqrt(3)*1.5*(q+r/2),-2.25*r
        if kind=='Bakery':
            if i==0:oven(core,x,y)
            elif i==1:shelf(core,x,y,kind)
            else:
                worktable(core,x,y)
                for dx in [-.4,0,.4]:cylinder(core,x+dx,y,.90,.17,.2,'Bread',8,top=.12)
        elif kind=='Herbalist':
            if i==0:
                worktable(core,x,y);pot(core,x-.45,y,.9);cylinder(core,x+.38,y,.9,.2,.36,'HerbPurple',8,top=.10)
            else:shelf(core,x,y,kind)
        elif kind=='Chapel':
            if i==0:
                core.box((x,y,.66),(1.6,.85,1.32),'ChapelStone');core.box((x,y,1.35),(1.83,1.0,.12),'Stone')
                for dx in [-.5,.5]:cylinder(core,x+dx,y,1.42,.07,.34,'RoyalGold')
            else:bench(core,x,y)
        elif kind=='Warehouse':
            crate(core,x-.46,y);crate(core,x+.46,y);crate(core,x,y,.85,.76)
        elif kind=='Stable':
            core.box((x,y,.35),(1.5,.8,.7),'Timber');core.box((x,y,.73),(1.34,.65,.16),'Bread')
            for dx in [-.82,.82]:core.box((x+dx,y+.4,.78),(.12,.12,1.56),'Timber')
            for z in [.5,1.15]:core.box((x,y+.4,z),(1.75,.13,.12),'TimberLight')
        else:
            if i==0:
                worktable(core,x,y);core.box((x,y,.905),(1.1,.65,.02),'InteriorLinen')
            elif i==1:
                for dx in [-.65,.65]:core.box((x+dx,y,.95),(.12,.5,1.9),'Timber')
                core.box((x,y,1.55),(1.5,.14,.15),'Timber')
                for dx in [-.4,0,.4]:core.box((x+dx,y-.1,1),(.07,.07,1.5),'RockDark')
            else:bench(core,x,y)
    for m,name in [(core,item['shell']),(cover,item['cover'])]:models.append(m.finish(name,collection))
for folder in ['Source','Staging','Previews','Integration']:(OUT/folder).mkdir(parents=True,exist_ok=True)
report=[]
for obj in models:
    obj.data.calc_loop_triangles();report.append(dict(name=obj.name,dimensions=list(obj.dimensions),triangles=len(obj.data.loop_triangles),materials=[m.name for m in obj.data.materials]))
(OUT/'Integration/models.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'Integration/palette.json').write_text(json.dumps({'M_MapLP_'+k:'#'+v for k,v in helper['PALETTE'].items()},indent=2),encoding='utf-8')
bpy.data.libraries.write(str(OUT/'Source/TownExpansion.blend'),{scene},fake_user=True,compress=True)
bpy.context.window.scene=previous
print(json.dumps(report))
