"""Author skinned wearable fits against the immutable shared humanoid rest rig."""
import bpy, runpy, math, json
from pathlib import Path
from mathutils import Matrix, Vector
ROOT=Path(__file__).resolve().parents[1]
pc=runpy.run_path(str(ROOT/'Scripts/build_modules.py'))
Geometry=pc['Geometry']
SCENE='PawnGearFits_Studio'
Geometry.finish.__globals__['STUDIO']=SCENE
manifest=[]
PAWN='Assets/DynamicAsset/PawnLowPoly/Models/'
EQUIP='Assets/DynamicAsset/EquipmentDemo/Models/'

def setup():
    assert SCENE not in bpy.data.scenes,'Owned gear studio already exists; update explicitly.'
    scene=bpy.data.scenes.new(SCENE);scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    scene.collection.objects.link(bpy.data.objects['CustomizationRig'])
    bpy.context.window.scene=scene
    print('Gear studio ready; shared rest rig retained')

def finish(g,name,path,slot,body='',race='',mask=0,hair=False):
    obj=g.finish(name,slot,race=race)
    for key,value in dict(sourcePath=path,body=body,coverage=mask,hideHair=hair).items():obj[key]=value
    return obj

def headgear(kind,race):
    g=Geometry();w={'Head':1}
    width={'human':.224,'elf':.216,'goblin':.230,'dragon':.220,'orc':.248}[race]
    material='Trim' if kind=='Helmet' else 'Cloth'
    g.rings([((0,.007,1.678),width,.189,w),((0,.014,1.748),width*.91,.179,w),((0,.015,1.795),width*.55,.119,w)],material)
    if kind=='MageHat':
        g.rings([((0,.006,1.712),width*1.43,.263,w),((0,.006,1.738),width*1.43,.263,w)],'Cloth')
        g.rings([((0,.015,1.765),width*.77,.148,w),((.025,.025,1.927),.068,.068,w),((.080,.042,2.037),.015,.018,w)],'Cloth')
    elif kind=='Hood':
        g.box((0,.193,1.575),(width*1.7,.056,.265),'Cloth',w)
    else:
        g.box((0,.184,1.604),(width*1.55,.046,.15),'Leather',w)
        # Front cheek guards leave the muzzle, ears and tusks clear.
        if race!='dragon':
            for sign in [-1,1]:g.box((sign*(width-.008),-.065,1.557),(.031,.075,.156),'Trim',w)
    if race=='dragon':
        # Explicit openings around both horn trajectories. Preserve the central crest and front brow.
        faces=[];materials=[]
        for ids,mat in zip(g.faces,g.materials):
            points=[Vector(g.vertices[i]) for i in ids];center=sum(points,Vector())/len(points)
            horn_zone=center.z>1.69 and center.y>-.035 and abs(center.x)>.055
            if not horn_zone:faces.append(ids);materials.append(mat)
        g.faces,g.materials=faces,materials
    return finish(g,'fit_'+kind.lower()+'_'+race,PAWN+'Pawn_'+kind+'.fbx','head',race=race,hair=True)

def armor(kind,sex,build):
    g=Geometry();female=sex=='female';factor=[.91,1,1.10][build];body='body_'+sex+'_'+str(build)
    pelvis={'pelvis':1};chest={'spine_03':1};mat={'ArmorLeather':'Leather','ArmorPlate':'Trim','ArmorRobe':'Cloth'}[kind]
    g.rings([((0,0,.765),(.24 if female else .235)*factor+.022,.158,pelvis),
             ((0,0,.90),(.21 if female else .225)*factor+.022,.162,pelvis),
             ((0,0,1.02),(.172 if female else .212)*factor+.022,.151,{'spine_01':.65,'spine_02':.35}),
             ((0,-.006,1.16),(.22 if female else .25)*factor+.024,.185 if female else .169,{'spine_02':.4,'spine_03':.6}),
             ((0,0,1.27),(.233 if female else .263)*factor+.025,.167,chest),
             ((0,0,1.322),.105,.102,chest)],mat)
    for sign,suffix in [(1,'l'),(-1,'r')]:
        rad=(.078 if female else .091)*factor+.022;bone='upperarm_'+suffix
        g.rings([((sign*.239,0,1.258),rad,rad,{bone:.65,'spine_03':.35}),((sign*.325,0,1.25),rad,rad,{bone:1}),((sign*.424,0,1.25),rad*.88,rad*.88,{bone:1})],mat,axis='x')
    g.box((0,-.172,.931),(.075,.022,.061),'Trim',pelvis)
    if kind=='ArmorRobe':
        # Split thigh panels bend with each leg; no rigid skirt bridging the knees.
        for sign,suffix in [(1,'l'),(-1,'r')]:
            g.rings([((sign*.17,0,.795),.141,.155,{'thigh_'+suffix:1}),((sign*.17,0,.622),.142,.155,{'thigh_'+suffix:1})],mat)
    return finish(g,'fit_'+kind.lower()+'_'+body,PAWN+'Pawn_'+kind+'.fbx','chest',body=body,mask=1)

def legs():
    g=Geometry()
    for sign,suffix in [(1,'l'),(-1,'r')]:
        t='thigh_'+suffix;c='calf_'+suffix
        g.rings([((sign*.17,0,.81),.116,.126,{t:1}),((sign*.17,0,.615),.100,.103,{t:1}),((sign*.17,0,.56),.093,.093,{t:.5,c:.5}),((sign*.17,0,.515),.094,.097,{c:1}),((sign*.17,0,.305),.080,.081,{c:1})],'Cloth')
    return finish(g,'fit_trousers',EQUIP+'Equip_Trousers.fbx','legs',mask=2)

def boots():
    g=Geometry()
    for sign,suffix in [(1,'l'),(-1,'r')]:
        f='foot_'+suffix;c='calf_'+suffix
        g.rings([((sign*.17,0,.25),.093,.091,{f:.65,c:.35}),((sign*.17,0,.37),.098,.093,{c:1})],'Leather')
        g.box((sign*.17,-.082,.195),(.20,.333,.138),'Leather',{f:1})
        g.box((sign*.17,-.105,.214),(.16,.298,.024),'Trim',{f:1})
    return finish(g,'fit_boots',EQUIP+'Equip_Boots.fbx','feet',mask=4)

def cape(sex,build):
    g=Geometry();factor=[.91,1,1.10][build];body='body_'+sex+'_'+str(build)
    top=.245*factor;bottom=.27*factor
    ids=[]
    for offset in [0,.014]:
        ids.extend(g.vertex(p,w) for p,w in [((-top,.207+offset,1.27),{'spine_03':1}),((top,.207+offset,1.27),{'spine_03':1}),((bottom,.237+offset,.72),{'pelvis':1}),((-bottom,.237+offset,.72),{'pelvis':1})])
    for face in [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]:g.face(tuple(ids[i] for i in face),'Cloth')
    return finish(g,'fit_cape_'+body,PAWN+'Pawn_Cape.fbx','back',body=body)

def quiver():
    g=Geometry();w={'spine_03':1}
    g.box((-.10,.243,1.07),(.13,.12,.48),'Leather',w,tilt=-.20)
    for x in [-.14,-.10,-.06]:g.spike((x,.24,1.30),(x+.015,.24,1.46),.015,'Trim',weights=w)
    return finish(g,'fit_quiver',PAWN+'Pawn_Quiver.fbx','back')

def save():
    scene=bpy.data.scenes[SCENE];rows=[]
    for obj in scene.objects:
        if obj.type!='MESH' or not obj.get('sourcePath'):continue
        rows.append(dict(id=obj.name,sourcePath=obj['sourcePath'],slot=obj['slot'],body=obj['body'],race=obj['race'],coverage=obj['coverage'],hideHair=obj['hideHair']))
    (ROOT/'Integration/gear-manifest.json').write_text(json.dumps({'version':1,'fits':rows},ensure_ascii=False,indent=2),encoding='utf-8')
    bpy.data.libraries.write(str(ROOT/'Source/PawnGearFits.blend'),{scene},fake_user=True)
    print(json.dumps({'fits':len(rows),'source':str(ROOT/'Source/PawnGearFits.blend')}))

def export():
    scene=bpy.data.scenes[SCENE];bpy.context.window.scene=scene
    selected=list(bpy.context.selected_objects);active=bpy.context.view_layer.objects.active;copies=[];turn=Matrix.Rotation(math.pi,4,'Z')
    source=bpy.data.objects['CustomizationRig'];rig=source.copy();rig.data=source.data.copy();scene.collection.objects.link(rig);copies.append(rig)
    try:
        rig.data.transform(turn)
        for obj in list(scene.objects):
            if obj.type!='MESH' or not obj.get('sourcePath'):continue
            copy=obj.copy();copy.data=obj.data.copy();copy.name=obj.name+'_export';scene.collection.objects.link(copy);copies.append(copy)
            copy.data.transform(turn);copy.parent=rig
            for modifier in copy.modifiers:
                if modifier.type=='ARMATURE':modifier.object=rig
        for obj in selected:obj.select_set(False)
        for obj in copies:obj.hide_set(False);obj.hide_render=False;obj.select_set(True)
        bpy.context.view_layer.objects.active=rig;bpy.context.view_layer.update()
        result=bpy.ops.export_scene.fbx(filepath=str(ROOT/'Staging/PawnGearFits.fbx'),use_selection=True,object_types={'ARMATURE','MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=False,use_mesh_modifiers=True,mesh_smooth_type='FACE',armature_nodetype='NULL',primary_bone_axis='Y',secondary_bone_axis='X')
        assert result=={'FINISHED'};print('Exported PawnGearFits.fbx')
    finally:
        for obj in reversed(copies):
            data=obj.data;kind=obj.type;bpy.data.objects.remove(obj,do_unlink=True)
            if kind=='MESH':bpy.data.meshes.remove(data)
            else:bpy.data.armatures.remove(data)
        for obj in selected:obj.select_set(True)
        bpy.context.view_layer.objects.active=active
