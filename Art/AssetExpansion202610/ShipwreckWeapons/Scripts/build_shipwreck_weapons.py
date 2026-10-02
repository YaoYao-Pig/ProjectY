"""Ten authored sea relic weapons. Run only under an exclusive Blender MCP slot."""
import bpy,bmesh,math,json,runpy
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y');BASE=ROOT/'Art/AssetExpansion202610/ShipwreckWeapons'
PIPE=runpy.run_path(str(BASE.parent/'shared_pipeline.py'))
# Loading this module defines helpers; its guarded build() is deliberately not called.
W=runpy.run_path(str(BASE.parent/'Weapons/build_weapons.py'))
M=W['M'];beam=W['beam'];sweep=W['sweep'];profile=W['profile'];ring=W['ring'];gem=W['gem'];ridgeblade=W['ridgeblade'];applique=W['blade_applique']
PAL={'Steel':'778f95','Edge':'c4d2cd','Iron':'49555a','Dark':'303b42','Copper':'aa7849','Gold':'bdab77','Wood':'67513d','Lightwood':'987d58','Leather':'463e36','Bone':'d4c7a8','Red':'90584e','Green':'587668','Blue':'556e78','Cyan':'7aa8a1','Purple':'807c91','Cloth':'b8b09a','Verdigris':'648c7d','Pearl':'d9d9c6','Tar':'303634','Amber':'ddba72'}
def col(k):return 'SWW_'+k
W['beam'].__globals__['col']=col
M.finish.__globals__['PALETTE'].update({col(k):v for k,v in PAL.items()})
MATS={}
def ensure(key):
    k=key.removeprefix('SWW_');name='M_ShipwreckWeapons_'+k
    if name in bpy.data.materials:return bpy.data.materials[name]
    h=PAL[k];rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    rgba=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat.diffuse_color=rgba
    node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value=rgba;node.inputs['Roughness'].default_value=.86;node.inputs['Metallic'].default_value=0
    mat['palette_srgb']='#'+h;return mat
M.finish.__globals__['ensure_material']=ensure

def grip(m,lo=-.11,hi=.11,r=.033,mat='Leather',trim='Copper'):
    beam(m,(0,0,lo),(0,0,hi),r,mat,10)
    for i in range(7):
        z=lo+(hi-lo)*(i+.18)/7;beam(m,(0,0,z),(0,0,z+.012),r*1.045,'Cloth' if mat=='Cloth' else mat,10)
    for z in (lo-.018,hi-.005):beam(m,(0,0,z),(0,0,z+.027),r*1.23,trim,10)
def lathe(m,layers,n,mat,center=(0,0,0),axis='Z',caps=True):
    # r, axis coordinate. Includes inner-wall profile where a hollow form is needed.
    cx,cy,cz=center;v=[];f=[]
    for r,d in layers:
        for i in range(n):
            a=math.tau*i/n
            v.append((cx+r*math.cos(a),cy+r*math.sin(a),cz+d) if axis=='Z' else (cx+d,cy+r*math.cos(a),cz+r*math.sin(a)))
    for j in range(len(layers)-1):
        for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    if caps:f=[tuple(reversed(range(n)))]+f+[tuple(range((len(layers)-1)*n,len(layers)*n))]
    else:
        j=len(layers)-1
        for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(i+1)%n,i))
    m.part(v,f,col(mat))
def flatblade(m,outline,depth=.027,mat='Steel',edge='Edge'):
    n=len(outline);cx=sum(x for x,z in outline)/n;cz=sum(z for x,z in outline)/n
    v=[(x,0,z) for x,z in outline]+[(cx+(x-cx)*.91,-depth,cz+(z-cz)*.965) for x,z in outline]+[(cx+(x-cx)*.91,depth,cz+(z-cz)*.965) for x,z in outline]
    f=[tuple(range(n,2*n)),tuple(reversed(range(2*n,3*n)))];c=[col(mat)]*2
    for i in range(n):
        j=(i+1)%n;f.extend([(i,j,n+j,n+i),(j,i,2*n+i,2*n+j)]);c.extend([col(edge),col(edge)])
    m.part(v,f,c)
def shell(m,z,width=.12,depth=.048,mat='Pearl'):
    # Closed scallop shell, broad face toward -Y, used as a practical hand guard.
    outline=[(0,z-.015)]
    for i in range(11):
        a=math.pi*i/10;outline.append((width*math.cos(a),z+.02+width*.65*math.sin(a)))
    flatblade(m,outline,depth,mat,'Bone')
def chain(m,z,links=2):
    for i in range(links):ring(m,(0,0,z-.058*i),.037,.008,'Iron','XZ' if i%2==0 else 'YZ',12)

def cutlass(m):
    grip(m,mat='Blue');ring(m,(0,0,-.145),.035,.011,'Copper','XY',12)
    front=ridgeblade(m,[(.13,.086,0),(.26,.122,.014),(.46,.135,.047),(.65,.114,.103),(.78,.045,.18),(.835,.006,.21)],.021,'Steel','Edge',True)
    sweep(m,[(-.10,0,.14),(-.135,-.007,.05),(-.137,-.012,-.10),(-.066,0,-.147),(0,0,-.14)],[.023,.021,.021,.021,.026],'Copper',8)
    profile(m,[(-.115,.123),(.086,.114),(.086,.145),(-.092,.168)],.048,'Copper')
    beam(m,(0,-.024,.143),(0,-.035,.143),.041,'Verdigris',12)
    for z,x in [(.32,.027),(.38,.036),(.44,.043)]:applique(m,[(x-.028,z+.01),(x+.035,z-.004),(x+.034,z-.012),(x-.027,z+.004)],front,'Dark',.0007)

def boarder(m):
    grip(m,r=.037,mat='Cloth',trim='Iron')
    outline=[(-.055,.13),(.055,.13),(.06,.24),(.112,.28),(.063,.30),(.118,.365),(.068,.38),(.13,.445),(.08,.463),(.145,.53),(.095,.548),(.16,.618),(.12,.634),(.20,.745),(.12,.77),(-.05,.71),(-.066,.55),(-.07,.31)]
    flatblade(m,outline,.026,'Iron','Steel')
    profile(m,[(-.09,.13),(.12,.13),(.105,.17),(-.088,.17)],.071,'Copper')
    for x in [-.049,.049]:beam(m,(x,-.028,.24),(x,-.037,.24),.01,'Copper',8)
    # Short reinforcing strap sits on the flat central face.
    profile(m,[(-.038,.22),(.045,.22),(.045,.24),(-.038,.24)],.006,'Copper',(0,-.026,0))
    chain(m,-.165,1)

def bellmaul(m):
    sweep(m,[(0,0,-.23),(0,0,.17),(.025,0,.51),(.015,0,.79)], [.035,.037,.032,.044],'Wood',9)
    grip(m,lo=-.13,hi=.16,mat='Leather')
    for z in [.34,.41,.48,.55]:beam(m,(.017,0,z),(.017,0,z+.023),.042,'Copper',10)
    # Hollow bell faces -X; looped cross-section gives a real inner cavity and thick rim.
    lathe(m,[(.07,.11),(.115,.02),(.13,-.12),(.205,-.25),(.211,-.28),(.173,-.28),(.16,-.24),(.102,-.1),(.079,.035),(.041,.075)],12,'Copper',(0,0,.88),'X',False)
    beam(m,(.1,0,.88),(-.18,0,.88),.028,'Iron',8)
    beam(m,(-.185,0,.88),(-.222,0,.88),.06,'Verdigris',10)
    m.box((.165,0,.88),(.17,.15,.15),col('Iron'))
    m.box((.263,0,.88),(.044,.194,.194),col('Steel'))
    beam(m,(.008,0,.73),(.008,0,.85),.065,'Iron',8)
    ring(m,(-.27,0,.88),.192,.012,'Gold','YZ',16)

def anchoraxe(m):
    sweep(m,[(0,0,-.42),(0,0,.16),(.019,0,.58),(0,0,1.0)], [.042,.045,.048,.058],'Wood',8)
    grip(m,lo=-.15,hi=.14,r=.048,mat='Blue',trim='Iron')
    for z in [.29,.34,.39]:beam(m,(.008,0,z),(.008,0,z+.036),.05,'Cloth',8)
    beam(m,(-.25,0,.65),(.26,0,.65),.045,'Iron',8)
    ring(m,(0,0,1.05),.095,.023,'Iron','XZ',16)
    for side in [-1,1]:
        sweep(m,[(0,0,.78),(side*.2,0,.82),(side*.35,0,.98),(side*.4,0,1.15)], [.071,.066,.048,.023],'Iron',8)
        if side<0:ol=[(-.28,.87),(-.53,1.07),(-.46,1.27),(-.40,1.10),(-.32,1.02)]
        else:ol=[(.25,.88),(.48,1.05),(.46,1.19),(.38,1.13),(.31,1.01)]
        flatblade(m,ol,.037,'Steel','Edge')
    for x in [-.22,.22]:beam(m,(x,-.041,.65),(x,-.05,.65),.018,'Copper',8)
    chain(m,-.48,2)

def harpoon(m):
    beam(m,(0,0,-.73),(0,0,.77),.027,'Lightwood',9)
    grip(m,lo=-.11,hi=.14,r=.034,mat='Leather',trim='Iron')
    beam(m,(0,0,-.78),(0,0,-.7),.034,'Iron',9)
    beam(m,(0,0,.62),(0,0,.85),.045,'Copper',10)
    for z in [.64,.673,.706,.739]:ring(m,(0,0,z),.05,.009,'Cloth','XY',12)
    ridgeblade(m,[(.8,.071,0),(.96,.065,0),(1.22,.005,0)],.022,'Steel','Edge')
    for s,z in [(-1,.98),(1,.94)]:flatblade(m,[(0,z+.055),(s*.142,z-.102),(s*.123,z-.12),(s*.056,z-.047),(0,z-.04)],.015,'Iron','Steel')
    beam(m,(0,0,.35),(0,0,.40),.032,'Bone',9)

def dagger(m):
    grip(m,lo=-.10,hi=.08,r=.026,mat='Green',trim='Copper')
    front=ridgeblade(m,[(.095,.07,0),(.19,.15,.006),(.29,.11,.022),(.365,.015,.038),(.388,.004,.041)],.025,'Pearl','Edge',True)
    shell(m,.064,.115,.037)
    lathe(m,[(.018,-.149),(.041,-.135),(.041,-.118),(.023,-.108)],10,'Pearl')
    applique(m,[(-.018,.185),(.015,.244),(.019,.244),(-.01,.183)],front,'Steel',.0006)

def arbalest(m):
    outline=[(-.61,.075),(-.58,.19),(.04,.18),(.16,.1),(.33,.09),(.39,-.19),(.31,-.255),(.2,-.235),(.13,-.066),(-.18,-.022),(-.22,.071)]
    profile(m,outline,.13,'Blue',axis='X')
    for x in [-.037,.037]:beam(m,(x,-.57,.19),(x,.015,.19),.013,'Iron',6)
    pts=[(-.54,-.25,.18),(-.43,-.38,.18),(-.22,-.44,.18),(0,-.44,.18),(.22,-.44,.18),(.43,-.38,.18),(.54,-.25,.18)]
    sweep(m,pts,[.02,.03,.044,.052,.044,.03,.02],'Copper',8)
    sweep(m,[pts[0],(0,-.13,.195),pts[-1]],.005,'Cloth',6)
    beam(m,(-.11,-.08,.14),(.11,-.08,.14),.052,'Wood',10)
    for x in [-.115,.115]:
        ring(m,(x,-.08,.14),.091,.014,'Copper','YZ',14)
        beam(m,(x,-.08,.05),(x,-.08,.23),.01,'Copper',6)
        beam(m,(x,-.17,.14),(x,.01,.14),.01,'Copper',6)
        sweep(m,[(x,-.08,.14),(x*1.4,-.08,.14),(x*1.4,.02,.19)],.01,'Iron',6)
    for y in [-.50,-.29]:
        profile(m,[(y-.018,.025),(y+.018,.025),(y+.018,.171),(y-.018,.171)],.144,'Copper',axis='X')
    sweep(m,[(-.055,-.58,.13),(-.092,-.72,.1),(.092,-.72,.1),(.055,-.58,.13)],.018,'Iron',6)
    sweep(m,[(0,.1,.03),(0,.095,-.098),(0,.185,-.122),(0,.223,-.02)],.011,'Copper',6)
    beam(m,(0,.157,.04),(0,.145,-.052),.008,'Iron',6)
    m.vertices=[(x,y-.24,z+.14) for x,y,z in m.vertices]

def serpentbow(m):
    pts=[(.42,0,-.79),(.35,0,-.67),(.30,0,-.51),(.20,0,-.28),(0,0,-.13),(0,0,0),(0,0,.13),(.16,0,.28),(.30,0,.51),(.35,0,.67),(.42,0,.8)]
    rr=[.018,.025,.033,.042,.04,.04,.04,.042,.033,.025,.018]
    sweep(m,pts,rr,'Wood',8)
    # A seated bone belly follows the same curved limb, 4 mm embedded into wood.
    for subset,radii in [(pts[:5],rr[:5]),(pts[6:],rr[6:])]:
        sweep(m,[(x-.008,-.02,z) for x,y,z in subset],[r*.55 for r in radii],'Bone',6)
    grip(m,lo=-.1,hi=.1,r=.041,mat='Green',trim='Copper')
    for side,idx in [(-1,0),(1,-1)]:
        x,y,z=pts[idx]
        outline=[(x+.012,z-side*.026),(x-.06,z+side*.035),(x-.14,z+side*.063),(x-.173,z+side*.032),(x-.125,z+side*.019),(x-.107,z-side*.003),(x+.009,z-side*.010)]
        profile(m,outline,.05,'Verdigris')
        beam(m,(x-.095,-.025,z+side*.025),(x-.095,-.03,z+side*.025),.008,'Dark',7)
    sweep(m,[pts[0],pts[-1]],.0032,'Cloth',6)

def lighthouse(m):
    sweep(m,[(.025,0,-.85),(-.023,0,-.55),(0,0,-.13),(0,0,.13),(.025,0,.48),(-.012,0,.82)],[.024,.028,.033,.033,.035,.043],'Wood',9)
    grip(m,lo=-.12,hi=.13,r=.036,mat='Cloth')
    beam(m,(.025,0,-.88),(.025,0,-.81),.031,'Copper',9)
    lathe(m,[(.055,.77),(.145,.82),(.155,.85),(.133,.875)],6,'Copper')
    gem(m,(0,0,1.005),.071,.25,'Amber')
    beam(m,(0,0,.854),(0,0,.922),.033,'Gold',8)
    for i in range(6):
        a=math.tau*i/6;x=.122*math.cos(a);y=.122*math.sin(a)
        beam(m,(x,y,.86),(x,y,1.13),.012,'Copper',6)
    lathe(m,[(.132,1.123),(.163,1.155),(.155,1.184),(.044,1.265),(.014,1.277)],6,'Copper')
    beam(m,(0,0,1.269),(0,0,1.322),.015,'Iron',8)
    ring(m,(0,0,1.351),.03,.007,'Iron','XZ',12)
    for z in [.4,.46]:beam(m,(.018,0,z),(.018,0,z+.023),.042,'Verdigris',9)

def handgun(m):
    outline=[(-.36,.102),(-.31,.2),(.02,.194),(.1,.122),(.14,.012),(.205,-.208),(.15,-.294),(.07,-.283),(.018,-.192),(.063,-.074),(-.006,.035),(-.31,.041)]
    profile(m,outline,.083,'Lightwood',axis='X')
    profile(m,[(-.16,.1),(-.17,.213),(.041,.21),(.093,.156),(.049,.064),(-.06,.06)],.093,'Iron',axis='X')
    beam(m,(0,-.1,.192),(0,-.422,.192),.039,'Copper',12)
    beam(m,(0,-.415,.192),(0,-.54,.192),.041,'Copper',12,.068)
    # Dark visual aperture is a shallow insert; no internal firearm design is supplied.
    beam(m,(0,-.539,.192),(0,-.548,.192),.06,'Dark',12)
    ring(m,(0,-.546,.192),.065,.008,'Copper','XZ',16)
    sweep(m,[(0,-.072,.044),(0,-.107,-.057),(0,-.029,-.106),(0,.063,-.084),(0,.075,-.012)],.011,'Copper',7)
    sweep(m,[(0,-.011,.072),(0,-.029,.012),(0,-.003,-.046)],.007,'Iron',6)
    sweep(m,[(.047,.012,.163),(.047,.06,.24),(.047,.012,.263)],.013,'Copper',7)
    beam(m,(.046,.012,.159),(.062,.012,.159),.031,'Copper',10)
    for x in [-.044,.044]:
        outline=[(.105,-.07),(.153,-.17),(.139,-.221),(.09,-.206),(.08,-.142)]
        profile(m,outline,.006,'Pearl',(x,0,0),axis='X')
    for z,y in [(-.16,.115),(-.205,.132)]:
        profile(m,[(y-.054,z-.012),(y+.054,z-.012),(y+.049,z+.012),(y-.049,z+.012)],.091,'Blue',axis='X')
    m.vertices=[(x,y-.12,z+.17) for x,y,z in m.vertices]

BUILDERS=[cutlass,boarder,bellmaul,anchoraxe,harpoon,dagger,arbalest,serpentbow,lighthouse,handgun]
def build():
    scene,collection=PIPE['create_scene']('ShipwreckWeapons')
    rows=json.loads((BASE/'catalog.json').read_text(encoding='utf8'));objects=[]
    assert len(rows)==len(BUILDERS)==10
    for row,fn in zip(rows,BUILDERS):
        m=M();fn(m);obj=m.finish(row['id'],collection)
        obj['lore_zh']=row['lore_zh'];obj['display_name_zh']=row['display_name_zh'];obj['grip_origin']='0,0,0 in metres'
        objects.append(obj)
    result=PIPE['finish_batch']('ShipwreckWeapons',scene,objects,rows)
    assert all(r['nonmanifold_edges']==0 for r in result),[(r['name'],r['nonmanifold_edges']) for r in result]
    print(json.dumps({'created':len(result),'triangles':sum(r['triangles'] for r in result),'source':str(BASE/'Source/ShipwreckWeapons.blend')}))
if __name__=='__main__':build()
