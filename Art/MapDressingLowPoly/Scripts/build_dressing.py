"""通过 Blender MCP 制作二十四类米制陈设；独立场景，不修改其他资源。"""
import bpy, json, math, runpy, random
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y');OUT=ROOT/'Art/MapDressingLowPoly'
helper=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/mesh_helpers.py'));Mesh=helper['MeshBuilder']
helper['PALETTE'].update(DressLeaf='607650',DressMoss='536947',DressBone='c2b69a',DressHay='b7a06a',DressCloth='c5baa1',DressIron='565f60',DressWax='dec994',DressAmber='d3a25b',DressCrystal='68999d',DressCap='a77865',DressPetal='bfaa80')
previous=bpy.context.window.scene
scene=bpy.data.scenes.get('MapDressing_Source') or bpy.data.scenes.new('MapDressing_Source')
bpy.context.window.scene=scene;scene.unit_settings.scale_length=1
collection=bpy.data.collections.get('MapDressing_Masters')
if collection is None:collection=bpy.data.collections.new('MapDressing_Masters');scene.collection.children.link(collection)
for key,color in helper['PALETTE'].items():
    name='M_MapLP_'+key
    if name in bpy.data.materials:continue
    material=bpy.data.materials.new(name);material.use_nodes=True
    rgba=tuple(helper['srgb_linear'](int(color[i:i+2],16)/255) for i in (0,2,4))+(1,)
    material.diffuse_color=rgba;node=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value=rgba;node.inputs['Roughness'].default_value=.88;node.inputs['Metallic'].default_value=0;material['palette_srgb']='#'+color

def tube(m,a,b,r,key,n=8,top=None):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)))
    if u.length<.01:u=axis.cross(Vector((0,1,0)))
    u.normalize();v=axis.cross(u);top=r if top is None else top
    vs=[tuple(p+rad*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))) for p,rad in [(a,r),(b,top)] for i in range(n)]
    m.part(vs,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],key)

def stone(m,x,y,z,sx,sy,h,key='Rock',seed=1):
    rng=random.Random(seed);n=7
    vs=[(x+sx*rad*math.cos(i*math.tau/n),y+sy*rad*math.sin(i*math.tau/n),z+level) for rad,level in [(1,0),(.85,h*.65),(.45,h)] for i in range(n)]
    vs=[(a+rng.uniform(-.06,.06)*sx,b+rng.uniform(-.05,.05)*sy,c) for a,b,c in vs]
    faces=[tuple(reversed(range(n))),tuple(range(2*n,3*n))]
    faces += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(2) for i in range(n)]
    m.part(vs,faces,key)

def ring(m,x,y,z,r,width,h,key,n=10):
    vs=[(x+rad*math.cos(i*math.tau/n),y+rad*math.sin(i*math.tau/n),height) for height in [z,z+h] for rad in [r,r-width] for i in range(n)]
    fs=[]
    for i in range(n):
        j=(i+1)%n
        fs += [(i,j,j+2*n,i+2*n),(i+n,i+3*n,j+3*n,j+n),(i+2*n,j+2*n,j+3*n,i+3*n),(j,i,i+n,j+n)]
    m.part(vs,fs,key)

def leaf(m,a,b,width,key='DressLeaf'):
    a,b=Vector(a),Vector(b);mid=a.lerp(b,.6);side=Vector((-(b-a).y,(b-a).x,0)).normalized()*width
    m.part([tuple(a),tuple(mid+side),tuple(b),tuple(mid-side),tuple(mid+Vector((0,0,.07)))],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],key)

def wheel(m,x,y,z,r=.48):
    # 轮轴沿前后方向，车身沿长占地轴。
    tube(m,(x,y-.07,z),(x,y+.07,z),r,'Timber',10)
    tube(m,(x,y-.081,z),(x,y+.081,z),r*.67,'TimberLight',10)
    tube(m,(x,y-.1,z),(x,y+.1,z),.10,'DressIron',8)

def cart(m,broken=False):
    m.box((0,0,.66),(2.2,1.18,.15),'Timber')
    for y in [-.61,.61]:
        for z in [.84,1.06,1.28]:m.box((-.16 if broken else 0,y,z),(1.7 if broken else 2.25,.10,.16),'TimberLight')
    for x in [-1,1]:
        m.box((x,0,1),( .12,1.2,.65 if not broken else .35),'Timber')
    wheel(m,-.25,-.78,.48)
    if not broken:wheel(m,-.25,.78,.48)
    else:stone(m,.7,.65,0,.45,.23,.20,'Timber',7)
    for y in [-.4,.4]:m.beam((.7,y,.62),(2.2,y,.29),.10,.1,'Timber')
    if broken:m.beam((-1.3,0,.06),(.5,.2,1.0),.17,.22,'TimberLight')
    else:
        m.box((-.3,0,.98),(.75,.75,.5),'DressCloth');tube(m,(.6,0,.72),(.6,0,1.28),.3,'TimberLight')

def make(kind):
    m=Mesh();rng=random.Random(kind)
    if kind=='FallenLog':
        tube(m,(-2,0,.4),(1.85,.12,.42),.38,'Timber',9)
        for x in [-2.01,1.86]:tube(m,(x,0 if x<0 else .12,.4),(x+.014,0 if x<0 else .12,.4),.29,'TimberLight',9)
        tube(m,(-.4,0,.4),(.1,.55,.82),.16,'Timber',6,top=.06)
        for x in [-1.2,0,.8]:stone(m,x,-.17,.68,.35,.16,.10,'DressMoss',int((x+2)*10))
    elif kind=='Stump':
        tube(m,(0,0,.05),(.08,0,.7),.55,'Timber',9,top=.4);tube(m,(.08,0,.701),(.08,0,.72),.34,'TimberLight',9)
        for i in range(5):
            a=i*math.tau/5;tube(m,(.7*math.cos(a),.7*math.sin(a),.05),(0,0,.4),.14,'Timber',5,top=.22)
    elif kind in ['Ferns','Wildflowers']:
        for i in range(11):
            a=i*2.4;r=.3+rng.random()*.55;x,y=math.cos(a)*r,math.sin(a)*r
            if kind=='Ferns':
                leaf(m,(0,0,.08),(x,y,.4+rng.random()*.45),.16)
                for t in [.35,.6]:leaf(m,(x*t,y*t,.3),(x*t-y*.3,y*t+x*.3,.45),.08)
            else:
                h=.35+rng.random()*.45;tube(m,(x,y,.02),(x,y,h),.025,'DressLeaf',5)
                leaf(m,(x,y,.15),(x+.2,y+.1,.36),.1);stone(m,x,y,h,.12,.12,.09,'DressPetal',i)
    elif kind=='Mushrooms':
        for x,y,s in [(-.45,-.2,1),( .4,.2,.72),(.1,-.45,.5),(-.15,.45,.65)]:
            tube(m,(x,y,.03),(x,y,.5*s),.09*s,'DressBone',6)
            tube(m,(x,y,.4*s),(x,y,.65*s),.34*s,'DressCap',8,top=.09*s)
            tube(m,(x,y,.39*s),(x,y,.4*s),.32*s,'DressBone',8)
    elif kind=='Reeds':
        for i in range(13):
            x,y=rng.uniform(-.65,.65),rng.uniform(-.55,.55);h=rng.uniform(.9,1.65)
            tube(m,(x,y,.01),(x+.1,y,h),.025,'DressLeaf',5)
            tube(m,(x+.1,y,h-.28),(x+.1,y,h+.03),.075,'Timber',6)
            leaf(m,(x,y,.3),(x-.35,y+.2,h*.75),.08)
    elif kind=='Cairn':
        for i in range(5):stone(m,.08*math.sin(i),.05*math.cos(i),i*.22,.65-i*.09,.55-i*.08,.29,'RockLight' if i%2 else 'Rock',i)
    elif kind=='StandingStones':
        for i,(x,h) in enumerate([(-1.4,1.3),(0,2.4),(1.4,1.7)]):
            stone(m,x,0,0,.45,.43,h,'RockDark',i);m.box((x,-.425,h*.65),(.10,.018,.4),'DressMoss')
    elif kind=='Well':
        ring(m,0,0,0,.86,.25,.82,'Stone');ring(m,0,0,.81,.91,.25,.14,'RockLight')
        tube(m,(0,0,.18),(0,0,.19),.59,'WaterDeep',10)
        for x in [-.74,.74]:m.box((x,0,1.4),(.13,.14,1.9),'Timber')
        m.box((0,0,2.25),(1.72,.18,.18),'TimberLight');tube(m,(0,0,1),(0,0,2.23),.025,'DressHay',5)
        ring(m,0,0,.83,.18,.04,.25,'TimberLight',8)
    elif kind in ['Handcart','BrokenCart']:cart(m,kind=='BrokenCart')
    elif kind=='Haystack':
        for i,x in enumerate([-1.1,0,1.1]):stone(m,x,0,0,.85,.7,1.25 if i==1 else .95,'DressHay',i)
        for x in [-.75,.75]:m.box((x,0,1.04),(.045,1.3,.06),'Timber')
        tube(m,(0,0,.1),(0,0,1.6),.08,'Timber',6)
    elif kind=='Firewood':
        for row in range(3):
            for col in range(5-row):
                x=(col-(4-row)/2)*.51;z=.23+row*.4
                tube(m,(x,-.66,z),(x,.66,z),.24,'Timber',7)
                tube(m,(x,-.675,z),(x,-.66,z),.18,'TimberLight',7)
        for x in [-1.4,1.4]:m.box((x,0,.52),(.12,1.55,1.04),'Timber')
    elif kind=='DryingRack':
        for x in [-1.8,1.8]:m.box((x,0,1.1),(.14,.18,2.2),'Timber');m.box((x,0,.08),(.4,1.15,.16),'Timber')
        tube(m,(-1.8,0,2.06),(1.8,0,2.06),.028,'DressHay',5)
        for i,x in enumerate([-1.1,0,1.05]):
            m.box((x,0,1.5),(.8,.065,.95 if i!=1 else 1.2),'DressCloth' if i%2==0 else 'DressLeaf')
            m.box((x,0,2.06),(.06,.11,.14),'TimberLight')
    elif kind=='NoticeBoard':
        for x in [-.65,.65]:m.box((x,0,1),(.13,.15,2),'Timber')
        m.box((0,0,1.52),(1.7,.18,.95),'TimberLight');m.box((0,0,2.08),(1.95,.42,.14),'Timber')
        for i,x in enumerate([-.5,0,.5]):m.box((x,-.10,1.57+(.1 if i==1 else -.08)),(.36,.02,.45),'DressCloth')
    elif kind=='WaterTrough':
        m.box((0,0,.15),(3.5,1.05,.3),'Timber')
        for y in [-.49,.49]:m.box((0,y,.45),(3.5,.15,.62),'TimberLight')
        for x in [-1.69,1.69]:m.box((x,0,.45),(.14,1.05,.62),'TimberLight')
        m.box((0,0,.47),(3.2,.8,.03),'Water')
        for x in [-1.1,1.1]:m.box((x,0,.04),(.38,1.35,.08),'Stone')
    elif kind=='LanternPost':
        stone(m,0,0,0,.3,.3,.22,'Stone');m.box((0,0,1.45),(.13,.13,2.8),'Timber')
        m.beam((0,0,2.35),(.55,0,2.78),.08,.08,'DressIron');m.box((.35,0,2.8),(.85,.1,.1),'DressIron')
        m.box((.66,0,2.38),(.32,.32,.48),'DressAmber')
        for z in [2.1,2.65]:m.box((.66,0,z),(.45,.45,.09),'DressIron')
        for x in [.48,.84]:m.box((x,-.18,2.38),(.04,.04,.52),'DressIron')
    elif kind=='Rubble':
        for i in range(17):stone(m,rng.uniform(-1.8,1.8),rng.uniform(-.6,.6),0,rng.uniform(.18,.45),rng.uniform(.18,.38),rng.uniform(.2,.65),'RockDark' if i%3 else 'Stone',i)
        m.beam((-1.6,-.5,.1),(1.3,.3,.7),.2,.25,'Timber')
    elif kind=='Bones':
        for i in range(5):
            x,y=rng.uniform(-.5,.4),rng.uniform(-.5,.5)
            tube(m,(x,y,.12),(x+.6,y+.15,.13),.05,'DressBone',6)
            for dx in [0,.6]:stone(m,x+dx,y+dx*.25,.06,.1,.1,.15,'DressBone',i)
        stone(m,-.35,.12,.04,.25,.21,.36,'DressBone')
        for x in [-.45,-.26]:m.box((x,-.082,.24),(.065,.025,.065),'Window')
    elif kind=='Candlestand':
        tube(m,(0,0,0),(0,0,.14),.42,'DressIron');tube(m,(0,0,.1),(0,0,1.15),.06,'DressIron')
        for i in [-1,0,1]:
            x=i*.46;h=1.3 if i==0 else 1.1
            m.beam((0,0,.7),(x,0,h),.055,.055,'DressIron');tube(m,(x,0,h),(x,0,h+.07),.15,'DressIron')
            tube(m,(x,0,h+.07),(x,0,h+.32),.07,'DressWax');tube(m,(x,0,h+.32),(x,0,h+.43),.045,'DressAmber',5,top=0)
    elif kind=='ChainPillar':
        m.box((0,0,.13),(.9,.9,.26),'Stone');m.box((0,0,1.2),(.55,.55,2.15),'RockDark');m.box((0,0,2.25),(.72,.72,.18),'Stone')
        for i in range(8):ring(m,-.35+i*.06,-.36,.15+i*.21,.12,.045,.055,'DressIron',6)
        m.box((.3,-.36,1.9),(.18,.12,.12),'DressIron')
    elif kind=='MineSupport':
        for x in [-1.85,1.85]:
            m.box((x,0,1.35),(.34,.55,2.7),'Timber');m.beam((x,0,1.65),(x*.63,0,2.72),.2,.4,'TimberLight')
            m.box((x,0,.14),(.58,.8,.28),'Stone')
        m.box((0,0,2.77),(4.3,.63,.38),'TimberLight')
        m.box((.2,0,.09),(2.8,1.15,.18),'Timber')
    elif kind=='MossStatue':
        m.box((0,0,.15),(1.1,.95,.3),'Stone');stone(m,0,0,.3,.38,.32,1.1,'Rock')
        stone(m,0,0,1.35,.3,.28,.46,'Stone');m.beam((-.28,0,1.24),(-.65,0,.88),.22,.28,'RockDark')
        m.box((.42,0,1.24),(.5,.25,.3),'Rock');stone(m,-.1,-.2,.31,.44,.3,.15,'DressMoss')
        stone(m,.1,-.2,1.51,.26,.15,.12,'DressMoss',3)
    elif kind=='Crystals':
        stone(m,0,0,0,.75,.6,.23,'RockDark')
        for i,(x,y,h,r) in enumerate([(-.3,0,.9,.17),(.15,.15,1.25,.23),(.43,-.2,.62,.18),(-.38,-.3,.47,.16)]):
            tube(m,(x,y,.15),(x+.06,y,h),r,'DressCrystal',6,top=r*.8);tube(m,(x+.06,y,h),(x+.09,y,h+.3),r*.8,'DressCrystal',6,top=0)
    else:raise ValueError(kind)
    return m

kit=json.loads((OUT/'Integration/kit.json').read_text(encoding='utf-8'));models=[]
try:
    for item in kit:
        name=item['name'];old=bpy.data.objects.get(name)
        if old:
            assert old.name in collection.objects;mesh=old.data;bpy.data.objects.remove(old,do_unlink=True)
            if mesh.users==0:bpy.data.meshes.remove(mesh)
        obj=make(item['kind']).finish(name,collection);obj.data.calc_loop_triangles()
        bpy.context.view_layer.update()
        assert obj.dimensions.x <= (5 if item['large'] else 2.3) and obj.dimensions.y <= (1.95 if item['large'] else 2.3),name
        models.append(dict(name=name,assetId=item['assetId'],propId=item['propId'],dimensions=list(obj.dimensions),triangles=len(obj.data.loop_triangles),materials=[m.name for m in obj.data.materials]))
    for folder in ['Source','Staging','Previews']: (OUT/folder).mkdir(parents=True,exist_ok=True)
    bpy.data.libraries.write(str(OUT/'Source/MapDressing.blend'),{scene},fake_user=True,compress=True)
    (OUT/'Integration/models.json').write_text(json.dumps(models,ensure_ascii=False,indent=2),encoding='utf-8')
    names={name for model in models for name in model['materials']}
    (OUT/'Integration/palette.json').write_text(json.dumps({name:bpy.data.materials[name]['palette_srgb'] for name in sorted(names)},indent=2),encoding='utf-8')
    print(json.dumps({'models':len(models),'triangles':sum(x['triangles'] for x in models),'source':str(OUT/'Source/MapDressing.blend')}))
finally:bpy.context.window.scene=previous
