"""Run only through Blender MCP. Independent scene; existing scenes and masters are preserved."""
import bpy, json, math, runpy, bmesh
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path('D:/Program/Unity/Project Y')
ART=ROOT/'Art/FirearmsExpansion202610'
for folder in ('Source','Staging','Previews','Integration'):(ART/folder).mkdir(parents=True,exist_ok=True)
g=runpy.run_path(str(ROOT/'Art/ArsenalExpansion202610/Scripts/geometry.py'))
Mesh,beam,ring,plate=[g[k] for k in ('Mesh','beam','ring','plate')]
name='FirearmsExpansion202610_Source'
previous_scene=bpy.context.window.scene
revision=globals().get('REVISE') is True
if name in bpy.data.scenes:
    assert revision, 'Firearm source already exists; inspect and explicitly request REVISE'
    scene=bpy.data.scenes[name];masters=bpy.data.collections[name+'_Masters']
else:
    scene=bpy.data.scenes.new(name);masters=bpy.data.collections.new(name+'_Masters');scene.collection.children.link(masters)
bpy.context.window.scene=scene;scene.unit_settings.scale_length=1
rows=json.loads((ART/'manifest.json').read_text(encoding='utf-8'))
palette={'GunSteel':('68737c',.55,.32),'GunCoating':('424950',.15,.58),'GunWood':('604a39',0,.70),
         'GunWoodLight':('795840',0,.65),'GunRubber':('303133',0,.85),'GunBrass':('8f7950',.75,.33),
         'GunLens':('245054',.4,.12),'GunTan':('6d6756',.1,.75)}
for key,(color,metal,roughness) in palette.items():
    g['helpers']['PALETTE'][key]=color
    mat=bpy.data.materials.get('M_MapLP_'+key) or bpy.data.materials.new('M_MapLP_'+key)
    mat.use_nodes=True;node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    rgba=tuple(g['helpers']['srgb_linear'](int(color[i:i+2],16)/255) for i in (0,2,4))+(1,)
    node.inputs['Base Color'].default_value=rgba;node.inputs['Metallic'].default_value=metal
    node.inputs['Roughness'].default_value=roughness;mat.diffuse_color=rgba
(ART/'Integration/palette.json').write_text(json.dumps(palette,indent=2),encoding='utf-8')

def profile(m,outline,width,material):
    count=len(outline)
    points=[(side*width/2,y,z) for side in (-1,1) for y,z in outline]
    m.part(points,[tuple(reversed(range(count))),tuple(range(count,2*count))]+
           [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)],material)

def pin(m,y,z,radius=.006):
    beam(m,(-.063,y,z),(-.067,y,z),radius,'GunSteel',12)
    beam(m,(.063,y,z),(.067,y,z),radius,'GunSteel',12)

def muzzle(m,end,radius=.035):
    ring(m,(0,-end,.18),radius,.004,'GunSteel',normal=(0,1,0),sides=20)
    beam(m,(0,-end+.009,.18),(0,-end+.014,.18),radius*.72,'GunRubber',20)

def rifle(m,row):
    id=row['id'];end=row['muzzle'];sniper=id in (802,803);shotgun=id in (804,805)
    furniture='GunWood' if id in (801,802,804) else 'GunCoating'
    profile(m,[(-.35,.115),(-.35,.215),(-.29,.24),(.035,.235),(.065,.19),(.06,.095),(-.17,.08)],.125,'GunCoating')
    m.box((0,-.15,.235),(.092,.32,.014),'GunSteel')
    # Recessed ejection port, bolt and two assembly pins on either side.
    for x in (-.0635,.0635):
        m.box((x,-.105,.186),(.003,.12,.032),'GunRubber')
        m.box((x,-.115,.181),(.004,.095,.018),'GunSteel')
    for y,z in [(-.27,.14),(.015,.13),(-.18,.215)]:pin(m,y,z)
    profile(m,[(.025,.13),(.065,.10),(.125,-.14),(.065,-.17),(.01,-.015)],.073,furniture)
    for z in (-.03,-.06,-.09,-.12):
        m.box((.037,.065-z*.29,z),(.004,.06,.007),'GunRubber')
        m.box((-.037,.065-z*.29,z),(.004,.06,.007),'GunRubber')
    guard=[(0,.015,.06),(0,-.015,-.035),(0,-.10,-.035),(0,-.125,.025),(0,-.10,.075)]
    for a,b in zip(guard,guard[1:]):beam(m,a,b,.007,'GunSteel',10)
    beam(m,(0,-.045,.065),(0,-.065,.005),.006,'GunSteel',10)
    for x in (-.061,.061):m.box((x,-.22,.067),(.012,.165,.045),'GunSteel')
    m.box((0,-.12,.25),(.055,.27,.012),'GunCoating')
    for j in range(9):m.box((0,-.24+j*.028,.261),(.064,.012,.008),'GunSteel')
    if id in (800,803,805):
        for z in (.105,.18):beam(m,(0,.06,z),(0,.37,z-.035),.014,'GunSteel',12)
        profile(m,[(.16,.205),(.35,.19),(.36,.135),(.17,.145)],.093,'GunCoating')
        profile(m,[(.36,.19),(.405,.18),(.42,-.055),(.375,-.07)],.105,'GunRubber')
        if id==803:
            for y in (.20,.31):beam(m,(0,y,.18),(0,y,.235),.009,'GunSteel',12)
            m.box((0,.255,.244),(.095,.19,.023),'GunTan')
    else:
        profile(m,[(.055,.21),(.12,.19),(.24,.195),(.40,.175),(.41,-.06),(.33,-.075),(.18,.035),(.085,.07)],.098,furniture)
        profile(m,[(.40,.175),(.423,.17),(.433,-.065),(.41,-.07)],.105,'GunRubber')
        # Inlaid side panel, smaller than the stock outline.
        for x in (-.0495,.0495):m.box((x,.285,.115),(.002,.15,.028),'GunWoodLight')
    barrel_radius=.029 if shotgun else .021 if sniper else .023
    beam(m,(0,-.32,.18),(0,-end,.18),barrel_radius,'GunSteel',20)
    if sniper:
        profile(m,[(-.66,.12),(-.64,.155),(-.32,.165),(-.31,.07),(-.56,.075)],.105,furniture)
        for y in (-.36,-.60):ring(m,(0,y,.18),.026,.005,'GunCoating',normal=(0,1,0),sides=16)
        beam(m,(-.065,-.02,.20),(-.115,.01,.20),.009,'GunSteel',12)
        beam(m,(-.115,.01,.20),(-.12,.05,.13),.012,'GunSteel',12)
        beam(m,(-.12,.05,.13),(-.12,.07,.13),.019,'GunCoating',12)
        if id==803:
            for x in (-.062,.062):
                beam(m,(x,-.55,.085),(x,-.82,.06),.011,'GunSteel',12)
                beam(m,(x,-.82,.06),(x,-.88,.035),.013,'GunRubber',12)
            beam(m,(0,-.37,.18),(0,-.92,.18),.027,'GunSteel',20)
    elif shotgun:
        beam(m,(0,-.30,.105),(0,-end+.07,.105),.019,'GunSteel',16)
        profile(m,[(-.54,.085),(-.54,.145),(-.34,.155),(-.32,.08)],.115,furniture)
        for y in (-.35,-.38,-.41,-.44,-.47,-.50):
            m.box((-.058,y,.118),(.004,.007,.05),'GunRubber')
            m.box((.058,y,.118),(.004,.007,.05),'GunRubber')
        if id==805:
            for y in (-.19,-.14,-.09):
                beam(m,(.083,y,.13),(.083,y,.215),.014,'GunRubber',16)
                beam(m,(.083,y,.13),(.083,y,.145),.015,'GunBrass',16)
    else:
        profile(m,[(-.66,.115),(-.65,.215),(-.35,.22),(-.34,.09)],.112,furniture)
        for x in (-.0565,.0565):
            for y in (-.40,-.46,-.52,-.58):m.box((x,y,.178),(.003,.035,.024),'GunRubber')
        beam(m,(0,-.33,.215),(0,-.68,.215),.011,'GunSteel',12)
        m.box((0,-.68,.20),(.058,.028,.055),'GunCoating')
    muzzle(m,end,barrel_radius)
    m.box((0,-end+.055,.215),(.014,.018,.05),'GunSteel')
    m.box((0,.015,.251),(.035,.025,.028),'GunSteel')
    ring(m,(0,.335,.01),.013,.004,'GunSteel',normal=(1,0,0),sides=12)

def attachment(m,id):
    if id==810:
        m.box((0,0,-.05),(.12,.15,.10),'EqIron')
        beam(m,(-.12,0,-.20),(.12,0,-.20),.125,'EqIron',12)
        for x in (-.125,.125):ring(m,(x,0,-.20),.09,.012,'EqRuby',normal=(1,0,0),sides=12)
    elif id in (811,812):
        h=.19 if id==811 else .27
        m.box((0,0,-h/2),(.11,.15,h),'EqIron')
        m.box((0,0,-h),(.14,.17,.025),'EqCyan' if id==811 else 'EqAmber')
        for x in (-.057,.057):
            for y in (-.045,.045):m.box((x,y,-h/2),(.012,.014,h*.7),'EqBronze')
    elif id in (813,814):
        m.box((0,0,.025),(.10,.20,.05),'EqIron')
        length=.25 if id==813 else .43
        for y in (-.06,.06):m.box((0,y,.055),(.08,.03,.08),'EqBronze')
        beam(m,(0,length/2,.105),(0,-length/2,.105),.052 if id==813 else .062,'EqIron',12)
        for y in (-length/2,length/2):
            ring(m,(0,y,.105),.055 if id==813 else .067,.012,'EqBronze',normal=(0,1,0))
            beam(m,(0,y,.105),(0,y-.003,.105),.041 if id==813 else .052,'EqCyan',12)
        beam(m,(0,0,.14),(0,0,.19),.027,'EqIron',8)
    elif id in (815,816,817):
        length={815:.16,816:.28,817:.20}[id]
        beam(m,(0,0,0),(0,-length,0),.065,'EqIron',10)
        for y in (-.025,-length+.02):ring(m,(0,y,0),.066,.013,'EqRuby' if id==817 else 'EqBronze',normal=(0,1,0))
        for side in (-1,1):
            for y in (-.055,-.105):m.box((side*.063,y,0),(.014,.026,.04),'Window')
        ring(m,(0,-length,0),.043,.011,'EqBronze',normal=(0,1,0))
    elif id in (818,819):
        m.box((0,0,0),(.04,.20,.14),'EqIron')
        if id==818:
            m.box((-.015,0,.085),(.10,.25,.075),'TimberLight')
            for y in (-.07,.07):m.box((-.012,y,.087),(.105,.023,.08),'EqBronze')
        else:
            for z in (-.045,.045):
                beam(m,(.035,-.13,z),(.035,.13,z),.019,'EqIron',8)
                for y in (-.08,-.04,0,.04,.08):ring(m,(.035,y,z),.025,.006,'EqBronze',normal=(0,1,0),sides=8)
    else:
        m.box((0,0,-.03),(.17,.12,.06),'Timber')
        for x in (-.055,0,.055):
            beam(m,(x,0,0),(x,0,.17 if id==820 else .11),.018 if id==820 else .025,'EqBronze',8)
            beam(m,(x,0,.17 if id==820 else .11),(x,0,.21 if id==820 else .12),.018 if id==820 else .025,'EqIron' if id==820 else 'EqRuby',8,.1 if id==820 else 1)

export=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
report=[]
for row in rows:
    old=bpy.data.objects.get(row['model'])
    if old:
        assert revision and old.name in masters.objects
        bpy.data.objects.remove(old,do_unlink=True)
    m=Mesh()
    if row['kind']=='weapon':rifle(m,row)
    else:attachment(m,row['id'])
    remap={'EqIron':'GunCoating','Timber':'GunWood','TimberLight':'GunWoodLight','EqBronze':'GunSteel',
           'EqRuby':'GunRubber','EqCyan':'GunLens','EqAmber':'GunBrass','Window':'GunRubber'}
    m.material_keys=[remap.get(key,key) for key in m.material_keys]
    if row['id'] in (813,814):m.vertices=[(x*.72,y,z*.75) for x,y,z in m.vertices]
    if row['id'] in (815,816,817):m.vertices=[(x*.58,y*.72,z*.58) for x,y,z in m.vertices]
    if row['id'] in (818,819):m.vertices=[(x*.75,y*.8,z*.75) for x,y,z in m.vertices]
    obj=m.finish(row['model'],masters)
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bevel=obj.modifiers.new('MachinedEdge','BEVEL');bevel.width=.0014;bevel.segments=1;bevel.limit_method='ANGLE';bevel.angle_limit=.5
    bpy.ops.object.modifier_apply(modifier=bevel.name);obj.select_set(False)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm,dist=.000001,edges=list(bm.edges))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bad=sum(not e.is_manifold for e in bm.edges);bm.to_mesh(obj.data);bm.free()
    obj.data.update();obj.data.calc_loop_triangles()
    assert bad==0 and all(p.area>0 for p in obj.data.polygons),row['id']
    bpy.context.view_layer.update()
    result=export(obj.name,str(ART/'Staging'/(obj.name+'.fbx')),overwrite=revision)
    report.append(dict(id=row['id'],triangles=len(obj.data.loop_triangles),dimensions=list(obj.dimensions),export=result))
bpy.data.libraries.write(str(ART/'Source/Firearms.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
overview=bpy.data.scenes.get('FirearmsExpansion202610_Overview')
if overview:
    for display in overview.objects:
        source=bpy.data.objects.get(display.name.split('.')[0])
        if source:display.data=source.data
(ART/'Integration/models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.context.window.scene=previous_scene
print(json.dumps({'models':len(report),'triangles':sum(r['triangles'] for r in report),'source':str(ART/'Source/Firearms.blend')}))
