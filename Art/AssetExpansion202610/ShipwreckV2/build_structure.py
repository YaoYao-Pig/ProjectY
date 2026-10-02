"""Large multi-storey wreck shell and human-scale interior facilities. Blender MCP only."""
import bpy,math,json,runpy
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path('D:/Program/Unity/Project Y');BASE=ROOT/'Art/AssetExpansion202610';OUT=BASE/'ShipwreckV2'
P=runpy.run_path(str(BASE/'shared_pipeline.py'));S=runpy.run_path(str(BASE/'Shipwreck/build_shipwreck.py'))
Mesh=S['Mesh'];beam=S['beam'];boxbeam=S['boxbeam'];lathe=S['lathe'];torus=S['torus'];crate=S['crate']
S['G']['PALETTE'].update(S2Stone='837c6b',S2Hemp='b0a283',S2Cloth='a7a996',S2Copper='9d8050',S2Cabin='776652',S2Edge='918063')
REFS=json.loads((OUT/'references.json').read_text(encoding='utf8'))
STATIONS=[(-54,.75),(-45,7.8),(-33,13.5),(-15,17.4),(9,18.3),(30,15),(45,11.1)]
YS=sorted(set([y for y,w in STATIONS]+[-42,-36,-30,-27,-24,-21,-18,-12,-9,-6,-3,0,3,6,12,15,18,21,24,27,33,36,39,42]))
def width(y):
    assert -54<=y<=45
    for (a,w),(b,v) in zip(STATIONS,STATIONS[1:]):
        if a<=y<=b:return w+(v-w)*(y-a)/(b-a)
def slab(m,poly,lo,hi,mat):S['extrusion'](m,poly,lo,hi,mat)
def shell(m,levels,limits=(-54,45),gap=False,endcap=True):
    ys=sorted(set([y for y in YS if limits[0]<=y<=limits[1]]+list(limits)))
    for side in [-1,1]:
        for k,((h0,f0),(h1,f1)) in enumerate(zip(levels,levels[1:])):
            for j,(a,b) in enumerate(zip(ys,ys[1:])):
                if gap and side==1 and a>=-15 and b<=-6:continue
                w0,w1=width(a),width(b)
                outer=[(side*w0*f0,a,h0),(side*w1*f0,b,h0),(side*w1*f1,b,h1),(side*w0*f1,a,h1)]
                inner=[(side*max(.02,abs(x)-.28),y,z) for x,y,z in outer]
                m.part(outer+inner,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],['SWWood','S2Cabin','SWTar','SWWood','SWPlank','SWWood'])
        for h,f in [levels[0],levels[-1]]:
            for a,b in zip(ys,ys[1:]):
                if gap and side==1 and a>=-15 and b<=-6:continue
                boxbeam(m,(side*width(a)*f,a,h),(side*width(b)*f,b,h),.20,.22,'SWTar' if h<4 else 'SWPlank')
        for y in ys[1:-1:2]:
            if gap and side==1 and -15<y<-6:continue
            for (h0,f0),(h1,f1) in zip(levels,levels[1:]):
                boxbeam(m,(side*max(.02,width(y)*f0-.15),y,h0),(side*max(.02,width(y)*f1-.15),y,h1),.18,.24,'SWPale')
    if endcap:
        for (h0,f0),(h1,f1) in zip(levels,levels[1:]):
            for y in [-54,45]:
                if not limits[0]<=y<=limits[1]:continue
                w0,w1=width(y)*f0,width(y)*f1
                v=[(-w0,y-.15,h0),(w0,y-.15,h0),(w1,y-.15,h1),(-w1,y-.15,h1)]
                m.part(v+[(x,yy+.3,z) for x,yy,z in v],[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'SWWood')
def rim(m,z,f=1,limits=(-54,45),gap=False,inside=2.1):
    ys=sorted(set([y for y in YS if limits[0]<=y<=limits[1]]+list(limits)))
    for s in [-1,1]:
        for a,b in zip(ys,ys[1:]):
            if gap and s==1 and a>=-15 and b<=-6:continue
            wa,wb=width(a)*f,width(b)*f
            ia,ib=max(.01,wa-inside),max(.01,wb-inside)
            slab(m,[(s*ia,a),(s*wa,a),(s*wb,b),(s*ib,b)],z-.25,z+.02,'SWDeck')
def lower(m):
    shell(m,[(-3,.15),(-1.15,.56),(0,.86),(2.25,.965)])
    rim(m,0,.86,(-36,39),False,2.15)
    boxbeam(m,(0,-54,-2.9),(0,45,-2.9),.55,.6,'SWTar')
    boxbeam(m,(0,45.12,1.8),(0,47.6,-1.2),.22,.28,'SWIron')
    m.box((0,47.5,-.5),(2.2,.35,3),'SWWood')
def mainsides(m):shell(m,[(2.25,.965),(4,1.0),(5.2,1.0)],gap=True)
def forecastle(m):
    shell(m,[(5.2,1.0),(7.2,1.0),(8.4,1.0)],(-54,-27))
    rim(m,7.2,1.0,(-54,-27),False,2.1)
    boxbeam(m,(0,-54,5.2),(0,-54,9.2),.4,.38,'SWEnd')
def aftercastle(m):
    shell(m,[(5.2,1.0),(7.2,1.0),(8.4,1.0)],(27,45))
    rim(m,7.2,1.0,(27,45),False,2.1)
    for x in [-7,-3.5,0,3.5,7]:m.box((x,45.19,6.2),(.9,.1,.8),'SWDark')
def decktrim(m):rim(m,4,1.0,gap=True)
def partition(m,door=False,wide=False):
    total=4.8 if wide else 5.2;high=2.9 if wide else 2.8 if door else 2.6;thick=.35 if wide else .25
    opening=3.6 if wide else 2.4 if door else 0;clear=2.6 if wide else 2.45
    if opening:
        side=(total-opening)/2
        for sign in [-1,1]:m.box((sign*(opening/2+side/2),0,high/2),(side,thick,high),'S2Cabin')
        m.box((0,0,(clear+high)/2),(opening,thick,high-clear),'S2Cabin')
        for x in [-opening/2,opening/2]:boxbeam(m,(x,-thick*.55,0),(x,-thick*.55,high),.14,.12,'SWPale')
    else:
        for i in range(8):m.box((-total/2+(i+.5)*total/8,0,high/2),(total/8,thick,high),'SWWood' if i%4==0 else 'S2Cabin')
    for x in [-total/2,total/2]:boxbeam(m,(x,0,0),(x,0,high),.16,.22,'SWPlank')
    boxbeam(m,(-total/2,0,high),(total/2,0,high),.18,thick+.08,'SWPlank')
    if not opening:boxbeam(m,(-total/2,-.16,.16),(total/2,-.16,.16),.14,.08,'SWTar')
def hammocks(m):
    for x in [-.77,.77]:
        for y in [-1.4,1.4]:boxbeam(m,(x,y,0),(x,y,1.8),.11,.13,'SWWood')
        boxbeam(m,(x,-1.4,.13),(x,1.4,.13),.12,.12,'SWPlank')
        verts=[];ny=9;nx=5
        for thickness in [-.025,.025]:
            for j in range(ny):
                t=-1+2*j/(ny-1);y=1.16*t;z=.70+.70*t*t
                for i in range(nx):u=-1+2*i/(nx-1);verts.append((x+u*.43,y,z+.10*u*u+thickness))
        f=[];n=ny*nx
        for k in [0,n]:
            for j in range(ny-1):
                for i in range(nx-1):f.append((k+j*nx+i,k+j*nx+i+1,k+(j+1)*nx+i+1,k+(j+1)*nx+i))
        edge=list(range(nx))+[j*nx+nx-1 for j in range(1,ny)]+list(range(n-2,n-nx-1,-1))+[j*nx for j in range(ny-2,0,-1)]
        for a,b in zip(edge,edge[1:]+edge[:1]):f.append((a,b,b+n,a+n))
        m.part(verts,f,'S2Cloth')
        for s in [-1,1]:
            for dx in [-.4,.4]:beam(m,(x+dx,s*1.16,1.52),(x,s*1.4,1.77),.018,'S2Hemp')
        first=len(m.vertices);m.box((0,0,0),(.65,.32,.14),'SWCloth')
        rotation=Matrix.Rotation(math.atan(1.4*.70/(1.16**2)),4,'X')
        for k in range(first,len(m.vertices)):m.vertices[k]=tuple(rotation@Vector(m.vertices[k])+Vector((x,.70,1.02)))
    for y in [-1.4,1.4]:boxbeam(m,(-.95,y,1.8),(.95,y,1.8),.14,.14,'SWPlank')
def stove(m):
    m.box((0,0,.5),(1.9,1.1,1.0),'S2Stone')
    m.box((0,0,1.06),(2.08,1.24,.13),'SWIron')
    m.box((-.3,-.56,.42),(.8,.06,.56),'SWDark')
    for x in [-.75,.18]:boxbeam(m,(x,-.62,.12),(x,-.62,.74),.09,.09,'S2Stone')
    beam(m,(.57,.3,1.14),(.57,.3,2.72),.17,'SWIron',10)
    lathe(m,[(0,.22),(.3,.34),(.43,.31),(.46,.28)],'SWIron',12,(-.43,0,1.14))
    torus(m,(-.43,0,1.6),.3,.025,'SWIron')
    for x in [-.83,-.03]:torus(m,(x,0,1.40),.10,.024,'SWIron','XZ')
    boxbeam(m,(-1,-.52,.05),(1,-.52,.05),.13,.14,'SWTar')
def table(m):
    m.box((0,0,.79),(3.35,1.2,.16),'SWPlank')
    for x in [-1.3,1.3]:
        for y in [-.4,.4]:boxbeam(m,(x,y,0),(x,y,.72),.13,.14,'SWWood')
    for y in [-1.15,1.15]:
        m.box((0,y,.42),(3.35,.40,.12),'SWWood')
        for x in [-1.25,1.25]:boxbeam(m,(x,y,0),(x,y,.4),.15,.15,'SWPlank')
    for x in [-.8,0,.8]:m.box((x,0,.875),(.035,1.16,.008),'SWDark')
def shelves(m):
    for x in [-1.3,1.3]:boxbeam(m,(x,.2,0),(x,.2,2.25),.15,.17,'SWWood')
    for z in [.12,1.08,2.16]:m.box((0,0,z),(2.75,.88,.12),'SWPlank')
    crate(m,(-.72,0,.18),(.78,.64,.64));crate(m,(.52,0,.18),(1.05,.64,.66))
    for x in [-.74,0,.74]:crate(m,(x,0,1.14),(.56,.55,.58))
    boxbeam(m,(-1.30,.41,.20),(1.30,.41,2.20),.10,.11,'SWTar')
def desk(m):
    m.box((0,0,.82),(2.2,1.0,.14),'SWPlank')
    for x in [-.85,.85]:
        for y in [-.34,.34]:boxbeam(m,(x,y,0),(x,y,.79),.15,.15,'SWWood')
    m.box((.63,0,.6),(.64,.78,.31),'S2Cabin')
    m.box((.63,-.40,.6),(.56,.07,.24),'SWPale')
    torus(m,(.63,-.445,.6),.043,.009,'S2Copper','XZ',12)
    boxbeam(m,(-.98,.39,.91),(.99,.39,.91),.08,.08,'SWTar')
def weaponsrack(m):
    for x in [-1.05,1.05]:
        boxbeam(m,(x,0,0),(x,.1,1.85),.14,.16,'SWWood')
        boxbeam(m,(x,-.39,.09),(x,.42,.09),.16,.14,'SWPlank')
    for z in [.32,1.43]:boxbeam(m,(-1.13,.02,z),(1.13,.02,z),.14,.18,'SWPlank')
    for x in [-.7,-.35,0,.35,.7]:boxbeam(m,(x,-.02,1.42),(x,-.30,1.42),.065,.065,'SWIron')
def cage(m):
    m.box((0,0,.10),(3,3,.20),'SWPlank')
    for x in [-1.4,1.4]:
        for y in [-1.4,1.4]:boxbeam(m,(x,y,.15),(x,y,2.46),.12,.12,'SWIron')
    for a,b in [((-1.4,-1.4,0),(1.4,-1.4,0)),((1.4,-1.4,0),(1.4,1.4,0)),((1.4,1.4,0),(-1.4,1.4,0)),((-1.4,1.4,0),(-1.4,-1.4,0))]:
        for z in [.3,2.45]:boxbeam(m,(a[0],a[1],z),(b[0],b[1],z),.09,.09,'SWIron')
        for j in range(1,8):
            x=a[0]+(b[0]-a[0])*j/8;y=a[1]+(b[1]-a[1])*j/8
            beam(m,(x,y,.3),(x,y,2.45),.029,'SWIron',6)
    m.box((.45,-1.47,1.22),(.22,.12,.30),'S2Copper')
def mast(m):
    # Large square sail for the 99m hull; retain the original 1m-radius foot.
    beam(m,(0,0,0),(.5,.3,40.5),.56,'SWWood',9,.30)
    lathe(m,[(0,1.0),(.7,.94),(.84,.60)],'SWTar',10)
    boxbeam(m,(-28.8,.30,29.6),(28.0,.20,31.4),.50,.50,'SWPlank')
    contour=[(-13.6,18.75),(12.8,19.65),(10.8,10.5),(8.0,11.2),
             (7.2,8.4),(3.2,9.2),(1.0,8.0),(-1.2,10.4),
             (-4.4,9.8),(-7.6,11.4),(-12.0,10.7)]
    contour=[(x*2,8+(z-8)*2) for x,z in contour]
    n=len(contour);verts=[(x,.44+d,z) for d in [-.05,.05] for x,z in contour]
    m.part(verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+
           [(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)],'SWCloth')
    for x,z in [(-26.0,29.6),(25.6,31.2)]:beam(m,(x,.28,z),(.28,-.28,4.2),.05,'SWDark',6)
    beam(m,(.5,.3,40.4),(.62,.4,41.2),.28,'SWEnd',7,.05)

DEFS=[('S2_Hull_Lower','三倍船体·下舱外壳',lower,'船底至下舱墙，含周界窄木带；内部不封死'),
 ('S2_Hull_MainSides','主甲板分层船舷',mainsides,'下舱视角可剖切，左舷破口Z6–15'),
 ('S2_Forecastle_Sides','抬高船艏舷墙',forecastle,'高平台舷墙和周界窄带，顶层甲板7.2米'),
 ('S2_Aftcastle_Sides','高艉楼外侧船壳',aftercastle,'高艉楼、舵机与侧窗，保留内部平台'),
 ('S2_MainDeck_Trim','主甲板周界木带',decktrim,'仅2.1米周界填缝，不封楼梯井'),
 ('S2_Partition_Solid','船舱实木隔墙',lambda m:partition(m),'标准短隔墙，5.2米宽'),
 ('S2_Partition_Door','船舱通行门墙',lambda m:partition(m,True),'2.4米净宽，2.45米净高通行口'),
 ('S2_DoorFrame_Wide','货舱双人宽门框',lambda m:partition(m,True,True),'3.6米净宽，2.6米净高'),
 ('S2_HammockRack','船员双吊床',hammocks,'弧面布床、绑绳与木架，全套真人尺度'),
 ('S2_GalleyHearth','船用石炉灶',stove,'石炉、锅、火口与金属烟管'),
 ('S2_MessTable','船员长桌与双凳',table,'完整用餐设施，桌面0.87米'),
 ('S2_CargoShelves','分层货舱架',shelves,'两层木箱与斜撑，货箱均落在搁板'),
 ('S2_CaptainDesk','船长抽屉海图桌',desk,'桌面0.89米，海图与航海小物可另摆'),
 ('S2_WeaponRack','登船武具架',weaponsrack,'空挂钩与稳定木脚，沿舱壁陈列'),
 ('S2_PrisonCage','货舱铁栅笼',cage,'四面闭合铁栅和锁扣，作为阻挡陈设'),
 ('S2_Mast_Tall','远航残帆高桅',mast,'约41.2米断桅、52.8×23.3米大残帆；基座原尺寸，帆底高8米，楼下剖切隐藏')]

def build(rebuild=False):
    old=bpy.context.window.scene
    try:
        if rebuild:
            scene=bpy.data.scenes['AE202610_ShipwreckV2'];col=bpy.data.collections['AE202610_ShipwreckV2_Masters']
            for o in list(col.objects):
                assert o.name.startswith('S2_');data=o.data;bpy.data.objects.remove(o,do_unlink=True)
                if data.users==0:bpy.data.meshes.remove(data)
            bpy.context.window.scene=scene
        else:scene,col=P['create_scene']('ShipwreckV2')
        objects=[];rows=[]
        for i,(name,title,fn,note) in enumerate(DEFS):
            m=Mesh();fn(m);o=m.finish(name,col);objects.append(o)
            rows.append(dict(title=title,category='ship_multilevel_structure' if i<5 else 'ship_interior_furniture',map_asset_id=800+i,
                design_zh=note,origin='hull segments share absolute ship centre / height; furniture bottom centre',
                references=[REFS[0],REFS[2],REFS[3]] if i<8 else [REFS[0],REFS[1],REFS[2]],
                literature_reference={'title':'William Morris: The Sundering Flood, chapter XLIV','url':'https://www.gutenberg.org/cache/epub/25547/pg25547-images.html','motif':'River trade and cargo journeys; original fantasy design.'},review_status='pending'))
        rows[10]['support_surfaces']=[{'name':'tabletop','rect_unity_xz':[-1.5,1.5,-.5,.5],'height':.87}]
        rows[12]['support_surfaces']=[{'name':'tabletop','rect_unity_xz':[-1,1,-.28,.42],'height':.89}]
        result=P['finish_batch']('ShipwreckV2',scene,objects,rows)
        print(json.dumps({'assets':len(result),'triangles':sum(r['triangles'] for r in result)}))
        return result
    finally:bpy.context.window.scene=old
