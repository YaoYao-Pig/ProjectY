import bpy, math, runpy, json
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y')
BASE=ROOT/'Art/AssetExpansion202610'
P=runpy.run_path(str(BASE/'shared_pipeline.py'))
H=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/mesh_helpers.py'))
H['PALETTE'].update(AECrust='aa7046',AECrumb='dfbc7e',AERed='a34436',AELeaf='657c47',AEYellow='d8aa54',
 AEWax='84543a',AEBrown='655042',AEWhite='ded4b2',AEBone='c7b995',AEIron='424c51',AESteel='85938e',
 AECopper='ab8652',AECyan='4d9198',AEBlue='516c8b',AEPurple='755875',AECloth='a4afa2',AEDark='333b3d',
 AELeather='705040',AEMoss='53674a',AEAsh='9c9e91',AEBerry='653842')
Mesh=H['MeshBuilder']
if globals().get('REBUILD',False):
    scene=bpy.data.scenes['AE202610_Items'];col=bpy.data.collections['AE202610_Items_Masters']
    for obj in list(col.objects):
        assert obj.name.startswith('AE_Item_')
        mesh=obj.data;bpy.data.objects.remove(obj,do_unlink=True)
        if mesh.users==0:bpy.data.meshes.remove(mesh)
    bpy.context.window.scene=scene
else:scene,col=P['create_scene']('Items')
rows=runpy.run_path(str(BASE/'Items/item_data.py'))['ALL']
refs=json.loads((BASE/'Items/references.json').read_text(encoding='utf8'))
objects=[]

def lathe(m,profile,mat,n=16,center=(0,0,0),s=(1,1,1)):
    v=[]
    for z,r in profile:
        for i in range(n):
            a=math.tau*i/n
            v.append((center[0]+r*math.cos(a)*s[0],center[1]+r*math.sin(a)*s[1],center[2]+z*s[2]))
    f=[tuple(reversed(range(n))),tuple(range((len(profile)-1)*n,len(profile)*n))]
    f += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(profile)-1) for i in range(n)]
    m.part(v,f,mat)

def ellipsoid(m,c,s,mat,n=16,k=8):
    v=[(c[0],c[1],c[2]-s[2])]
    for j in range(1,k):
        a=-math.pi/2+math.pi*j/k
        for i in range(n):
            b=math.tau*i/n
            v.append((c[0]+s[0]*math.cos(a)*math.cos(b),c[1]+s[1]*math.cos(a)*math.sin(b),c[2]+s[2]*math.sin(a)))
    v.append((c[0],c[1],c[2]+s[2]));t=len(v)-1
    f=[(0,1+(i+1)%n,1+i) for i in range(n)]
    f += [(1+j*n+i,1+j*n+(i+1)%n,1+(j+1)*n+(i+1)%n,1+(j+1)*n+i) for j in range(k-2) for i in range(n)]
    f += [(t,1+(k-2)*n+i,1+(k-2)*n+(i+1)%n) for i in range(n)]
    m.part(v,f,mat)

def rod(m,a,b,r,mat,n=8,r2=None):
    a,b=Vector(a),Vector(b);d=b-a;q=d.to_track_quat('Z','Y')
    v=[]
    for c,rr in [(a,r),(b,r if r2 is None else r2)]:
        for i in range(n):
            p=q@Vector((rr*math.cos(math.tau*i/n),rr*math.sin(math.tau*i/n),0))+c;v.append(tuple(p))
    m.part(v,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)

def ring(m,c,r,w,mat,n=24,k=6,plane='XZ'):
    v=[]
    for i in range(n):
        a=math.tau*i/n
        for j in range(k):
            b=math.tau*j/k;rr=r+w*math.cos(b)
            p=(rr*math.cos(a),w*math.sin(b),rr*math.sin(a))
            if plane=='XY':p=(p[0],p[2],p[1])
            v.append(tuple(c[t]+p[t] for t in range(3)))
    m.part(v,[(i*k+j,((i+1)%n)*k+j,((i+1)%n)*k+(j+1)%k,i*k+(j+1)%k) for i in range(n) for j in range(k)],mat)

def plate(m,points,y,depth,mat):
    n=len(points);v=[(x,yy,z) for yy in [y-depth/2,y+depth/2] for x,z in points]
    m.part(v,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)

def gem(m,c,s,mat):
    x,y,z=c;a,b,h=s
    v=[(x-a,y-b,z),(x+a,y-b,z),(x+a,y+b,z),(x-a,y+b,z),(x,y,z+h),(x,y,z-h*.3)]
    m.part(v,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)],mat)

def leaf(m,a,b,width,mat='AELeaf'):
    a,b=Vector(a),Vector(b);mid=(a+b)*.5
    off=Vector((width,0,0))
    m.part([tuple(a),tuple(mid+off),tuple(b),tuple(mid-off),tuple(mid+Vector((0,-.008,.015)))],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],mat)

def cloth_loop(m,x,width,ry,rz,zc,mat):
    v=[];n=24
    for xx in [x-width/2,x+width/2]:
        for thick in [0,.003]:
            for j in range(n):
                a=math.tau*j/n;v.append((xx,(ry+thick)*math.cos(a),zc+(rz+thick)*math.sin(a)))
    f=[]
    for j in range(n):
        k=(j+1)%n
        f += [(j,k,2*n+k,2*n+j),(n+j,3*n+j,3*n+k,n+k),(j,n+j,n+k,k),(2*n+j,2*n+k,3*n+k,3*n+j)]
    m.part(v,f,mat)

def armor_shell(m,mat,back=False):
    xs=[-.29,-.17,0,.17,.29];v=[]
    for layer in [0,.028]:
        for j in range(3):
            for k,x in enumerate(xs):
                z=([.15,.10,.09,.10,.15] if j==0 else [.40]*5 if j==1 else [.46,.61,.54 if not back else .58,.61,.46])[k]
                y=(.12+.045*(1-(x/.30)**2)) if back else (-.115-.075*(1-(x/.30)**2))
                v.append((x,y+(layer if back else -layer),z))
    f=[]
    for layer in [0,15]:
        for j in range(2):
            for k in range(4):f.append((layer+j*5+k,layer+j*5+k+1,layer+(j+1)*5+k+1,layer+(j+1)*5+k))
    perimeter=[0,1,2,3,4,9,14,13,12,11,10,5]
    for a,b in zip(perimeter,perimeter[1:]+perimeter[:1]):f.append((a,b,b+15,a+15))
    m.part(v,f,mat)

def bent_plate(m,points,y,depth,mat):
    # Split at the shell's ribs so broad decorations follow its real planar facets.
    def clip(poly,x,greater):
        result=[]
        for a,b in zip(poly,poly[1:]+poly[:1]):
            ia=a[0]>=x if greater else a[0]<=x
            ib=b[0]>=x if greater else b[0]<=x
            if ia:result.append(a)
            if ia!=ib:
                t=(x-a[0])/(b[0]-a[0]);result.append((x,a[1]+t*(b[1]-a[1])))
        clean=[]
        for p in result:
            if not clean or abs(p[0]-clean[-1][0])+abs(p[1]-clean[-1][1])>1e-7:clean.append(p)
        if len(clean)>1 and abs(clean[0][0]-clean[-1][0])+abs(clean[0][1]-clean[-1][1])<1e-7:clean.pop()
        return clean
    cuts=[-.5,-.17,0,.17,.5]
    for left,right in zip(cuts,cuts[1:]):
        poly=clip(clip(points,left,True),right,False)
        if len(poly)>=3:plate(m,poly,y,depth,mat)

def chest_surface(x):
    x=abs(x)
    if x<=.17:return -.218+(.075*(.17/.30)**2)*x/.17
    return -.218+.075*(.17/.30)**2+(.075*(.29/.30)**2-.075*(.17/.30)**2)*(x-.17)/.12

def bowl(m,c,r,h,mat):
    lathe(m,[(0,r*.55),(.025,r*.70),(h*.75,r),(h,r),(h,r*.85),(h*.28,r*.55)],mat,16,c)

def food(m,i):
    if i==0:
        ellipsoid(m,(0,0,.11),(.25,.15,.11),'AECrust')
        for x in [-.11,0,.11]:
            pts=[]
            for j in range(7):
                y=-.075+j*.025;xx=x+y*.40;z=.11+.11*math.sqrt(max(.01,1-(xx/.25)**2-(y/.15)**2))
                pts.append((xx,y,z+.0008))
            for a,b in zip(pts,pts[1:]):rod(m,a,b,.006,'AECrumb',6)
    elif i==1:
        ellipsoid(m,(0,0,.095),(.09,.08,.095),'AERed')
        rod(m,(0,0,.17),(.017,.005,.22),.008,'AEBrown')
        leaf(m,(.006,0,.20),(.075,.002,.228),.022)
    elif i==2:
        n=18;angle=[math.radians(42)+math.radians(276)*j/n for j in range(n+1)]
        v=[(0,0,z) for z in [0,.12]]
        for z in [0,.12]:v += [(.17*math.cos(a),.17*math.sin(a),z) for a in angle]
        b=2;t=2+n+1
        f=[(0,b+j,b+j+1) for j in range(n)]+[(1,t+j+1,t+j) for j in range(n)]+[(b+j,t+j,t+j+1,b+j+1) for j in range(n)]+[(0,1,t,b),(0,b+n,t+n,1)]
        m.part(v,f,['AEYellow']*(2*n)+['AEWax']*n+['AECrumb']*2)
    elif i==3:
        ellipsoid(m,(0,0,.055),(.26,.075,.055),'AEWax')
        plate(m,[(-.23,.05),(-.34,.12),(-.33,.005)],0,.025,'AEBrown')
        plate(m,[(-.03,.08),(.08,.15),(.14,.06)],0,.025,'AECopper')
        for y in [-.07,.07]:ellipsoid(m,(.185,y,.067),(.012,.004,.012),'AEDark',8,4)
        for x in [-.10,0,.10]:rod(m,(x,-.063,.085),(x+.035,.063,.085),.007,'AEBrown',6)
    elif i==4:
        ellipsoid(m,(-.045,0,.09),(.16,.10,.09),'AECrust')
        rod(m,(.03,0,.072),(.235,0,.042),.025,'AEBone',10)
        for y in [-.020,.020]:ellipsoid(m,(.24,y,.04),(.03,.025,.025),'AEWhite',10,6)
    elif i==5:
        rod(m,(-.28,0,.06),(.28,0,.06),.007,'AEBrown')
        for x in [-.16,0,.16]:
            rod(m,(x,0,.03),(x,0,.115),.018,'AEWhite')
            lathe(m,[(.11,.07),(.14,.065),(.17,.032),(.175,.013)],'AECrumb',12,(x,0,0))
        for x in [-.08,.08]:m.box((x,0,.06),(.07,.065,.06),'AERed')
    elif i==6:
        for x,z in [(-.055,.012),(0,.025),(.055,.009)]:
            rod(m,(x,-.16,z+.035),(x,.08,z+.055),.012,'AECrust',10,.04)
            for dx in [-.035,0,.035]:leaf(m,(x,.07,z+.05),(x+dx,.21,z+.07),.018)
        rod(m,(-.087,.035,.06),(.085,.035,.06),.012,'AEWhite')
    elif i==7:
        lathe(m,[(0,.15),(.025,.17),(.065,.16),(.070,.14),(.045,.13)],'AECrust')
        lathe(m,[(.046,.135),(.054,.135)],'AEYellow')
        for j in range(5):
            a=j*math.tau/5;ellipsoid(m,(.07*math.cos(a),.07*math.sin(a),.067),(.025,.025,.025),'AEBerry',10,6)
    elif i==8:
        m.box((0,0,.052),(.25,.19,.10),'AECloth')
        plate(m,[(-.13,.10),(.03,.06),(.13,.10),(.13,.12),(-.13,.12)],-.07,.045,'AEWhite')
        for x in [-.085,.085]:m.box((x,0,.058),(.018,.2,.116),'AELeather')
        ellipsoid(m,(0,.075,.11),(.105,.07,.027),'AECrust')
    else:
        bowl(m,(0,0,0),.18,.12,'AEWax')
        lathe(m,[(.070,.14),(.078,.14)],'AECrust')
        for x,y in [(-.05,.025),(.06,.03),(.025,-.06)]:ellipsoid(m,(x,y,.088),(.038,.029,.020),'AECrumb',10,4)
        for x in [-.185,.185]:ring(m,(x,0,.075),.045,.013,'AEWax',16,6)

def medical(m,i):
    if i==0:
        # Rolled cloth with visible concentric layers and a loose folded tail.
        n=24;v=[]
        for z,r in [(.015,.067),(.12,.067),(.12,.022),(.015,.022)]:
            v.extend((r*math.cos(math.tau*j/n),r*math.sin(math.tau*j/n),z) for j in range(n))
        m.part(v,[(k*n+j,k*n+(j+1)%n,((k+1)%4)*n+(j+1)%n,((k+1)%4)*n+j) for k in range(4) for j in range(n)],'AEWhite')
        for r in [.034,.047,.060]:ring(m,(0,0,.12),r,.0014,'AECloth',24,4,'XY')
        for z in [.04,.075,.107]:ring(m,(0,0,z),.067,.001,'AECloth',24,4,'XY')
        m.box((.095,0,.01),(.16,.12,.012),'AEWhite')
        for x in [.09,.11]:m.box((x,0,.017),(.004,.12,.004),'AEBlue')
    elif i==1:
        ellipsoid(m,(0,0,.035),(.14,.10,.035),'AEMoss',12,6)
        for x in [-.09,.09]:cloth_loop(m,x,.014,.077,.027,.035,'AECloth')
        leaf(m,(-.04,-.104,.025),(.03,-.104,.064),.02,'AEWhite')
    elif i==2:
        for x in [-.065,.065]:m.box((x,0,.018),(.07,.37,.03),'AECrumb')
        for y in [-.13,0,.13]:m.box((0,y,.04),(.22,.036,.025),'AEWhite')
        for y in [-.13,0,.13]:m.box((.015,y,.059),(.037,.05,.012),'AELeather')
    elif i==3:
        lathe(m,[(0,.055),(.02,.085),(.12,.09),(.155,.07),(.17,.066)],'AEMoss')
        lathe(m,[(.17,.072),(.184,.073),(.192,.061)],'AEBrown')
        for a in [0,math.pi/2,math.pi,math.pi*1.5]:
            x,y=.035*math.cos(a),.035*math.sin(a);lathe(m,[(.192,.008),(.194,.008)],'AEDark',8,(x,y,0))
        ring(m,(0,0,.161),.069,.005,'AECopper',24,6,'XY')
        for x in [-.02,.025]:rod(m,(x,-.082,.045),(x+.012,-.083,.11),.005,'AEDark')
    else:
        m.box((0,0,.033),(.29,.21,.055),'AELeather')
        plate(m,[(-.15,.05),(-.14,.15),(.14,.15),(.15,.05)],.09,.022,'AELeather')
        for x in [-.075,-.035]:rod(m,(x,-.075,.072),(x,.055,.072),.005,'AEBone',8,.001)
        lathe(m,[(0,.024),(.03,.024),(.035,.01),(.06,.009)],'AEMoss',10,(.062,.005,.06))
        lathe(m,[(.06,.012),(.071,.012)],'AEBrown',10,(.062,.005,.06))
        m.box((-.055,0,.072),(.085,.028,.015),'AELeather')
        for x in [-.115,.115]:m.box((x,0,.075),(.018,.22,.10),'AEBrown')
        m.box((0,-.112,.04),(.05,.015,.035),'AECopper')

def potion(m,i):
    profiles=[[(0,.065),(.03,.085),(.16,.105),(.24,.055),(.30,.025),(.34,.025)],
              [(0,.08),(.03,.105),(.13,.105),(.21,.045),(.36,.022)],
              [(0,.065),(.03,.085),(.20,.085),(.24,.047),(.28,.032)],
              [(0,.055),(.03,.067),(.28,.052),(.33,.031),(.37,.027)],
              [(0,.065),(.02,.09),(.14,.086),(.19,.046),(.27,.028)]]
    colors=['AERed','AECyan','AEMoss','AEPurple','AEAsh'];top=profiles[i][-1][0]
    lathe(m,profiles[i],colors[i],12 if i!=2 else 6,s=(1,.70 if i==0 else 1,1))
    lathe(m,[(top,.033),(top+.025,.037),(top+.04,.027)],'AEBrown',12)
    ring(m,(0,0,top-.018),profiles[i][-1][1]+.007,.008,'AECopper',16,6,'XY')
    if i==0:
        plate(m,[(-.012,.075),(-.014,.15),(0,.165),(.014,.15),(.012,.075)],-.064,.014,'AECopper')
    if i==1:
        for x in [-.10,.10]:ring(m,(x,0,.15),.037,.009,'AECopper',16,6)
    if i==2:
        lathe(m,[(top+.04,.045),(top+.06,.052),(top+.085,.02)],'AEWhite',10)
        m.box((0,-.077,.13),(.07,.010,.065),'AEWhite')
    if i==3:
        for z in [.08,.24]:ring(m,(0,0,z),.055,.007,'AECopper',16,6,'XY')
        gem(m,(0,-.055,.17),(.02,.012,.035),'AECyan')
    if i==4:
        path=[]
        for j in range(11):
            z=.04+j*.014;x=-.06+j*.0095
            profile=profiles[i]
            for (z0,r0),(z1,r1) in zip(profile,profile[1:]):
                if z0<=z<=z1:
                    r=r0+(r1-r0)*(z-z0)/(z1-z0);break
            path.append((x,-math.sqrt(max(.0001,r*r-x*x))-.003,z))
        for a,b in zip(path,path[1:]):rod(m,a,b,.006,'AELeather')
        for a in [0,2.09,4.19]:rod(m,(.05*math.cos(a),.05*math.sin(a),.015),(.065*math.cos(a),.065*math.sin(a),-.025),.012,'AECopper')

def armor(m,i):
    # Two separately thickened anatomical shell plates, open at neck, arms and waist.
    front=['AESteel','AELeather','AEMoss','AEWhite','AEIron'][i]
    outline=[(-.29,.15),(-.31,.44),(-.22,.61),(-.12,.62),(-.09,.53),(.09,.53),(.12,.62),(.22,.61),(.31,.44),(.29,.15),(.17,.09),(-.17,.09)]
    armor_shell(m,front)
    armor_shell(m,'AELeather' if i in [1,2] else front,True)
    shell_vertex_count=len(m.vertices)
    for x in [-.185,.185]:m.box((x,-.01,.591),(.10,.32,.033),'AELeather')
    for z in [.19,.30]:
        for x in [-.283,.283]:m.box((x,0,z),(.035,.34,.055),'AELeather')
        m.box((0,-.20,z),(.065,.017,.055),'AECopper')
    if i==0:
        for z in [.14,.22,.30]:bent_plate(m,[(-.23,z),(-.25,z+.07),(.25,z+.07),(.23,z)],-.20,.018,'AESteel')
        bent_plate(m,[(-.20,.35),(-.17,.49),(-.045,.47),(-.035,.36)],-.202,.017,'AEAsh')
        rod(m,(.065,-.195,.39),(.18,-.195,.48),.004,'AEDark')
    if i==1:
        for x,z,s in [(-.12,.42,.12),(.12,.42,.12),(0,.54,.12),(-.09,.25,.11),(.09,.25,.11)]:
            bent_plate(m,[(x-s,z+.08),(x,z+.115),(x+s,z+.08),(x+s*.8,z),(x,z-.095),(x-s*.8,z)],-.205,.018,'AEIron')
            rod(m,(x,-.218,z-.07),(x,-.218,z+.08),.008,'AECopper')
    if i==2:
        ring(m,(0,.005,.60),.128,.019,'AECloth',20,6,'XY')
        for x in [-.18,-.09,0,.09,.18]:bent_plate(m,[(x-.028,.35),(x-.025,.49),(x+.025,.49),(x+.028,.35)],-.20,.024,'AECopper')
        for x in [-.18,0,.18]:ring(m,(x,.17,.42),.021,.006,'AECopper',12,4)
    if i==3:
        for x in [-.275,.275]:ellipsoid(m,(x,0,.53),(.11,.21,.075),'AEWhite',10,4)
        bent_plate(m,[(-.085,.40),(0,.50),(.085,.40),(0,.29)],-.210,.034,'AECopper')
        gem(m,(0,-.239,.402),(.042,.015,.065),'AECyan')
        for x in [-.19,.19]:plate(m,[(x-.07,.05),(x-.08,.18),(x+.08,.18),(x+.07,.05)],-.18,.027,'AEWhite')
    if i==4:
        for z in [.34,.40,.46]:
            for s in [-1,1]:rod(m,(s*.025,-.205,z+.02),(s*.23,-.205,z-.015),.015,'AEIron')
        for x in [-.21,.21]:rod(m,(x,.02,.61),(x*1.10,.15,.69),.027,'AEIron',6,.006)
        gem(m,(0,-.20,.49),(.035,.02,.04),'AEBerry')
    for x in [-.21,.21]:
        for z in [.19,.45,.545]:ellipsoid(m,(x,-.196,z),(.010,.007,.010),'AECopper',8,4)
    # Conform ornament parts to the curved breastplate and vary each garment's cut.
    for index,(x,y,z) in enumerate(m.vertices):
        if index>=shell_vertex_count and y<-.18:y=chest_surface(x)+(y+.19)
        elif i==2 and index>=shell_vertex_count and y>.165:
            # Back-ring band follows the back plate instead of sinking into it.
            y=.193-(chest_surface(x)+.218)*(.045/.075)+(y-.164)
        width=[1,.96,.88,1.05,.91][i];height=[1,.91,1.09,1.04,.98][i]
        m.vertices[index]=(x*width,y,z*height)

def jewelry(m,i):
    # Display at pawn accessory scale, documented; ring hole remains completely open.
    metal=['AECopper','AESteel','AECopper','AECopper','AEIron'][i]
    ring(m,(0,0,.065),.053,.009,metal,32,6)
    if i==0:
        for s in [-1,1]:
            rod(m,(s*.045,0,.094),(s*.027,-.002,.132),.011,metal)
            ellipsoid(m,(s*.025,0,.129),(.018,.014,.012),metal,8,4)
            ellipsoid(m,(s*.021,-.014,.13),(.004,.003,.003),'AERed',6,4)
        gem(m,(0,0,.126),(.019,.014,.023),'AERed')
    elif i==1:
        for s in [-1,1]:
            for a,b in [((s*.044,0,.10),(s*.03,0,.139)),((s*.03,0,.139),(s*.012,0,.15))]:rod(m,a,b,.006,metal)
            rod(m,(s*.012,0,.15),(s*.004,0,.147),.004,metal)
        gem(m,(0,0,.138),(.013,.012,.018),'AECyan')
    elif i==2:
        m.box((0,0,.125),(.062,.038,.025),metal)
        m.box((0,0,.140),(.048,.032,.009),'AERed')
        m.box((0,0,.147),(.006,.022,.006),'AECopper')
    elif i==3:
        for j in range(6):
            a=math.tau*j/6;rod(m,(.022*math.cos(a),0,.132+.022*math.sin(a)),(.040*math.cos(a),0,.132+.040*math.sin(a)),.004,metal,6)
        ellipsoid(m,(0,0,.132),(.025,.018,.025),'AEYellow',12,6)
    else:
        for s in [-1,1]:
            rod(m,(s*.04,0,.10),(s*.024,0,.139),.007,metal)
            rod(m,(s*.029,0,.121),(s*.046,0,.137),.005,metal,6,.002)
            rod(m,(s*.024,0,.139),(s*.012,0,.145),.005,metal)
        gem(m,(0,0,.139),(.021,.017,.028),'AEPurple')

def rune(m,i):
    if i==0:points=[(.10*math.cos(math.tau*j/6),.115+.10*math.sin(math.tau*j/6)) for j in range(6)]
    elif i==1:points=[(.105*math.cos(math.tau*j/16),.12+.085*math.sin(math.tau*j/16)) for j in range(16)]
    elif i==2:points=[(-.075,.015),(.07,.025),(.09,.18),(.055,.245),(-.08,.23)]
    elif i==3:points=[(-.06,.24),(.045,.23),(.035,.13),(.015,.05),(-.055,0),(-.01,.10)]
    else:points=[((.115 if j%2==0 else .065)*math.sin(math.pi*j/5),.13+(.115 if j%2==0 else .065)*math.cos(math.pi*j/5)) for j in range(10)]
    plate(m,points,0,.04,['AEIron','AECyan','AEBrown','AEBone','AEDark'][i])
    y=-.026;mat=['AECopper','AESteel','AELeaf','AEBlue','AEPurple'][i]
    glyphs=[[[(-.05,.07),(0,.13),(.04,.08)],[(0,.13),(0,.19),(.05,.16)]],
            [[(-.06,.15),(-.03,.18),(.025,.07),(.055,.11)],[(-.055,.10),(0,.06),(.06,.15)]],
            [[(0,.21),(0,.10),(-.045,.055)],[(0,.12),(.05,.06)],[(-.03,.20),(0,.16),(.04,.20)]],
            [[(-.025,.17),(.012,.15),(-.018,.13)],[(-.015,.10),(.012,.13),(.018,.17)]],
            [[(-.055,.14),(0,.19),(.055,.14),(0,.075),(-.055,.14)]]]
    for path in glyphs[i]:
        for a,b in zip(path,path[1:]):rod(m,(a[0],y,a[1]),(b[0],y,b[1]),.006,mat,6)
    if i==2:
        for x in [-.047,.045]:ellipsoid(m,(x,-.029,.04),(.009,.005,.009),'AECopper',8,4)
    if i==4:ellipsoid(m,(0,-.036,.13),(.015,.01,.017),'AEPurple',8,4)

builders={'food':food,'medical':medical,'potion':potion,'armor':armor,'ring':jewelry,'rune':rune}
for row in rows:
    m=Mesh();builders[row['category']](m,row['variant'])
    obj=m.finish(row['name'],col)
    obj['asset_category']=row['category'];obj['lore']=row['lore']
    if row['category']=='armor':
        for v in obj.data.vertices:v.co.z-=.34
        row['origin']='torso mount, z = source standing chest center; rigid armor requires pawn fit review'
    else:
        minimum=min(v.co.z for v in obj.data.vertices)
        for v in obj.data.vertices:v.co.z-=minimum
        row['origin']='object base / jewelry display base; no gameplay attachment configured'
    row['references']=refs[row['category']]
    row['review_status']='pending visual review'
    objects.append(obj)
report=P['finish_batch']('Items',scene,objects,rows)
(BASE/'Items/lore.md').write_text('# 物品背景与造型\n\n原创奇幻设定；不定义治疗数值或装备属性。\n\n'+'\n\n'.join('## '+r['title']+' / '+r['name']+'\n\n'+r['lore'] for r in rows),encoding='utf8')
print(json.dumps({'items':len(report),'triangles':sum(r['triangles'] for r in report)}))
