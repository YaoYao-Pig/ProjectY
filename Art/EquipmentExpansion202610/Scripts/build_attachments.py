"""Thirty original socket-local attachment masters. Execute only through Blender MCP.

The default/user scene is preserved. Source meshes remain editable in one isolated scene.
Shapes use flat polygons and solid materials; no texture or external asset dependency.
"""
import bpy, math, json, runpy
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/Program/Unity/Project Y/Art/EquipmentExpansion202610')
for folder in ('Source', 'Staging', 'Integration', 'Previews'):
    (ROOT / folder).mkdir(parents=True, exist_ok=True)
SCENE = 'EquipmentExpansion202610_Source'
if SCENE in bpy.data.scenes:
    assert globals().get('REUSE_SOURCE') is True, 'Source already exists; resume must be explicit.'
    scene = bpy.data.scenes[SCENE]
    masters = bpy.data.collections['EquipmentExpansion202610_Masters']
else:
    scene = bpy.data.scenes.new(SCENE)
    masters = bpy.data.collections.new('EquipmentExpansion202610_Masters')
    scene.collection.children.link(masters)
bpy.context.window.scene = scene
scene.unit_settings.scale_length = 1
manifest = json.loads((ROOT / 'manifest.json').read_text(encoding='utf-8'))
helpers = runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py')
helpers['PALETTE'].update(manifest['palette'])
Mesh = helpers['MeshBuilder']
# Create by node type first, so the shared helper never relies on localized node names.
for key, hex_color in helpers['PALETTE'].items():
    name = 'M_MapLP_' + key
    if name in bpy.data.materials:
        continue
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    node = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    sockets = {s.identifier: s for s in node.inputs}
    rgba = tuple(helpers['srgb_linear'](int(hex_color[i:i+2], 16)/255) for i in (0,2,4)) + (1,)
    sockets['Base Color'].default_value = rgba
    sockets['Metallic'].default_value = .18 if key.startswith('Eq') else 0
    sockets['Roughness'].default_value = .65
    material.diffuse_color = rgba
    material['palette_srgb'] = '#' + hex_color

def beam(m, a, b, radius, material='EqIron', sides=8, taper=1):
    a, b = Vector(a), Vector(b)
    axis = (b-a).normalized()
    u = axis.cross(Vector((0,0,1)))
    if u.length < .01:
        u = axis.cross(Vector((0,1,0)))
    u.normalize()
    v = axis.cross(u)
    vertices = [tuple(c + radius*k*(math.cos(i*2*math.pi/sides)*u + math.sin(i*2*math.pi/sides)*v))
                for c,k in ((a,1),(b,taper)) for i in range(sides)]
    m.part(vertices, [tuple(reversed(range(sides))),tuple(range(sides,2*sides))] +
           [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)], material)

def torus(m, center, radius, tube=.012, material='EqBronze', normal=(0,0,1), sides=12, tube_sides=4, start=0, sweep=math.tau):
    center, axis = Vector(center), Vector(normal).normalized()
    u = axis.cross(Vector((0,0,1)))
    if u.length < .01:
        u = axis.cross(Vector((0,1,0)))
    u.normalize()
    v = axis.cross(u)
    vertices=[]
    closed=abs(sweep-math.tau)<1e-6
    ring_count=sides if closed else sides+1
    for j in range(ring_count):
        angle=start+sweep*j/sides
        radial=math.cos(angle)*u+math.sin(angle)*v
        for i in range(tube_sides):
            t=math.tau*i/tube_sides
            vertices.append(tuple(center+radial*(radius+tube*math.cos(t))+axis*tube*math.sin(t)))
    faces=[]
    for j in range(sides):
        for i in range(tube_sides):
            a=j*tube_sides+i;b=j*tube_sides+(i+1)%tube_sides
            next_ring=((j+1)%ring_count)*tube_sides
            faces.append((a,b,next_ring+(i+1)%tube_sides,next_ring+i))
    if not closed:
        faces += [tuple(reversed(range(tube_sides))),tuple(range(sides*tube_sides,(sides+1)*tube_sides))]
    m.part(vertices,faces,material)

def crystal(m, center, radius, height, material='EqCyan', axis=(0,0,1)):
    center, axis=Vector(center), Vector(axis).normalized()
    u=axis.cross(Vector((0,1,0)))
    if u.length<.01:u=axis.cross(Vector((1,0,0)))
    u.normalize();v=axis.cross(u)
    vertices=[tuple(center-axis*height*.45)]
    vertices += [tuple(center+radius*(u*math.cos(i*math.pi/3)+v*math.sin(i*math.pi/3))) for i in range(6)]
    vertices += [tuple(center+axis*height*.55)]
    m.part(vertices,[(0,1+(i+1)%6,1+i) for i in range(6)]+[(7,1+i,1+(i+1)%6) for i in range(6)],material)

def profile(m, outline, y, thickness, material):
    # Extruded front silhouette; outline is an ordered sequence of x,z pairs.
    count=len(outline)
    vertices=[(x,y+s*thickness/2,z) for s in (-1,1) for x,z in outline]
    m.part(vertices,[tuple(reversed(range(count))),tuple(range(count,2*count))]+
           [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)],material)

def lathe(m, rings, material, x=0, y=0, sides=8):
    vertices=[(x+r*math.cos(i*math.tau/sides),y+r*math.sin(i*math.tau/sides),z) for z,r in rings for i in range(sides)]
    faces=[tuple(reversed(range(sides))),tuple(range((len(rings)-1)*sides,len(rings)*sides))]
    for j in range(len(rings)-1):
        faces += [(j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i) for i in range(sides)]
    m.part(vertices,faces,material)

def collar(m, z=0, radius=.067):
    torus(m,(0,0,z-.045),radius,.014)
    torus(m,(0,0,z+.025),radius,.014)
    for x in (-radius,radius):
        beam(m,(x,0,z-.045),(x,0,z+.025),.009)

def shaft_base(m):
    collar(m,-.10,.061)
    collar(m,.10,.061)
    beam(m,(0,-.064,-.15),(0,-.064,.15),.019)

def backplate(m):
    m.box((0,.025,0),(.19,.055,.25),'EqIron')
    for z in (-.095,.095):
        m.box((0,.055,z),(.22,.025,.025),'EqBronze')

def head_sun(m):
    collar(m)
    beam(m,(0,0,.015),(0,0,.13),.025)
    torus(m,(0,0,.25),.145,.021,normal=(0,1,0),sides=12)
    crystal(m,(0,-.025,.25),.055,.14,'EqAmber')
    for a in (0,math.pi/2,math.pi,3*math.pi/2):
        x,z=math.cos(a),math.sin(a)
        beam(m,(x*.11,0,.25+z*.11),(x*.20,0,.25+z*.20),.023,'EqBronze',4,.2)

def head_ember(m):
    collar(m)
    # Explicit pedestal and roof leave large windows around the ember core.
    lathe(m,[(.04,.07),(.075,.12),(.095,.10)],'EqIron')
    lathe(m,[(.31,.12),(.36,.035)],'EqBronze')
    crystal(m,(0,0,.20),.075,.25,'EqRuby')
    for a in (0,math.pi/2,math.pi,3*math.pi/2):
        x,y=math.cos(a)*.105,math.sin(a)*.105
        beam(m,(x,y,.08),(x,y,.32),.014,'EqBronze',4)
    torus(m,(0,0,.39),.031,.009,normal=(0,1,0),sides=8)

def head_storm(m):
    collar(m)
    for x,top in ((-.16,.31),(0,.43),(.16,.34)):
        beam(m,(0,0,.04),(x,0,.15),.026,'EqIron',6)
        beam(m,(x,0,.15),(x,0,top),.018,'EqBronze',6)
        crystal(m,(x,0,top),.031,.075,'EqCyan')
    crystal(m,(0,-.045,.17),.055,.15,'EqViolet')

def head_bell(m):
    collar(m)
    beam(m,(0,0,.02),(0,0,.07),.019,'EqIron',6)
    beam(m,(-.14,0,.06),(.14,0,.06),.014,'EqBronze',6)
    for x in (-.14,.14):beam(m,(x,0,.06),(x,0,.38),.014,'EqIron',6)
    beam(m,(-.14,0,.38),(.14,0,.38),.018,'EqBronze',6)
    for x,z in ((-.09,.13),(0,.08),(.09,.17)):
        beam(m,(x,0,.35),(x,0,.26),.005,'EqIron',4)
        beam(m,(x,0,.27),(x,0,z),.026,'EqBronze',8)
        beam(m,(x,-.001,z-.001),(x,-.001,z-.007),.018,'Window',8)
    crystal(m,(0,-.055,.29),.026,.07,'EqCyan')

def head_urn(m):
    collar(m)
    lathe(m,[(.035,.04),(.09,.105),(.23,.11),(.28,.055),(.31,.055)],'EqJade')
    for x in (-.12,.12):torus(m,(x,0,.20),.057,.012,normal=(0,1,0),sides=8)
    torus(m,(0,0,.29),.06,.012)
    beam(m,(.07,0,.19),(.18,0,.27),.024,'EqBronze',6,.7)
    crystal(m,(0,0,.34),.041,.09,'EqJade')
    m.box((0,-.109,.17),(.09,.012,.10),'EqIron')

def head_antler(m):
    collar(m)
    for sign in (-1,1):
        chain=[(0,0,.04),(sign*.10,0,.14),(sign*.16,0,.28),(sign*.14,0,.42)]
        for a,b in zip(chain,chain[1:]):beam(m,a,b,.026,'RockLight',6,.72)
        beam(m,(sign*.12,0,.20),(sign*.25,0,.29),.017,'RockLight',5,.1)
        beam(m,(sign*.16,0,.29),(sign*.23,.005,.40 if sign>0 else .36),.014,'RockLight',5,.1)
    crystal(m,(0,-.02,.15),.055,.14,'EqRuby')

def head_fan(m):
    collar(m)
    for i in range(5):
        a=(i-2)*.36
        tip=Vector((math.sin(a)*.32,0,.10+math.cos(a)*.32))
        base=Vector((math.sin(a)*.08,0,.10+math.cos(a)*.08))
        beam(m,(0,0,.04),tuple(base),.015,'EqBronze',6)
        crystal(m,tuple((base+tip)/2),.045,(tip-base).length,'EqCyan' if i%2==0 else 'EqViolet',tuple(tip-base))

def head_scope(m):
    collar(m)
    beam(m,(0,0,.03),(0,0,.16),.027,'EqBronze',6)
    beam(m,(0,.105,.23),(0,-.20,.23),.065,'EqIron',10,.85)
    for y in (.10,-.11,-.20):torus(m,(0,y,.23),.066 if y!=-.20 else .056,.012,normal=(0,1,0))
    beam(m,(0,-.198,.23),(0,-.21,.23),.044,'EqCyan',10)
    torus(m,(0,-.10,.35),.052,.010,normal=(0,1,0))
    for sign in (-1,1):beam(m,(0,-.035,.23),(sign*.13,-.035,.23),.016,'EqBronze',6)

def head_comet(m):
    collar(m)
    crystal(m,(0,0,.26),.074,.44,'EqAmber')
    for sign in (-1,1):
        profile(m,[(sign*.035,.04),(sign*.13,.18),(sign*.09,.39),(sign*.065,.22)],.015,.045,'EqIron')
    crystal(m,(-.10,.025,.08),.036,.20,'EqRuby',(-.55,0,-.85))
    crystal(m,(.10,.025,.10),.026,.14,'EqAmber',(.55,0,-.85))

def head_halo(m):
    collar(m)
    for x in (-.13,.13):
        beam(m,(0,0,.02),(x,0,.12),.011,'EqIron',6)
        beam(m,(x,0,.12),(x,0,.28),.012,'EqIron',6)
    for z,r in ((.12,.13),(.28,.13)):
        torus(m,(0,0,z),r,.012,'EqBronze',sides=16)
    crystal(m,(0,0,.20),.035,.23,'EqViolet',axis=(1,0,0))
    crystal(m,(0,0,.34),.025,.06,'EqCyan')

def shaft_gyro(m):
    shaft_base(m)
    torus(m,(0,0,0),.13,.016,'EqBronze',normal=(1,0,0),sides=16)
    torus(m,(0,0,0),.16,.014,'EqIron',normal=(0,1,0),sides=16)
    for x in (-.16,.16):crystal(m,(x,0,0),.035,.07,'EqAmber')

def shaft_fins(m):
    shaft_base(m)
    beam(m,(0,-.083,-.19),(0,-.083,.19),.023,'EqCyan',6)
    for i in range(5):
        z=(i-2)*.07;width=.23-abs(i-2)*.035
        m.box((0,-.06,z),(width,.12,.018),'EqIron')
        m.box((0,-.126,z),(width*.7,.012,.022),'EqBronze')

def shaft_rail(m):
    shaft_base(m)
    for x,z,length in ((.09,-.02,.36),(.115,.085,.30),(.14,.17,.24)):
        m.box((x,-.025,z),(.035,.045,length),'EqIron' if x!=.115 else 'EqBronze')
    beam(m,(.14,-.025,.29),(.14,-.025,.35),.012,'EqBronze',4)
    beam(m,(.10,-.025,.33),(.18,-.025,.33),.008,'EqIron',4)

def shaft_bellows(m):
    shaft_base(m)
    for x in (-.10,.10):
        lathe(m,[(-.16,.045),(-.12,.065),(.11,.065),(.15,.04)],'Timber',x=x,y=-.06)
        for z in (-.10,-.05,0,.05,.10):torus(m,(x,-.06,z),.067,.006,'EqBronze',sides=8)
        beam(m,(x,-.06,-.13),(0,-.09,-.22),.02,'EqIron',6)

def shaft_dial(m):
    shaft_base(m)
    beam(m,(0,-.05,0),(.11,-.08,0),.018,'EqIron',6)
    torus(m,(.11,-.09,0),.122,.016,'EqBronze',normal=(0,1,0),sides=16)
    for a in [i*math.pi/4 for i in range(8)]:
        beam(m,(.11+.10*math.cos(a),-.09,.10*math.sin(a)),(.11+.123*math.cos(a),-.09,.123*math.sin(a)),.007,'EqIron',4)
    beam(m,(.04,-.11,-.07),(.20,-.11,.09),.010,'EqAmber',4,.2)
    crystal(m,(.11,-.115,0),.021,.045,'EqCyan',axis=(0,1,0))
    torus(m,(-.09,-.07,.12),.044,.01,'EqIron',normal=(0,1,0),sides=8)

def shaft_reed(m):
    shaft_base(m)
    for x,top in ((-.09,.19),(0,.14),(.09,.08)):
        beam(m,(x,-.10,-.18),(x,-.10,top),.025,'EqBronze',8)
        beam(m,(x,-.10,top),(x,-.10,top+.004),.018,'Window',8)
        for z in (-.08,-.02,.04):m.box((x,-.126,z),(.012,.006,.018),'Window')
    m.box((0,-.07,-.12),(.25,.04,.035),'EqIron')

def shaft_weight(m):
    shaft_base(m)
    beam(m,(0,0,.11),(.17,0,.11),.017,'EqBronze',6)
    for z in (.07,.02,-.03):torus(m,(.17,0,z),.024,.007,'EqIron',normal=(0,1,0) if z!=.02 else (1,0,0),sides=8)
    crystal(m,(.17,0,-.15),.077,.20,'EqIron')
    torus(m,(.17,0,-.15),.067,.01,'EqBronze',sides=8)

def shaft_glass(m):
    shaft_base(m)
    x=.11;y=-.06
    for z in (-.17,.17):m.box((x,y,z),(.17,.14,.025),'EqBronze')
    for dx in (-.07,.07):
        for dy in (-.05,.05):beam(m,(x+dx,y+dy,-.16),(x+dx,y+dy,.16),.009,'EqIron',6)
    lathe(m,[(-.15,.065),(-.12,.066),(0,.014),(.12,.066),(.15,.065)],'EqCyan',x=x,y=y,sides=6)
    crystal(m,(x,y-.063,-.10),.032,.07,'EqAmber')

def thruster_jet(m):
    backplate(m)
    for x in (-.105,.105):
        beam(m,(x,.11,-.15),(x,.14,.15),.066,'EqBronze',8,1.05)
        beam(m,(x,.14,.11),(x,.155,.22),.073,'EqIron',8,1.25)
        beam(m,(x,.155,.215),(x,.156,.226),.060,'Window',8)
        beam(m,(x,.156,.225),(x,.157,.235),.035,'EqAmber',8)
    m.box((0,.17,-.05),(.09,.08,.08),'EqCyan')

def thruster_flywheel(m):
    backplate(m)
    center=(0,.12,.04)
    torus(m,center,.18,.028,'EqIron',normal=(0,1,0),sides=16)
    beam(m,(0,.07,.04),(0,.17,.04),.042,'EqBronze',8)
    for i in range(6):
        a=i*math.pi/3;x,z=math.cos(a)*.15,math.sin(a)*.15
        beam(m,center,(x,.12,z+.04),.014,'EqBronze',6)
        crystal(m,(x,.12,z+.04),.026,.06,'EqAmber',axis=(x,0,z))

def thruster_piston(m):
    backplate(m)
    beam(m,(0,.12,-.18),(0,.12,.02),.062,'EqIron',8)
    beam(m,(0,.12,.01),(0,.12,.21),.025,'RockLight',8)
    m.box((0,.12,.23),(.27,.12,.07),'EqBronze')
    for x in (-.09,.09):
        beam(m,(x,.11,-.14),(x,.11,.19),.012,'EqIron',6)
        for z in (-.10,-.06,-.02,.02,.06):torus(m,(x,.11,z),.025,.005,'EqBronze',sides=6)

def gear(m,center,radius,material,teeth=10):
    x,y,z=center;outline=[]
    for i in range(teeth):
        for j,r in ((0,radius*.80),(1,radius),(2,radius),(3,radius*.80)):
            a=math.tau*(i+j/4)/teeth
            outline.append((x+math.cos(a)*r,z+math.sin(a)*r))
    profile(m,outline,y,.035,material)

def thruster_saw(m):
    backplate(m)
    gear(m,(-.07,.13,.08),.15,'EqIron',11)
    gear(m,(.09,.16,-.06),.10,'EqBronze',9)
    for x,z in ((-.07,.08),(.09,-.06)):
        beam(m,(x,.13,z),(x,.19,z),.022,'EqRuby',8)
    beam(m,(-.07,.195,.08),(.09,.195,-.06),.012,'RockLight',4)

def thruster_furnace(m):
    backplate(m)
    m.box((0,.13,0),(.24,.17,.29),'EqIron')
    m.box((0,.223,.015),(.17,.012,.15),'EqAmber')
    for x in (-.065,-.022,.022,.065):m.box((x,.235,.015),(.013,.014,.16),'EqBronze')
    beam(m,(.08,.13,.10),(.08,.13,.27),.04,'EqIron',8)
    beam(m,(.08,.13,.24),(.16,.13,.27),.038,'EqBronze',8)
    beam(m,(-.06,.14,-.15),(-.06,.14,-.20),.035,'EqRuby',6)

def thruster_anchor(m):
    backplate(m)
    torus(m,(0,.14,-.02),.088,.024,'EqBronze',normal=(0,1,0),sides=12)
    for sign in (-1,1):
        beam(m,(0,.12,.04),(sign*.21,.12,.19),.022,'EqIron',6)
        profile(m,[(sign*.18,.16),(sign*.27,.21),(sign*.25,.08),(sign*.23,.13)],.12,.045,'EqIron')
    for z in (-.10,-.05,0,.05):beam(m,(-.06,.17,z),(.06,.17,z+.04),.007,'TimberLight',4)

def thruster_fan(m):
    backplate(m)
    torus(m,(0,.14,0),.19,.013,'EqIron',normal=(0,1,0),sides=16)
    beam(m,(0,.08,0),(0,.20,0),.037,'EqBronze',8)
    for i in range(4):
        a=i*math.pi/2
        points=[]
        for x,z in ((.025,-.02),(.17,.025),(.14,.09),(.04,.04)):
            points.append((x*math.cos(a)-z*math.sin(a),x*math.sin(a)+z*math.cos(a)))
        profile(m,points,.14,.026,'EqCyan' if i%2==0 else 'EqBronze')

def thruster_mercury(m):
    backplate(m)
    torus(m,(0,.14,0),.14,.037,'EqCyan',normal=(0,1,0),sides=14,start=-.6,sweep=4.35)
    torus(m,(0,.14,0),.14,.011,'EqIron',normal=(0,1,0),sides=14,start=-.6,sweep=4.35)
    beam(m,(0,.08,-.13),(0,.08,.13),.025,'EqBronze',8)
    for x,z in ((-.08,.13),(.08,-.13)):
        beam(m,(x,.14,z),(x*.7,.18,0),.012,'EqIron',6)
    crystal(m,(0,.14,0),.035,.10,'EqViolet')

def catalyst_base(m):
    m.box((0,.025,0),(.10,.05,.15),'EqIron')
    for z in (-.055,.055):m.box((0,.057,z),(.13,.025,.025),'EqBronze')

def catalyst_orbit(m):
    catalyst_base(m)
    center=(0,.11,.035)
    for normal,r in (((0,1,0),.115),((1,0,1),.098),((1,0,-1),.081)):
        torus(m,center,r,.009,'EqBronze',normal=normal,sides=12)
    crystal(m,center,.042,.13,'EqViolet')
    crystal(m,(.115,.11,.035),.016,.04,'EqCyan')

def catalyst_censer(m):
    catalyst_base(m)
    for x in (-.075,.075):
        beam(m,(0,.055,.07),(x,.13,.05),.007,'EqBronze',4)
        beam(m,(x,.13,.05),(x*.6,.13,-.10),.007,'EqBronze',4)
    lathe(m,[(-.23,.03),(-.20,.073),(-.12,.067),(-.095,.04)],'EqBronze',y=.13)
    for x in (-.04,0,.04):m.box((x,.193,-.15),(.016,.012,.035),'Window')
    crystal(m,(0,.13,-.07),.033,.08,'EqJade')
    beam(m,(.04,.13,-.13),(.115,.13,-.07),.012,'EqIron',6)

def catalyst_key(m):
    catalyst_base(m)
    torus(m,(.045,.11,.14),.063,.017,'EqBronze',normal=(0,1,0),sides=10)
    beam(m,(.045,.11,.09),(.045,.11,-.18),.024,'EqIron',6)
    for z in (-.07,-.12,-.17):m.box((.082,.11,z),(.09,.045,.025),'EqBronze')
    crystal(m,(-.012,.12,-.035),.031,.22,'EqViolet')

def catalyst_rain(m):
    catalyst_base(m)
    beam(m,(0,.12,-.14),(0,.12,.20),.012,'EqBronze',6)
    for i in range(5):
        z=-.055+i*.045;length=.12-i*.013
        profile(m,[(.01,z),(.01+length,z+.06),(.015+length,z+.09),(.01,z+.025)],.12,.015,'EqCyan' if i%2 else 'RockLight')
    crystal(m,(0,.12,-.16),.03,.08,'EqCyan')
    beam(m,(-.055,.12,.19),(.075,.12,.19),.008,'EqIron',4)

BUILDERS = [head_sun,head_ember,head_storm,head_bell,head_urn,head_antler,head_fan,head_scope,head_comet,head_halo,
            shaft_gyro,shaft_fins,shaft_rail,shaft_bellows,shaft_dial,shaft_reed,shaft_weight,shaft_glass,
            thruster_jet,thruster_flywheel,thruster_piston,thruster_saw,thruster_furnace,thruster_anchor,thruster_fan,thruster_mercury,
            catalyst_orbit,catalyst_censer,catalyst_key,catalyst_rain]

def build_batch(start,end):
    for i in range(start,end):
        row=manifest['assets'][i]
        mesh=Mesh();BUILDERS[i](mesh)
        obj=mesh.finish(row['model'],masters)
        obj['item_id']=row['id'];obj['slot_kind']=row['slotKind'];obj['display_name']=row['name']
        obj['purpose']='socket-local detachable attachment; preserve origin'
        obj.data.calc_loop_triangles()
        assert len(obj.data.uv_layers)==1
        assert all(p.area>1e-10 and not p.use_smooth for p in obj.data.polygons),row['model']
        print(row['id'],row['model'],'triangles',len(obj.data.loop_triangles))
    bpy.context.view_layer.update()

print('Authoring helpers ready; explicit build_batch(start,end) creates controlled groups.')
