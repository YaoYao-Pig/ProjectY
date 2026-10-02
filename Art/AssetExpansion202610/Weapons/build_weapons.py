"""55 original low-poly weapons. Run in the existing Blender via MCP only.

Every silhouette is built from authored profiles and section meshes, not imported
reference geometry. References remain outside Assets and are never used as textures.
"""
import bpy, math, json, runpy
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y/Art/AssetExpansion202610/Weapons')
PIPE=runpy.run_path(str(ROOT.parent/'shared_pipeline.py'))
H=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py')
M=H['MeshBuilder']
PALETTE={'Steel':'899ba0','Edge':'c2ccc8','Iron':'465159','Dark':'303c43','Copper':'b47d4f','Gold':'bca26b','Wood':'69513e','Lightwood':'957451','Leather':'493d37','Bone':'d2c4a2','Red':'824c44','Green':'607e68','Blue':'4d707f','Cyan':'69b6b4','Purple':'857092','Cloth':'ada596'}
H['PALETTE'].update({'AEW_'+k:v for k,v in PALETTE.items()})

def col(k):return 'AEW_'+k
def beam(m,a,b,r,mat,sides=8,r2=None):
    a,b=Vector(a),Vector(b);d=b-a;assert d.length>1e-7
    d.normalize();u=d.cross(Vector((0,0,1)))
    if u.length<.01:u=d.cross(Vector((0,1,0)))
    u.normalize();v=d.cross(u);r2=r if r2 is None else r2
    verts=[tuple(c+rad*(math.cos(i*math.tau/sides)*u+math.sin(i*math.tau/sides)*v)) for c,rad in [(a,r),(b,r2)] for i in range(sides)]
    faces=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]+[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    m.part(verts,faces,col(mat))

def sweep(m,pts,radii,mat,sides=8):
    # Continuous rings avoid visible joints in bent wood and metal.
    pts=[Vector(p) for p in pts];verts=[]
    if isinstance(radii,(float,int)):radii=[radii]*len(pts)
    for j,(p,r) in enumerate(zip(pts,radii)):
        d=(pts[min(j+1,len(pts)-1)]-pts[max(0,j-1)]).normalized();u=Vector((0,1,0));u=u-d*u.dot(d)
        if u.length<.01:u=Vector((1,0,0));u=u-d*u.dot(d)
        u.normalize();v=d.cross(u)
        verts.extend(tuple(p+r*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))) for i in range(sides))
    faces=[tuple(reversed(range(sides)))]
    for j in range(len(pts)-1):
        for i in range(sides):faces.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
    faces.append(tuple(range((len(pts)-1)*sides,len(pts)*sides)))
    m.part(verts,faces,col(mat))

def profile(m,outline,depth,mat,center=(0,0,0),axis='Y'):
    # Extruded authored outline; used for stocks, guards and layered emblems.
    n=len(outline);cx,cy,cz=center;verts=[]
    if depth>=.06 and n>=5:
        # Shallow bevels make formed wooden stocks read as solids in oblique view.
        mx=sum(p[0] for p in outline)/n;mz=sum(p[1] for p in outline)/n
        bevel=min(depth*.13,.008)
        for offset,scale in [(-depth/2,.965),(-depth/2+bevel,1),(depth/2-bevel,1),(depth/2,.965)]:
            for x,z in outline:
                x=mx+(x-mx)*scale;z=mz+(z-mz)*scale
                verts.append((cx+x,cy+offset,cz+z) if axis=='Y' else (cx+offset,cy+x,cz+z))
        faces=[tuple(reversed(range(n))),tuple(range(3*n,4*n))]
        for j in range(3):faces.extend((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for i in range(n))
        m.part(verts,faces,col(mat));return
    for s in [-1,1]:
        for x,z in outline:
            verts.append((cx+x,cy+s*depth/2,cz+z) if axis=='Y' else (cx+s*depth/2,cy+x,cz+z))
    m.part(verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],col(mat))

def ridgeblade(m,stations,depth,mat='Steel',edge='Edge',precise_front=False):
    # Four-point diamond section, tapered stations may offset the center in X.
    verts=[]
    maxwidth=max(w for z,w,x in stations)
    for z,w,x in stations:
        d=depth*min(1,w/maxwidth*2)
        verts.extend([(x-w/2,0,z),(x,-d,z),(x+w/2,0,z),(x,d,z)])
    faces=[(3,2,1,0)];mats=[col(mat)];front=[]
    for j in range(len(stations)-1):
        for k in range(4):
            q=(4*j+k,4*j+(k+1)%4,4*(j+1)+(k+1)%4,4*(j+1)+k)
            if precise_front and k in [0,1]:
                for tri in [(q[0],q[1],q[2]),(q[0],q[2],q[3])]:
                    faces.append(tri);mats.append(col(edge if k==0 else mat));front.append([verts[i] for i in tri])
            else:faces.append(q);mats.append(col(edge if k in [0,3] else mat))
    faces.append(tuple(range(4*(len(stations)-1),4*len(stations))));mats.append(col(mat));m.part(verts,faces,mats)
    return front

def blade_applique(m,outline,front,mat,rise=.0012,embed=.0008):
    """Clip a plate against actual blade triangles and seat its back in the metal.

    A center-line Y value cannot describe a diamond blade, especially when its
    center is offset. Each closed patch follows the exact underlying plane.
    """
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    for triangle in front:
        t=[(v[0],v[2]) for v in triangle];poly=list(outline)
        sign=1 if cross(*t)>0 else -1
        for a,b in zip(t,t[1:]+t[:1]):
            if not poly:break
            clipped=[]
            for p,q in zip(poly,poly[1:]+poly[:1]):
                dp=sign*cross(a,b,p);dq=sign*cross(a,b,q)
                pin=dp>=-1e-11;qin=dq>=-1e-11
                if pin:clipped.append(p)
                if pin!=qin:
                    f=dp/(dp-dq);clipped.append((p[0]+f*(q[0]-p[0]),p[1]+f*(q[1]-p[1])))
            poly=[]
            for p in clipped:
                if not poly or math.dist(p,poly[-1])>1e-8:poly.append(p)
            if len(poly)>1 and math.dist(poly[0],poly[-1])<1e-8:poly.pop()
        if len(poly)<3:continue
        # Remove redundant collinear corners introduced by clipping at a station.
        again=True
        while again and len(poly)>3:
            again=False
            for i in range(len(poly)):
                if abs(cross(poly[i-1],poly[i],poly[(i+1)%len(poly)]))<1e-12:
                    poly.pop(i);again=True;break
        area=abs(sum(p[0]*q[1]-q[0]*p[1] for p,q in zip(poly,poly[1:]+poly[:1])))/2
        if area<1e-10:continue
        den=cross(*t)
        def y_at(p):
            a=cross(t[1],t[2],p)/den;b=cross(t[2],t[0],p)/den
            return a*triangle[0][1]+b*triangle[1][1]+(1-a-b)*triangle[2][1]
        n=len(poly);verts=[(x,y_at((x,z))+offset,z) for offset in [-rise,embed] for x,z in poly]
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        m.part(verts,faces,col(mat))

def ring(m,center,r,t,mat,plane='XZ',steps=16,start=0,end=math.tau):
    cx,cy,cz=center;pts=[]
    for i in range(steps+1):
        a=start+(end-start)*i/steps
        if plane=='XZ':p=(cx+r*math.cos(a),cy,cz+r*math.sin(a))
        elif plane=='XY':p=(cx+r*math.cos(a),cy+r*math.sin(a),cz)
        else:p=(cx,cy+r*math.cos(a),cz+r*math.sin(a))
        pts.append(p)
    if abs(end-start-math.tau)<.001:
        # Individual closed segments meet cleanly; no coincident full end cap.
        for a,b in zip(pts[:-1],pts[1:]):beam(m,a,b,t,mat,6)
    else:sweep(m,pts,t,mat,6)

def gem(m,c,r,h,mat='Cyan'):
    x,y,z=c;N=6;verts=[(x,y,z-h*.5)]+[(x+r*math.cos(i*math.tau/N),y+r*math.sin(i*math.tau/N),z-h*.12) for i in range(N)]+[(x+r*.7*math.cos(i*math.tau/N),y+r*.7*math.sin(i*math.tau/N),z+h*.23) for i in range(N)]+[(x,y,z+h*.5)]
    faces=[(0,1+(i+1)%N,1+i) for i in range(N)]+[(1+i,1+(i+1)%N,1+N+(i+1)%N,1+N+i) for i in range(N)]+[(13,7+i,7+(i+1)%N) for i in range(N)];m.part(verts,faces,col(mat))

def grip(m,bottom,top,r=.033,material='Leather',trim='Copper'):
    beam(m,(0,0,bottom),(0,0,top),r,material,10)
    for j in range(6):
        z=bottom+(top-bottom)*(j+.5)/6
        beam(m,(0,0,z),(0,0,z+.009),r*1.045,'Cloth' if material=='Cloth' else 'Wood',10)
    beam(m,(0,0,bottom-.035),(0,0,bottom+.009),r*1.5,trim,10,r*.9)

def rivet(m,p,r=.009,mat='Gold',axis='Y'):
    x,y,z=p
    beam(m,(x,y-.002,z),(x,y-.008,z),r,mat,8) if axis=='Y' else beam(m,(x-.002,y,z),(x-.008,y,z),r,mat,8)

def sword(m,v,great=False):
    L=[1.06,.76,1.13,1.1,1.0][v] if not great else [1.53,1.68,1.58,1.54,1.63][v]
    w=[.145,.16,.105,.155,.13][v] if not great else [.33,.26,.35,.30,.29][v]
    g=.13 if not great else .22;low=-.15 if not great else -.33
    grip(m,low,g,.033 if not great else .044,['Red','Leather','Green','Leather','Purple'][v],['Copper','Iron','Copper','Gold','Gold'][v])
    beam(m,(0,0,g-.016),(0,0,g+.08),.025 if not great else .034,'Iron',8)
    depth=.027 if not great else .042
    if v==0:stations=[(g+.03,w*.7,0),(g+.13,w,0),(L-.18,w*.76,0),(L,.006 if not great else w*.65,0)]
    elif v==1:stations=[(g+.03,w*.8,0),(g+.14,w,0),(L-.1,w*.7,0),(L,w*.53,-w*.12)] if not great else [(g+.02,w*.75,0),(g+.19,w,0),(L-.24,w*.73,0),(L,.004,0)]
    elif v==2:stations=[(g+.03,w*.55,0),(g+.28,w,.02),(L-.20,w*.66,.035),(L,.004,.01)]
    elif v==3:stations=[(g+.03,w*.67,0),(g+.22,w,0),(L-.22,w*.82,0),(L,.004,0)]
    else:stations=[(g+.02,w*.7,0)]+[(g+(L-g)*i/7,w*(1-i/10),math.sin(i*1.8)*w*.18) for i in range(1,7)]+[(L,.006,0)]
    front=ridgeblade(m,stations,depth,'Dark' if v in [0,3] and great or v==3 else 'Steel',precise_front=v in [1,3] or (v==2 and not great))
    span=[.22,.18,.2,.21,.18][v]*(1.5 if great else 1)
    trim=['Copper','Iron','Copper','Gold','Gold'][v]
    if v==3 and not great:ring(m,(0,0,g+.01),.145,.018,trim,'XZ',20,.23,math.tau-.23)
    else:
        for s in [-1,1]:
            points=[(0,0,g),(s*span*.55,0,g+.018),(s*span,0,g+[.10,-.025,-.07,-.09,.055][v])]
            sweep(m,points,[.03,.027,.009] if not great else [.041,.034,.014],trim,6)
            if v==4 or (v==2 and great):beam(m,points[1],(s*span*.76,0,g+.14),.02,trim,6,.006)
    if v==0:
        for i in range(3 if not great else 4):
            z=g+.18+i*.105
            profile(m,[(w*.32,z),(w*.66,z+.07),(w*.38,z+.15)],depth*.8,'Copper')
        gem(m,(0,-.035,g+.075),.028,.08,'Red')
    elif v==1:
        for z in [g+.2,g+.31]:
            blade_applique(m,[(-w*.44,z-.015),(w*.44,z-.015),(w*.44,z+.015),(-w*.44,z+.015)],front,'Iron',rise=.0024)
            for x in [-w*.34,w*.34]:
                circle=[(x+.008*math.cos(i*math.tau/8),z+.008*math.sin(i*math.tau/8)) for i in range(8)]
                blade_applique(m,circle,front,'Copper',rise=.0045)
        if not great:blade_applique(m,[(-w*.30,.63),(-w*.48,.61),(-w*.43,.57)],front,'Dark',rise=.0008)
        else:beam(m,(0,0,low-.04),(0,0,low-.13),.07,'Copper',10,.04)
    elif v==2:
        if great:
            for i in range(4):
                z=g+.22+i*.21
                sweep(m,[(-w*.27,.017,z),(-w*.7,.03,z+.13),(-w*.57,.018,z+.22)],[.045,.034,.008],'Bone',6)
        else:blade_applique(m,[(-.012,g+.19),(0,L-.22),(.012,g+.19)],front,'Green',rise=.0008)
    elif v==3:blade_applique(m,[(-.012,g+.18),(0,L-.22),(.012,g+.18)],front,'Gold',rise=.0012)
    else:
        beam(m,(0,0,low-.06),(0,0,low-.025),.061,'Bone' if not great else 'Gold',8)
        gem(m,(0,-depth-.01,g+.12),.026,.09,'Purple' if great else 'Gold')

def bow(m,v):
    h=[.85,.70,.64,.71,.82][v];dx=[.20,.27,.17,.29,.19][v]
    pts=[];r=[]
    for j in range(13):
        t=-1+j/6;z=h*t*(.86 if v==2 and t<0 else 1)
        x=dx*(1-math.cos(abs(t)*math.pi*.5))
        if v in [1,3]:x-=.08*max(0,(abs(t)-.72)/.28)**2
        pts.append((x,0,z));r.append(.037*(1-abs(t)*.65))
    sweep(m,pts,r,['Wood','Wood','Green','Dark','Lightwood'][v],8)
    # Laminated belly is a continuous narrower backing strip.
    sweep(m,[(x-.008,-.014,z) for x,y,z in pts],[max(.006,t*.43) for t in r],['Lightwood','Bone','Lightwood','Red','Copper'][v],6)
    for i in [0,11]:sweep(m,pts[i:i+2],[r[i]*1.13,r[i+1]*1.13],'Bone' if v==1 else 'Copper',8)
    # The un-drawn string lies entirely behind the grip, with a real brace height.
    sweep(m,[pts[0],pts[-1]],[.0027,.0027],'Cloth',6)
    # Wrapped grip follows the central rise rather than floating beside it.
    for z in [-.065,-.035,-.005,.025,.055]:beam(m,(0,0,z),(0,0,z+.017),.043,['Leather','Leather','Cloth','Red','Blue'][v],8)
    if v==4:
        profile(m,[(-.065,-.11),(.035,-.11),(.048,.11),(-.065,.11)],.06,'Copper')
        for z in [-.08,.08]:rivet(m,(0,-.039,z),.012,'Iron')
    if v==1:
        for s in [-1,1]:
            tipx=pts[0 if s<0 else -1][0]
            sweep(m,[(tipx,0,s*h),(tipx-.07,0,s*(h+.055)),(tipx-.12,0,s*(h+.085))],[.014,.011,.003],'Bone',6)

def crossbow(m,v):
    length=[.82,.75,.56,.91,.6][v];span=[.49,.40,.33,.44,.35][v]
    wood=['Wood','Red','Green','Blue','Red'][v]
    outline=[(-length*.65,.06),(-length*.62,.16),(.12,.16),(.34,.03),(.39,-.18),(.20,-.21),(.12,-.04),(-.10,-.02),(-.1,.065)]
    profile(m,outline,.09,wood,axis='X')
    for z in [.085,.16]:
        if z==.16:
            for x in [-.04,.04]:beam(m,(x,-length*.60,z),(x,.08,z),.013,'Iron',6)
    y=-length*.40
    for layer in range(2 if v==1 else 1):
        z=.145+layer*.13
        pts=[(-span,y+.13,z),(-span*.65,y+.015,z),(0,y-.015,z),(span*.65,y+.015,z),(span,y+.13,z)]
        sweep(m,pts,[.017,.029,.033,.029,.017],'Bone' if v==2 else 'Steel',8)
        sweep(m,[pts[0],(0,y+.19,z),pts[-1]],.004,'Cloth',6)
        if layer:beam(m,(0,y,.13),(0,y,z),.038,'Copper',8)
    # Open trigger guard and independent front stirrup.
    sweep(m,[(0,.06,-.015),(0,.02,-.12),(0,.13,-.135),(0,.18,-.015)],.012,'Copper',6)
    beam(m,(0,.105,.045),(0,.08,-.075),.009,'Iron',6)
    if v in [0,3]:
        sweep(m,[(-.05,-length*.62,.12),(-.09,-length*.75,.1),(.09,-length*.75,.1),(.05,-length*.62,.12)],.016,'Iron',6)
    if v in [1,3]:
        for x in [-.1,.1]:
            beam(m,(-.10,.035,.16),(.10,.035,.16),.02,'Copper',8)
            ring(m,(x,.035,.16),.055,.010,'Copper','YZ',12)
            beam(m,(x,.035,.16),(x,.09,.20),.011,'Iron',6)
    if v==4:
        sweep(m,[(-.045,.02,.17),(-.065,.02,.30),(0,.02,.35),(.065,.02,.30),(.045,.02,.17)],.018,'Gold',6)
    for side in [-1,1]:
        for yy in [-length*.28,.21]:beam(m,(side*.048,yy,.07),(side*.054,yy,.07),.014,'Gold',8)

def gun(m,v,long=True):
    length=([1.02,.72,.97,.65,.85] if long else [.42,.27,.34,.24,.30])[v]
    iron=['Iron','Dark','Steel','Iron','Dark'][v];wood=['Wood','Wood','Bone','Green','Red'][v]
    bw=.038 if long else .031;z=.12
    # Authored stock profile forms grip and shoulder, with shaped wrist and heel.
    if long:
        outline=[(-.30,.10),(-.22,.19),(.10,.17),(.18,.10),(.43,.06),(.47,-.17),(.39,-.23),(.21,-.16),(.12,-.025),(.06,-.09),(.055,-.20),(-.015,-.22),(-.025,.015),(-.25,.015)]
    else:
        outline=[
            [(-.11,.12),(.08,.13),(.12,.055),(.16,-.10),(.14,-.18),(.075,-.24),(.018,-.22),(.06,-.09),(-.005,.012),(-.11,.012)],
            [(-.11,.12),(.10,.13),(.15,.04),(.20,-.15),(.13,-.25),(.015,-.22),(.05,-.10),(-.005,.012),(-.11,.012)],
            [(-.11,.12),(.085,.13),(.13,.025),(.15,-.19),(.09,-.235),(.017,-.20),(.042,-.075),(-.008,.012),(-.11,.012)],
            [(-.11,.12),(.065,.13),(.10,.025),(.14,-.13),(.10,-.21),(.008,-.19),(.035,-.065),(-.005,.012),(-.11,.012)],
            [(-.11,.12),(.10,.13),(.13,.025),(.18,-.16),(.14,-.245),(.04,-.23),(.015,-.175),(.065,-.075),(-.005,.012),(-.11,.012)]
        ][v]
    profile(m,outline,.09 if long else .065,wood,axis='X')
    receiver=[(-.21,.075),(-.21,.18),(.09,.18),(.13,.12),(.07,.025),(-.13,.025)]
    if not long:receiver=[(y*.66,z) for y,z in receiver]
    profile(m,receiver,.106 if long else .073,iron,axis='X')
    barrels=[-.029,.029] if v==2 and not long else [0]
    for x in barrels:
        beam(m,(x,-.13,z),(x,-length,z),bw*.83 if len(barrels)>1 else bw,iron,10)
        if v==1:
            beam(m,(x,-length+.12,z),(x,-length-.015,z),bw*1.05,'Copper',10,bw*2.1)
            beam(m,(x,-length-.018,z),(x,-length-.026,z),bw*1.82,'Dark',10)
            beam(m,(x,-length-.027,z),(x,-length-.031,z),bw*1.04,'Iron',10)
        else:
            beam(m,(x,-length+.035,z),(x,-length-.008,z),bw*1.15,iron,10)
            beam(m,(x,-length-.009,z),(x,-length-.014,z),bw*.78,'Dark',10)
    if long:
        profile(m,[(-length+.19,.065),(-.25,.065),(-.23,-.01),(-length+.23,.003)],.102,wood,axis='X')
        for yy in [-length*.73,-length*.43]:beam(m,(0,yy-.016,z),(0,yy+.016,z),bw*1.32,'Copper' if v!=4 else 'Steel',10)
        profile(m,[(.41,.056),(.455,.04),(.477,-.166),(.448,-.197),(.41,-.17)],.104,'Iron',axis='X')
        if v==2:
            for xx in [-.056,.056]:profile(m,[(.17,.04),(.37,.025),(.4,-.12),(.25,-.085)],.008,'Bone',(xx,0,0),axis='X')
        if v==4:
            for j in range(4):profile(m,[(.24+j*.038,.01),(.262+j*.038,-.14),(.28+j*.038,-.15),(.256+j*.038,.014)],.11,'Cloth',axis='X')
    # Forged trigger guard with clear inner opening; only external fictional mechanisms.
    sweep(m,[(0,-.12,.006),(0,-.15,-.086),(0,-.07,-.133),(0,.045,-.1),(0,.055,-.028)],.011,'Copper',6)
    sweep(m,[(0,-.06,.024),(0,-.074,-.018),(0,-.05,-.068)],.006,'Iron',6)
    beam(m,(.032,.045,.145),(.056,.045,.145),.026,'Copper',10)
    sweep(m,[(.047,.045,.145),(.047,.070,.215),(.047,.028,.233)],.014,'Copper',6)
    for yy in [-.1,.06]:beam(m,(-.055,yy,.115),(-.061,yy,.115),.012,'Gold',8)
    for yy in [-length+.09,-.05]:profile(m,[(yy-.014,z+.035),(yy+.018,z+.035),(yy+.01,z+.082),(yy-.014,z+.077)],.018,'Iron',axis='X')
    if v==3:
        beam(m,(.073,-.07,.045),(.073,-.07,.095),.043,'Copper',10)
        beam(m,(.073,-.07,.215),(.073,-.07,.24),.043,'Copper',10)
        for yy in [-.108,-.032]:beam(m,(.073,yy,.09),(.073,yy,.22),.006,'Copper',6)
        gem(m,(.075,-.07,.155),.040,.16,'Cyan')
    elif v==0 and not long:
        for xx in [-.04,.04]:profile(m,[(.11,.045),(.158,-.11),(.116,-.197),(.052,-.186),(.081,-.07)],.008,'Bone',(xx,0,0),axis='X')
    elif v==4 and not long:
        ring(m,(0,.12,-.245),.049,.01,'Copper','YZ',12,.4,math.tau-.4)

def shield(m,v):
    if v==0:outline=[(-.34,.39),(.34,.39),(.32,.02),(.19,-.32),(0,-.56),(-.19,-.32),(-.32,.02)]
    elif v==1:outline=[(.40*math.cos(i*math.tau/16),.40*math.sin(i*math.tau/16)) for i in range(16)]
    elif v==2:outline=[(-.34,-.64),(.34,-.64),(.35,.47),(.27,.56),(-.27,.56),(-.35,.47)]
    elif v==3:outline=[(0,.5),(.27,.36),(.37,.10),(.23,-.29),(0,-.55),(-.23,-.29),(-.37,.1),(-.27,.36)]
    else:outline=[(-.33,.39),(.33,.39),(.37,.06),(0,-.50),(-.37,.06)]
    # Convex front with recessed wooden back, closed rim. Faces never form a thin plane.
    N=len(outline);verts=[(x,-.04+.10*(abs(x)/.4)**2,z) for x,z in outline]+[(x,.035+.10*(abs(x)/.4)**2,z) for x,z in outline]+[(0,-.13,0),(0,.02,0)]
    faces=[];mats=[]
    for i in range(N):
        j=(i+1)%N;faces.extend([(2*N,i,j),(2*N+1,N+j,N+i),(i,N+i,N+j,j)])
        mats.extend([col(['Red','Green','Blue','Red','Bone'][v]),col('Wood'),col('Iron')])
    m.part(verts,faces,mats)
    trim=['Gold','Copper','Iron','Bone','Gold'][v]
    for i in range(N):
        a=Vector(verts[i]);b=Vector(verts[(i+1)%N]);a.y-=.006;b.y-=.006;beam(m,a,b,.018 if v!=3 else .025,trim,8)
        if i%2==0:rivet(m,tuple(a),.013,trim)
    # Back straps have a visible stand-off and a central grab bar.
    for z in [-.15,.15]:sweep(m,[(-.16,.025,z),(-.12,.15,z),(.11,.15,z),(.16,.025,z)],.019,'Leather',8)
    beam(m,(0,.13,-.15),(0,.13,.15),.031,'Wood',8)
    decoration_start=len(m.vertices)
    if v==0:
        profile(m,[(0,.27),(.1,.03),(.06,-.17),(0,-.25),(-.08,-.11),(-.06,.07),(-.02,.02)],.022,'Gold',(0,-.135,0))
    elif v==1:
        beam(m,(0,-.13,0),(0,-.23,0),.10,'Copper',12,.045)
        for i in range(0,8,2):
            a=i*math.tau/8;profile(m,[(.12*math.cos(a-.2),.12*math.sin(a-.2)),(.29*math.cos(a),.29*math.sin(a)),(.12*math.cos(a+.2),.12*math.sin(a+.2))],.009,'Gold',(0,-.13,0))
    elif v==2:
        zz=[-.57,-.30,0,.25,.5]
        for a,b in zip(zz[:-1],zz[1:]):profile(m,[(-.029,a),(.029,a),(.029,b),(-.029,b)],.044,'Iron',(0,-.15,0))
        sweep(m,[(-.22,-.14,.20),(-.1,-.14,.20),(-.14,-.14,.25)],.011,'Cloth',6)
    elif v==3:
        for z,w in [(.28,.22),(.07,.27),(-.15,.23),(-.31,.13)]:profile(m,[(-w,z+.1),(w,z+.1),(w*.6,z-.04),(0,z-.12),(-w*.6,z-.04)],.033,'Red',(0,-.135,0))
    else:ring(m,(0,-.143,.03),.17,.018,'Gold','XZ',18,.40,math.tau-.3)
    # Seat applied heraldry on the curved shield, so side views cannot expose a
    # floating emblem. The front is exactly a radial triangle fan.
    def front_y(x,z):
        for i in range(N):
            ax,az=outline[i];bx,bz=outline[(i+1)%N];det=ax*bz-bx*az
            if abs(det)<1e-9:continue
            a=(x*bz-bx*z)/det;b=(ax*z-x*az)/det
            if a>=-1e-5 and b>=-1e-5 and a+b<=1.0001:
                return -.13*(1-a-b)+verts[i][1]*a+verts[(i+1)%N][1]*b
        return -.13
    for k in range(decoration_start,len(m.vertices)):
        x,y,z=m.vertices[k];m.vertices[k]=(x,y+front_y(x,z)+.13,z)

def dagger(m,v):
    grip(m,-.095,.07,.027,['Leather','Blue','Bone','Cloth','Leather'][v],['Iron','Gold','Copper','Copper','Steel'][v])
    beam(m,(0,0,.055),(0,0,.105),.023,'Copper' if v==3 else 'Iron',8)
    sts=[[(.09,.09,0),(.24,.11,0),(.34,.075,0),(.39,.005,.01)],[(.08,.045,0),(.17,.074,0),(.37,.034,.01),(.43,.004,.018)],[(.08,.06,0),(.19,.11,.015),(.31,.09,.065),(.4,.005,.10)],[(.08,.06,0),(.3,.06,0),(.34,.034,0),(.35,.01,0)],[(.08,.055,0),(.29,.045,0),(.46,.003,0)]][v]
    ridgeblade(m,sts,.022,['Steel','Cyan','Dark','Edge','Steel'][v], 'Edge' if v!=1 else 'Cyan')
    if v!=3:
        for s in [-1,1]:sweep(m,[(0,0,.07),(s*.08,0,.08),(s*.10,0,.12 if v==2 else .085)],[.02,.016,.009],'Gold' if v==1 else 'Iron',6)
    if v==0:ring(m,(0,0,-.15),.034,.008,'Iron','XZ',12)
    elif v==1:beam(m,(0,0,.07),(0,0,.12),.041,'Gold',8)
    elif v==4:
        profile(m,[(-.007,.12),(0,.37),(.007,.12)],.004,'Cyan',(0,-.024,0));beam(m,(0,0,-.125),(0,0,-.10),.045,'Steel',12)

def staff(m,v):
    # Shaft has shaped bends but leaves a straight grip around zero.
    pts=[(.015,0,-.87),(-.02,0,-.55),(0,0,-.13),(0,0,.14),([-.035,.025,-.045,.0,.02][v],0,.53),(0,0,.80)]
    sweep(m,pts,[.019,.025,.030,.030,.032,.042],['Wood','Lightwood','Bone','Dark','Wood'][v],9)
    for z in [-.1,-.055,-.01,.035,.08]:beam(m,(0,0,z),(0,0,z+.016),.034,'Cloth' if v==4 else 'Leather',8)
    beam(m,(.015,0,-.91),(.015,0,-.83),.028,'Copper',9)
    if v==0:
        sweep(m,[(0,0,.70),(-.10,0,.86),(-.14,0,1.12),(-.02,0,1.27),(.15,0,1.21),(.18,0,1.10)],[.039,.032,.027,.021,.016,.011],'Wood',8)
        beam(m,(.16,0,1.17),(.16,0,1.06),.008,'Copper',6)
        gem(m,(.16,0,.98),.065,.16,'Green')
        beam(m,(.16,0,.89),(.16,0,.93),.027,'Copper',8)
        for z in [.89,1.06]:ring(m,(.16,0,z),.09,.012,'Copper','XY',12)
        for a in range(4):
            t=a*math.pi/2;beam(m,(.16+.08*math.cos(t),.08*math.sin(t),.9),(.16+.08*math.cos(t),.08*math.sin(t),1.06),.008,'Copper',6)
    elif v==1:
        sweep(m,[(0,0,.72),(-.07,0,.92),(-.12,0,1.18),(.02,0,1.29),(.18,0,1.21),(.18,0,1.02),(.08,0,.96)],[.035,.03,.026,.024,.019,.015,.011],'Lightwood',8)
        gem(m,(.08,0,1.10),.055,.19,'Cyan');beam(m,(.08,0,.97),(.08,0,1.04),.019,'Copper',8)
    elif v==2:
        # A radial, peaked mushroom cap with real underside thickness.
        N=12;verts=[(0,0,1.14)]+[(.22*math.cos(i*math.tau/N),.22*math.sin(i*math.tau/N),.96) for i in range(N)]+[(.20*math.cos(i*math.tau/N),.20*math.sin(i*math.tau/N),.925) for i in range(N)]+[(0,0,.88)]
        faces=[(0,1+i,1+(i+1)%N) for i in range(N)]+[(1+i,13+i,13+(i+1)%N,1+(i+1)%N) for i in range(N)]+[(25,13+(i+1)%N,13+i) for i in range(N)]
        m.part(verts,faces,[col('Red')]*N+[col('Bone')]*(N*2));beam(m,(0,0,.73),(0,0,1.01),.045,'Bone',8)
        for x,y in [(-.13,0),(.10,-.10),(.10,.10)]:beam(m,(x,y,.94),(x,y,.78),.008,'Copper',6);gem(m,(x,y,.75),.025,.09,'Gold')
        for x,y in [(.05,0),(-.08,.04),(.10,-.05)]:
            z=1.14-.18*math.hypot(x,y)/.22-.011
            beam(m,(x,y,z),(x,y,z+.015),.023,'Bone',7)
    elif v==3:
        beam(m,(0,0,.74),(0,0,.94),.04,'Copper',8);gem(m,(0,0,1.04),.081,.27,'Purple')
        for a in [0,math.pi*.5,math.pi,math.pi*1.5]:
            x,y=math.cos(a),math.sin(a);sweep(m,[(x*.02,y*.02,.81),(x*.14,y*.14,.92),(x*.14,y*.14,1.17),(x*.035,y*.035,1.27)],.013,'Copper',6)
        for z in [.92,1.17]:ring(m,(0,0,z),.14,.011,'Gold','XY',8)
    else:
        for s in [-1,1]:sweep(m,[(0,0,.72),(s*.13,0,.90),(s*.16,0,1.21+(s*.045))],[.036,.026,.01],'Iron',6)
        gem(m,(0,0,1.02),.073,.25,'Gold');beam(m,(-.05,0,.83),(.05,0,.83),.045,'Copper',8)
        beam(m,(0,0,.82),(0,0,.94),.028,'Copper',8)

def optic(m,v):
    L=[.32,.17,.26,.27,.13][v];r=[.040,.042,.065,.044,.044][v]
    if v==1:profile(m,[(-.085,.02),(.085,.02),(.06,.11),(-.055,.12)],.075,'Steel',axis='X')
    else:beam(m,(0,L*.5,.07),(0,-L*.5,.07),r,['Copper','Steel','Iron','Copper','Bone'][v],12)
    # Objective and eyepiece remain visibly different; no glass coplanar with rims.
    for y,rad in [(-L*.5,r*1.35),(L*.5,r*.78)]:
        beam(m,(0,y-.012,.07),(0,y+.012,.07),rad,'Gold' if v in [0,3] else 'Steel',12)
        beam(m,(0,y-.014 if y<0 else y+.014,.07),(0,y-.019 if y<0 else y+.019,.07),rad*.77,'Cyan' if v!=3 else 'Gold',12)
    for y in [-L*.24,L*.24]:
        beam(m,(0,y-.008,.07),(0,y+.008,.07),r*1.075,'Iron',12)
        profile(m,[(y-.015,-.03),(y+.015,-.03),(y+.013,.054),(y-.013,.054)],.04,'Copper',axis='X')
    profile(m,[(-L*.34,-.038),(L*.34,-.038),(L*.34,-.02),(-L*.34,-.02)],.15 if v==4 else .064,'Iron',axis='X')
    if v==3:beam(m,(r*.75,0,.07),(r*1.6,0,.07),.023,'Gold',12)
    if v==2:
        for y in [-L*.48,-L*.35]:beam(m,(0,y-.007,.07),(0,y+.007,.07),r*1.40,'Bone',12)
    if v==4:sweep(m,[(-.065,-.025,-.028),(-.07,-.025,.11),(0,-.025,.14),(.07,-.025,.11),(.065,-.025,-.028)],.009,'Copper',6)

def suppressor(m,v):
    L=[.28,.38,.33,.21,.34][v];r=[.067,.046,.048,.078,.050][v]
    beam(m,(0,.035,0),(0,0,0),r*.62,'Copper',10)
    if v==0:beam(m,(0,0,0),(0,-L,0),r*.7,'Copper',12,r*1.3)
    else:beam(m,(0,0,0),(0,-L,0),r,['Copper','Leather','Green','Dark','Steel'][v],8 if v==4 else 12)
    for yy in [0,-L]:
        rr=r*(1.3 if yy==-L and v==0 else .7 if v==0 else 1)
        beam(m,(0,yy-.012,0),(0,yy+.008,0),rr*1.06,'Iron' if v==1 else 'Copper',12)
    # Dark inset is a visual aperture; no physical internal firearm detail modeled.
    beam(m,(0,-L-.013,0),(0,-L-.017,0),r*.45,'Dark',12)
    if v in [1,2]:
        for yy in [-L*.2,-L*.47,-L*.75]:beam(m,(0,yy-.009,0),(0,yy+.009,0),r*1.025,'Cloth' if v==1 else 'Bone',12)
    if v==3:
        for x in [-r*.96,r*.96]:profile(m,[(-L*.86,-.025),(-L*.14,-.025),(-L*.14,.025),(-L*.86,.025)],.014,'Bone',(x,0,0),axis='X')
    if v==4:
        for x in [-r*.93,r*.93]:profile(m,[(-L*.9,-.006),(-L*.1,-.006),(-L*.1,.006),(-L*.9,.006)],.006,'Purple',(x,0,0),axis='X')

def build(replace=False):
    if replace:
        scene=bpy.data.scenes['AE202610_Weapons'];collection=bpy.data.collections['AE202610_Weapons_Masters']
        assert all(o.name.startswith('AEW_') for o in collection.objects)
        for o in list(collection.objects):
            data=o.data;bpy.data.objects.remove(o,do_unlink=True)
            if data.users==0:bpy.data.meshes.remove(data)
        bpy.context.window.scene=scene
        for key,value in PALETTE.items():
            mat=bpy.data.materials.get('M_MapLP_AEW_'+key)
            if mat:
                rgba=tuple(H['srgb_linear'](int(value[i:i+2],16)/255) for i in [0,2,4])+(1,)
                node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
                node.inputs['Base Color'].default_value=rgba;mat.diffuse_color=rgba;mat['palette_srgb']='#'+value
    else:scene,collection=PIPE['create_scene']('Weapons')
    rows=json.loads((ROOT/'catalog.json').read_text(encoding='utf8'));objects=[]
    builders={'Sword':lambda m,v:sword(m,v),'Greatsword':lambda m,v:sword(m,v,True),'Bow':bow,'Crossbow':crossbow,'Longgun':lambda m,v:gun(m,v,True),'Pistol':lambda m,v:gun(m,v,False),'Shield':shield,'Dagger':dagger,'Staff':staff,'Scope':optic,'Suppressor':suppressor}
    for row in rows:
        m=M();builders[row['category']](m,row['variant'])
        # Align the hand volume rather than an arbitrary stock corner to zero.
        if row['category'] in ['Longgun','Pistol']:
            shift=(0,-.04,.10) if row['category']=='Longgun' else (0,-.115,.11)
            m.vertices=[tuple(Vector(p)+Vector(shift)) for p in m.vertices]
        elif row['category']=='Crossbow':
            m.vertices=[(x,y-.20,z+.095) for x,y,z in m.vertices]
        elif row['category']=='Scope':
            m.vertices=[(x,y,z+.038) for x,y,z in m.vertices]
        obj=m.finish(row['id'],collection)
        obj['lore_zh']=row['lore_zh'];obj['asset_category']=row['category'];obj['grip_origin']='mesh local zero in metres'
        if row['category']=='Bow':row['origin_contract']+='; bow limbs lie in XZ and string toward +X; aim is -X; grip center is zero; animation/socket integration pending'
        objects.append(obj)
    result=PIPE['finish_batch']('Weapons',scene,objects,rows)
    print(json.dumps(dict(created=len(result),triangles=[min(r['triangles'] for r in result),max(r['triangles'] for r in result)],source=str(ROOT/'Source/Weapons.blend'))))

if __name__=='__main__':build()
