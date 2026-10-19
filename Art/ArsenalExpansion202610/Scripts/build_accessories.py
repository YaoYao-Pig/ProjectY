"""Twenty distinct utility attachments, with socket-local rail and edge conventions."""
import bpy,math,json,runpy
from pathlib import Path
ROOT=Path('D:/Program/Unity/Project Y/Art/ArsenalExpansion202610')
g=runpy.run_path(str(ROOT/'Scripts/geometry.py'))
Mesh,beam,ring,crystal,plate,lathe,collar,shaft_mount,rear_mount,rail_mount,edge_mount=[g[k] for k in ('Mesh','beam','ring','crystal','plate','lathe','collar','shaft_mount','rear_mount','rail_mount','edge_mount')]
scene=bpy.data.scenes['ArsenalExpansion202610_Source'];bpy.context.window.scene=scene
masters=bpy.data.collections['ArsenalExpansion202610_Masters']
design=json.loads((ROOT/'design.json').read_text(encoding='utf-8'))

def still(m):
    collar(m)
    lathe(m,[(.03,.055),(.08,.08),(.20,.08),(.24,.055)],'EqCyan',x=-.025,sides=8)
    lathe(m,[(.24,.035),(.32,.11),(.34,.11)],'EqBronze',x=-.025,sides=10)
    lathe(m,[(.331,.093),(.337,.093)],'Window',x=-.025,sides=10)
    points=[(.07+.06*math.cos(i*math.tau/10),-.015+.06*math.sin(i*math.tau/10),.09+i*.007) for i in range(31)]
    for a,b in zip(points,points[1:]):beam(m,a,b,.008,'EqBronze',5)
    beam(m,points[0],(.12,-.07,.065),.009,'EqBronze',5)
    crystal(m,(.12,-.07,.04),.012,.035,'EqCyan')

def snuffer(m):
    collar(m)
    beam(m,(0,0,.02),(0,0,.12),.026,'EqIron',6)
    lathe(m,[(.10,.13),(.14,.13),(.31,.035)],'EqIron',sides=6)
    plate(m,[(-.10,.13),(.10,.13),(.02,.28)],-.08,.012,'EqRuby')
    for sign in (-1,1):
        beam(m,(sign*.075,0,.15),(sign*.18,0,.22),.026,'EqBronze',6,.8)
        beam(m,(sign*.18,0,.22),(sign*.18,0,.33),.020,'EqIron',6,.5)

def peacock(m):
    collar(m)
    for i in range(5):
        angle=(i-2)*.34;x=math.sin(angle)*.22;z=.13+math.cos(angle)*.18
        beam(m,(0,0,.035),(x,0,z),.009,'EqBronze',6)
        plate(m,[(x-.038,z-.045),(x+.038,z-.045),(x+.045,z+.025),(x,z+.065),(x-.045,z+.025)],-.015,.018,'EqBronze')
        crystal(m,(x,-.032,z+.009),.022,.049,'EqViolet',axis=(0,0,1))
        m.box((x,-.052,z+.010),(.015,.010,.020),'EqCyan')
    lathe(m,[(.04,.055),(.10,.067),(.17,.032)],'EqViolet',sides=8)

def beak(m):
    collar(m)
    for angle in (0,2.094,4.188):
        x,y=.07*math.cos(angle),.07*math.sin(angle)
        beam(m,(0,0,.02),(x,y,.16),.014,'RockLight',6)
    lathe(m,[(.10,.04),(.15,.08),(.26,.075),(.30,.042)],'EqAmber',sides=6)
    plate(m,[(.025,.26),(.15,.29),(.22,.23),(.25,.13),(.18,.23),(.035,.23)],0,.045,'RockLight')
    crystal(m,(.05,-.04,.105),.026,.065,'EqCyan')
    for z in (.16,.22):ring(m,(0,0,z),.079,.007,'EqBronze',sides=6)

def spindle(m):
    shaft_mount(m)
    beam(m,(0,-.06,0),(.13,-.08,0),.018,'EqIron',6)
    beam(m,(.13,-.08,-.13),(.13,-.08,.13),.023,'EqBronze',6)
    for z in (-.12,.12):ring(m,(.13,-.08,z),.075,.012,'EqBronze',sides=10)
    for a in (0,math.tau/3,math.tau*2/3):
        x=.13+.055*math.cos(a);y=-.08+.055*math.sin(a)
        beam(m,(x,y,-.11),(x,y,.11),.010,'EqRuby',4)
    for z in (-.10,.10):ring(m,(-.06,-.09,z),.03,.008,'EqIron',normal=(0,1,0),sides=8)

def thistle(m):
    shaft_mount(m)
    for z in (-.10,0,.10):crystal(m,(.095,-.085,z),.035,.075,'EqJade')
    for sign in (-1,1):
        beam(m,(.095,-.085,-.17),(.095+sign*.075,-.085,0),.012,'RockLight',6)
        beam(m,(.095+sign*.075,-.085,0),(.095,-.085,.17),.012,'RockLight',6)
        beam(m,(.095+sign*.060,-.085,.05),(.095+sign*.105,-.085,.11),.010,'RockLight',5,.15)
    beam(m,(0,-.065,-.14),(.095,-.085,-.17),.012,'EqBronze',6)

def eye(m):
    shaft_mount(m)
    points=[(-.18,-.09,0),(-.08,-.09,.09),(.08,-.09,.09),(.18,-.09,0),(.08,-.09,-.09),(-.08,-.09,-.09),(-.18,-.09,0)]
    for a,b in zip(points,points[1:]):beam(m,a,b,.012,'EqIron',6)
    crystal(m,(0,-.095,0),.055,.14,'EqCyan')
    for sign in (-1,1):
        plate(m,[(sign*.05,sign*.10),(sign*.16,sign*.16),(sign*.21,sign*.10),(sign*.14,sign*.11)],-.065,.018,'EqBronze')

def hammer(m):
    rear_mount(m)
    ring(m,(0,.13,0),.15,.018,'EqBronze',normal=(0,1,0),sides=12,start=-.75,sweep=4.7)
    m.box((.08,.13,.12),(.15,.12,.085),'EqIron')
    beam(m,(.08,.13,-.05),(.08,.13,.12),.020,'EqBronze',6)
    m.box((.08,.13,-.065),(.08,.09,.085),'EqJade')
    for z in (-.015,.015,.045):ring(m,(.08,.13,z),.029,.006,'EqIron',sides=8)

def guillotine(m):
    rear_mount(m)
    for x in (-.11,.11):beam(m,(x,.11,-.17),(x,.11,.21),.021,'EqBronze',6)
    for z in (-.16,.21):m.box((0,.11,z),(.27,.09,.035),'EqIron')
    plate(m,[(-.09,.17),(.09,.17),(.09,.035),(-.09,-.06)],.11,.025,'EqViolet')
    plate(m,[(-.09,-.06),(.09,.035),(.09,.011),(-.09,-.08)],.11,.030,'RockLight')
    beam(m,(0,.11,.21),(0,.11,.26),.010,'EqIron',6)

def ballast(m):
    rear_mount(m)
    plate(m,[(-.13,-.12),(-.16,.06),(-.10,.17),(.025,.19),(.12,.10),(.095,-.04),(.15,-.12),(.03,-.18)],.14,.14,'EqRuby')
    for x,z in ((-.07,-.12),(.075,-.10)):
        plate(m,[(x-.025,z),(x+.035,z),(x+.02,z-.16),(x-.025,z-.12)],.13,.045,'EqIron')
    ring(m,(-.02,.22,.07),.050,.009,'EqBronze',normal=(0,1,0),sides=10)
    beam(m,(-.04,.231,.04),(.01,.231,.10),.006,'RockLight',4)

def circuit(m):
    rear_mount(m,.10,.15)
    points=[(-.10,.11,-.10),(.015,.11,-.035),(-.035,.11,.02),(.11,.11,.15),(.025,.11,.07),(.065,.11,.015),(-.10,.11,-.10)]
    for a,b in zip(points,points[1:]):beam(m,a,b,.010,'EqBronze',4)
    crystal(m,(0,.11,.02),.031,.10,'EqCyan')
    for z in (-.06,.07):beam(m,(-.06,.055,z),(-.06,.11,z),.025,'RockLight',6)

def bonebell(m):
    rear_mount(m,.10,.15)
    for a,b in [((-.09,.11,.07),(0,.11,.19)),((0,.11,.19),(.09,.11,.07)),((.09,.11,.07),(-.09,.11,.07))]:beam(m,a,b,.012,'EqViolet',6)
    for x,z,r in ((-.06,-.035,.045),(.055,-.065,.055)):
        beam(m,(x,.11,.07),(x,.11,z+.05),.006,'EqBronze',4)
        lathe(m,[(z-.045,r),(z+.025,r*.55),(z+.05,r*.35)],'RockLight',x=x,y=.11,sides=8)
        lathe(m,[(z-.047,r*.73),(z-.05,r*.73)],'Window',x=x,y=.11,sides=8)
        crystal(m,(x,.11,z-.055),.012,.035,'EqJade')

def tracer(m):
    rail_mount(m)
    beam(m,(0,-.055,-.17),(0,-.055,.17),.010,'EqRuby',4)
    for sign in (-1,1):
        beam(m,(0,-.055,.09),(sign*.05,-.055,.20),.008,'EqRuby',4)
    for z in (-.12,.075):
        pts=[(-.04,-.07,z),(0,-.07,z+.05),(.04,-.07,z),(0,-.07,z-.05),(-.04,-.07,z)]
        for a,b in zip(pts,pts[1:]):beam(m,a,b,.006,'EqBronze',4)

def wedges(m):
    rail_mount(m)
    for i in range(3):
        z=-.08+i*.08;x=(-1 if i%2 else 1)*.02
        plate(m,[(x-.04,z-.025),(x+.04,z-.025),(x+.04,z+.035),(x-.025,z+.065)],-.055,.045,'EqBronze')
    m.box((.07,-.018,0),(.07,.04,.11),'EqIron')

def echo(m):
    rail_mount(m)
    for sign in (-1,1):
        plate(m,[(sign*.015,-.08),(sign*.105,.10),(sign*.115,.19),(sign*.06,.10)],-.05,.025,'EqCyan')
        ring(m,(sign*.055,-.04,-.06),.035,.008,'EqBronze',normal=(0,1,0),sides=8)
    beam(m,(-.06,-.03,-.10),(.06,-.03,-.10),.012,'EqIron',6)

def lastmile(m):
    rail_mount(m)
    m.box((0,-.045,.015),(.045,.04,.36),'EqIron')
    for z in (-.12,-.07,-.02,.03,.08):m.box((0,-.070,z),(.068,.012,.015),'RockLight')
    ring(m,(0,-.055,.20),.067,.010,'EqIron',normal=(0,1,0),sides=10,start=.30,sweep=5.5)
    crystal(m,(0,-.057,.205),.013,.04,'EqAmber')

def salt(m):
    edge_mount(m)
    for x,z in ((-.035,-.01),(.035,.035)):crystal(m,(x,-.055,z),.025,.13,'RockLight')
    m.box((0,-.030,-.075),(.095,.018,.025),'EqRuby')
    beam(m,(.06,-.025,-.05),(.08,-.075,-.09),.007,'EqBronze',5)
    beam(m,(.08,-.075,-.09),(.035,-.075,-.11),.007,'EqBronze',5)

def rivets(m):
    edge_mount(m)
    for i in range(3):
        z=-.07+i*.07;x=(-1 if i%2 else 1)*.025
        beam(m,(x,-.025,z),(x,-.10,z),.026,'EqIron',6)
        beam(m,(x,-.10,z),(x,-.13,z),.027,'RockLight',6,.15)
    for x in (-.07,-.035,0,.035,.07):plate(m,[(x-.012,-.08),(x+.012,-.08),(x,-.115)],-.022,.022,'EqBronze')

def mist(m):
    edge_mount(m)
    plate(m,[(-.065,-.07),(-.065,.08),(-.04,.105),(-.04,-.045),(.04,-.045),(.04,.105),(.065,.08),(.065,-.07)],-.025,.022,'RockLight')
    crystal(m,(0,-.07,.015),.032,.14,'EqCyan')
    for sign in (-1,1):
        beam(m,(sign*.02,-.07,-.02),(sign*.07,-.09,-.06),.009,'EqBronze',5)
        beam(m,(sign*.07,-.09,-.06),(sign*.08,-.12,-.035),.009,'EqBronze',5)

def grooves(m):
    edge_mount(m)
    for a,b in [((-.07,-.035,-.08),(.07,-.035,-.08)),((.07,-.035,-.08),(0,-.035,.12)),((0,-.035,.12),(-.07,-.035,-.08))]:beam(m,a,b,.010,'EqIron',4)
    for i in range(3):
        z=-.045+i*.045;width=.10-i*.025
        m.box((0,-.055,z),(width,.018,.017),'EqJade')
    beam(m,(.055,-.04,.03),(.075,-.04,.12),.012,'RockLight',5,.1)
    lathe(m,[(-.13,.020),(-.11,.035),(-.09,.035)],'EqBronze',y=-.04,sides=6)

BUILDERS={701:still,702:snuffer,703:peacock,704:beak,705:spindle,706:thistle,707:eye,708:hammer,709:guillotine,710:ballast,
          711:circuit,712:bonebell,713:tracer,714:wedges,715:echo,716:lastmile,717:salt,718:rivets,719:mist,720:grooves}
def build(ids):
    for row in design['attachments']:
        if row['id'] not in ids:continue
        m=Mesh();BUILDERS[row['id']](m)
        if row['slotKind']=='rail':m.vertices=[(-y,-z,x) for x,y,z in m.vertices]
        obj=m.finish(row['model'],masters)
        obj['item_id']=row['id'];obj['slot_kind']=row['slotKind'];obj['display_name']=row['name'];obj['asset_kind']='attachment'
        obj.data.calc_loop_triangles();assert all(p.area>1e-10 for p in obj.data.polygons),row['model']
        print(row['id'],row['model'],len(obj.data.loop_triangles))
    bpy.context.view_layer.update()
print('Accessory authoring ready; explicit build({ids}) is required.')
