"""20 original maritime props. Owns AE202610_ShipwreckProps only; metres, bottom origins."""
import bpy, math, json, runpy
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path('D:/Program/Unity/Project Y');OUT=ROOT/'Art/AssetExpansion202610/ShipwreckProps'
P=runpy.run_path(str(OUT.parent/'shared_pipeline.py'))
G=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/mesh_helpers.py'));Mesh=G['MeshBuilder']
H=runpy.run_path(str(OUT.parent/'Shipwreck/build_shipwreck.py'))
beam=H['beam'];boxbeam=H['boxbeam'];lathe=H['lathe'];torus=H['torus'];extrusion=H['extrusion']
G['PALETTE'].update(SPWood='79634c',SPEnd='a18b65',SPDark='343f3d',SPIron='515e5e',SPBronze='a58d5b',SPCloth='b9b297',SPPaper='c8bb91',SPTeal='647e74',SPRed='915447',SPSand='ab9267',SPCream='d5c7a7',SPLeather='655247')
REFS={r['id']:r for r in json.loads((OUT/'References/references.json').read_text(encoding='utf8'))}

def rotate(m,start,axis,angle,offset=(0,0,0)):
    mat=Matrix.Rotation(math.radians(angle),3,axis)
    for i in range(start,len(m.vertices)):m.vertices[i]=tuple(mat@Vector(m.vertices[i])+Vector(offset))

def tube(m,profile,mat,n=12,c=(0,0,0)):
    # Closed profile cross-section; bowls have a true open cavity and solid bottom.
    v=[(c[0]+r*math.cos(j*math.tau/n),c[1]+r*math.sin(j*math.tau/n),c[2]+z) for z,r in profile for j in range(n)]
    f=[]
    for k in range(len(profile)):
        kk=(k+1)%len(profile)
        for j in range(n):f.append((k*n+j,k*n+(j+1)%n,kk*n+(j+1)%n,kk*n+j))
    m.part(v,f,mat)

def curve(m,points,r,mat='SPCloth',n=6):
    # Shared vertex rings make all elbows physically continuous, including cup handles.
    points=[Vector(p) for p in points];vertices=[]
    tangents=[(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized() for i in range(len(points))]
    basis=[Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))]
    reference=min(basis,key=lambda axis:sum(abs(axis.dot(t)) for t in tangents))
    for i,point in enumerate(points):
        tangent=tangents[i];u=tangent.cross(reference).normalized();v=tangent.cross(u).normalized()
        for j in range(n):vertices.append(tuple(point+u*(r*math.cos(j*math.tau/n))+v*(r*math.sin(j*math.tau/n))))
    faces=[tuple(reversed(range(n))),tuple(range((len(points)-1)*n,len(points)*n))]
    faces.extend((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(points)-1) for j in range(n))
    m.part(vertices,faces,mat)

def strap(m,x,y0,y1,z,w=.022,mat='SPLeather'):
    m.box((x,(y0+y1)/2,z),(w,y1-y0,.014),mat)

def compass(m):
    lathe(m,[(0,.072),(.018,.083),(.046,.084),(.053,.079)],'SPBronze',12)
    lathe(m,[(.052,.073),(.056,.073)],'SPCream',12)
    torus(m,(0,0,.058),.076,.005,'SPIron',n=24)
    for a in range(8):
        t=a*math.tau/8
        beam(m,(.062*math.sin(t),.062*math.cos(t),.058),(.069*math.sin(t),.069*math.cos(t),.058),.0016,'SPDark',4)
    extrusion(m,[(-.011,0),(0,-.054),(.011,0)],.057,.061,'SPRed')
    extrusion(m,[(-.011,0),(0,.054),(.011,0)],.057,.061,'SPDark')
    lathe(m,[(.060,.007),(.065,.007)],'SPBronze',8)
    torus(m,(0,.101,.03),.02,.004,'SPBronze',n=12)

def chart(m):
    # Three solid folded panels and broad inlaid coast silhouettes.
    sections=[(-.21,-.07,.008,.024),(-.07,.07,.024,.009),(.07,.21,.009,.022)]
    for a,b,za,zb in sections:
        v=[(a,-.15,za),(b,-.15,zb),(b,.15,zb),(a,.15,za)]
        m.part(v+[(x,y,z+.004) for x,y,z in v],[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'SPPaper')
    def surface(x):
        a,b,za,zb=next(s for s in sections if s[0]<=x<=s[1])
        return za+(zb-za)*(x-a)/(b-a)+.004
    for poly in [[(-.177,-.108),(-.105,-.12),(-.10,-.066),(-.138,-.026),(-.18,-.03)],[(.083,.018),(.133,-.022),(.18,.015),(.155,.069),(.19,.096),(.10,.112)]]:
        start=len(m.vertices);extrusion(m,poly,0,.0018,'SPTeal')
        for i in range(start,len(m.vertices)):
            x,y,z=m.vertices[i];m.vertices[i]=(x,y,surface(x)+z)
    for x,y in [(-.048,.08),(.00,.066),(.036,.035),(.059,.001)]:
        start=len(m.vertices);m.box((x,y,.0007),(.012,.006,.0014),'SPRed')
        for i in range(start,len(m.vertices)):
            xx,yy,z=m.vertices[i];m.vertices[i]=(xx,yy,surface(xx)+z)

def logbook(m):
    m.box((0,0,.01),(.22,.28,.02),'SPLeather');m.box((0,0,.042),(.207,.266,.054),'SPPaper')
    m.box((0,0,.079),(.22,.28,.02),'SPLeather');m.box((-.104,0,.044),(.018,.282,.074),'SPWood')
    for y in [-.10,.10]:m.box((-.106,y,.047),(.02,.018,.08),'SPBronze')
    m.box((.065,0,.093),(.027,.30,.011),'SPTeal');m.box((.062,-.055,.101),(.041,.035,.010),'SPBronze')
    m.box((.014,.020,.093),(.064,.091,.006),'SPWood')

def hourglass(m):
    for z in [.012,.266]:lathe(m,[(z-.012,.089),(z+.012,.089)],'SPWood',8)
    for x,y in [(-.06,-.06),(.06,-.06),(-.06,.06),(.06,.06)]:beam(m,(x,y,.024),(x,y,.254),.01,'SPBronze',6)
    lathe(m,[(.027,.048),(.045,.059),(.090,.040),(.135,.013),(.178,.04),(.219,.059),(.253,.048)],'SPTeal',10)
    lathe(m,[(.028,.0495),(.045,.0598),(.075,.0471),(.092,.040)],'SPSand',10)
    lathe(m,[(.207,.0543),(.219,.0598),(.232,.0556)],'SPSand',10)
    beam(m,(0,0,.107),(0,0,.193),.0035,'SPSand',6)

def spyglass(m):
    # Horizontal telescope laid on its widest octagonal end, not standing on an invented base.
    start=len(m.vertices)
    lathe(m,[(0,.032),(.015,.034),(.03,.028),(.11,.028),(.13,.04),(.30,.04),(.32,.049),(.43,.049),(.447,.056),(.465,.056)],'SPBronze',12)
    lathe(m,[(.146,.042),(.291,.042)],'SPLeather',12)
    lathe(m,[(.466,.045),(.468,.045)],'SPDark',12)
    lathe(m,[(.469,.036),(.47,.036)],'SPTeal',12)
    for z,r in [(.04,.03),(.12,.035),(.318,.047),(.435,.053)]:torus(m,(0,0,z),r,.004,'SPDark',n=12)
    rotate(m,start,'Y',90,(-.235,0,.056))

def lantern(m):
    lathe(m,[(0,.09),(.021,.10),(.045,.075)],'SPDark',8)
    lathe(m,[(.048,.067),(.222,.063)],'SPSand',8)
    for a in range(4):
        t=math.pi/4+a*math.pi/2;x=.078*math.cos(t);y=.078*math.sin(t)
        boxbeam(m,(x,y,.029),(x*.87,y*.87,.252),.012,.012,'SPIron')
    lathe(m,[(.225,.089),(.239,.089),(.291,.045),(.307,.038)],'SPIron',8)
    lathe(m,[(.304,.026),(.321,.024)],'SPBronze',8)
    torus(m,(0,0,.360),.046,.006,'SPIron','XZ',16)
    for z in [.055,.211]:torus(m,(0,0,z),.071,.006,'SPBronze',n=8)

def flask(m):
    start=len(m.vertices)
    lathe(m,[(0,.044),(.035,.080),(.10,.091),(.18,.067),(.21,.026),(.249,.023)],'SPLeather',12)
    for i in range(start,len(m.vertices)):
        x,y,z=m.vertices[i];m.vertices[i]=(x,y*.58,z)
    lathe(m,[(.25,.027),(.272,.027)],'SPEnd',8)
    start=len(m.vertices);torus(m,(0,0,.10),.091,.005,'SPTeal',n=12)
    for i in range(start,len(m.vertices)):
        x,y,z=m.vertices[i];m.vertices[i]=(x,y*.58,z)
    for s in [-1,1]:curve(m,[(s*.02,-.03,.228),(s*.077,-.037,.18),(s*.088,-.031,.10),(s*.065,-.03,.04)],.005,'SPBronze')

def mug(m):
    tube(m,[(0,.047),(.016,.06),(.145,.065),(.157,.062),(.157,.049),(.025,.044),(.018,.010),(0,.01)],'SPWood',12)
    lathe(m,[(0,.012),(.019,.012)],'SPWood',12)
    for z in [.026,.136]:torus(m,(0,0,z),.061,.004,'SPIron',n=12)
    curve(m,[(.052,0,.13),(.10,0,.132),(.116,0,.106),(.109,0,.048),(.054,0,.033)],.012,'SPEnd')

def bowl(m):
    tube(m,[(0,.047),(.012,.058),(.06,.095),(.084,.108),(.098,.105),(.098,.091),(.061,.079),(.026,.045),(.022,.009),(0,.009)],'SPCream',12)
    lathe(m,[(0,.011),(.023,.011)],'SPCream',12)
    torus(m,(0,0,.09),.103,.005,'SPTeal',n=12)

def plate(m):
    tube(m,[(0,.070),(.008,.11),(.032,.151),(.043,.153),(.046,.139),(.024,.108),(.018,.02),(0,.02)],'SPWood',16)
    lathe(m,[(0,.023),(.019,.023)],'SPWood',16)
    torus(m,(0,0,.039),.144,.004,'SPEnd',n=16)

def canvas(m):
    # Rolled sailcloth plus visible loose flap, shape distinct from medical parcel.
    m.box((0,-.04,.008),(.38,.23,.016),'SPCloth')
    beam(m,(-.19,.058,.065),(.19,.058,.065),.065,'SPCloth',12)
    for x in [-.145,.135]:
        torus(m,(0,0,0),.068,.006,'SPTeal',n=16)
        start=len(m.vertices)-96;rotate(m,start,'Y',90,(x,.058,.065))
    for y in [-.145,-.12]:boxbeam(m,(-.18,y,.018),(.18,y,.018),.005,.004,'SPEnd')
    beam(m,(-.191,.058,.065),(-.198,.058,.065),.04,'SPEnd',12)

def sewing(m):
    m.box((0,0,.008),(.23,.15,.016),'SPWood')
    for x in [-.111,.111]:m.box((x,0,.04),(.013,.15,.068),'SPEnd')
    for y in [-.07,.07]:m.box((0,y,.04),(.23,.012,.068),'SPEnd')
    for x in [-.061,.012]:
        lathe(m,[(.014,.023),(.022,.023),(.025,.016),(.060,.016),(.065,.023),(.071,.023)],'SPTeal' if x<0 else 'SPRed',8,c=(x,-.014,0))
    m.box((.067,.0,.043),(.058,.088,.045),'SPCloth')
    beam(m,(.055,-.035,.065),(.092,.031,.077),.0023,'SPIron',6)
    # Raised, tilted lid leaves an actual open box.
    start=len(m.vertices);m.box((0,0,0),(.23,.145,.012),'SPWood');rotate(m,start,'X',65,(0,.105,.135))
    for x in [-.063,.063]:beam(m,(x,.067,.068),(x,.078,.072),.01,'SPBronze',8)

def rope(m):
    for r in [.037,.057,.077,.097]:torus(m,(0,0,.012),r,.009,'SPSand',n=20)
    curve(m,[(-.092,-.004,.013),(-.132,-.045,.013),(-.117,-.098,.014),(-.062,-.115,.019),(-.037,-.081,.025),(-.071,-.072,.03),(-.10,-.104,.027),(-.122,-.145,.014)],.009,'SPSand')
    beam(m,(-.02,-.084,.018),(.031,-.115,.018),.01,'SPDark',6)

def pulley(m):
    # A working block silhouette: twin cheek plates, sheave and a stout eye.
    poly=[(-.073,-.065),(.073,-.065),(.085,.02),(.045,.075),(-.045,.075),(-.085,.02)]
    for z in [.012,.105]:extrusion(m,poly,z,z+.018,'SPWood')
    start=len(m.vertices)
    lathe(m,[(.034,.059),(.044,.059),(.048,.05),(.084,.05),(.088,.059),(.1,.059)],'SPIron',12)
    for z in [.052,.079]:torus(m,(0,0,z),.052,.004,'SPSand',n=16)
    beam(m,(0,0,0),(0,0,.138),.015,'SPBronze',8)
    torus(m,(0,.105,.069),.033,.009,'SPIron','XZ',12)
    boxbeam(m,(0,.052,.064),(0,.105,.036),.025,.025,'SPIron')

def nails(m):
    m.box((0,0,.008),(.23,.13,.016),'SPWood')
    for x in [-.11,.11]:m.box((x,0,.043),(.015,.13,.07),'SPEnd')
    for y in [-.06,.06]:m.box((0,y,.043),(.23,.015,.07),'SPEnd')
    for a,b in [((-.083,-.03,.027),(.003,.03,.045)),((-.041,.042,.039),(.06,-.035,.025)),((-.068,.025,.05),(.049,.017,.05)),((.014,-.038,.04),(.088,.038,.047)),((-.077,-.023,.056),(.004,-.017,.037))]:
        beam(m,a,b,.004,'SPIron',4);beam(m,a,tuple(a[i]+(b[i]-a[i])*.07 for i in range(3)),.011,'SPIron',4)

def letter(m):
    m.box((0,0,.005),(.208,.142,.01),'SPPaper')
    extrusion(m,[(-.103,.067),(.103,.067),(0,-.022)],.010,.013,'SPCream')
    for x in [-.059,.059]:strap(m,x,-.073,.073,.016,.006,'SPCloth')
    lathe(m,[(.014,.018),(.021,.023),(.026,.018)],'SPRed',10,c=(0,-.028,0))
    m.box((0,-.028,.027),(.016,.004,.0018),'SPBronze')

def purse(m):
    lathe(m,[(0,.041),(.020,.065),(.089,.076),(.129,.052),(.150,.028),(.185,.035)],'SPLeather',9)
    torus(m,(0,0,.147),.031,.005,'SPCloth',n=12)
    curve(m,[(.017,-.022,.154),(.062,-.061,.126),(.032,-.072,.099)],.0035,'SPCloth')
    curve(m,[(.003,-.03,.153),(-.027,-.049,.10),(-.015,-.044,.076)],.0035,'SPCloth')
    lathe(m,[(.001,.016),(.005,.016)],'SPBronze',10,c=(.075,-.05,0))

def spice(m):
    lathe(m,[(0,.046),(.015,.06),(.100,.065),(.143,.045),(.16,.038)],'SPTeal',10)
    lathe(m,[(.16,.044),(.178,.044),(.187,.032)],'SPEnd',10)
    lathe(m,[(.187,.015),(.20,.018)],'SPWood',8)
    m.box((0,-.062,.077),(.052,.008,.056),'SPPaper')
    m.box((0,-.068,.077),(.019,.004,.018),'SPRed')
    torus(m,(0,0,.147),.044,.004,'SPCloth',n=16)

def medical(m):
    # Soft faceted parcel, twin ties, and attached bandage roll.
    v=[(-.14,-.088,0),(.14,-.088,0),(.14,.088,0),(-.14,.088,0),(-.16,-.08,.055),(.16,-.08,.055),(.16,.08,.055),(-.16,.08,.055),(-.13,-.068,.108),(.13,-.068,.108),(.13,.068,.108),(-.13,.068,.108)]
    f=[(3,2,1,0),(8,9,10,11)]+[(k*4+j,k*4+(j+1)%4,(k+1)*4+(j+1)%4,(k+1)*4+j) for k in range(2) for j in range(4)]
    m.part(v,f,'SPCloth')
    for x in [-.085,.085]:
        m.box((x,0,.114),(.019,.14,.012),'SPTeal')
        for y in [-.081,.081]:boxbeam(m,(x,y,.018),(x,y,.105),.018,.013,'SPTeal')
    m.box((0,-.089,.064),(.036,.009,.05),'SPPaper')
    # A closed, embossed leaf mark rather than a single-sided decorative plane.
    leaf=[(-.007,-.096,.061),(0,-.096,.080),(.009,-.096,.065),(0,-.096,.049)]
    m.part(leaf+[(x,y-.002,z) for x,y,z in leaf],[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'SPTeal')
    beam(m,(-.048,.015,.135),(.048,.015,.135),.029,'SPCream',10)
    beam(m,(-.049,.015,.135),(-.052,.015,.135),.012,'SPEnd',10)

def pipe(m):
    tube(m,[(0,.025),(.018,.033),(.062,.042),(.082,.044),(.086,.038),(.086,.027),(.034,.023),(.025,.008),(0,.008)],'SPWood',10,c=(-.085,0,0))
    lathe(m,[(0,.01),(.026,.01)],'SPWood',10,c=(-.085,0,0))
    curve(m,[(-.057,0,.029),(-.018,0,.025),(.038,0,.03),(.11,0,.052),(.176,0,.084),(.204,0,.088)],.008,'SPLeather',8)
    beam(m,(.176,0,.084),(.215,0,.088),.008,'SPDark',8)
    torus(m,(-.085,0,.080),.04,.004,'SPBronze',n=10)

DEFS=[
('MarinerCompass','暮潮航海罗盘',compass,'navigation','table',['sot_gear','sot_cabin'],'旧铜外壳护住象牙色盘面，赤红指针仍指向船员记忆中的北方。掌舵者在浓雾中反复确认的微小方向，如今静伏在潮湿案桌上。'),
('FoldedSeaChart','三折沿岸海图',chart,'navigation','table',['sot_table','sot_cabin'],'麻纸沿旧折痕隆起，褪绿的海岸和断续红点仍勾出商路。最后一个记号停在没有名字的浅湾，折回的纸角藏住了船长未说出口的打算。'),
('CaptainsLog','皮封航海日志',logbook,'navigation','table',['sot_table','sot_cabin'],'厚皮封面用铜箍保护书脊，青灰绑带压住受潮膨起的书页。日志原来逐日记录潮水与分粮，末尾却夹着一张始终没有寄出的家书。'),
('WatchHourglass','值更木架沙漏',hourglass,'navigation','table',['sot_cabin','sot_gear'],'四根细柱围住收腰的计时瓶，浅砂凝在最后一次值更之间。船员曾靠它交换夜岗，如今无人再翻转木架，舱外的浪声依旧准时。'),
('BrassSpyglass','皮握铜望远镜',spyglass,'navigation','table',['sot_gear','sot_cabin'],'套接铜管已缩回便于携带的长度，旧皮握套留下掌心的暗痕。它看过港口的炊烟，也看过接近的风暴，最后映入镜口的是倾斜海面。'),
('CabinLantern','铁罩值夜船灯',lantern,'navigation','table',['sot_gear','sot_table'],'铁护条围住暖色灯罩，提环仍能挂上舱梁的木钩。有限的灯油曾照亮深夜缝补的双手；如今它的形状使废船仍像有人等待归来。'),
('LeatherFlask','皮套船员酒壶',flask,'domestic','table',['skyrim_household','skyrim_tavern'],'扁腹酒壶收在磨旧皮套中，短木塞牢牢堵住壶口。出航时装入的烈酒常被分成很小的份量，寒冷值夜之后，人人都记得那一点暖意。'),
('WoodenMug','铁箍木杯',mug,'domestic','table',['skyrim_household','skyrim_tavern'],'宽口木杯用两道暗铁箍束紧，粗柄足够戴手套的船员握住。杯底久留苦麦酒气味，杯沿的一处磨平则来自同一位水手多年的习惯。'),
('CoarseBowl','青边粗瓷碗',bowl,'domestic','table',['skyrim_household','skyrim_tavern'],'浅色粗瓷留着厚实碗口，青灰窄边是这件日用器唯一的装饰。厨子用它分热粥和炖豆，风浪来时总把它塞进麻布间，以免相互撞碎。'),
('WoodenPlate','浅沿木餐盘',plate,'domestic','table',['skyrim_household','skyrim_tavern'],'低矮宽沿围出一只朴素木盘，磨亮的内面盛过干面包与盐鱼。餐盘没有刻下姓名，因为船上的日子常把各人的东西渐渐混在一起。'),
('CanvasRepairRoll','束带修帆卷布',canvas,'repair','table',['wow_firstaid','sot_supplies'],'厚帆布卷得紧实，一角仍铺在桌面等待裁剪。两道青灰束带保住干燥的内层，足够修补小裂口，也曾临时盖住发烧船员的肩头。'),
('SewingKit','船匠针线木盒',sewing,'repair','table',['wow_firstaid','skyrim_smith'],'掀开的浅木盒露出两色线轴和插针软垫，短铜合页没有被盐锈咬断。船匠把它放在顺手的位置，每一处补缀都让旧帆多撑过一程。'),
('RopeKnot','细缆盘结',rope,'repair','floor',['sot_rope','skyrim_smith'],'几圈短麻缆盘在一起，松开的绳尾绕成不太整齐的结。它可以捆扎木箱、吊起水桶或临时系住舱门，是船员随手保留的小段余料。'),
('WoodenPulley','木颊双槽滑轮',pulley,'repair','floor',['sot_rope','skyrim_smith'],'双木颊护住带槽铁轮，粗吊环留有长期受力的暗痕。船上的重物曾借它轻松越过舷边，如今松弛绳索已不再拉动其中的转轴。'),
('IronNailBox','船钉浅木盒',nails,'repair','table',['skyrim_smith','sot_supplies'],'短铁钉散在浅木盒里，方钉帽因反复锤击而高低不齐。修补船板时总有人嫌它太少，风平浪静的时候又总有人忘记将盒盖找回来。'),
('WaxSealedLetter','赤蜡封口信件',letter,'navigation','table',['sot_table','sot_cabin'],'折好的厚纸被两道细绳约束，深红封蜡遮住接缝。信件始终没有离开船长的案桌，潮气模糊了收件人的名字，却没能松开那一点蜡。'),
('DrawstringPurse','抽绳零钱袋',purse,'domestic','table',['skyrim_household','sot_table'],'鼓起的旧皮钱袋收拢在麻绳下，一枚铜钱滚落在旁边。这里装着靠岸后买一餐热饭的打算，也装着水手答应带给孩子的小小礼物。'),
('SpiceJar','木盖香料小罐',spice,'domestic','table',['skyrim_household','skyrim_tavern'],'青灰陶罐套着短木盖，窄纸签只留一块褪红记号。长途航行让同样的盐鱼令人厌倦，而一撮香料能使拥挤船舱短暂想起家中的灶火。'),
('BandageParcel','草药绑带医疗包',medical,'medical','table',['wow_firstaid','skyrim_cure'],'麻布包被两道青灰带束紧，顶上别着备用绷带卷。淡绿叶记号说明里面还有干草药，船医曾在狭窄铺位边用它处理绳伤和木刺。'),
('BentWoodPipe','弯柄旧木烟斗',pipe,'domestic','table',['lotr_pipe','lotr_bilbo'],'粗木斗钵接着一段温润弯柄，旧铜口圈留下暗淡的光。夜更结束后水手常靠着舷板慢慢等待余火熄灭，那短暂安静比烟草更令人眷恋。'),
]

def build(rebuild=False):
    old=bpy.context.window.scene
    try:
        if rebuild:
            scene=bpy.data.scenes['AE202610_ShipwreckProps'];col=bpy.data.collections['AE202610_ShipwreckProps_Masters']
            for obj in list(col.objects):
                assert obj.name.startswith('SWP_');data=obj.data;bpy.data.objects.remove(obj,do_unlink=True)
                if data.users==0:bpy.data.meshes.remove(data)
            bpy.context.window.scene=scene
        else:scene,col=P['create_scene']('ShipwreckProps')
        objects=[];metadata=[]
        for index,(slug,title,fn,category,placement,refs,lore) in enumerate(DEFS):
            mesh=Mesh();fn(mesh)
            minz=min(v[2] for v in mesh.vertices)
            mesh.vertices=[(x,y,z-minz) for x,y,z in mesh.vertices]
            obj=mesh.finish('SWP_'+slug,col);objects.append(obj)
            metadata.append(dict(slug=slug,title=title,category=category,placement=placement,map_asset_id=830+index,
                origin='bottom origin, metres; Blender -Y front, Unity +Z front; zero transforms',
                intended_use='tabletop / inventory prop; floor rope and tackle retain real scale',
                lore=lore,references=[REFS[key] for key in refs],
                literary_reference={'work':'Robert Louis Stevenson — Treasure Island','url':'https://www.gutenberg.org/ebooks/120','motif':'shipboard provisions, cabin objects, an unfinished voyage; original fiction, no copied prose'},
                review_status='pending'))
        rows=P['finish_batch']('ShipwreckProps',scene,objects,metadata)
        for row,obj in zip(rows,objects):
            x,y,z=row['dimensions_blender_xyz'];row['dimensions_unity_xyz']=[x,z,y]
            row['surface_clearance_m']=.004 if row['placement']=='table' else 0
            pts=[(-v[0],v[2],-v[1]) for v in obj.bound_box]
            lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
            row['bounds_unity']={'min':lo,'max':hi,'center':[(lo[i]+hi[i])/2 for i in range(3)],'size':[hi[i]-lo[i] for i in range(3)]}
        (OUT/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
        print(json.dumps({'group':'ShipwreckProps','count':len(rows),'triangles':sum(r['triangles'] for r in rows)}))
        return rows
    finally:bpy.context.window.scene=old

def render(start=0,end=20):
    """Four real views; project camera bounds to guarantee uncropped hero silhouettes."""
    rows=json.loads((OUT/'manifest.json').read_text(encoding='utf8'))
    scene=P['setup_review']('ShipwreckProps');old=bpy.context.window.scene
    views={'front':(0,-4,0),'side':(4,0,0),'back':(0,4,0),'hero':(2.6,-4,2.6)}
    try:
        bpy.context.window.scene=scene
        for row in rows[start:end]:
            source=bpy.data.objects[row['name']];obj=source.copy();obj.data=source.data;scene.collection.objects.link(obj);obj.hide_render=False
            corners=[Vector(v) for v in source.bound_box]
            lo=Vector(tuple(min(v[i] for v in corners) for i in range(3)));hi=Vector(tuple(max(v[i] for v in corners) for i in range(3)))
            center=(lo+hi)/2;span=max(hi-lo);obj.scale=(1/span,)*3;obj.location=-center/span
            try:
                for view,position in views.items():
                    camera=scene.camera;camera.location=position;camera.rotation_euler=(-camera.location).to_track_quat('-Z','Y').to_euler()
                    rotation=camera.rotation_euler.to_matrix().transposed()
                    projected=[rotation@((v-center)/span) for v in corners]
                    extent=max(max(p[i] for p in projected)-min(p[i] for p in projected) for i in (0,1))
                    camera.data.ortho_scale=max(1.32,extent*1.16)
                    scene.render.filepath=str(OUT/'Previews'/(row['name']+'_'+view+'.png'))
                    bpy.ops.render.render(write_still=True,scene=scene.name)
            finally:bpy.data.objects.remove(obj,do_unlink=True)
        print('PROPS_RENDER_COMPLETE',start,end)
    finally:bpy.context.window.scene=old

if __name__=='__main__':build()
