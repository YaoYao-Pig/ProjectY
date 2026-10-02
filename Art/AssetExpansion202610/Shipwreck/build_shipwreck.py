"""Original cog-wreck kit. Execute through Blender MCP; only owns AE202610_Shipwreck."""
import bpy,bmesh,math,json,runpy
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path('D:/Program/Unity/Project Y');BASE=ROOT/'Art/AssetExpansion202610';OUT=BASE/'Shipwreck'
P=runpy.run_path(str(BASE/'shared_pipeline.py'))
G=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/mesh_helpers.py'));Mesh=G['MeshBuilder']
G['PALETTE'].update(SWWood='665646',SWPlank='8c7558',SWPale='a48b65',SWEnd='b39c75',SWDark='403d35',
 SWTar='343e3e',SWIron='4b595a',SWRust='876049',SWBronze='a78e58',SWCloth='b9b297',SWTeal='59756c',SWWater='376f7a',SWDeck='827059',SWDeckWet='776650')
REFS=json.loads((OUT/'References/references.json').read_text(encoding='utf8'))
STATIONS=[(-18,.25),(-15,2.6),(-11,4.5),(-5,5.8),(3,6.1),(10,5.0),(15,3.7)]
def width_at(y):
    assert STATIONS[0][0]<=y<=STATIONS[-1][0]
    for (a,w),(b,v) in zip(STATIONS,STATIONS[1:]):
        if a<=y<=b:return w+(v-w)*(y-a)/(b-a)

def beam(m,a,b,r,mat='SWWood',n=6,r2=None):
    a,b=Vector(a),Vector(b);q=(b-a).to_track_quat('Z','Y');v=[]
    for p,rr in [(a,r),(b,r if r2 is None else r2)]:
        for j in range(n):v.append(tuple(p+q@Vector((rr*math.cos(j*math.tau/n),rr*math.sin(j*math.tau/n),0))))
    m.part(v,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)],mat)

def boxbeam(m,a,b,w,d,mat):
    a,b=Vector(a),Vector(b);q=(b-a).to_track_quat('Z','Y');v=[]
    for p in [a,b]:
        for x,y in [(-w/2,-d/2),(w/2,-d/2),(w/2,d/2),(-w/2,d/2)]:v.append(tuple(p+q@Vector((x,y,0))))
    m.part(v,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)

def extrusion(m,poly,bottom,top,mat):
    n=len(poly);v=[(x,y,z) for z in [bottom,top] for x,y in poly]
    m.part(v,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)],mat)

def lathe(m,profile,mat,n=12,c=(0,0,0)):
    v=[(c[0]+r*math.cos(j*math.tau/n),c[1]+r*math.sin(j*math.tau/n),c[2]+z) for z,r in profile for j in range(n)]
    f=[tuple(reversed(range(n))),tuple(range((len(profile)-1)*n,len(profile)*n))]
    f.extend((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(profile)-1) for j in range(n))
    m.part(v,f,mat)

def torus(m,c,r,t,mat,plane='XY',n=24):
    v=[];k=6
    for i in range(n):
        a=i*math.tau/n
        for j in range(k):
            b=j*math.tau/k;p=((r+t*math.cos(b))*math.cos(a),(r+t*math.cos(b))*math.sin(a),t*math.sin(b))
            if plane=='XZ':p=(p[0],p[2],p[1])
            v.append(tuple(c[s]+p[s] for s in range(3)))
    m.part(v,[(i*k+j,((i+1)%n)*k+j,((i+1)%n)*k+(j+1)%k,i*k+(j+1)%k) for i in range(n) for j in range(k)],mat)

def transform(m,start=0,scale=1,offset=(0,0,0),rotation=0):
    mat=Matrix.Rotation(rotation,4,'Z')
    for i in range(start,len(m.vertices)):m.vertices[i]=tuple(mat@Vector(m.vertices[i])*scale+Vector(offset))

def hull(m,damaged=True):
    # Stave strips follow a continuous hull section; open above the deck line.
    levels=[(-2.8,.12),(-2.25,.47),(-1.2,.80),(-.12,.97),(1.05,1.0)]
    for side in [-1,1]:
        for k,((z0,f0),(z1,f1)) in enumerate(zip(levels,levels[1:])):
            for j,((y0,w0),(y1,w1)) in enumerate(zip(STATIONS,STATIONS[1:])):
                if damaged and side==1 and j==2 and k>=3:continue
                zt=z1
                if damaged and side==1 and j==3 and k==3:zt=.45
                outer=[(side*w0*f0,y0,z0),(side*w1*f0,y1,z0),(side*w1*f1,y1,zt),(side*w0*f1,y0,zt)]
                inner=[(side*max(.008,abs(x)-.20),y,z+.04) for x,y,z in outer]
                m.part(outer+inner,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],['SWWood','SWDark','SWTar','SWWood','SWPlank','SWWood'])
        # Three thick strakes emphasize the characteristic timber hull.
        for z,f in [(-1.22,.81),(-.15,.98),(1.08,1.00)]:
            for j,((y0,w0),(y1,w1)) in enumerate(zip(STATIONS,STATIONS[1:])):
                if damaged and side==1 and j==2 and z>0:continue
                boxbeam(m,(side*w0*f,y0,z),(side*w1*f,y1,z),.16,.15,'SWTar')
    # Flat, high medieval stern transom; pointed bow stem.
    x=STATIONS[-1][1]
    for z,h,w in [(-1.55,1.2,x*.72),(-.46,1.04,x*.94),(.58,1.06,x)]:m.box((0,15,z),(w*2,.28,h),'SWWood')
    boxbeam(m,(0,-18,-2.7),(0,-18,2.15),.32,.36,'SWEnd')
    boxbeam(m,(0,-18,-2.65),(0,15,-2.65),.45,.43,'SWTar')
    # Exposed ribs rise along the sides; center stays unobstructed at deck level.
    for y in [-13,-9,-4,1,6,11]:
        w=width_at(y)
        for side in [-1,1]:
            path=[(side*w*.16,y,-2.55),(side*w*.46,y,-2.05),(side*w*.77,y,-1.05),(side*(w-.23),y,.85+(y<-10)*.55)]
            for a,b in zip(path,path[1:]):boxbeam(m,a,b,.19,.24,'SWPale')

def deck(m,damaged=True):
    # Solid clipped cross-strips join without gaps. Top is navigation height 0.
    cuts=sorted(set([p[0] for p in STATIONS]+[y for y in range(-17,16)]))
    for j,(a,b) in enumerate(zip(cuts,cuts[1:])):
        wa=max(.15,width_at(a)-.24);wb=max(.15,width_at(b)-.24)
        ra=min(wa,2.7) if damaged and -10<=a and b<=-4 else wa
        rb=min(wb,2.7) if damaged and -10<=a and b<=-4 else wb
        extrusion(m,[(-wa,a),(ra,a),(rb,b),(-wb,b)],-.18,0,'SWDeckWet' if j%4==0 else 'SWDeck')
    # A small broken right rim is above inaccessible hull edge, not a floor hole.
    if damaged:
        for y in [-9.8,-7.7,-5.1]:boxbeam(m,(2.45,y,-.02),(2.94,y-.23,.02),.28,.10,'SWEnd')

def sterncastle(m):
    # Rigid ruin with blocked cabin footprint; no false traversable door.
    m.box((0,0,1.15),(5.2,4.4,2.3),'SWWood')
    m.box((0,0,2.4),(5.8,4.7,.28),'SWPlank')
    for x in [-2.68,2.68]:
        for y in [-2.05,-.65,.65,2.05]:boxbeam(m,(x,y,2.5),(x,y,3.18),.13,.13,'SWEnd')
        boxbeam(m,(x,-2.1,3.18),(x,2.1,3.18),.16,.16,'SWPlank')
    for x in [-2.2,-.9,.9,2.2]:m.box((x,-2.24,1.24),(.38,.09,.64),'SWDark')
    m.box((0,-2.23,.88),(1.1,.10,1.76),'SWDark')
    for x in [-.56,.56]:boxbeam(m,(x,-2.32,0),(x,-2.32,1.84),.12,.12,'SWPale')
    boxbeam(m,(-.62,-2.32,1.84),(.62,-2.32,1.84),.12,.12,'SWPale')
    for x in [-2.4,0,2.4]:boxbeam(m,(x,-2.30,.06),(x,-2.3,2.30),.10,.10,'SWPlank')
    for y in [-1.6,0,1.6]:boxbeam(m,(-2.65,y,.08),(2.65,y,.08),.14,.16,'SWTar')
    # Stern steering oar bracket and pale square merchant banner (no wheel/cannon).
    beam(m,(0,2.20,.75),(0,3.30,-.8),.10,'SWIron')
    m.box((0,3.35,-.45),(1.0,.18,1.6),'SWWood')

def mast(m,fallen=False):
    beam(m,(0,0,0),(.24,.12,7.2),.28,'SWWood',9,.17)
    lathe(m,[(0,.5),(.35,.47),(.42,.3)],'SWTar',10)
    boxbeam(m,(-3.6,.16,5.4),(3.5,.10,5.85),.20,.21,'SWPlank')
    # A ragged, closed-thickness square sail remains attached to yard and mast.
    contour=[(-3.4,5.35),(3.2,5.75),(2.7,4.0),(2.0,4.25),(1.8,3.40),(.8,3.70),(.25,3.2),(-.3,4.05),(-1.1,3.65),(-1.9,4.35),(-3.0,3.95)]
    n=len(contour);v=[(x,.20+d,z) for d in [-.025,.025] for x,z in contour]
    m.part(v,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)],'SWCloth')
    for x in [-3.2,3.1]:beam(m,(x,.1,5.5),(.12,-.14,2.1),.018,'SWDark',6)
    beam(m,(.24,.12,7.15),(.31,.2,7.48),.14,'SWEnd',7,.025)
    if fallen:
        rot=Matrix.Rotation(math.radians(82),4,'Y')
        for i,v in enumerate(m.vertices):m.vertices[i]=tuple(rot@Vector(v)+Vector((-3.5,0,.7)))

def bowribs(m):
    for y,w in [(-2.4,.3),(-1.4,1.4),(0,2.2),(1.6,2.65)]:
        for s in [-1,1]:
            path=[(s*.12,y,.05),(s*w*.5,y,.55),(s*w,y,1.65)]
            for a,b in zip(path,path[1:]):boxbeam(m,a,b,.20,.24,'SWEnd')
    boxbeam(m,(0,-2.5,.0),(0,1.8,.0),.25,.34,'SWWood')
    for s in [-1,1]:boxbeam(m,(s*.4,-2.3,1.4),(s*2.6,1.6,1.4),.14,.22,'SWPlank')

def rail(m):
    for x,h in [(-1.8,1.05),(-.7,.80),(.7,.38),(1.8,1.0)]:boxbeam(m,(x,0,0),(x,0,h),.14,.17,'SWWood')
    boxbeam(m,(-1.8,0,1.05),(-.45,0,.8),.18,.2,'SWPlank')
    boxbeam(m,(.4,0,.40),(1.8,0,1),.18,.2,'SWEnd')
    boxbeam(m,(-1.85,0,.23),(1.85,0,.23),.14,.16,'SWTar')

def hatch(m):
    m.box((0,0,.015),(2.2,2.6,.03),'SWDark')
    for x in [-1.1,1.1]:m.box((x,0,.12),(.2,2.8,.24),'SWPale')
    for y in [-1.3,1.3]:m.box((0,y,.12),(2.4,.2,.24),'SWPale')
    for x,end in [(-.78,.9),(-.38,.2),(.12,-.15),(.59,.83)]:
        boxbeam(m,(x,-1.2,.18),(x+.09,end,.32),.27,.08,'SWPlank')
    beam(m,(-.98,0,.3),(.96,.15,.30),.045,'SWIron')

def capstan(m):
    lathe(m,[(0,.46),(.18,.46),(.24,.3),(.9,.28),(1,.40),(1.12,.42)],'SWWood',10)
    for a in [0,math.pi/2]:
        beam(m,(-.95*math.cos(a),-.95*math.sin(a),.89),(.95*math.cos(a),.95*math.sin(a),.89),.06,'SWPale')
    for z in [.21,.77,1.07]:torus(m,(0,0,z),.32 if z<1 else .40,.024,'SWIron')

def anchor(m):
    beam(m,(0,0,.16),(0,0,1.65),.075,'SWIron',8)
    boxbeam(m,(-.7,0,1.16),(.7,0,1.16),.12,.15,'SWWood')
    for s in [-1,1]:
        beam(m,(0,0,.2),(s*.53,0,.50),.07,'SWIron')
        beam(m,(s*.53,0,.50),(s*.64,0,.80),.10,'SWRust',6,.015)
    torus(m,(0,0,1.76),.13,.033,'SWIron','XZ',16)

def crate(m,c,s):
    x,y,z=c;w,d,h=s;m.box((x,y,z+h/2),(w,d,h),'SWWood')
    for dx in [-w*.4,w*.4]:m.box((x+dx,y-d/2-.02,z+h/2),(.10,.08,h+.03),'SWPale')
    for zz in [.08,h-.08]:m.box((x,y-d/2-.025,z+zz),(w+.04,.08,.11),'SWPale')
    boxbeam(m,(x-w*.35,y-d/2-.07,z+.14),(x+w*.35,y-d/2-.07,z+h-.14),.10,.07,'SWPlank')
    for dx in [-.25,0,.25]:m.box((x+dx*w,y,z+h+.01),(.035,d,.025),'SWDark')

def barrel(m,c,scale=1):
    x,y,z=c
    profile=[(0,.34),(.10,.40),(.53,.46),(.92,.4),(1.02,.34)]
    lathe(m,[(zz*scale,r*scale) for zz,r in profile],'SWWood',12,c)
    for zz,r in [(.12,.408),(.49,.464),(.88,.412)]:
        lathe(m,[(zz*scale,r*scale),((zz+.07)*scale,r*scale)],'SWIron',12,c)
    lathe(m,[(1.025*scale,.33*scale),(1.05*scale,.33*scale)],'SWPlank',12,c)

def cargo_crates(m):
    crate(m,(-.54,0,0),(1.05,1.18,.9));crate(m,(.56,.12,0),(.85,.9,.68));crate(m,(-.45,.03,.90),(.72,.78,.56))
    m.box((.55,-.35,.38),(.25,.035,.24),'SWCloth')
def cargo_barrels(m):
    barrel(m,(-.48,0,0),1.15);barrel(m,(.49,.08,0),.90)
    for x,y in [(-.20,-.4),(.18,.30)]:m.box((x,y,.05),(.22,.3,.1),'SWTeal')
def rope(m):
    for j in range(5):torus(m,(0,0,.045+j*.007),.18+j*.065,.024,'SWPale',n=28)
    for a,b in [((.43,0,.07),(.56,-.11,.055)),((.56,-.11,.055),(.72,-.05,.03))]:beam(m,a,b,.023,'SWPale')
def bell(m):
    for x in [-.56,.56]:boxbeam(m,(x,0,0),(x,0,1.8),.12,.15,'SWWood')
    boxbeam(m,(-.70,0,1.8),(.68,0,1.8),.15,.18,'SWPlank')
    beam(m,(0,0,1.2),(0,0,1.78),.025,'SWIron')
    lathe(m,[(.69,.38),(.78,.37),(1.08,.22),(1.2,.1)],'SWBronze',16)
    lathe(m,[(.68,.31),(.70,.31)],'SWDark',16)
    beam(m,(0,0,.65),(0,0,.50),.04,'SWIron')
def debris(m):
    for a,b in [((-1,-.4,.06),(.9,.0,.09)),((-.8,.45,.12),(.95,-.23,.15)),((-.5,-.55,.19),(.25,.68,.24))]:boxbeam(m,a,b,.26,.08,'SWPlank')
    for x,y in [(-.8,0),(.2,-.15),(.6,.3)]:m.box((x,y,.035),(.16,.25,.07),'SWTeal')
def dinghy(m):
    old=len(m.vertices);hull(m,True);transform(m,old,.13,(0,0,.37))
    for y in [-.8,.45,1.1]:m.box((0,y,.38),(1.10,.23,.10),'SWPlank')
def gangplank(m):
    for i in range(7):m.box((-.96+i*.32,0,-.1),(.315,4.8,.20),'SWPlank' if i%3 else 'SWWood')
    for y in [-1.8,0,1.8]:m.box((0,y,-.24),(2.32,.16,.10),'SWTar')

def marker(m,abandoned=False):
    start=len(m.vertices);hull(m,not abandoned);deck(m,not abandoned)
    s=len(m.vertices);sterncastle(m);transform(m,s,.85,(0,12,0))
    s=len(m.vertices);mast(m);transform(m,s,1.15,(0,-1,0))
    if not abandoned:
        s=len(m.vertices);bowribs(m);transform(m,s,1,(0,-14.4,.12))
    transform(m,start,.049,(0,0,.08))

DEFS=[
 ('SW_Map_WreckMarker','暮潮号沉船标识','world_marker',lambda m:marker(m), '水线原点；33米小地图船体缩制成约1.8米的大地图标識'),
 ('SW_Map_AbandonedCog','废弃商船标识','world_marker',lambda m:marker(m,True),'完整高艉楼与残帆识别点'),
 ('SW_Hull_CogWreck','暮潮号破损船壳','ship_structure',hull,'船壳围住开放甲板，不封闭内部；甲板高度0，船底负高度'),
 ('SW_Deck_Cog','暮潮号连续甲板','ship_structure',deck,'连续无六边形缝木甲板，顶高0；导航按内缩轮廓生成'),
 ('SW_SternCastle','封闭船长艉楼','ship_structure',sterncastle,'后部高艉楼；内部不开放、占地阻挡'),
 ('SW_BowRibs','暴露船艏肋骨','ship_structure',bowribs,'折断木肋组合，放置于船艏不可达边缘'),
 ('SW_Mast_BrokenSquare','断桅与残方帆','ship_structure',mast,'单桅方帆，断口浅色木芯；最低帆缘高于3米'),
 ('SW_Mast_Fallen','横卧桅杆残骸','ship_dressing',lambda m:mast(m,True),'横卧倒桅，按完整外形阻挡，不跨主通道'),
 ('SW_Rail_Broken','断裂船舷栏杆','ship_dressing',rail,'完整低栏与参差断柱，沿甲板边缘摆放'),
 ('SW_Hatch_Collapsed','塌陷货舱口','ship_dressing',hatch,'深色有厚度舱底和断盖；整体不可行走'),
 ('SW_Capstan','木质绞盘','ship_dressing',capstan,'四臂绞盘与铁箍，船首缆绳设备'),
 ('SW_Anchor_Rusted','铁锈双爪锚','ship_dressing',anchor,'横木锚杆、双爪和吊环，保留中世纪船用轮廓'),
 ('SW_Cargo_SaltCrates','潮湿盐货箱垛','ship_dressing',cargo_crates,'三只木箱形成完整货垛，侧面盐封标签'),
 ('SW_Cargo_WetBarrels','湿木桶货组','ship_dressing',cargo_barrels,'高低双桶和少量水藻，完整铁箍'),
 ('SW_Rope_Coil','盘绕船缆','ship_dressing',rope,'粗缆五圈和散开绳尾'),
 ('SW_Bell_BrokenFrame','旧铜船钟','ship_dressing',bell,'木架铜钟、挂点与钟舌均有实体连接'),
 ('SW_Drift_Planks','漂积木板','ship_dressing',debris,'三根交错木板与少量水藻，低矮不挡视线'),
 ('SW_Boat_BrokenDinghy','破损随船小艇','ship_dressing',dinghy,'中空小艇与横座，适合船旁水面散落'),
 ('SW_Gangplank','登船木跳板','ship_structure',gangplank,'木板顶高0、实体厚0.29；宽2.24长4.8米')]

def build(rebuild=False):
    old=bpy.context.window.scene
    try:
        if rebuild:
            scene=bpy.data.scenes['AE202610_Shipwreck'];collection=bpy.data.collections['AE202610_Shipwreck_Masters']
            for o in list(collection.objects):
                assert o.name.startswith('SW_');data=o.data;bpy.data.objects.remove(o,do_unlink=True)
                if data.users==0:bpy.data.meshes.remove(data)
            bpy.context.window.scene=scene
        else:scene,collection=P['create_scene']('Shipwreck')
        objects=[];metadata=[]
        for name,title,category,fn,notes in DEFS:
            m=Mesh();fn(m);o=m.finish(name,collection);objects.append(o)
            metadata.append(dict(title=title,category=category,design_zh=notes,origin='deck plane / waterline; Blender -Y bow, +Z up; 1 unit = 1 m',
                references=REFS[:3] if category=='world_marker' or category=='ship_structure' else REFS[1:],
                history_reference={'title':'German Historical Museum — Cog','url':'https://www.dhm.de/mediathek/en/ship-types/milestones-in-the-history-of-european-shipbuilding/04-cog/','motif':'single square mast, broad merchant hull and raised castles; fantasy game scale rather than archaeological replica'},
                literature_reference={'title':'William Morris — The Sundering Flood, chapter XLIV','url':'https://www.gutenberg.org/cache/epub/25547/pg25547-images.html','motif':'river trade, cargo convoys and uncertain travel; no copied prose'},review_status='pending'))
        result=P['finish_batch']('Shipwreck',scene,objects,metadata)
        contract=dict(units='meters',hull='SW_Hull_CogWreck',deck='SW_Deck_Cog',deck_height=0,water_height=-1.15,
            hull_stations_blender_y_half_width=STATIONS,deck_stations_unity_z_half_width=[[-y,max(.15,w-.24)] for y,w in STATIONS],
            nav_margin=.65,suggested_hex_radius=1.0,deck_missing_blender_xy={'xmin':2.7,'ymin':-10,'ymax':-4},
            verified_blender_to_unity='Unity (X,Y,Z) = Blender (-X,Z,-Y), confirmed against imported asymmetric deck notch.',
            deck_missing_unity_xz={'xmax':-2.7,'zmin':4,'zmax':10,'exclude':'x < -2.7 and 4 < z < 10; use full-cell navigation margin'},
            unity_prefab_directory='Assets/DynamicAsset/AssetExpansion202610/Shipwreck/Prefabs',
            terrain_render='do not draw a ground column over the continuous deck mesh; water cells blocked and below deck',
            recommended_fixed_props=[{'name':'SW_SternCastle','relative_unity_xz':[0,-12],'blocks':'full cabin bounds'},
              {'name':'SW_Mast_BrokenSquare','relative_unity_xz':[0,1],'blocks':'mast base only; sail overhead'},
              {'name':'SW_Hatch_Collapsed','relative_unity_xz':[2.6,6],'blocks':'entire hatch'},
              {'name':'SW_Capstan','relative_unity_xz':[0,12],'blocks':'capstan bounds'}],
            note='Check imported asymmetry before integration. World marker stays within single hex, local scene uses 1:1 metres. No swimmable water or ship simulation implied.')
        (OUT/'asset_contract.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2),encoding='utf8')
        print(json.dumps({'group':'Shipwreck','models':len(result),'triangles':sum(r['triangles'] for r in result)}))
        return result
    finally:bpy.context.window.scene=old

if __name__=='__main__':build()
