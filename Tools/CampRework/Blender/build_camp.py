"""Editable, metre-scale camp kit. Run through Blender MCP, not a second Blender."""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/Program/Unity/Project Y/Art/CampPresentation')
for folder in ('Source', 'Export', 'Previews', 'Integration'):
    (ROOT / folder).mkdir(parents=True, exist_ok=True)
SCENE = 'CampPresentation_Art'
if SCENE in bpy.data.scenes:
    raise RuntimeError('Camp art scene already exists; inspect it before rebuilding.')
scene = bpy.data.scenes.new(SCENE)
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
bpy.context.window.scene = scene
rng = random.Random(271026)
materials = {}
palette = {'Oak':'76583e','OakLight':'a8885a','OakEdge':'c1a473','OakDark':'493b2d',
 'Iron':'414d4b','Steel':'81908b','Brass':'b69b61','Stone':'827f6f','StoneLight':'a09c88',
 'Canvas':'c4b78f','CanvasShade':'a59978','ForestCloth':'53695b','RedCloth':'8b5145',
 'Leather':'805b42','Rope':'c2ab78','Earth':'72684e','EarthLight':'9a8763','Grass':'697b4b',
 'Leaf':'61774b','Coal':'292d29','Ember':'e58b35','Flame':'ffd487','Glass':'628b7e',
 'Paper':'dbcc9f','Bandage':'d1c6a5','Water':'487e85'}
def linear(v):
    return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
for name, hx in palette.items():
    color=tuple(linear(int(hx[i:i+2],16)/255) for i in (0,2,4))+(1,)
    mat=bpy.data.materials.get('Camp_'+name) or bpy.data.materials.new('Camp_'+name)
    mat.use_nodes=True
    node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value=color
    node.inputs['Roughness'].default_value=.84
    mat.diffuse_color=color
    if name in ('Iron','Steel','Brass'):
        node.inputs['Metallic'].default_value=.28
        node.inputs['Roughness'].default_value=.62
    if name in ('Ember','Flame'):
        node.inputs['Emission Color'].default_value=color
        node.inputs['Emission Strength'].default_value=1.4
    materials[name]=mat

current=None
def finish(obj,name,mat):
    obj.name=name
    for c in list(obj.users_collection):c.objects.unlink(obj)
    current.objects.link(obj)
    obj.data.materials.append(materials[mat])
    return obj
def cube(name,loc,size,mat='Oak',bevel=.025,rot=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object;o.scale=size;o.rotation_euler.z=rot
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(o,name,mat)
    if bevel:
        m=o.modifiers.new('Crafted edges','BEVEL');m.width=bevel;m.segments=1
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
    return o
def cyl(name,loc,r,depth,mat='Iron',verts=12,rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc)
    o=finish(bpy.context.object,name,mat)
    if rot:o.rotation_euler=rot
    return o
def beam(name,a,b,r,mat='Oak',verts=8):
    a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,mat,verts)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def mesh(name,verts,faces,mat):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);current.objects.link(o);data.materials.append(materials[mat]);return o
def sphere(name,loc,scale,mat,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc)
    o=finish(bpy.context.object,name,mat);o.scale=scale;return o
def plank_floor(x,y,w,d,z=.08):
    for i in range(max(1,round(w/.23))):
        n=round(w/.23);cube('Floor plank',(x-w/2+(i+.5)*w/n,y,z),(w/n-.014,d,.12),'Oak' if i%3 else 'OakLight',.012)
def crate(x,y,z,s=1,open_top=False):
    for side in (-1,1):
        for h in range(3):cube('Crate slat',(x,y+side*.34*s,z+(.14+h*.2)*s),(.9*s,.055*s,.17*s),'OakLight',.012)
        for h in range(3):cube('Crate end',(x+side*.43*s,y,z+(.14+h*.2)*s),(.06*s,.67*s,.17*s),'Oak',.012)
        for yy in (-.34,.34):cube('Crate corner',(x+side*.4*s,y+yy*s,z+.32*s),(.075*s,.075*s,.65*s),'OakDark',.01)
    cube('Crate floor',(x,y,z+.04*s),(.85*s,.62*s,.08*s),'Oak',.01)
    if not open_top:
        for j in range(4):cube('Crate lid',(x,y+(-.255+j*.17)*s,z+.64*s),(.9*s,.155*s,.06*s),'OakLight',.012)
    beam('Diagonal brace',(x-.36*s,y-.38*s,z+.06*s),(x+.36*s,y-.38*s,z+.61*s),.033*s,'OakEdge',4)
def barrel(x,y,z,s=1):
    vs=[];rings=[(0,.28),(.08,.31),(.45,.37),(.82,.31),(.9,.28)]
    for h,r in rings:
        for i in range(12):a=2*math.pi*i/12;vs.append((x+math.cos(a)*r*s,y+math.sin(a)*r*s,z+h*s))
    faces=[]
    for k in range(4):
        for i in range(12):faces.append((k*12+i,k*12+(i+1)%12,(k+1)*12+(i+1)%12,(k+1)*12+i))
    faces.extend([tuple(range(11,-1,-1)),tuple(range(48,60))]);o=mesh('Coopered barrel',vs,faces,'Oak')
    o.data.materials.append(materials['OakLight'])
    for p in o.data.polygons:p.material_index=int(p.index%4==0)
    for h,r in ((.12,.324),(.72,.332)):cyl('Barrel hoop',(x,y,z+h*s),r*s,.065*s,'Iron')
    for j in range(4):cube('Barrel lid plank',(x,y+(j-1.5)*.13*s,z+.902*s),(.45*s,.12*s,.025*s),'OakLight',.006)
def sack(x,y,z,s=1):
    sphere('Supply sack',(x,y,z+.34*s),(.3*s,.25*s,.38*s),'CanvasShade',2)
    cyl('Sack neck',(x,y,z+.67*s),.11*s,.13*s,'Canvas',8);cyl('Sack tie',(x,y,z+.68*s),.12*s,.035*s,'Rope',8)
def lantern(x,y,z,s=1):
    cube('Lantern glow',(x,y,z+.22*s),(.17*s,.17*s,.28*s),'Flame',.015)
    for dx in (-.1,.1):
        for dy in (-.1,.1):beam('Lantern frame',(x+dx*s,y+dy*s,z+.05*s),(x+dx*s,y+dy*s,z+.4*s),.016*s,'Iron',6)
    cube('Lantern base',(x,y,z+.045*s),(.25*s,.25*s,.06*s),'Iron',.02)
    cube('Lantern cap',(x,y,z+.42*s),(.27*s,.27*s,.08*s),'Iron',.03)
    beam('Lantern handle',(x-.08*s,y,z+.45*s),(x,y,z+.6*s),.015*s,'Iron',6)
    beam('Lantern handle',(x+.08*s,y,z+.45*s),(x,y,z+.6*s),.015*s,'Iron',6)
def cloth_roof(x,y,width,depth,z,mat='ForestCloth'):
    vs=[];nx=10;ny=6
    for j in range(ny+1):
        for i in range(nx+1):
            u=i/nx;v=j/ny
            zz=z+.48*(1-abs(u*2-1))-.095*math.sin(v*math.pi)-.04*math.sin(u*math.pi*6)
            vs.append((x+(u-.5)*width,y+(v-.5)*depth,zz))
    faces=[]
    for j in range(ny):
        for i in range(nx):a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
    o=mesh('Tensioned canvas canopy',vs,faces,mat)
    m=o.modifiers.new('Cloth thickness','SOLIDIFY');m.thickness=.025
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
    for side in (-1,1):beam('Canopy edge rope',(x-width/2,y+side*depth/2,z),(x+width/2,y+side*depth/2,z),.018,'Rope',6)
def canopy(w=3.3,d=2.3,z=2.6,mat='ForestCloth'):
    for x in (-w/2+.15,w/2-.15):
        for y in (-d/2+.15,d/2-.15):
            beam('Canopy post',(x,y,0),(x,y,z+.12),.06,'Oak',8)
            beam('Braced frame',(x,y,z-.6),(x-math.copysign(.43,x),y,z-.05),.04,'OakLight',6)
    cloth_roof(0,0,w,d,z,mat)
def workbench(level):
    if level==0:
        crate(-.65,0,0,.8);cube('Folded work mat',(.3,0,.06),(1.1,.75,.1),'Leather',.05);tools(.3,0,.16);return
    plank_floor(0,0,2.8,1.9)
    for x in (-.85,.85):
        for y in (-.36,.36):cube('Mortised leg',(x,y,.62),(.16,.18,1.05),'OakDark',.02)
        cube('Bench trestle',(x,0,.35),(.22,1,.13),'OakLight',.025)
    for y in (-.43,-.22,0,.22,.43):cube('Bench top',(0,y,1.18),(2.35,.205,.16),'OakLight' if y==0 else 'Oak',.018)
    cube('Cross stretcher',(0,.15,.4),(1.8,.1,.12),'OakDark',.02)
    cube('Vice body',(.85,-.47,1.32),(.35,.3,.25),'Iron',.025)
    beam('Vice screw',(.85,-.65,1.3),(.85,-.85,1.3),.04,'Steel',10)
    tools(-.2,-.12,1.28);crate(-1.3,.55,0,.65,True);sack(.9,.8,.12,.65)
    if level>=2:
        canopy();cube('Toolboard',(0,.81,1.75),(2.25,.1,.78),'OakDark',.02)
        for x in (-.8,-.4,0,.4,.8):
            beam('Hanging tool handle',(x,.73,1.5),(x,.73,1.95),.022,'OakLight',6)
            cube('Hanging tool head',(x,.72,1.95),(.19,.08,.12),'Steel',.018)
        lantern(1.22,-.5,1.3,.75);barrel(-1.9,.4,0,.85)
def tools(x,y,z):
    cube('Leather working pad',(x,y,z),(1,.55,.035),'Leather',.01)
    beam('Hammer handle',(x-.3,y-.15,z+.06),(x+.18,y-.05,z+.06),.035,'OakLight',8)
    cube('Hammer head',(x+.19,y-.05,z+.11),(.12,.28,.14),'Steel',.025)
    cube('Blade blank',(x+.05,y+.16,z+.06),(.67,.1,.04),'Steel',.006,rot=.2)
    for i in range(3):cyl('Rivet',(x-.35+i*.14,y+.12,z+.06),.025,.035,'Brass',8)
def forge(level):
    if level==0:
        cube('Forge foundation',(0,0,.12),(1.45,1.2,.24),'Stone',.07);crate(.95,.2,0,.6,True);return
    for row in range(4):
        for side in (-1,1):
            cube('Hearth side stone',(side*.55,.06,.15+row*.23),(.3,.95,.21),'StoneLight' if row%2 else 'Stone',.04)
        cube('Hearth back stone',(0,.45,.15+row*.23),(1.4,.3,.21),'Stone',.04)
    cube('Hearth bed',(0,0,.22),(1.35,1,.3),'Stone',.05)
    for i in range(18):sphere('Coal embers',(rng.uniform(-.4,.4),rng.uniform(-.27,.3),.43+rng.uniform(0,.08)),(.08,.07,.05),'Ember' if i%3==0 else 'Coal')
    for row in range(7):cube('Flue stone',(.15,.32,1.1+row*.24),(.65,.6,.22),'StoneLight' if row%3==0 else 'Stone',.025)
    cube('Chimney cap',(.15,.32,2.8),(.86,.79,.12),'StoneLight',.04)
    cyl('Anvil stump',(-1.1,-.5,.36),.36,.72,'OakDark',10)
    cube('Anvil foot',(-1.1,-.5,.77),(.58,.44,.12),'Iron',.03)
    cube('Anvil waist',(-1.1,-.5,.92),(.32,.28,.25),'Iron',.025)
    cube('Anvil face',(-1.1,-.5,1.09),(.8,.37,.16),'Steel',.03)
    mesh('Anvil horn',[(-1.5,-.68,1.03),(-1.5,-.32,1.03),(-1.5,-.32,1.17),(-1.5,-.68,1.17),(-1.93,-.5,1.11)],[(0,1,2,3),(0,4,1),(1,4,2),(2,4,3),(3,4,0)],'Steel')
    beam('Tongs',(-1.25,-.55,1.2),(-.8,-.4,1.2),.018,'Iron',6)
    barrel(1.05,-.45,0,.75);cube('Water surface',(1.05,-.45,.67),(.3,.3,.015),'Water',0)
    if level>=2:
        for i in range(4):cube('Stored iron bar',(.9+i*.12,.8,.17),(.09,.9,.1),'Steel',.01)
        for j in range(3):beam('Fuel logs',(.8,1,.15+j*.14),(1.55,1,.15+j*.14),.075,'Oak',8)
        cube('Bellows',(.9,.25,.58),(.7,.45,.25),'Leather',.09,rot=.25)
        lantern(-1.45,.55,.05,.7)
def chest(x,y,z,s=1):
    cube('Chest body',(x,y,z+.33*s),(1.1*s,.7*s,.6*s),'Oak',.04)
    vs=[]
    for xx in (-.55,.55):
        for i in range(7):a=i*math.pi/6;vs.append((x+xx*s,y+math.cos(a)*.35*s,z+(.6+math.sin(a)*.21)*s))
    faces=[tuple(range(6,-1,-1)),tuple(range(7,14))]
    for i in range(6):faces.append((i,i+1,i+8,i+7))
    mesh('Arched chest lid',vs,faces,'OakLight')
    for dx in (-.4,.4):
        cube('Chest iron band',(x+dx*s,y-.36*s,z+.33*s),(.06*s,.035*s,.57*s),'Iron',.007)
        beam('Chest lid binding',(x+dx*s,y-.35*s,z+.62*s),(x+dx*s,y+.35*s,z+.62*s),.034*s,'Iron',6)
    cube('Chest clasp',(x,y-.385*s,z+.55*s),(.12*s,.045*s,.22*s),'Brass',.012)
def warehouse(level):
    chest(0,-.3,0,1.1)
    if level>=1:
        plank_floor(0,0,3.2,2.1);crate(-1.1,.65,.14,.9);crate(-1.1,.65,.74,.72);barrel(1,.7,.14,.85);sack(.9,-.5,.14,.8)
    if level>=2:
        canopy(3.9,2.8,2.7,'CanvasShade');crate(1.55,-.7,0,.8,True);sack(-1.55,-.7,.1,.75)
        cube('Supply shelf',(0,1,1.65),(2.2,.45,.1),'OakLight',.02)
        for x in (-1,1):cube('Shelf upright',(x,1.1,1.1),(.12,.12,2.2),'OakDark',.015)
        for i in range(4):sack(-.75+i*.5,1,1.7,.5)
def medical(level):
    if level==0:
        cube('Folded canvas',(0,0,.18),(1.4,.6,.36),'Canvas',.08);crate(.95,.1,0,.65);return
    # A ridge tent with a visibly open front and individual hanging flaps.
    w,d,z=2.8,2.5,1.55
    for x in (-w/2,w/2):
        mesh('Tent wall',[(x,-d/2,0),(x,d/2,0),(x,d/2,z),(x,-d/2,z)],[(0,1,2,3),(3,2,1,0)],'CanvasShade')
    mesh('Tent back',[(-w/2,d/2,0),(w/2,d/2,0),(w/2,d/2,z),(0,d/2,z+.9),(-w/2,d/2,z)],[(0,1,2,3,4),(4,3,2,1,0)],'CanvasShade')
    cloth_roof(0,0,w+.16,d+.18,z,'Canvas')
    for side in (-1,1):
        mesh('Tied tent flap',[(side*.03,-d/2-.06,z+.48),(side*w/2,-d/2-.06,z),(side*w/2,-d/2-.06,0),(side*.85,-d/2-.06,.55)],[(0,1,2,3),(3,2,1,0)],'Canvas')
        beam('Tent front guy',(side*w/2,-d/2,z),(side*(w/2+.7),-d/2-.6,.08),.016,'Rope',6)
        cube('Tent peg',(side*(w/2+.7),-d/2-.6,.12),(.07,.07,.24),'OakDark',.01)
    cube('Bedroll',(0,.2,.28),(1.8,.72,.3),'ForestCloth',.1)
    cube('Pillow',(.62,.2,.47),(.5,.6,.12),'Bandage',.08)
    cube('Medical table',(-1.5,-1.4,.88),(1.15,.65,.1),'OakLight',.015)
    for x in (-1.95,-1.05):beam('Medical table leg',(x,-1.4,0),(x,-1.4,.85),.05,'Oak',6)
    for i in range(3):cyl('Medicine flask',(-1.8+i*.28,-1.4,1.06),.075,.23,'Glass',10);cyl('Flask cork',(-1.8+i*.28,-1.4,1.19),.045,.05,'Oak',8)
    if level>=2:
        lantern(1.6,-1.4,.05,.9);crate(1.7,.3,0,.9,True)
        for i in range(4):cyl('Rolled bandages',(1.5+i*.12,.2,.7),.055,.18,'Bandage',10)
def firepit():
    for i in range(11):
        a=i*2*math.pi/11;sphere('Fire ring stone',(math.cos(a)*.72,math.sin(a)*.72,.15),(.22,.18,.16),'StoneLight')
    for a in (0,.9,-.9):beam('Campfire log',(-.48*math.cos(a),-.48*math.sin(a),.12),(.48*math.cos(a),.48*math.sin(a),.12),.105,'OakDark',8)
    for i in range(7):sphere('Glowing coals',(rng.uniform(-.35,.35),rng.uniform(-.35,.35),.18),(.12,.09,.055),'Ember')
    for x in (-.85,.85):beam('Cooking tripod',(x,-.25,0),(0,.1,1.45),.035,'Iron',8)
    beam('Cooking tripod',(0,.95,0),(0,.1,1.45),.035,'Iron',8)
    beam('Pot chain',(0,.1,1.4),(0,.1,.85),.013,'Iron',6)
    sphere('Hanging cooking pot',(0,.1,.7),(.34,.3,.26),'Iron',2)
    cyl('Pot rim',(0,.1,.84),.29,.06,'Steel',12)
    for a in (0,2.1,4.2):
        x,y=math.cos(a)*1.65,math.sin(a)*1.65
        beam('Campfire bench',(x-math.sin(a)*.65,y+math.cos(a)*.65,.34),(x+math.sin(a)*.65,y-math.cos(a)*.65,.34),.2,'Oak',10)

BUILDERS={'Workbench':workbench,'Forge':forge,'Warehouse':warehouse,'Medical':medical}
assets=[]
for family,builder in BUILDERS.items():
    for level in range(3):
        current=bpy.data.collections.new(f'Camp_{family}_L{level}');scene.collection.children.link(current)
        builder(level);assets.append(current)
current=bpy.data.collections.new('Camp_Firepit');scene.collection.children.link(current);firepit();assets.append(current)
manifest=[]
for collection in assets:
    # Baking to one mesh per asset preserves material slots and makes the kit inexpensive to instantiate.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in collection.objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=next(iter(collection.objects))
    bpy.ops.object.join();obj=bpy.context.object;obj.name=collection.name
    scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    obj.data.calc_loop_triangles()
    manifest.append({'name':obj.name,'vertices':len(obj.data.vertices),'triangles':len(obj.data.loop_triangles),'dimensions':list(obj.dimensions),'materials':[m.name for m in obj.data.materials]})
    # A Blender +Y facing asset maps to Unity +Z with the project's additional Z half turn.
    from mathutils import Matrix
    export_mesh=obj.data.copy();export_mesh.transform(Matrix.Rotation(math.pi,4,'Z'))
    export_obj=bpy.data.objects.new(obj.name+'_Export',export_mesh);scene.collection.objects.link(export_obj)
    bpy.ops.object.select_all(action='DESELECT');export_obj.select_set(True);bpy.context.view_layer.objects.active=export_obj
    out=ROOT/'Export'/(obj.name+'.fbx')
    bpy.ops.export_scene.fbx(filepath=str(out),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',
        global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',bake_space_transform=True,
        use_mesh_modifiers=True,use_triangles=True,bake_anim=False,add_leaf_bones=False,path_mode='RELATIVE')
    bpy.data.objects.remove(export_obj,do_unlink=True);bpy.data.meshes.remove(export_mesh)
    obj.hide_render=True;obj.hide_set(True)
(ROOT/'Integration'/'kit-manifest.json').write_text(json.dumps({'palette':palette,'assets':manifest},ensure_ascii=False,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(ROOT/'Source'/'CampPresentation.blend'),{scene},fake_user=True)
print(json.dumps({'source':str(ROOT/'Source'/'CampPresentation.blend'),'assets':len(manifest),'triangles':sum(a['triangles'] for a in manifest),'names':[a['name'] for a in manifest]}))
