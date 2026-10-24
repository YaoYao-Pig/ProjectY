"""Twelve original profession weapons. Run explicit batches inside Blender through MCP."""
import bpy, math, json, runpy
from pathlib import Path
ROOT=Path('D:/Program/Unity/Project Y/Art/ProfessionArsenal20261025')
for folder in ('Source','Staging','Previews','Integration'):(ROOT/folder).mkdir(parents=True,exist_ok=True)
g=runpy.run_path('D:/Program/Unity/Project Y/Art/ArsenalExpansion202610/Scripts/geometry.py')
Mesh,beam,ring,crystal,plate,lathe,blade,grip=[g[k] for k in ('Mesh','beam','ring','crystal','plate','lathe','blade','grip')]
NAME='ProfessionArsenal20261025_Source'
if NAME in bpy.data.scenes:
    assert globals().get('RESUME'), 'Explicit RESUME required'
    scene=bpy.data.scenes[NAME];masters=bpy.data.collections['ProfessionArsenal20261025_Masters']
else:
    scene=bpy.data.scenes.new(NAME);masters=bpy.data.collections.new('ProfessionArsenal20261025_Masters');scene.collection.children.link(masters)
bpy.context.window.scene=scene;scene.unit_settings.scale_length=1

def tube(m,points,r=.014,mat='EqBronze',sides=6):
    for a,b in zip(points,points[1:]):beam(m,a,b,r,mat,sides)

def staff(m,mat='Timber',top=.83,bottom=-.74):
    beam(m,(0,0,bottom),(0,0,top),.041,mat,8)
    for z in (bottom+.03,-.22,.20,top-.03):beam(m,(0,0,z),(0,0,z+.04),.056,'EqBronze',8)
    for z in (-.15,-.09,-.03,.03,.09,.15):ring(m,(0,0,z),.042,.005,'Plaster',sides=8)

def bottle(m,x,z,color='EqJade',s=.12,y=0):
    lathe(m,[(z-s,.045),(z-s*.8,s*.72),(z,s),(z+s*.55,s*.68),(z+s*.8,s*.27),(z+s*1.25,s*.27)],color,x=x,y=y,sides=8)
    ring(m,(x,y,z-s*.8),s*.71,.010,'EqBronze',sides=8)
    ring(m,(x,y,z+s*.55),s*.68,.010,'EqBronze',sides=8)
    beam(m,(x,y,z+s*1.22),(x,y,z+s*1.44),s*.32,'Timber',8)

def alembic(m):
    staff(m,'Window',.85)
    bottle(m,0,.97,'EqCyan',.15)
    lathe(m,[(1.16,.055),(1.23,.14),(1.29,.025)],'EqBronze',sides=8)
    tube(m,[(0,0,1.27),(.16,0,1.29),(.24,0,1.20),(.24,0,.92),(.17,0,.86)],.016)
    bottle(m,.20,.75,'EqJade',.069)
    for sign in (-1,1):tube(m,[(sign*.065,0,.78),(sign*.18,0,.89),(sign*.18,0,1.10),(sign*.07,0,1.17)],.012,'EqIron')
    for z in (.88,.95,1.02):m.box((-.035,-.145,z),(.065,.012,.009),'Plaster')

def injector(m):
    grip(m,low=-.16,high=.13,r=.039,material='Window')
    beam(m,(-.16,0,.16),(.16,0,.16),.022,'EqBronze',8)
    for x in (-.16,.16):ring(m,(x,0,.16),.034,.008,'EqBronze',normal=(0,1,0),sides=10)
    lathe(m,[(.19,.045),(.23,.07),(.52,.07),(.57,.045)],'EqJade',sides=10)
    for x in (-.065,.065):beam(m,(x,0,.21),(x,0,.55),.014,'EqIron',6)
    for z in (.23,.52):ring(m,(0,0,z),.071,.012,'EqBronze',sides=10)
    for z in (.29,.35,.41,.47):m.box((0,-.073,z),(.032,.009,.009),'Plaster')
    blade(m,[(.56,.055),(.80,.042),(1.04,.002)],.015,('RockLight','Plaster'))
    m.box((0,0,-.23),(.16,.09,.027),'EqBronze')
    beam(m,(0,0,-.20),(0,0,-.16),.023,'EqIron')

def lute(m):
    # Neck straddles the existing staff grip at z=0; resonator hangs below the hand.
    outline=[(-.07,-.15),(-.20,-.27),(-.29,-.47),(-.27,-.63),(-.16,-.76),(0,-.81),(.16,-.76),(.27,-.63),(.29,-.47),(.20,-.27),(.07,-.15)]
    plate(m,outline,.045,.19,'Timber')
    plate(m,[(x*.95,z+.006) for x,z in outline],-.058,.028,'EqAmber')
    beam(m,(0,0,-.20),(0,0,.44),.045,'TimberLight',8)
    m.box((0,-.041,.11),(.073,.018,.60),'Window')
    plate(m,[(-.045,.37),(-.075,.60),(.02,.66),(.073,.58),(.045,.37)],0,.08,'Timber')
    ring(m,(0,-.082,-.40),.082,.012,'EqBronze',normal=(0,1,0),sides=12)
    # Sound hole is a dark inset, not a decal or transparent sheet.
    beam(m,(0,-.075,-.40),(0,-.083,-.40),.067,'EqIron',12)
    m.box((0,-.09,-.65),(.23,.027,.038),'EqBronze')
    for i in range(6):
        x=(i-2.5)*.012;beam(m,(x,-.106,-.65),(x,-.067,.54),.0028,'Plaster',4)
        z=.40+i*.038;side=-1 if i%2 else 1
        beam(m,(side*.04,0,z),(side*.10,0,z),.010,'EqBronze',6)
        crystal(m,(side*.105,0,z),.017,.035,'EqJade')
    for z in (-.10,-.02,.06,.14,.22,.30):beam(m,(-.035,-.053,z),(.035,-.053,z),.0035,'EqBronze',4)
    for sign in (-1,1):tube(m,[(sign*.15,-.080,-.70),(sign*.23,-.080,-.58),(sign*.24,-.080,-.46)],.008,'EqBronze')

def lyre(m):
    # A narrow central handle gives the staff pose a real hand contact point.
    grip(m,low=-.19,high=.18,r=.041,material='TimberLight')
    plate(m,[(-.22,.22),(-.26,.30),(-.19,.42),(.19,.42),(.26,.30),(.22,.22)],0,.13,'Timber')
    for sign in (-1,1):
        tube(m,[(sign*.18,0,.33),(sign*.29,0,.55),(sign*.31,0,.85),(sign*.24,0,1.02)],.035,'EqBronze',8)
        plate(m,[(sign*.25,.91),(sign*.39,1.00),(sign*.25,1.08),(sign*.18,1.01)],0,.075,'RockLight')
    beam(m,(-.25,0,.97),(.25,0,.97),.032,'TimberLight',8)
    for i in range(7):
        x=(i-3)*.060;beam(m,(x,-.074,.35),(x,-.035,.97),.0035,'Plaster',4)
        beam(m,(x,0,.98),(x,0,1.04),.012,'EqBronze',6)
    crystal(m,(0,-.080,.30),.062,.09,'EqCyan')
    ring(m,(0,0,-.28),.046,.011,'EqBronze',normal=(0,1,0),sides=10)

def censer(m):
    staff(m,'Plaster',.87)
    lathe(m,[(.82,.065),(.90,.14),(.97,.17),(1.05,.17),(1.11,.11)],'EqIron',sides=10)
    for z,r in ((.91,.15),(1.07,.17)):ring(m,(0,0,z),r,.016,'EqBronze',sides=10)
    lathe(m,[(1.08,.18),(1.11,.18),(1.24,.04)],'EqBronze',sides=10)
    crystal(m,(0,0,1.28),.045,.12,'EqAmber')
    for a in range(0,360,60):
        t=math.radians(a);x,y=.17*math.cos(t),.17*math.sin(t)
        beam(m,(x,y,.95),(x,y,1.04),.015,'EqAmber',6)
    for sign in (-1,1):
        tube(m,[(0,0,.80),(sign*.24,0,.88),(sign*.24,0,1.18),(0,0,1.29)],.014,'EqBronze')
        for i in range(4):ring(m,(sign*.24,0,.91+i*.059),.025,.006,'EqBronze',normal=(0,1,0),sides=8)
    m.box((0,-.049,.49),(.13,.018,.045),'EqBronze')
    m.box((0,-.049,.49),(.045,.021,.16),'EqBronze')

def mace(m):
    grip(m,low=-.19,high=.16,r=.041,material='Window')
    beam(m,(0,0,.16),(0,0,.61),.041,'EqIron',8)
    lathe(m,[(.57,.075),(.64,.10),(.86,.10),(.93,.06)],'EqBronze',sides=8)
    for a in range(0,360,60):
        t=math.radians(a);u=(math.cos(t),math.sin(t))
        outline=[(.07,.62),(.15,.64),(.20,.78),(.15,.89),(.07,.91)]
        verts=[(r*u[0]-s*u[1]*.018,r*u[1]+s*u[0]*.018,z) for s in (-1,1) for r,z in outline]
        n=len(outline);m.part(verts,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],'Plaster')
    crystal(m,(0,0,.96),.05,.10,'EqAmber')
    ring(m,(0,0,.56),.077,.013,'EqBronze',sides=10)
    m.box((0,-.062,.39),(.13,.024,.04),'EqBronze')
    m.box((0,-.064,.39),(.04,.027,.17),'EqBronze')

def spindle(m):
    staff(m,'EqIron',.79)
    crystal(m,(0,0,1.03),.12,.48,'EqViolet')
    for sign in (-1,1):
        tube(m,[(0,0,.79),(sign*.15,0,.86),(sign*.19,0,1.10),(sign*.09,0,1.29),(0,0,1.35)],.018,'EqIron')
    for z,r in ((.85,.08),(.95,.145),(1.05,.16),(1.15,.13)):ring(m,(0,0,z),r,.009,'EqRuby',sides=12)
    for sign in (-1,1):
        tube(m,[(sign*.14,0,.86),(sign*.24,0,.72),(sign*.24,0,.59)],.006,'EqBronze',4)
        crystal(m,(sign*.24,0,.55),.035,.11,'Plaster')
    for z in (-.56,-.39,.43,.57):ring(m,(0,0,z),.045,.008,'EqRuby',sides=8)

def ritual_knife(m):
    grip(m,low=-.16,high=.14,r=.036,material='EqRuby')
    blade(m,[(.17,.09),(.30,.16),(.43,.15),(.56,.19),(.73,.12),(.91,.002)],.029,('EqIron','RockLight'))
    plate(m,[(-.012,.24),(.018,.26),(.023,.64),(.011,.77),(-.016,.63)],-.031,.011,'EqRuby')
    for sign in (-1,1):tube(m,[(0,0,.15),(sign*.13,0,.19),(sign*.17,0,.29)],.023,'Plaster')
    ring(m,(0,0,-.25),.055,.012,'EqIron',normal=(0,1,0),sides=10)
    crystal(m,(0,0,-.25),.027,.075,'EqViolet')

def rapier(m):
    grip(m,low=-.19,high=.16,r=.033,material='Window')
    blade(m,[(.20,.060),(.38,.056),(1.13,.035),(1.31,.001)],.018,('Plaster','RockLight'))
    beam(m,(-.18,0,.19),(.18,0,.19),.018,'EqBronze',8)
    ring(m,(0,0,.19),.13,.012,'EqBronze',sides=14)
    tube(m,[(.14,0,.19),(.19,-.035,.03),(.14,-.035,-.15),(0,0,-.20)],.014,'EqBronze',8)
    tube(m,[(-.10,-.08,.19),(-.17,-.10,.02),(-.10,-.07,-.12)],.010,'EqBronze',6)
    crystal(m,(0,0,-.25),.048,.09,'EqCyan')

def parrying(m):
    grip(m,low=-.17,high=.13,r=.035,material='Window')
    blade(m,[(.16,.12),(.28,.14),(.64,.08),(.83,.002)],.032,('Plaster','EqIron'))
    # Outward teeth read as a genuine blade-catching guard, not another rapier.
    for sign in (-1,1):
        tube(m,[(0,0,.15),(sign*.16,0,.22),(sign*.23,0,.39)],.022,'EqBronze',6)
        blade(m,[(.30,.035),(.49,.003)],.014,('RockLight','EqIron'),x=sign*.20)
    ring(m,(0,-.05,.15),.084,.013,'EqBronze',normal=(0,1,0),sides=12)
    crystal(m,(0,0,-.23),.041,.08,'EqCyan')

def crook(m):
    staff(m,'TimberLight',.87)
    tube(m,[(0,0,.81),(-.05,0,1.07),(.02,0,1.24),(.19,0,1.29),(.32,0,1.18),(.32,0,1.03),(.24,0,.94)],.038,'TimberLight',8)
    for z in (.75,.82):ring(m,(0,0,z),.048,.010,'EqJade',sides=8)
    tube(m,[(.20,0,1.28),(.20,0,1.05),(.10,0,.98)],.006,'Timber',4)
    for x,z in ((.09,.97),(.20,1.06)):
        crystal(m,(x,0,z),.032,.13,'Plaster')
    plate(m,[(-.055,.69),(-.21,.61),(-.15,.48),(-.035,.55)],-.01,.022,'EqJade')
    plate(m,[(-.045,.54),(-.16,.46),(-.10,.32),(-.035,.43)],-.012,.019,'Window')
    ring(m,(.06,-.055,.61),.047,.009,'EqBronze',normal=(0,1,0),sides=10)

def fangbow(m):
    pts=[(-.235,0,-.66),(-.085,0,-.44),(-.005,0,-.15),(-.005,0,.15),(-.085,0,.44),(-.235,0,.66)]
    tube(m,pts,.037,'Timber',8);beam(m,pts[0],pts[-1],.006,'Plaster',6)
    m.box((0,0,0),(.073,.09,.19),'Window')
    for z in (-.08,-.03,.02,.07):ring(m,(0,0,z),.044,.005,'EqJade',sides=8)
    for sign in (-1,1):
        for x,z in ((-.045,.25),(-.092,.40),(-.17,.54)):
            plate(m,[(x,sign*(z-.04)),(x+.13,sign*(z+.02)),(x+.05,sign*(z+.14)),(x+.018,sign*(z+.055))],0,.08,'Plaster')
        tube(m,[(-.02,-.045,sign*.20),(-.07,-.045,sign*.39),(-.18,-.025,sign*.58)],.011,'EqJade',6)
    crystal(m,(.04,-.05,.23),.035,.10,'EqAmber')

ROWS=[
 ('AlembicStaff','炼金蒸馏杖','alchemist','staff',alembic),('CausticInjector','腐蚀注射剑','alchemist','sword',injector),
 ('ResonanceLute','共鸣鲁特琴','bard','staff',lute),('MarchingLyre','行军七弦琴','bard','staff',lyre),
 ('MercyCenser','慈悲香炉杖','priest','staff',censer),('VigilMace','守夜祷锤','priest','sword',mace),
 ('HexSpindle','缚咒纺锤杖','hexer','staff',spindle),('BloodCovenKnife','血契仪刀','hexer','sword',ritual_knife),
 ('SilverRapier','银线刺剑','duelist','sword',rapier),('ParryingDagger','捕刃左手匕','duelist','sword',parrying),
 ('PackmasterCrook','驯群钩杖','beastmaster','staff',crook),('FangBow','狼牙猎弓','beastmaster','bow',fangbow)]

def build(indices):
    for i in indices:
        key,display,profession,kind,fn=ROWS[i];name='Profession_'+key
        mesh=Mesh();fn(mesh);obj=mesh.finish(name,masters)
        obj['display_name']=display;obj['profession']=profession;obj['weapon_kind']=kind
        obj['grip_origin']='Blender (0,0,0); Unity (0,0,0)'
        obj.data.calc_loop_triangles()
        assert all(p.area>1e-10 for p in obj.data.polygons),name
        print(name,len(obj.data.vertices),'vertices',len(obj.data.loop_triangles),'triangles')
    bpy.context.view_layer.update()

print('Profession weapon builders ready:',len(ROWS))
