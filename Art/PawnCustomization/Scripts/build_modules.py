"""Owned modular character studio. Invoke individual steps through Blender MCP.

Coordinates and rest bones come from PawnHumanoid; never alter that source rig.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[1]
STUDIO = 'PawnCustomization_Studio'
ROLES = ['Skin', 'Cloth', 'Leather', 'Hair', 'EyeWhite', 'Iris', 'Horn', 'Mouth', 'Trim']
COLORS = [(0.63, .40, .26, 1), (.18, .31, .32, 1), (.16, .105, .065, 1),
          (.12, .075, .045, 1), (.89, .84, .66, 1), (.06, .10, .085, 1),
          (.75, .65, .43, 1), (.23, .11, .095, 1), (.60, .44, .21, 1)]


def setup():
    assert STUDIO not in bpy.data.scenes, 'Studio already exists; update owned meshes explicitly.'
    for folder in ['Source', 'Staging', 'Integration', 'Previews']:
        (ROOT / folder).mkdir(parents=True, exist_ok=True)
    original = bpy.data.objects['Pawn_Humanoid']
    scene = bpy.data.scenes.new(STUDIO)
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    rig = original.copy()
    rig.data = original.data.copy()
    rig.name = 'CustomizationRig'
    rig.animation_data_clear()
    scene.collection.objects.link(rig)
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    for name, color in zip(ROLES, COLORS):
        mat = bpy.data.materials.new('PC_' + name)
        mat.diffuse_color = color
        shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        shader.inputs['Base Color'].default_value = color
        shader.inputs['Roughness'].default_value = .85
    bpy.context.window.scene = scene
    print(json.dumps({'studio': STUDIO, 'bones': len(rig.data.bones)}))


class Geometry:
    def __init__(self):
        self.vertices, self.faces, self.materials, self.weights = [], [], [], []

    def vertex(self, pos, weights):
        self.vertices.append(tuple(pos))
        self.weights.append(weights)
        return len(self.vertices) - 1

    def face(self, ids, material):
        self.faces.append(ids)
        self.materials.append(ROLES.index(material))

    def rings(self, rows, material, sides=8, axis='z'):
        # Rows: center, two radial dimensions, normalized bone-weight dictionary.
        rings = []
        for center, a, b, weights in rows:
            ring = []
            for i in range(sides):
                angle = math.tau * i / sides + math.pi / sides
                offset = (a * math.cos(angle), b * math.sin(angle), 0) if axis == 'z' else (0, a * math.cos(angle), b * math.sin(angle))
                ring.append(self.vertex(Vector(center) + Vector(offset), weights))
            rings.append(ring)
        self.face(tuple(reversed(rings[0])), material)
        for a, b in zip(rings, rings[1:]):
            for i in range(sides):
                j = (i + 1) % sides
                self.face((a[i], a[j], b[j], b[i]), material)
        self.face(tuple(rings[-1]), material)

    def box(self, center, size, material, weights, tilt=0):
        c = Vector(center)
        ids = []
        rot = Matrix.Rotation(tilt, 3, 'Y')
        for x, y, z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]:
            ids.append(self.vertex(c + rot @ Vector((x*size[0]/2,y*size[1]/2,z*size[2]/2)), weights))
        for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:
            self.face(tuple(ids[i] for i in f), material)

    def spike(self, base, tip, radius, material='Skin', weights=None):
        weights = weights or {'Head': 1}
        direction = Vector(tip) - Vector(base)
        q = Vector((0,0,1)).rotation_difference(direction)
        ring = [self.vertex(Vector(base) + q @ Vector((radius*math.cos(i*math.tau/5),radius*math.sin(i*math.tau/5),0)),weights) for i in range(5)]
        end = self.vertex(tip, weights)
        self.face(tuple(reversed(ring)), material)
        for i in range(5): self.face((ring[i],ring[(i+1)%5],end),material)

    def finish(self, name, slot, race='', sex='', label=''):
        scene = bpy.data.scenes[STUDIO]
        assert name not in bpy.data.objects, name
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        for role in ROLES: mesh.materials.append(bpy.data.materials['PC_' + role])
        for face, material in zip(mesh.polygons,self.materials): face.material_index=material
        bm=bmesh.new();bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        # Explicit UVs also make FBX material import consistent. Pure-color art uses no texture.
        uv=mesh.uv_layers.new(name='UVMap')
        for face in mesh.polygons:
            for i in face.loop_indices:
                p=mesh.vertices[mesh.loops[i].vertex_index].co
                uv.data[i].uv=(p.x+.5,p.z/2)
        obj=bpy.data.objects.new(name,mesh);scene.collection.objects.link(obj)
        rig=bpy.data.objects['CustomizationRig'];obj.parent=rig
        for bone in rig.data.bones: obj.vertex_groups.new(name=bone.name)
        for i, weights in enumerate(self.weights):
            assert abs(sum(weights.values())-1)<1e-5
            for bone, weight in weights.items(): obj.vertex_groups[bone].add([i],weight,'REPLACE')
        obj.modifiers.new('Shared humanoid','ARMATURE').object=rig
        for key,value in dict(slot=slot,race=race,sex=sex,label=label,owned_customization=True).items(): obj[key]=value
        return obj


def body(sex, build):
    g=Geometry();female=sex=='female';factor=[.91,1,1.10][build]
    pelvis={'pelvis':1};chest={'spine_03':1}
    g.rings([((0,0,.77),(.24 if female else .235)*factor,.132,pelvis),
             ((0,0,.90),(.21 if female else .225)*factor,.14,pelvis),
             ((0,0,1.02),(.172 if female else .212)*factor,.125,{'spine_01':.65,'spine_02':.35}),
             ((0,-.006,1.16),(.22 if female else .25)*factor,.158 if female else .14,{'spine_02':.4,'spine_03':.6}),
             ((0,0,1.27),(.233 if female else .263)*factor,.14,chest),
             ((0,0,1.32),.087,.08,chest)],'Cloth')
    g.rings([((0,0,1.30),.081,.073,chest),((0,0,1.36),.081,.073,{'Head':1}),((0,0,1.42),.079,.072,{'Head':1})],'Skin')
    g.rings([((0,0,.90),(.218 if female else .232)*factor,.147,pelvis),((0,0,.947),(.208 if female else .226)*factor,.145,pelvis)],'Leather')
    g.box((0,-.149,.926),(.067,.014,.058),'Trim',pelvis)
    # Continuous elbow and knee topology with blended weights; both sides share the exact base rest rig.
    for sign,suffix in [(1,'l'),(-1,'r')]:
        u='upperarm_'+suffix;l='lowerarm_'+suffix;h='hand_'+suffix
        radius=(.078 if female else .091)*factor
        g.rings([((sign*.235,0,1.25),radius,radius,{u:.65,'spine_03':.35}),
                 ((sign*.32,0,1.25),radius,radius,{u:1}),((sign*.43,0,1.25),radius*.84,radius*.84,{u:1})],'Cloth',axis='x')
        g.rings([((sign*.419,0,1.25),radius*.81,radius*.81,{u:1}),((sign*.495,0,1.25),radius*.74,radius*.74,{u:1}),
                 ((sign*.532,0,1.25),radius*.70,radius*.70,{u:.5,l:.5}),((sign*.57,0,1.25),radius*.76,radius*.76,{l:1}),
                 ((sign*.735,0,1.25),.044,.043,{l:1}),((sign*.795,0,1.25),.043,.042,{h:1})],'Skin',axis='x')
        g.box((sign*.848,-.007,1.25),(.15,.087,.10),'Skin',{h:1})
        g.box((sign*.807,-.058,1.235),(.065,.04,.056),'Skin',{h:1})
        t='thigh_'+suffix;c='calf_'+suffix;f='foot_'+suffix
        g.rings([((sign*.17,0,.80),.103,.113,{t:1}),((sign*.17,0,.615),.087,.090,{t:1}),
                 ((sign*.17,0,.56),.080,.080,{t:.5,c:.5}),((sign*.17,0,.515),.081,.084,{c:1}),
                 ((sign*.17,0,.30),.068,.069,{c:1})],'Cloth')
        g.rings([((sign*.17,0,.25),.08,.078,{f:.65,c:.35}),((sign*.17,0,.37),.085,.08,{c:1})],'Leather')
        g.box((sign*.17,-.082,.195),(.174,.31,.115),'Leather',{f:1})
    return g.finish('body_'+sex+'_'+str(build),'body',sex=sex,label=['纤细','匀称','健壮'][build])


def head(race,sex,variant):
    g=Geometry();w={'Head':1};female=sex=='female'
    width={'human':.192,'elf':.175,'goblin':.195,'dragon':.182,'orc':.212}[race]
    jaw=width*(.74 if female else .90)*(1.06 if variant else .94)
    g.rings([((0,0,1.365),.079,.072,w),((0,-.015,1.425),jaw,.123,w),
             ((0,0,1.53),width,.154,w),((0,0,1.635),width,.165,w),
             ((0,.008,1.724),.156,.139,w),((0,.012,1.765),.092,.09,w)],'Skin')
    for s in [-1,1]:
        if race in ['elf','goblin']:
            g.spike((s*.16,0,1.57),(s*(.33 if race=='goblin' else .295),.022,1.66 if race=='elf' else 1.61),.078)
            g.spike((s*.191,-.026,1.584),(s*(.298 if race=='goblin' else .272),-.010,1.63),.028,'Mouth')
        elif race!='dragon':
            g.box((s*.184,0,1.57),(.048,.067,.09),'Skin',w)
        eyex=s*(.080 if race!='orc' else .092)
        g.box((eyex,-.151,1.591),(.060,.024,.031 if female else .033),'EyeWhite',w,tilt=s*(.08 if race in ['elf','dragon'] else 0))
        g.box((eyex,-.165,1.591),(.024,.009,.028),'Iris',w)
        g.box((eyex,-.151,1.622),(.081,.035,.016 if female else .025),'Hair' if race in ['human','elf','goblin'] else 'Skin',w,tilt=-s*.1)
        if race=='orc':g.spike((s*.087,-.148,1.455),(s*.087,-.198,1.531),.022,'Horn')
        if race=='dragon':
            g.spike((s*.127,.035,1.701),(s*.185,.102,1.836 if variant else 1.806),.042,'Horn')
            g.spike((s*.168,.065,1.575),(s*.251,.115,1.64),.036,'Skin')
    if race=='dragon':
        g.rings([((0,-.073,1.455),.115,.145,w),((0,-.099,1.495),.130,.172,w),((0,-.072,1.54),.106,.161,w)],'Skin')
        for s in [-1,1]:g.box((s*.058,-.250,1.525),(.021,.009,.013),'Mouth',w)
        g.box((0,-.252,1.484),(.172,.012,.011),'Mouth',w)
    else:
        g.spike((0,-.125,1.57),(0,-(.244 if race=='goblin' else .209 if race=='orc' else .196),1.532),.030 if female else .038)
        g.box((0,-.139,1.465),(.095 if race!='orc' else .147,.019,.012 if female else .013),'Mouth',w)
    if variant:
        # An actual brow/cheek and jaw variant, not just a renamed or recolored mesh.
        for s in [-1,1]:g.box((s*.126,-.112,1.53),(.065,.043,.036),'Skin',w,tilt=s*.2)
    return g.finish('head_'+race+'_'+sex+'_'+str(variant),'head',race,sex,['柔和','棱角'][variant])


def hair(style):
    g=Geometry();w={'Head':1}
    if style==0:
        # Narrow crest avoids dragon horns; valid for every head.
        for y,z in [(-.095,1.757),(-.02,1.786),(.06,1.773),(.13,1.713)]:g.box((0,y,z),(.084,.09,.066),'Hair',w)
    else:
        g.rings([((0,.015,1.705),.184,.162,w),((0,.01,1.762),.156,.146,w),((0,.01,1.800),.083,.085,w)],'Hair')
        if style==1:
            for s in [-1,1]:g.box((s*.164,.051,1.674),(.065,.152,.16),'Hair',w)
        else:
            g.box((0,.141,1.599),(.276,.095,.31),'Hair',w)
            for s in [-1,1]:g.box((s*.161,.05,1.594),(.058,.126,.255),'Hair',w)
    return g.finish('hair_'+str(style),'hair',race='all' if style==0 else 'human,elf,goblin,orc',label=['短脊','短发','齐肩'][style])


def save_manifest():
    scene=bpy.data.scenes[STUDIO]
    modules=[]
    for o in scene.objects:
        if not o.get('owned_customization'):continue
        modules.append({'id':o.name,'slot':o['slot'],'race':o['race'],'sex':o['sex'],'label':o['label']})
        assert all(abs(sum(x.weight for x in v.groups)-1)<1e-5 for v in o.data.vertices)
    manifest={'version':1,'modules':modules,'roles':ROLES,'colors':[list(c) for c in COLORS]}
    (ROOT/'Integration/modules.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    bpy.data.libraries.write(str(ROOT/'Source/PawnCustomization.blend'),{scene},fake_user=True)
    print(json.dumps({'modules':len(modules),'vertices':sum(len(o.data.vertices) for o in scene.objects if o.type=='MESH'),'source':str(ROOT/'Source/PawnCustomization.blend')}))


def export():
    scene=bpy.data.scenes[STUDIO];bpy.context.window.scene=scene
    assert bpy.context.mode=='OBJECT'
    source=bpy.data.objects['CustomizationRig'];selected=list(bpy.context.selected_objects);active=bpy.context.view_layer.objects.active
    copies=[];turn=Matrix.Rotation(math.pi,4,'Z')
    rig=source.copy();rig.data=source.data.copy();rig.name='CustomizationExportRig';scene.collection.objects.link(rig);copies.append(rig)
    try:
        rig.data.transform(turn)
        for o in list(scene.objects):
            if not o.get('owned_customization'):continue
            copy=o.copy();copy.data=o.data.copy();scene.collection.objects.link(copy);copy.name=o.name+'_export';copies.append(copy)
            copy.data.transform(turn);copy.parent=rig
            for mod in copy.modifiers:
                if mod.type=='ARMATURE':mod.object=rig
        for o in selected:o.select_set(False)
        for o in copies:o.hide_set(False);o.select_set(True)
        bpy.context.view_layer.objects.active=rig;bpy.context.view_layer.update()
        result=bpy.ops.export_scene.fbx(filepath=str(ROOT/'Staging/PawnCustomization.fbx'),use_selection=True,
            object_types={'ARMATURE','MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',
            axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=False,use_mesh_modifiers=True,
            mesh_smooth_type='FACE',armature_nodetype='NULL',primary_bone_axis='Y',secondary_bone_axis='X')
        assert result=={'FINISHED'}
        print(json.dumps({'fbx':str(ROOT/'Staging/PawnCustomization.fbx'),'bytes':(ROOT/'Staging/PawnCustomization.fbx').stat().st_size}))
    finally:
        for o in reversed(copies):
            data=o.data;kind=o.type;bpy.data.objects.remove(o,do_unlink=True)
            if kind=='MESH':bpy.data.meshes.remove(data)
            else:bpy.data.armatures.remove(data)
        for o in selected:o.select_set(True)
        bpy.context.view_layer.objects.active=active
