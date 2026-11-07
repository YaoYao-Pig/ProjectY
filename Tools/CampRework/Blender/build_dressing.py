import bpy,math,random,json
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path('D:/Program/Unity/Project Y/Art/CampPresentation')
scene=bpy.data.scenes['CampPresentation_Art'];bpy.context.window.scene=scene
materials={name.removeprefix('Camp_'):mat for name,mat in bpy.data.materials.items() if name.startswith('Camp_') and '.' not in name}
rng=random.Random(31027)
source=Path('D:/Program/Unity/Project Y/Tools/CampRework/Blender/build_camp.py').read_text(encoding='utf8')
exec(source[source.index('current=None'):source.index('BUILDERS=')])
new=[]
current=bpy.data.collections.new('Camp_BackdropTree');scene.collection.children.link(current);new.append(current)
beam('Rooted trunk',(0,0,0),(.17,.08,4.95),.16,'OakDark',9)
for i in range(5):
    a=i*math.tau/5;beam('Visible root',(0,0,.21),(math.cos(a)*.65,math.sin(a)*.65,.035),.10,'Oak',7)
for tier,(z,radius,height) in enumerate([(1.3,1.7,1.75),(2.25,1.42,1.65),(3.1,1.1,1.55),(3.9,.77,1.5)]):
    vertices=[];n=24;angle=tier*.27
    for ring in range(3):
        for i in range(n):
            a=i*math.tau/n+angle;spike=.83 if i%2 else 1.08
            rr=radius*spike*(1 if ring==0 else .77 if ring==1 else .38)
            zz=z+(-.13 if i%2==0 else .08) if ring==0 else z+.24 if ring==1 else z+height*.62
            vertices.append((.04*tier+math.cos(a)*rr,.025*tier+math.sin(a)*rr,zz))
    vertices.append((.1+.04*tier,.025*tier,z+height))
    faces=[]
    for ring in range(2):
        for i in range(n):faces.append((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i))
    for i in range(n):faces.append((2*n+i,2*n+(i+1)%n,3*n))
    faces.append(tuple(range(n-1,-1,-1)))
    foliage=mesh('Layered needle boughs',vertices,faces,'Leaf');foliage.data.materials.append(materials['Grass'])
    for face in foliage.data.polygons:face.material_index=1 if face.index%7==0 else 0
    for i in range(7):
        a=i*math.tau/7+angle;beam('Exposed branch',(.05,.02,z+.23),(math.cos(a)*radius*.85,math.sin(a)*radius*.85,z-.08),.025,'OakDark',5)
current=bpy.data.collections.new('Camp_Clearing');scene.collection.children.link(current);new.append(current)
vertices=[(0,0,.012)];n=64
for ring,(size,z) in enumerate([(0.78,0),(1,0),(.985,-.35),(.94,-.52)]):
    for i in range(n):
        a=i*math.tau/n;wave=1+.035*math.sin(a*5)+.02*math.cos(a*9)
        vertices.append((math.cos(a)*8.9*size*wave,math.sin(a)*6.65*size*wave,z+(rng.uniform(-.035,.015) if ring>1 else 0)))
faces=[]
for i in range(n):faces.append((0,1+i,1+(i+1)%n))
for ring in range(3):
    for i in range(n):faces.append((1+ring*n+i,1+(ring+1)*n+i,1+(ring+1)*n+(i+1)%n,1+ring*n+(i+1)%n))
ground=mesh('Organic forest clearing',vertices,faces,'Grass');ground.data.materials.append(materials['Earth']);ground.data.materials.append(materials['OakDark'])
for p in ground.data.polygons:
    if p.index>=n*2:p.material_index=1 if p.index<n*3 else 2
for i in range(120):
    a=rng.random()*math.tau;r=rng.uniform(.82,.98);x=math.cos(a)*8.9*r;y=math.sin(a)*6.6*r
    for j in range(5):
        angle=rng.random()*math.tau;h=rng.uniform(.12,.3);width=.035
        dx,dy=math.cos(angle)*width,math.sin(angle)*width
        mesh('Grass blades',[(x-dx,y-dy,.01),(x+dx,y+dy,.01),(x+dx*2+h*.15,y+dy*2,h)],[(0,1,2),(2,1,0)],'Leaf' if j%2 else 'Grass')
for i in range(18):
    a=rng.random()*math.tau;r=rng.uniform(.86,.99);x=math.cos(a)*8.9*r;y=math.sin(a)*6.6*r
    sphere('Embedded border rock',(x,y,.045),(.15+rng.random()*.22,.12+rng.random()*.2,.09+rng.random()*.12),'Stone',1)
manifest=json.loads((ROOT/'Integration'/'kit-manifest.json').read_text())
for collection in new:
    bpy.ops.object.select_all(action='DESELECT')
    for o in collection.objects:o.select_set(True)
    bpy.context.view_layer.objects.active=next(iter(collection.objects));bpy.ops.object.join();o=bpy.context.object;o.name=collection.name
    scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);o.data.calc_loop_triangles()
    manifest['assets'].append({'name':o.name,'vertices':len(o.data.vertices),'triangles':len(o.data.loop_triangles),'dimensions':list(o.dimensions),'materials':[m.name for m in o.data.materials]})
    me=o.data.copy();me.transform(Matrix.Rotation(math.pi,4,'Z'));ex=bpy.data.objects.new(o.name+'_Export',me);scene.collection.objects.link(ex)
    bpy.ops.object.select_all(action='DESELECT');ex.select_set(True);bpy.context.view_layer.objects.active=ex
    bpy.ops.export_scene.fbx(filepath=str(ROOT/'Export'/(o.name+'.fbx')),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',bake_space_transform=True,use_mesh_modifiers=True,use_triangles=True,bake_anim=False,add_leaf_bones=False,path_mode='RELATIVE')
    bpy.data.objects.remove(ex,do_unlink=True);bpy.data.meshes.remove(me);o.hide_set(True);o.hide_render=True
(ROOT/'Integration'/'kit-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
bpy.data.libraries.write(str(ROOT/'Source'/'CampPresentation.blend'),{scene},fake_user=True)
print(json.dumps({'assets':len(manifest['assets']),'added':[c.name for c in new]}))
