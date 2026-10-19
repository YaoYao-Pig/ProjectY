"""Twenty original grip-local weapon masters. Load and build explicit ID batches via MCP."""
import bpy,math,json,runpy
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y/Art/ArsenalExpansion202610')
for name in ('Source','Staging','Previews','Integration'):(ROOT/name).mkdir(parents=True,exist_ok=True)
g=runpy.run_path(str(ROOT/'Scripts/geometry.py'))
Mesh,beam,ring,crystal,plate,lathe,blade,grip=[g[key] for key in ('Mesh','beam','ring','crystal','plate','lathe','blade','grip')]
name='ArsenalExpansion202610_Source'
if name in bpy.data.scenes:
    assert globals().get('RESUME') is True,'Explicit resume required'
    scene=bpy.data.scenes[name];masters=bpy.data.collections['ArsenalExpansion202610_Masters']
else:
    scene=bpy.data.scenes.new(name);masters=bpy.data.collections.new('ArsenalExpansion202610_Masters');scene.collection.children.link(masters)
bpy.context.window.scene=scene;scene.unit_settings.scale_length=1
design=json.loads((ROOT/'design.json').read_text(encoding='utf-8'))

def staff_base(m,material):
    beam(m,(0,0,-.79),(0,0,.97),.043,material,10)
    for z in (-.77,-.25,.20,.72,.91):beam(m,(0,0,z),(0,0,z+.05),.063,'EqBronze',10)
    for z in (-.12,-.04,.04,.12):ring(m,(0,0,z),.046,.006,'TimberLight')

def tide(m):
    staff_base(m,'Window')
    lathe(m,[(.77,.064),(.83,.095),(.91,.095),(.96,.055)],'EqCyan')
    ring(m,(0,0,1.08),.17,.021,'EqBronze',normal=(0,1,0),sides=12,start=-.1,sweep=math.pi+ .2)
    beam(m,(-.14,0,1.20),(.14,0,1.20),.012,'EqBronze',6)
    for x,h in ((-.11,1.20),(0,1.15),(.11,1.22)):
        beam(m,(x,0,1.20),(x,0,h-.10),.005,'EqBronze',4)
        crystal(m,(x,0,h-.12),.024,.073,'EqCyan')
    for x in (-.14,.14):beam(m,(0,0,.94),(x,0,1.12),.017,'EqIron',6)
    beam(m,(0,0,.96),(0,0,1.23),.018,'EqBronze',6)
    ring(m,(0,0,1.225),.055,.012,'EqBronze')

def kiln(m):
    staff_base(m,'EqIron')
    m.box((0,0,1.06),(.22,.20,.24),'RockLight')
    m.box((-.015,-.105,1.055),(.14,.018,.105),'EqAmber')
    for x in (-.062,-.015,.032):m.box((x,-.12,1.055),(.012,.022,.11),'EqIron')
    m.box((0,0,1.19),(.255,.23,.035),'EqBronze')
    beam(m,(.13,0,1.05),(.13,0,1.26),.035,'EqIron',8)
    beam(m,(.13,0,1.23),(.20,0,1.26),.033,'EqBronze',8)
    for z in (.88,.94):ring(m,(0,0,z),.078,.015,'RockLight')
    beam(m,(0,0,1.20),(0,0,1.25),.045,'EqIron',8)

def bough(m):
    staff_base(m,'TimberLight')
    for sign,top in ((-1,1.23),(1,1.31)):
        points=[(0,0,.82),(sign*.10,0,.99),(sign*.16,0,top-.08),(sign*.07,0,top)]
        for i,(a,b) in enumerate(zip(points,points[1:])):beam(m,a,b,.035-i*.007,'TimberLight',6)
        for x,z in ((sign*.11,1.02),(sign*.14,1.13)):
            plate(m,[(x,z),(x+sign*.095,z+.035),(x+sign*.04,z+.085)],-.01,.02,'EqJade')
    lathe(m,[(1.02,.035),(1.07,.095),(1.10,.10)],'EqJade',sides=8)
    ring(m,(0,0,1.10),.098,.011,'RockLight')
    beam(m,(0,.025,.96),(0,.025,1.27),.017,'TimberLight',6)
    ring(m,(0,.025,1.265),.053,.012,'RockLight')

def rifle_base(m,stock=True):
    m.box((0,-.16,.15),(.17,.49,.20),'EqIron')
    if stock:
        m.box((0,.31,.11),(.14,.35,.20),'Timber');m.box((0,.49,.11),(.18,.055,.24),'EqIron')
    beam(m,(0,.04,.10),(0,.09,-.20),.063,'Timber',6)
    m.box((0,-.27,.035),(.14,.27,.11),'TimberLight')
    # Magazine receiver matches the original (0,.04,.22) Unity socket.
    for x in (-.07,.07):m.box((x,-.22,.05),(.022,.19,.06),'EqBronze')
    # Small true side rail supports the new common rail socket.
    m.box((.10,-.12,.18),(.025,.20,.045),'EqBronze')

def borer(m):
    rifle_base(m)
    beam(m,(0,-.38,.18),(0,-1.08,.18),.036,'EqIron',10)
    for y,r in ((-.94,.06),(-1.0,.055),(-1.06,.049),(-1.12,.044)):
        beam(m,(0,y,.18),(0,y-.035,.18),r,'EqBronze',8,.76)
    beam(m,(0,-1.15,.18),(0,-1.16,.18),.025,'Window',8)
    for x in (-.099,.099):
        beam(m,(x,-.32,.09),(x,-.12,.25),.015,'EqBronze',4)
        beam(m,(x,-.12,.25),(x,.02,.09),.015,'EqBronze',4)
    m.box((0,-.08,.30),(.045,.09,.08),'EqIron')
    m.box((0,-.86,.26),(.025,.035,.08),'EqBronze')
    m.box((0,.49,.11),(.19,.06,.24),'Window')

def watch(m):
    rifle_base(m,False)
    for z in (.04,.20):
        points=[(0,.08,z),(0,.30,z-.025),(0,.49,z)]
        for a,b in zip(points,points[1:]):beam(m,a,b,.039,'Timber',6)
    beam(m,(0,.49,.025),(0,.49,.22),.035,'EqIron',6)
    beam(m,(0,-.38,.18),(0,-1.04,.18),.042,'EqIron',10)
    for x in (-.065,.065):beam(m,(x,-.40,.18),(x,-.96,.18),.014,'EqBronze',6)
    ring(m,(0,-.08,.32),.058,.011,'EqBronze',normal=(0,1,0))
    beam(m,(0,-.50,.11),(0,-.50,-.11),.013,'EqBronze',6)
    crystal(m,(0,-.50,-.15),.055,.13,'EqAmber')
    beam(m,(0,-1.01,.18),(0,-1.08,.18),.065,'EqBronze',8)

def dusk(m):
    rifle_base(m)
    m.box((0,.30,.12),(.16,.41,.21),'Window')
    m.box((-.084,.30,.13),(.012,.27,.045),'EqRuby')
    m.box((.084,.30,.13),(.012,.27,.045),'EqRuby')
    beam(m,(0,-.38,.18),(0,-.97,.18),.065,'EqIron',8)
    m.box((0,-.58,.24),(.19,.41,.14),'EqIron')
    for y in (-.46,-.55,-.64):m.box((0,y,.316),(.13,.025,.016),'EqRuby')
    beam(m,(0,-.94,.18),(0,-1.10,.18),.095,'EqIron',8,1.1)
    beam(m,(0,-1.102,.18),(0,-1.114,.18),.065,'Window',8)
    for x in (-.032,.032):beam(m,(x,-.87,.24),(x,-.87,.39),.011,'EqBronze',6)

def ceremony(m):
    grip(m)
    blade(m,[(.20,.10),(.27,.16),(.34,.12),(1.02,.12),(1.17,.005)],.031,('RockLight','Plaster'))
    ring(m,(0,0,.18),.20,.022,'EqBronze',normal=(0,1,0),sides=14,start=.50,sweep=5.2)
    beam(m,(-.20,0,.18),(.20,0,.18),.026,'EqIron',6)
    crystal(m,(0,-.055,.20),.036,.09,'EqViolet')
    m.box((0,0,-.235),(.10,.10,.07),'RockLight')

def red_thread(m):
    grip(m,material='Window')
    plate(m,[(-.065,.21),(.07,.21),(.055,.87),(.12,1.13),(.07,1.20),(-.04,.99)],0,.055,'EqIron')
    plate(m,[(.039,.23),(.071,.22),(.055,.87),(.12,1.13),(.073,1.17),(.02,.91)],-.001,.062,'RockLight')
    plate(m,[(-.019,.27),(.003,.27),(.015,.95),(.05,1.08),(.025,1.05),(-.013,.92)],-.033,.012,'EqRuby')
    ring(m,(0,0,.19),.18,.018,'EqBronze',normal=(0,1,0),sides=10,start=.2,sweep=2.8)
    beam(m,(-.18,0,.17),(.16,0,.20),.023,'EqBronze',6)
    crystal(m,(0,0,-.24),.06,.12,'EqRuby')

def thorn(m):
    grip(m,material='Window')
    blade(m,[(.20,.12),(.31,.25),(.41,.18),(.52,.26),(.65,.22),(.85,.28),(1.17,.004)],.037,('RockLight','EqIron'))
    for sign in (-1,1):
        beam(m,(0,0,.18),(sign*.21,0,.24),.023,'EqJade',6)
        for x in (.09,.16,.21):beam(m,(sign*x,0,.18+x*.28),(sign*(x+.025),0,.27+x*.28),.014,'EqJade',5,.12)
    for a,b in [((0,0,-.17),(.07,0,-.24)),((.07,0,-.24),(0,0,-.32)),((0,0,-.32),(-.07,0,-.24)),((-.07,0,-.24),(0,0,-.17))]:beam(m,a,b,.014,'EqBronze',4)

def vise(m):
    grip(m,-.32,.23,.056,'Window')
    blade(m,[(.28,.17),(.52,.19),(1.36,.17),(1.61,.008)],.045)
    for sign in (-1,1):
        plate(m,[(sign*.11,.63),(sign*.21,.74),(sign*.19,1.43),(sign*.12,1.54),(sign*.13,.86)],0,.070,'EqIron')
        beam(m,(sign*.07,0,.48),(sign*.18,0,.72),.032,'EqBronze',6)
    for z in (.22,.28):beam(m,(-.29,0,z),(.29,0,z),.03,'EqBronze',6)

def windmill(m):
    grip(m,-.32,.23,.056)
    plate(m,[(-.11,.28),(.10,.28),(.17,1.15),(.32,1.58),(.22,1.67),(-.03,1.28)],0,.075,'EqIron')
    plate(m,[(.08,.30),(.10,.28),(.17,1.15),(.32,1.58),(.22,1.63),(.11,1.23)],0,.082,'RockLight')
    ring(m,(0,0,.24),.12,.025,'EqBronze',normal=(0,1,0))
    for sign in (-1,1):
        for z in (.39,.57):plate(m,[(sign*.08,z),(sign*.26,z+.05),(sign*.18,z+.15),(sign*.08,z+.08)],0,.035,'EqCyan')
    beam(m,(-.29,0,.23),(.29,0,.23),.027,'EqBronze',6)

def candle(m):
    grip(m,-.32,.23,.056,'Window')
    blade(m,[(.28,.23),(.68,.23),(1.40,.14),(1.65,.004)],.047,('EqIron','Window'))
    blade(m,[(.35,.042),(1.32,.032),(1.52,.004)],.009,('EqAmber',),y=-.05)
    for sign,drop in ((-1,-.06),(1,.11)):
        beam(m,(0,0,.23),(sign*.28,0,.23+drop),.033,'EqBronze',6)
        beam(m,(sign*.28,0,.23+drop),(sign*.30,0,.15+drop),.025,'EqBronze',6,.4)
    lathe(m,[(-.44,.085),(-.40,.075),(-.34,.045)],'EqBronze')

def colossal_base(m):
    grip(m,-.42,.26,.057,'Window')
    beam(m,(-.42,0,.26),(.42,0,.26),.045,'EqIron',6)
    m.box((0,.066,.70),(.22,.05,.32),'EqBronze')

def siege(m):
    colossal_base(m)
    blade(m,[(.30,.29),(.49,.44),(1.66,.44),(1.66+.03,.55),(1.92,.55)],.065,('EqIron','RockDark'))
    for z in (.62,.98,1.34,1.70):
        m.box((0,-.068,z),(.35,.018,.025),'EqBronze')
        for x in (-.14,.14):beam(m,(x,-.070,z),(x,-.095,z),.024,'RockLight',6)
    for x in (-.20,.20):m.box((x,0,.50),(.12,.15,.30),'EqBronze')

def frost(m):
    colossal_base(m)
    blade(m,[(.31,.29),(.53,.56),(.75,.42),(1.70,.37),(1.98,.12)],.065,('RockLight','EqIron'))
    blade(m,[(.60,.21),(1.65,.15),(1.86,.008)],.015,('EqCyan','WaterDeep'),y=-.066)
    for sign in (-1,1):
        beam(m,(sign*.30,0,.27),(sign*.34,0,.50),.034,'EqIron',6)
        beam(m,(sign*.34,0,.50),(sign*.22,0,.60),.034,'EqIron',6)
        for i,z in enumerate((.72,.89,1.07)):
            crystal(m,(sign*(.21-i*.015),0,z),.025,.15,'EqCyan',axis=(sign*.4,0,-1))

def crimson(m):
    colossal_base(m)
    plate(m,[(-.20,.31),(.16,.31),(.28,1.48),(.46,1.88),(.34,2.00),(-.02,1.86),(-.21,1.47)],0,.12,'EqIron')
    plate(m,[(.13,.34),(.16,.31),(.28,1.48),(.46,1.88),(.34,1.96),(.20,1.58)],0,.128,'RockLight')
    for z in (.83,1.08,1.33):m.box((-.08,-.070,z),(.12,.018,.08),'EqRuby')
    beam(m,(-.16,-.085,.47),(-.14,-.085,1.60),.018,'EqBronze',6)
    for sign in (-1,1):
        beam(m,(0,0,.26),(sign*.30,0,.38),.036,'EqBronze',6)
        beam(m,(sign*.30,0,.38),(sign*.42,0,.30),.025,'EqBronze',6)

BOW_POINTS=[(-.235,0,-.60),(-.065,0,-.38),(-.005,0,-.15),(-.005,0,.15),(-.065,0,.38),(-.235,0,.60)]
def bow_base(m,material):
    for a,b in zip(BOW_POINTS,BOW_POINTS[1:]):beam(m,a,b,.035,material,8)
    beam(m,BOW_POINTS[0],BOW_POINTS[-1],.006,'Plaster',6)
    m.box((0,0,0),(.070,.08,.19),'Timber')
    m.box((.053,0,.23),(.055,.065,.12),'EqBronze')

def webbow(m):
    bow_base(m,'Timber')
    for sign in (-1,1):
        a=(-.055,0,sign*.20);b=(.07,0,sign*.39);c=(-.16,0,sign*.55)
        beam(m,a,b,.023,'EqIron',6);beam(m,b,c,.020,'EqIron',6)
        for f in (.35,.60,.85):
            beam(m,(-.235,0,sign*(.20+.36*f)),(-.055+.125*f,-.012,sign*(.20+.19*f)),.004,'Plaster',4)
    m.box((0,-.043,0),(.055,.012,.17),'EqJade')

def egret(m):
    bow_base(m,'RockLight')
    for sign in (-1,1):
        for dy in (-.045,.045):
            beam(m,(-.055,dy*.4,sign*.31),(-.13,dy,sign*.50),.018,'RockLight',6)
            beam(m,(-.13,dy,sign*.50),(-.235,0,sign*.60),.013,'RockLight',6)
        for i in range(3):
            x=-.025-i*.035;z=sign*(.22+i*.08)
            plate(m,[(x,z),(x+.10,z+sign*.05),(x+.02,z+sign*.12)],-.045,.014,'RockLight')
    m.box((0,-.045,0),(.052,.014,.17),'EqCyan')

def grave(m):
    bow_base(m,'Window')
    for sign in (-1,1):
        lathe(m,[(sign*.11,.028),(sign*.20,.043),(sign*.28,.028)],'EqJade',x=.03,y=-.07,sides=6)
        for z in (sign*.12,sign*.25):ring(m,(.03,-.07,z),.033,.008,'EqBronze',sides=8)
        for x,z in ((-.07,sign*.38),(-.17,sign*.54)):
            beam(m,(x,0,z),(x+.06,0,z-sign*.11),.017,'RockLight',5,.1)
        beam(m,(.03,-.065,sign*.11),(-.025,-.065,sign*.30),.008,'EqBronze',6)

def quenchaxe(m):
    beam(m,(0,0,-.25),(0,0,.80),.044,'TimberLight')
    for z in (-.20,-.12,-.04):beam(m,(0,0,z),(0,0,z+.016),.047,'EqIron')
    plate(m,[(-.11,.68),(.17,.67),(.42,.48),(.50,.82),(.42,.97),(.13,.91),(-.11,.90)],0,.12,'RockLight')
    plate(m,[(.42,.48),(.50,.82),(.42,.97),(.39,.89),(.43,.78),(.35,.54)],0,.13,'EqIron')
    m.box((.08,-.067,.79),(.12,.018,.06),'EqAmber')
    plate(m,[(-.10,.72),(-.30,.73),(-.34,.88),(-.25,.93),(-.10,.86)],0,.075,'EqIron')
    m.box((0,0,.80),(.16,.18,.20),'EqBronze')

def faultpick(m):
    beam(m,(0,0,-.25),(0,0,1.10),.044,'Timber')
    for z in (-.20,-.12,-.04,.23):beam(m,(0,0,z),(0,0,z+.016),.048,'EqIron')
    for y in (-.045,.045):
        plate(m,[(.0,1.04),(.22,1.13),(.53,.95),(.26,1.21),(.0,1.20)],y,.038,'EqIron')
    m.box((-.22,0,1.10),(.32,.14,.16),'EqIron')
    m.box((-.38,0,1.10),(.055,.18,.22),'RockLight')
    ring(m,(0,-.09,1.10),.085,.014,'EqBronze',normal=(0,1,0),sides=12)
    beam(m,(-.03,-.11,1.06),(.045,-.11,1.15),.008,'EqCyan',4)
    m.box((.17,-.071,1.145),(.16,.013,.025),'EqCyan')

BUILDERS={601:tide,602:kiln,603:bough,604:borer,605:watch,606:dusk,607:ceremony,608:red_thread,609:thorn,610:vise,
          611:windmill,612:candle,613:siege,614:frost,615:crimson,616:webbow,617:egret,618:grave,619:quenchaxe,620:faultpick}
def build(ids):
    for row in design['weapons']:
        if row['id'] not in ids:continue
        m=Mesh();BUILDERS[row['id']](m);obj=m.finish(row['model'],masters)
        obj['item_id']=row['id'];obj['base_weapon_id']=row['baseWeaponId'];obj['display_name']=row['name'];obj['asset_kind']='weapon'
        obj.data.calc_loop_triangles();assert all(p.area>1e-10 for p in obj.data.polygons),row['model']
        print(row['id'],row['model'],len(obj.data.loop_triangles))
    bpy.context.view_layer.update()
print('Weapon authoring ready; explicit build({ids}) is required.')
