"""Twelve compact, face-mounted additions. Execute through the live Blender MCP only."""
import bpy,math,json,runpy,bmesh,hashlib
from pathlib import Path
ROOT=Path('D:/Program/Unity/Project Y/Art/SocketExpansion202610')
for folder in ('Source','Scripts','Staging','Previews','Integration'):(ROOT/folder).mkdir(parents=True,exist_ok=True)
assert 'SocketExpansion202610_Source' not in bpy.data.scenes,'Inspect the existing source instead of rebuilding blindly'
scene=bpy.data.scenes.new('SocketExpansion202610_Source');bpy.context.window.scene=scene;scene.unit_settings.scale_length=1
masters=bpy.data.collections.new('SocketExpansion202610');scene.collection.children.link(masters)
g=runpy.run_path('D:/Program/Unity/Project Y/Art/ArsenalExpansion202610/Scripts/geometry.py')
Mesh,beam,ring,crystal,lathe,plate=[g[k] for k in ('Mesh','beam','ring','crystal','lathe','plate')]
ALLOWED={'M_MapLP_EqBronze','M_MapLP_EqIron','M_MapLP_EqCyan','M_MapLP_EqAmber'}
for name in ALLOWED:assert name in bpy.data.materials,name

def face(m,width,height):
    m.box((0,-.0075,0),(width,.015,height),'EqIron')

def tube(m,x,y0,y1,z,outer,inner,material,sides=8):
    points=[(x+r*math.cos(i*math.tau/sides),y,z+r*math.sin(i*math.tau/sides))
            for y,r in ((y0,outer),(y1,outer),(y0,inner),(y1,inner)) for i in range(sides)]
    faces=[]
    for i in range(sides):
        j=(i+1)%sides
        faces += [(i,j,sides+j,sides+i),(2*sides+i,3*sides+i,3*sides+j,2*sides+j),
                  (i,2*sides+i,2*sides+j,j),(sides+i,sides+j,3*sides+j,3*sides+i)]
    m.part(points,faces,material)

def leather(m):
    face(m,.060,.150)
    for z in (-.064,-.032,0,.032,.064):
        ring(m,(0,-.040,z),.030,.008,'EqAmber',sides=10,start=.12,sweep=math.tau-.24)
    for x in (-.026,.026):beam(m,(x,-.061,-.071),(x,-.061,.071),.008,'EqIron',4)
    m.box((0,-.076,.025),(.036,.015,.032),'EqBronze')
    m.box((0,-.084,.025),(.020,.005,.018),'EqIron')
    for z in (-.040,.066):m.box((0,-.073,z),(.042,.010,.010),'EqBronze')

def strap(m):
    face(m,.055,.095)
    for sign in (-1,1):
        points=[(sign*.023,-.014,-.055),(sign*.055,-.077,-.025),(sign*.045,-.095,.065),(sign*.020,-.025,.10)]
        for a,b in zip(points,points[1:]):beam(m,a,b,.010,'EqAmber',4)
    beam(m,(-.045,-.096,.065),(.045,-.096,.065),.012,'EqBronze',6)
    beam(m,(-.05,-.080,-.02),(.044,-.095,.06),.008,'EqIron',4)
    m.box((0,-.027,.055),(.035,.017,.028),'EqBronze')

def counterweight(m):
    lathe(m,[(0,.025),(-.030,.025),(-.047,.051),(-.090,.058),(-.125,.038),(-.138,.015)],'EqIron',sides=10)
    ring(m,(0,0,-.085),.057,.008,'EqBronze',sides=10)
    for x in (-.035,.035):beam(m,(x,-.038,-.048),(x,-.038,-.116),.006,'EqBronze',4)
    crystal(m,(0,-.052,-.084),.017,.045,'EqAmber')

def bloodweight(m):
    lathe(m,[(0,.025),(-.030,.025),(-.047,.041)],'EqBronze',sides=8)
    crystal(m,(0,0,-.080),.045,.145,'EqAmber',axis=(0,0,-1))
    for sign in (-1,1):
        beam(m,(sign*.021,0,-.028),(sign*.050,0,-.076),.008,'EqIron',6)
        beam(m,(sign*.050,0,-.076),(0,0,-.151),.007,'EqIron',6,.5)
    m.box((0,-.046,-.077),(.014,.010,.052),'EqBronze')

def farlimb(m):
    face(m,.040,.170)
    for z in (-.073,.073):m.box((0,-.021,z),(.085,.025,.022),'EqBronze')
    for sign in (-1,1):
        beam(m,(sign*.014,-.035,-.11),(sign*.034,-.035,.025),.009,'EqIron',6)
        beam(m,(sign*.034,-.035,.025),(sign*.015,-.035,.11),.008,'EqIron',6)
    beam(m,(0,-.047,-.065),(0,-.047,.065),.009,'EqCyan',6)
    for z in (-.075,.075):beam(m,(0,-.032,z),(0,-.049,z),.014,'EqIron',6)

def powerlimb(m):
    face(m,.055,.155)
    for sign in (-1,1):
        beam(m,(sign*.045,-.030,-.095),(-sign*.045,-.030,.095),.014,'EqIron',4)
    for z in (-.071,.071):m.box((0,-.019,z),(.10,.022,.028),'EqBronze')
    beam(m,(0,-.030,0),(0,-.068,0),.032,'EqBronze',6)
    beam(m,(0,-.069,0),(0,-.076,0),.019,'EqIron',6)
    for sign in (-1,1):m.box((sign*.041,-.040,sign*.075),(.025,.023,.024),'EqAmber')

def tension(m):
    face(m,.030,.130)
    lathe(m,[(-.054,.018),(-.039,.026),(.039,.026),(.054,.018)],'EqIron',y=-.037,sides=6)
    for z in (-.073,.073):
        beam(m,(0,-.037,z),(0,-.037,z+(.023 if z<0 else -.023)),.009,'EqBronze',6)
        ring(m,(0,-.037,z+(-.017 if z<0 else .017)),.026,.007,'EqBronze',normal=(0,1,0),sides=10)
    for z in (-.020,0,.020):m.box((0,-.064,z),(.023,.006,.006),'EqAmber')

def tideline(m):
    face(m,.036,.160)
    for z in (-.057,.057):
        ring(m,(0,-.043,z),.033,.008,'EqBronze',normal=(0,1,0),sides=10)
        beam(m,(0,-.016,z),(0,-.056,z),.013,'EqIron',6)
    crystal(m,(0,-.042,0),.021,.074,'EqCyan')
    for a,b in [((-.024,-.045,-.085),(.030,-.045,-.03)),((.030,-.045,-.03),(-.030,-.045,.03)),((-.030,-.045,.03),(.024,-.045,.085))]:beam(m,a,b,.004,'EqCyan',4)

def breaker(m):
    tube(m,0,0,-.165,0,.042,.024,'EqIron',10)
    for y in (-.018,-.083,-.146):tube(m,0,y+.010,y-.010,0,.050,.024,'EqBronze',10)
    for sign in (-1,1):
        m.box((sign*.047,-.061,0),(.014,.040,.045),'EqIron')
        m.box((sign*.047,-.116,0),(.014,.027,.045),'EqIron')
    for z in (-.038,.038):m.box((0,-.060,z),(.025,.028,.012),'EqAmber')

def splitter(m):
    tube(m,0,0,-.065,0,.043,.024,'EqIron',8)
    for x in (-.040,.040):
        tube(m,x,-.070,-.175,0,.031,.019,'EqIron',8)
        tube(m,x,-.142,-.166,0,.037,.019,'EqBronze',8)
        beam(m,(0,-.044,.026),(x,-.092,.026),.012,'EqBronze',6)
        beam(m,(0,-.044,-.026),(x,-.092,-.026),.012,'EqBronze',6)
    m.box((0,-.071,0),(.085,.026,.025),'EqIron')

def stockface(m):
    m.box((-.0075,0,0),(.015,.145,.080),'EqIron')
    for y in (-.056,.056):m.box((-.018,y,0),(.022,.018,.092),'EqBronze')

def rangefinder(m):
    stockface(m)
    m.box((-.041,.006,.004),(.052,.108,.061),'EqIron')
    tube(m,-.047,-.035,-.084,.014,.025,.015,'EqBronze',8)
    beam(m,(-.047,-.078,.014),(-.047,-.081,.014),.014,'EqCyan',8)
    m.box((-.069,.018,.005),(.010,.060,.035),'EqAmber')
    for y in (-.005,.015,.035):m.box((-.075,y,.007),(.005,.005,.023),'EqIron')
    ring(m,(-.047,.035,.042),.019,.005,'EqBronze',normal=(0,0,1),sides=8)

def springstock(m):
    stockface(m)
    for y in (-.083,.083):m.box((-.048,y,0),(.066,.018,.070),'EqIron')
    beam(m,(-.052,-.078,0),(-.052,.078,0),.010,'EqIron',6)
    points=[(-.052+.026*math.cos(i*math.tau/8),-.078+i*.004875,.026*math.sin(i*math.tau/8)) for i in range(33)]
    for a,b in zip(points,points[1:]):beam(m,a,b,.006,'EqBronze',5)
    beam(m,(-.084,-.080,-.030),(-.084,.080,-.030),.006,'EqIron',5)
    m.box((-.052,.091,0),(.041,.013,.041),'EqCyan')

DESIGNS=[
    (730,'缠革稳握柄','grip','LeatherGrip',leather),(731,'护手织带','grip','GuardStrap',strap),
    (732,'破势配重','pommel','ImpactWeight',counterweight),(733,'汲血配重','pommel','SiphonWeight',bloodweight),
    (734,'远猎弓臂','bowlimb','FarHuntBrace',farlimb),(735,'强力弓臂','bowlimb','PowerBrace',powerlimb),
    (736,'校准弓弦','bowstring','CalibratedTensioner',tension),(737,'潮线弓弦','bowstring','TidalPulley',tideline),
    (738,'破甲枪口','muzzle','BreakerMuzzle',breaker),(739,'分流枪口','muzzle','SplitterMuzzle',splitter),
    (740,'测距枪托','stock','RangefinderStock',rangefinder),(741,'复进枪托','stock','RecoilSpring',springstock)]
AXES={
    'grip':{'contactPlane':'Z=0','outward':'+Z','longAxis':'+Y'},
    'pommel':{'contactPlane':'Y=0','outward':'-Y','longAxis':'Y'},
    'bowlimb':{'contactPlane':'Z=0','outward':'+Z','longAxis':'+Y'},
    'bowstring':{'contactPlane':'Z=0','outward':'+Z','longAxis':'+Y'},
    'muzzle':{'contactPlane':'Z=0','outward':'+Z','longAxis':'+Z'},
    'stock':{'contactPlane':'X=0','outward':'+X','longAxis':'Z'}}
report=[]
for item,name,kind,label,build in DESIGNS:
    m=Mesh();build(m);obj=m.finish('Socket_'+str(item),masters)
    obj['item_id']=item;obj['display_name']=name;obj['slot_kind']=kind
    obj.data.calc_loop_triangles()
    assert all(p.area>1e-10 and not p.use_smooth for p in obj.data.polygons)
    assert {mat.name for mat in obj.data.materials}<=ALLOWED
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(edge.is_manifold for edge in bm.edges);bm.free()
    coordinates=[(-v.co.x,v.co.z,-v.co.y) for v in obj.data.vertices]
    low=[min(v[i] for v in coordinates) for i in range(3)];high=[max(v[i] for v in coordinates) for i in range(3)]
    size=[high[i]-low[i] for i in range(3)]
    assert .08<=max(size)<=.25,(item,size)
    if kind=='pommel':assert abs(high[1])<1e-7
    elif kind=='stock':assert abs(low[0])<1e-7
    else:assert abs(low[2])<1e-7
    report.append({'id':item,'name':name,'label':label,'slotKind':kind,'model':obj.name,
        'boundsUnity':{'min':low,'max':high,'size':size},'origin':[0,0,0],'rotation':[0,0,0],'scale':[1,1,1],
        'axesUnity':AXES[kind],'triangles':len(obj.data.loop_triangles),'vertices':len(obj.data.vertices),
        'uvLayers':len(obj.data.uv_layers),'nonManifoldEdges':0,'materials':[mat.name for mat in obj.data.materials],
        'geometrySha256':hashlib.sha256(repr(([tuple(v.co) for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons])).encode()).hexdigest(),
        'fbx':'Art/SocketExpansion202610/Staging/'+obj.name+'.fbx'})
    print(item,kind,'Unity size',size,'triangles',len(obj.data.loop_triangles))
bpy.context.view_layer.update()
assert len({r['geometrySha256'] for r in report})==12
manifest={'version':1,'status':'authored','coordinateConversion':'Blender (x,y,z) -> Unity (-x,z,-y), verified project FBX preset; Unity bakeAxisConversion=true and globalScale=1',
    'source':'Art/SocketExpansion202610/Source/WeaponAttachments.blend','pureColor':True,'models':report}
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(ROOT/'Source/WeaponAttachments.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print('SOURCE_COMPLETE',len(report),'models; original scenes preserved')
