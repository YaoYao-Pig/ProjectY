"""Original low-poly dungeon additions, executed only inside Blender via MCP.

No existing object, scene, material or project setting is replaced.
"""
from pathlib import Path
import bpy, math, json, runpy, random
from mathutils import Vector

ROOT=Path('D:/Program/Unity/Project Y')
OUT=ROOT/'Art/AssetExpansion202610/Dungeon'
pipe=runpy.run_path(str(ROOT/'Art/AssetExpansion202610/shared_pipeline.py'))
helper=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/mesh_helpers.py'))
Mesh=helper['MeshBuilder']
helper['PALETTE'].update(DGCeramic='a57357',DGCeramicShade='805a48',DGGlaze='58776a',DGGlazeShade='456052',DGIron='4f595a',DGRust='855e49',DGBronze='a79567',DGWax='d4c396',DGBone='c2b69a',DGMoss='607650',DGCloth='9a9173',DGBook='6c635b',DGEmber='c1935d',DGPaper='b9ae8e')

def tube(m,a,b,r,key,n=8,r2=None):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)))
    if u.length<.01:u=axis.cross(Vector((0,1,0)))
    u.normalize();v=axis.cross(u);r2=r if r2 is None else r2
    verts=[tuple(p+rad*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))) for p,rad in [(a,r),(b,r2)] for i in range(n)]
    m.part(verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],key)

def path_tube(m,points,r,key,n=6):
    points=[Vector(p) for p in points];verts=[]
    for k,p in enumerate(points):
        axis=(points[min(k+1,len(points)-1)]-points[max(0,k-1)]).normalized()
        u=axis.cross(Vector((0,1,0)))
        if u.length<.01:u=axis.cross(Vector((1,0,0)))
        u.normalize();v=axis.cross(u)
        verts.extend(tuple(p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))) for i in range(n))
    faces=[tuple(reversed(range(n))),tuple(range((len(points)-1)*n,len(points)*n))]
    faces += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(points)-1) for i in range(n)]
    m.part(verts,faces,key)

def solid(m,profile,key,n=12,xy=(0,0),angle=0):
    verts=[(xy[0]+r*math.cos(i*math.tau/n+angle),xy[1]+r*math.sin(i*math.tau/n+angle),z) for r,z in profile for i in range(n)]
    faces=[tuple(reversed(range(n))),tuple(range((len(profile)-1)*n,len(profile)*n))]
    faces += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(profile)-1) for i in range(n)]
    m.part(verts,faces,key)

def vessel(m,outer,inner,key,n=12,xy=(0,0),rim=None):
    # Two nested open shells, joined at rim; two separate caps provide a solid floor.
    verts=[(xy[0]+r*math.cos(i*math.tau/n),xy[1]+r*math.sin(i*math.tau/n),z) for r,z in outer+inner for i in range(n)]
    O=len(outer);I=len(inner);base=O*n
    faces=[tuple(reversed(range(n))),tuple(range(base,base+n))]
    faces += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(O-1) for i in range(n)]
    faces += [(base+j*n+i,base+(j+1)*n+i,base+(j+1)*n+(i+1)%n,base+j*n+(i+1)%n) for j in range(I-1) for i in range(n)]
    faces += [((O-1)*n+i,(O-1)*n+(i+1)%n,(O+I-1)*n+(i+1)%n,(O+I-1)*n+i) for i in range(n)]
    m.part(verts,faces,key)

def ring(m,x,y,z,r,width,h,key,n=12):
    verts=[(x+rad*math.cos(i*math.tau/n),y+rad*math.sin(i*math.tau/n),zz) for zz in [z,z+h] for rad in [r,r-width] for i in range(n)]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),(2*n+i,2*n+j,3*n+j,3*n+i),(j,i,n+i,n+j)]
    m.part(verts,faces,key)

def stone(m,x,y,z,sx,sy,h,key='Rock',seed=0):
    rng=random.Random(seed);n=7
    verts=[(x+sx*rad*math.cos(i*math.tau/n)*(1+rng.uniform(-.09,.09)),y+sy*rad*math.sin(i*math.tau/n)*(1+rng.uniform(-.09,.09)),z+level) for rad,level in [(1,0),(.88,h*.64),(.48,h)] for i in range(n)]
    m.part(verts,[tuple(reversed(range(n))),tuple(range(2*n,3*n))]+[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(2) for i in range(n)],key)

def band(m,z,r,key='DGBronze',h=.045,n=12):ring(m,0,0,z,r,.025,h,key,n)

def fitted_band(m,profile,z,h,key='DGBronze',n=14,xy=(0,0),angle=0):
    def radius(height):
        for (r0,z0),(r1,z1) in zip(profile,profile[1:]):
            if z0<=height<=z1:return r0+(r1-r0)*(height-z0)/(z1-z0)
        raise ValueError(('band outside profile',height,profile))
    x,y=xy;verts=[]
    for zz in [z,z+h]:
        for rr in [radius(zz)+.022,radius(zz)-.016]:
            verts += [(x+rr*math.cos(i*math.tau/n+angle),y+rr*math.sin(i*math.tau/n+angle),zz) for i in range(n)]
    fs=[]
    for i in range(n):
        j=(i+1)%n;fs += [(i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),(2*n+i,2*n+j,3*n+j,3*n+i),(j,i,n+i,n+j)]
    m.part(verts,fs,key)

def candle(m,x,y,z,h,r=.055):
    solid(m,[(r,z),(r,z+h*.88),(r*.91,z+h)],'DGWax',8,(x,y))
    tube(m,(x,y,z+h),(x,y,z+h+.025),.009,'Timber',5)
    for i in range(3):
        a=i*2.1;tube(m,(x+r*.94*math.cos(a),y+r*.94*math.sin(a),z+h*.65),(x+r*.94*math.cos(a),y+r*.94*math.sin(a),z+h*.92),r*.17,'DGWax',5)

def book(m,x,y,z,w=.24,h=.07,d=.31,key='DGBook'):
    m.box((x,y,z+h/2),(w,d,h*.7),'DGPaper')
    for dz in [0,h]:m.box((x,y,z+dz),(w+.025,d+.025,.02),key)
    m.box((x-w/2-.006,y,z+h/2),(.025,d+.025,h),'DGCeramicShade')

def barrel(m,xy=(0,0),r=.38,h=.88,broken=False):
    x,y=xy;n=14
    # Staves are individually tapered closed solids; iron hoops hold them together.
    for i in range(n-(3 if broken else 0)):
        a=i*math.tau/n;delta=math.tau/n*.475
        rings=[]
        for z,rad in [(0,r*.8),(.18*h,r*.94),(.5*h,r),(.82*h,r*.94),(h,r*.8)]:
            rings += [(x+rr*math.cos(aa),y+rr*math.sin(aa),z) for rr,aa in [(rad-.047,a-delta),(rad,a-delta),(rad,a+delta),(rad-.047,a+delta)]]
        faces=[(3,2,1,0),(16,17,18,19)]+[(j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i) for j in range(4) for i in range(4)]
        m.part(rings,faces,'TimberLight' if i%4 else 'Timber')
    profile=[(r*.8,0),(r*.94,.18*h),(r,.5*h),(r*.94,.82*h),(r*.8,h)]
    for z in [.12*h,.34*h,.72*h,.90*h]:fitted_band(m,profile,z,.055,'DGIron',n,xy,math.pi/n)
    solid(m,[(r*.75,.02),(r*.75,.055)],'Timber',n,xy)
    if not broken:
        for k in range(5):
            dx=(k-2)*r*.28;length=2*math.sqrt(max(.001,(r*.77)**2-dx*dx))
            m.box((x+dx,y,h-.02),(r*.27,length,.035),'TimberLight')

def make(kind):
    m=Mesh()
    if kind=='Urn_TallKeeper':
        vessel(m,[(.23,0),(.29,.12),(.37,.66),(.31,.93),(.20,1.10),(.23,1.16)],[(.19,.09),(.23,.20),(.30,.65),(.25,.9),(.145,1.10),(.175,1.16)],'DGCeramic',14)
        profile=[(.23,0),(.29,.12),(.37,.66),(.31,.93),(.20,1.10),(.23,1.16)]
        for z in [.12,.88,1.105]:fitted_band(m,profile,z,.045,'DGBronze',14)
        solid(m,[(.235,1.163),(.245,1.185),(.16,1.23),(.06,1.32)],'DGCeramicShade',14)
        solid(m,[(.055,1.32),(.055,1.37)],'DGBronze',10)
    elif kind=='Amphora_TwinHandle':
        vessel(m,[(.18,0),(.25,.10),(.36,.48),(.28,.77),(.115,.92),(.13,1.08)],[(.14,.08),(.19,.13),(.29,.48),(.23,.73),(.067,.92),(.082,1.08)],'DGCeramicShade',12)
        for s in [-1,1]:path_tube(m,[(s*.11,0,1),(s*.35,0,.96),(s*.49,0,.79),(s*.45,0,.61),(s*.31,0,.57)],.048,'DGCeramic',7)
        profile=[(.18,0),(.25,.10),(.36,.48),(.28,.77),(.115,.92),(.13,1.08)]
        fitted_band(m,profile,.1,.045,'DGCeramic',12);fitted_band(m,profile,1.03,.04,'DGCeramic',12)
    elif kind=='Jar_SquatMoss':
        vessel(m,[(.28,0),(.39,.15),(.42,.34),(.34,.54),(.25,.59),(.29,.65)],[(.23,.08),(.32,.15),(.35,.33),(.28,.49),(.19,.59),(.22,.65)],'DGGlaze',14)
        profile=[(.28,0),(.39,.15),(.42,.34),(.34,.54),(.25,.59),(.29,.65)]
        fitted_band(m,profile,.56,.045,'DGGlazeShade',14);fitted_band(m,profile,.02,.045,'DGGlazeShade',14)
        for s in [-1,1]:path_tube(m,[(s*.31,0,.47),(s*.48,0,.48),(s*.52,0,.37),(s*.4,0,.29)],.044,'DGGlazeShade')
    elif kind=='Pot_ThreeLegCook':
        vessel(m,[(.25,.18),(.36,.33),(.35,.58),(.30,.66),(.325,.71)],[(.20,.25),(.29,.34),(.285,.58),(.245,.66),(.266,.71)],'DGIron',14)
        for a in [0,math.tau/3,2*math.tau/3]:tube(m,(.28*math.cos(a),.28*math.sin(a),.02),(.24*math.cos(a),.24*math.sin(a),.27),.042,'DGIron',6,r2=.055)
        for s in [-1,1]:path_tube(m,[(s*.31,0,.58),(s*.45,0,.62),(s*.46,0,.49),(s*.33,0,.43)],.03,'DGIron')
        band(m,.65,.322,'DGRust',.04,14)
    elif kind=='Urn_HexReliquary':
        vessel(m,[(.27,0),(.30,.08),(.30,.58),(.23,.73),(.22,.82)],[(.21,.07),(.24,.12),(.24,.55),(.17,.70),(.16,.82)],'RockLight',6)
        for z,r in [(.035,.32),(.58,.31),(.80,.24)]:band(m,z,r,'DGBronze',.06,6)
        solid(m,[(.25,.87),(.26,.91),(.15,1.06),(.03,1.10)],'Rock',6)
        for a in [i*math.tau/6 for i in range(6)]:
            x,y=.272*math.cos(a),.272*math.sin(a)
            tube(m,(x,y,.28),(x,y,.46),.025,'DGBronze',4)
    elif kind=='Urn_BrokenOpen':
        # Intentionally jagged rim, but shell retains physical thickness and a closed floor.
        n=14;profile=[(.28,0),(.35,.16),(.41,.55),(.35,.77)];verts=[]
        heights=[.84,.89,.94,.92,.84,.63,.53,.58,.72,.89,.94,.87,.92,.88]
        for inner in [False,True]:
            for j,(r,z) in enumerate(profile):
                for i in range(n):
                    zz=heights[i] if j==3 else z+(.08 if inner and j==0 else 0)
                    rr=r-(.06 if inner else 0)
                    verts.append((rr*math.cos(i*math.tau/n),rr*math.sin(i*math.tau/n),zz))
        fs=[tuple(reversed(range(n))),tuple(range(4*n,5*n))]
        fs += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(3) for i in range(n)]
        fs += [(4*n+j*n+i,4*n+(j+1)*n+i,4*n+(j+1)*n+(i+1)%n,4*n+j*n+(i+1)%n) for j in range(3) for i in range(n)]
        fs += [(3*n+i,3*n+(i+1)%n,7*n+(i+1)%n,7*n+i) for i in range(n)]
        m.part(verts,fs,'DGCeramic');band(m,.16,.369,'DGCeramicShade',.06,14)
        for i,(x,y) in enumerate([(.5,-.27),(.4,-.49),(.65,-.42)]):stone(m,x,y,0,.10,.08,.04,'DGCeramicShade',i)
    elif kind=='Barrel_Ironbound':barrel(m)
    elif kind=='Barrel_BurstCache':
        barrel(m,r=.39,h=.78,broken=True)
        for i,(x,y) in enumerate([(.38,-.41),(.58,-.2),(.55,-.55)]):
            path_tube(m,[(x-.15,y,.055),(x,y-.04,.09),(x+.18,y-.11,.06)],.045,'TimberLight',4)
        for x,y in [(.35,-.36),(.5,-.18),(.22,-.48)]:solid(m,[(.06,.02),(.08,.11),(.04,.17)],'DGCeramic',8,(x,y))
    elif kind=='Crate_OpenSupplies':
        m.box((0,0,.06),(1.08,.73,.12),'Timber')
        for y in [-.345,.345]:
            for z in [.19,.38,.57]:m.box((0,y,z),(1.08,.055,.16),'TimberLight')
        for x in [-.51,.51]:
            for z in [.19,.38,.57]:m.box((x,0,z),(.055,.69,.16),'TimberLight')
            for y in [-.31,.31]:m.box((x,y,.37),(.065,.075,.66),'Timber')
        for x in [-.30,0,.30]:
            vessel(m,[(.08,.13),(.12,.33),(.075,.45),(.075,.50)],[(.05,.2),(.075,.33),(.04,.45),(.04,.50)],'DGCeramic',8,(x,.05))
        book(m,.18,-.15,.19,.24,.12,.30)
    elif kind=='Shelf_ScrollArchive':
        for x in [-.65,.65]:m.box((x,0,.76),(.09,.4,1.52),'Timber')
        for z in [.10,.64,1.20,1.50]:m.box((0,0,z),(1.4,.46,.065),'TimberLight')
        m.box((0,.18,.80),(1.25,.035,1.38),'Timber')
        for i in range(6):
            x=-.48+i*.18;m.box((x,-.015,.35),(.115,.30,.40 if i%2 else .34),'DGBook' if i%2 else 'DGCeramicShade')
            m.box((x,-.172,.38),(.06,.01,.05),'DGBronze')
        for i in range(4):tube(m,(-.5+i*.28,-.12,.7575),(-.5+i*.28,.14,.7575),.085,'DGPaper',10)
        book(m,-.30,0,1.25,.33,.10,.32);book(m,.16,0,1.24,.35,.08,.33)
    elif kind=='Shelf_CandleSconce':
        m.box((0,.17,.78),(.25,.07,.80),'Timber')
        m.box((0,-.02,.98),(.86,.49,.085),'TimberLight')
        for x in [-.25,.25]:path_tube(m,[(x,.16,.63),(x,-.18,.94),(x,.16,.94)],.035,'DGIron')
        for x,h in [(-.27,.16),(-.09,.31),(.11,.22),(.28,.11)]:candle(m,x,-.02,1.025,h,.065)
    elif kind=='Candles_OfferingCluster':
        solid(m,[(.47,0),(.47,.07),(.39,.11)],'Rock',10)
        for x,y,h,r in [(-.20,-.06,.32,.08),(.02,.13,.48,.08),(.23,.04,.20,.07),(.02,-.20,.13,.06)]:candle(m,x,y,.115,h,r)
        for x,y in [(-.29,.2),(.24,-.20)]:stone(m,x,y,.105,.075,.06,.02,'DGWax')
    elif kind=='Post_Shackles':
        m.box((0,0,.08),(.66,.58,.16),'Stone');m.box((0,0,.78),(.21,.22,1.40),'Timber')
        for z in [.26,1.13]:m.box((0,0,z),(.245,.255,.065),'DGIron')
        for s in [-1,1]:
            pts=[(s*.10,-.1,1.08),(s*.27,-.16,.99),(s*.35,-.18,.77),(s*.32,-.18,.56)]
            path_tube(m,pts,.020,'DGIron')
            ring(m,s*.32,-.18,.47,.13,.025,.055,'DGIron',10)
    elif kind=='Rack_MinerTools':
        for x in [-.51,.51]:m.box((x,.09,.71),(.08,.13,1.42),'Timber');m.box((x,0,.045),(.22,.55,.09),'Timber')
        for z in [.43,1.15]:m.box((0,.06,z),(1.1,.13,.09),'TimberLight')
        for x in [-.30,.29]:
            tube(m,(x,-.10,.08),(x+.09,-.10,1.28),.035,'TimberLight',8)
        path_tube(m,[(-.65,-.1,1.15),(-.30,-.1,1.29),(.02,-.1,1.20)],.065,'DGIron',6)
        m.box((.29,-.10,.24),(.23,.055,.31),'DGIron')
    elif kind=='Bucket_RopeWell':
        vessel(m,[(.21,0),(.28,.49)],[(.16,.06),(.225,.49)],'TimberLight',12)
        for z,r in [(.04,.228),(.38,.279)]:band(m,z,r,'DGIron',.055,12)
        path_tube(m,[(-.27,0,.40),(-.29,0,.65),(-.19,0,.83),(.19,0,.83),(.29,0,.65),(.27,0,.40)],.024,'DGIron')
        for j in range(4):
            path_tube(m,[(.38+( .20+j*.018)*math.cos(i*math.tau/18),(.20+j*.018)*math.sin(i*math.tau/18),.027+j*.017) for i in range(19)],.018,'DGCloth',5)
    elif kind=='Debris_MossMasonry':
        for i,(x,y,sx,sy,h) in enumerate([(-.40,.04,.42,.32,.30),(.17,.14,.40,.28,.23),(.49,-.13,.26,.23,.19),(-.08,-.30,.25,.16,.11)]):
            stone(m,x,y,0,sx,sy,h,'Rock' if i%2 else 'Stone',i)
            stone(m,x-.04,y,h*.84,sx*.68,sy*.68,.055,'DGMoss',i+10)
        path_tube(m,[(-.62,.26,.04),(-.14,.34,.21),(.16,.22,.21),(.52,.23,.04)],.045,'Timber',7)
    elif kind=='Marker_BrokenPilgrim':
        m.box((0,0,.07),(.85,.66,.14),'Rock')
        # Broken asymmetric slab with a simple inset icon made from a sun and short ray.
        vs=[(-.27,-.11,.14),(.26,-.11,.14),(.26,-.11,.93),(.08,-.11,1.07),(-.27,-.11,.98),(-.27,.11,.14),(.26,.11,.14),(.26,.11,.93),(.08,.11,1.07),(-.27,.11,.98)]
        m.part(vs,[(4,3,2,1,0),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)],'Stone')
        tube(m,(0,-.123,.68),(0,-.147,.68),.105,'DGBronze',8)
        m.box((0,-.135,.44),(.045,.018,.24),'DGBronze')
        candle(m,-.27,-.20,.14,.21);candle(m,.27,-.18,.14,.12)
        stone(m,.23,.10,.15,.13,.13,.045,'DGMoss',1)
    elif kind=='Lectern_ForgottenLedger':
        m.box((0,0,.065),(.66,.52,.13),'Timber');m.box((0,.06,.53),(.17,.19,.96),'Timber')
        vs=[(-.46,-.30,.87),(.46,-.30,.87),(.46,.28,1.15),(-.46,.28,1.15),(-.46,-.30,.95),(.46,-.30,.95),(.46,.28,1.23),(-.46,.28,1.23)]
        m.part(vs,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'TimberLight')
        # Open book follows slope; closed page wedges avoid paper-like single-sided faces.
        for s in [-1,1]:
            verts=[(0,-.22,1.025),(s*.35,-.22,1.06),(s*.35,.20,1.266),(0,.20,1.23)]
            verts += [(x,y,z-.035) for x,y,z in verts]
            m.part(verts,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'DGPaper')
        m.box((0,-.305,.98),(.80,.055,.07),'Timber')
    elif kind=='Stool_SackRest':
        solid(m,[(.36,.46),(.36,.54)],'TimberLight',10)
        for a in [0,math.tau/3,2*math.tau/3]:tube(m,(.33*math.cos(a),.33*math.sin(a),0),(.23*math.cos(a),.23*math.sin(a),.47),.042,'Timber',6)
        solid(m,[(.20,.545),(.27,.64),(.24,.84),(.11,.93),(.075,1.00)],'DGCloth',9)
        band(m,.94,.11,'Timber',.035,9)
        path_tube(m,[(-.06,0,.96),(-.14,.03,1.045),(-.18,.01,1.075)],.043,'DGCloth',5)
        path_tube(m,[(.06,0,.96),(.12,-.025,1.045),(.17,-.03,1.055)],.035,'DGCloth',5)
    elif kind=='Grate_RubbleDrain':
        for x in [-.61,.61]:m.box((x,0,.065),(.20,1.17,.13),'Rock')
        for y in [-.53,.53]:m.box((0,y,.065),(1.05,.18,.13),'Rock')
        for x in [-.42,-.21,0,.21,.42]:m.box((x,0,.065),(.036,.93,.065),'DGIron')
        for y in [-.32,.32]:m.box((0,y,.055),(.94,.036,.060),'DGIron')
        for i,(x,y) in enumerate([(-.53,.47),(.58,.25),(.29,.51)]):stone(m,x,y,.13,.13,.10,.11,'RockDark',i)
        for x,y in [(-.49,-.41),(.43,.41)]:stone(m,x,y,.13,.15,.10,.025,'DGMoss')
    else:raise KeyError(kind)
    return m

SPECS=[
('Urn_TallKeeper','守墓人的长颈灰陶罐','vessel',['skyrim_altar','skyrim_ruunvald'],'Narrow closed ceremonial lid, tapered shoulder, restrained bronze collar.'),
('Amphora_TwinHandle','双耳运水陶瓶','vessel',['ds3_catacombs','ds3_dungeon'],'Two large continuous handles, narrow open neck and pointed shoulder.'),
('Jar_SquatMoss','青釉矮腹苔罐','vessel',['ds3_catacombs','skyrim_ruunvald'],'Low wide belly, thick open lip, small side handles and muted green glaze.'),
('Pot_ThreeLegCook','三足宿营铁锅','vessel',['ds3_dungeon','ds3_catacombs'],'Three stable feet, dark cast iron body and broad hollow cooking mouth.'),
('Urn_HexReliquary','六棱骨灰匣','vessel',['skyrim_altar','skyrim_ruunvald'],'Hexagonal stone silhouette, raised bronze bands and faceted sealed lid.'),
('Urn_BrokenOpen','破口祭灰罐','vessel',['skyrim_altar','ds3_catacombs'],'Large intentional chipped opening with real shell thickness and fallen sherds.'),
('Barrel_Ironbound','铁箍酒桶','storage',['ds3_storage','ds3_wood'],'Individual curved tapered staves, multiple iron hoops and fitted plank head.'),
('Barrel_BurstCache','破桶与散落小瓶','storage',['ds3_storage','ds3_wood'],'Missing front staves expose inner volume; separate discarded boards and small jars.'),
('Crate_OpenSupplies','敞口补给木箱','storage',['ds3_storage','ds3_wood'],'Board-built open crate contains visible hollow bottles and ledger.'),
('Shelf_ScrollArchive','残存卷宗架','archive',['skyrim_library','skyrim_lectern'],'Four timber levels, thick supports, readable books and rolled parchments.'),
('Shelf_CandleSconce','木托壁烛架','ritual',['ds3_dungeon','skyrim_ruunvald'],'Wall-mounted plank with iron support brackets and varied wax heights.'),
('Candles_OfferingCluster','供奉残烛台','ritual',['skyrim_altar','skyrim_ruunvald'],'Low stone tray supports varied melted candles, wax puddles and visible wicks.'),
('Post_Shackles','废牢拘束柱','prison',['ds3_dungeon','ds3_catacombs'],'Timber and iron collar construction with hanging paired metal shackles.'),
('Rack_MinerTools','矿工工具架','storage',['ds3_storage','ds3_wood'],'Stable rack holds a continuous pick head and a separate broad shovel blade.'),
('Bucket_RopeWell','木水桶与盘绳','storage',['ds3_storage','ds3_wood'],'Open bucket, thin hoop bands, continuous high handle and coiled rope.'),
('Debris_MossMasonry','覆苔倒塌砌石','ruin',['skyrim_moss','ds3_dungeon'],'Large coherent masonry fragments, top-growing moss and a single broken root.'),
('Marker_BrokenPilgrim','断角朝圣墓碑','ritual',['skyrim_altar','ds3_catacombs'],'Asymmetric broken grave slab, simple bronze sun mark and candles on stable base.'),
('Lectern_ForgottenLedger','遗忘账册讲台','archive',['skyrim_lectern','skyrim_library'],'Tilted reading surface, supported central post and thick open pages.'),
('Stool_SackRest','三脚凳与口粮袋','storage',['ds3_wood','ds3_storage'],'Three functional splayed legs support a stool and tied faceted cloth sack.'),
('Grate_RubbleDrain','落石排水铁栅','ruin',['ds3_dungeon','skyrim_moss'],'Recessed iron lattice surrounded by thick stone frame, few broken masonry corners.'),
]

def build():
    previous=bpy.context.window.scene
    scene,collection=pipe['create_scene']('Dungeon');objects=[];metadata=[]
    refs={x['id']:x for x in json.loads((OUT/'references.json').read_text(encoding='utf8'))}
    for kind,label,category,reference_ids,notes in SPECS:
        name='DG_'+kind
        mesh_builder=make(kind)
        lo=[min(v[i] for v in mesh_builder.vertices) for i in range(3)]
        hi=[max(v[i] for v in mesh_builder.vertices) for i in range(3)]
        origin=((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2])
        mesh_builder.vertices=[tuple(v[i]-origin[i] for i in range(3)) for v in mesh_builder.vertices]
        obj=mesh_builder.finish(name,collection);objects.append(obj)
        info=dict(display_name=label,category=category,design_notes=notes,reference_ids=reference_ids,
                  references=[refs[x] for x in reference_ids],units='metres',front_axis_blender='-Y',front_axis_unity='+Z',
                  pivot='bottom-center',shader_recommendation='Universal Render Pipeline/Lit',
                  review_status='awaiting_three_view_visual_review',footprint_policy='Asset-only; no collision or gameplay footprint inferred')
        metadata.append(info)
    rows=pipe['finish_batch']('Dungeon',scene,objects,metadata)
    bpy.context.window.scene=previous
    print(json.dumps(dict(status='DUNGEON_BUILD_COMPLETE',models=len(rows),triangles=sum(x['triangles'] for x in rows)),ensure_ascii=False))

if __name__=='__main__':build()

def rebuild_selected(kinds):
    previous=bpy.context.window.scene
    scene=bpy.data.scenes['AE202610_Dungeon'];bpy.context.window.scene=scene
    collection=bpy.data.collections['AE202610_Dungeon_Masters']
    for kind in kinds:
        name='DG_'+kind;old=bpy.data.objects[name];mesh=old.data
        assert old.name.startswith('DG_') and collection in old.users_collection
        bpy.data.objects.remove(old,do_unlink=True)
        if mesh.users==0:bpy.data.meshes.remove(mesh)
        builder=make(kind)
        lo=[min(v[i] for v in builder.vertices) for i in range(3)]
        hi=[max(v[i] for v in builder.vertices) for i in range(3)]
        origin=((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2])
        builder.vertices=[tuple(v[i]-origin[i] for i in range(3)) for v in builder.vertices]
        builder.finish(name,collection)
    metadata=json.loads((OUT/'manifest.json').read_text(encoding='utf8'))
    refs={x['id']:x for x in json.loads((OUT/'references.json').read_text(encoding='utf8'))}
    specs={('DG_'+s[0]):s for s in SPECS}
    for row in metadata:
        row['reference_ids']=specs[row['name']][3]
        row['references']=[refs[x] for x in row['reference_ids']]
    objects=[bpy.data.objects[row['name']] for row in metadata]
    pipe['finish_batch']('Dungeon',scene,objects,metadata)
    for kind in kinds:pipe['render_asset']('Dungeon','DG_'+kind)
    bpy.context.window.scene=previous
    print('DUNGEON_TARGETED_REPAIR_COMPLETE',kinds)
