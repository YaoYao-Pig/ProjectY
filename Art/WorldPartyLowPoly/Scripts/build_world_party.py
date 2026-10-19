"""Create isolated, editable world-map party miniatures; never clear an existing scene."""
from pathlib import Path
import json
import math
import runpy
import bpy
from mathutils import Vector

ROOT = Path('D:/Program/Unity/Project Y')
OUT = ROOT / 'Art/WorldPartyLowPoly'
NAMES = ['WorldParty_Flag', 'WorldParty_Caravan', 'WorldParty_Bandits', 'WorldParty_Goblins', 'WorldParty_Orcs']
PALETTE = {'Base': '66594a', 'Rim': 'bca27b', 'Wood': '66594a', 'Canvas': 'ded0ad',
           'Teal': '397a79', 'Gold': 'c7a264', 'Iron': '898379', 'Dark': '383b37',
           'Skin': 'c9a785', 'Leather': '875241', 'Goblin': '759754', 'Orc': '567747',
           'Burgundy': '834e4d', 'Bone': 'ded0ad'}

def linear(value):
    value = value / 255
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4

def build():
    assert not any(name in bpy.data.objects for name in NAMES), 'World party assets already exist; edit them instead.'
    for sub in ['Source', 'Staging', 'Previews', 'Integration']:
        (OUT / sub).mkdir(parents=True, exist_ok=True)
    source_path = OUT / 'Source/WorldParties.blend'
    assert not source_path.exists(), 'Refusing to overwrite existing source.'
    original = bpy.context.window.scene
    scene = bpy.data.scenes.new('WorldParty_Source')
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    bpy.context.window.scene = scene
    materials = {}
    for key, color in PALETTE.items():
        mat = bpy.data.materials.new('M_WorldParty_' + key)
        mat.use_nodes = True
        rgba = tuple(linear(int(color[i:i+2], 16)) for i in (0, 2, 4)) + (1,)
        mat.diffuse_color = rgba
        shader = mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = rgba
        shader.inputs['Roughness'].default_value = .9
        materials[key] = mat
    parts = []

    def finish(obj, color):
        obj.data.materials.append(materials[color])
        for face in obj.data.polygons:
            face.use_smooth = False
        parts.append(obj)
        return obj

    def cube(position, size, color):
        bpy.ops.mesh.primitive_cube_add(size=1, location=position)
        obj = bpy.context.object
        obj.scale = size
        return finish(obj, color)

    def cone(position, radius, top, height, color, vertices=8):
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=top, depth=height, location=position)
        return finish(bpy.context.object, color)

    def ball(position, size, color):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=position)
        obj = bpy.context.object
        obj.scale = size
        return finish(obj, color)

    def rod(start, end, radius, color, top=None):
        a, b = Vector(start), Vector(end)
        obj = cone((a+b)/2, radius, radius if top is None else top, (b-a).length, color)
        obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
        return obj

    def mesh(name, vertices, faces, color):
        data = bpy.data.meshes.new(name)
        data.from_pydata(vertices, [], faces)
        data.update()
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        return finish(obj, color)

    def base():
        cone((0, 0, .055), .69, .69, .11, 'Base', 12)
        cone((0, 0, .125), .67, .62, .05, 'Rim', 12)

    def humanoid(color, big=False):
        shoulder = .28 if big else .22
        for x in [-.14, .14]:
            cube((x, -.045, .23), (.19, .3, .16), 'Dark')
            rod((x, 0, .27), (x*.85, .02, .63), .095, 'Leather')
        cone((0, 0, .77), .22, shoulder, .43, color)
        cube((0, 0, .61), (.45, .33, .085), 'Leather')
        cube((0, -.185, .62), (.1, .04, .09), 'Gold')
        ball((0, -.025, 1.13), (.22 if big else .18, .18, .23), color)
        return shoulder

    manifest = []
    try:
        for name in NAMES:
            parts.clear()
            base()
            if name.endswith('Flag'):
                rod((-.25, 0, .15), (-.25, 0, 1.91), .045, 'Wood')
                cone((-.25, 0, 1.98), .085, 0, .18, 'Gold')
                # Thick folded cloth remains visible from either side of the camera.
                vertices = []
                for side in [-.018, .018]:
                    for x, y, top, bottom in [(-.24, 0, 1.82, 1.12), (.08, -.08, 1.79, 1.09), (.44, .055, 1.84, 1.14), (.64, 0, 1.76, 1.23)]:
                        vertices.extend([(x, y+side, top), (x, y+side, bottom)])
                faces = []
                for i in range(3):
                    k = i*2
                    faces.extend([(k,k+2,k+3,k+1), (k+9,k+11,k+10,k+8), (k,k+8,k+10,k+2), (k+1,k+3,k+11,k+9)])
                faces.extend([(0,1,9,8), (6,14,15,7)])
                mesh('FoldedBanner', vertices, faces, 'Teal')
                cube((.06, -.106, 1.46), (.18, .018, .18), 'Gold').rotation_euler.y = math.pi/4
                ball((-.22, .02, .23), (.2, .18, .12), 'Iron')
            elif name.endswith('Caravan'):
                # Loaded wagon and draught animal are one miniature within a single cell.
                cube((0, .19, .43), (.69, .76, .12), 'Wood')
                for x in [-.39, .39]:
                    for y in [-.04, .45]:
                        obj = cone((x,y,.32), .18, .18, .075, 'Wood', 10)
                        obj.rotation_euler.y = math.pi/2
                        rod((x-.045,y,.32),(x+.045,y,.32),.055,'Iron')
                cube((0,.19,.64),(.66,.73,.29),'Leather')
                for x in [-.28,.28]:
                    cube((x,.19,.75),(.06,.76,.23),'Wood')
                # Canvas roof with a deliberately coarse arched cross-section.
                cross=[(-.36,.79),(-.3,1.04),(-.14,1.17),(.14,1.17),(.3,1.04),(.36,.79)]
                verts=[(x,y,z) for y in [-.2,.59] for x,z in cross]
                faces=[tuple(range(5,-1,-1)),tuple(range(6,12))]+[(i,i+1,i+7,i+6) for i in range(5)]+[(5,0,6,11)]
                mesh('CanvasRoof',verts,faces,'Canvas')
                cube((.23,-.24,.63),(.19,.18,.19),'Wood')
                rod((-.23,-.12,.43),(-.23,-.66,.39),.025,'Wood')
                rod((.23,-.12,.43),(.23,-.66,.39),.025,'Wood')
                ball((0,-.48,.44),(.14,.27,.17),'Iron')
                for x in [-.095,.095]:
                    for y in [-.36,-.6]: rod((x,y,.18),(x,y,.44),.032,'Dark')
                rod((0,-.62,.45),(0,-.69,.65),.085,'Iron')
                ball((0,-.73,.66),(.095,.13,.1),'Iron')
                for x in [-.055,.055]: rod((x,-.68,.71),(x,-.66,.86),.027,'Dark',top=.01)
            else:
                kind = name.rsplit('_',1)[1]
                color = {'Bandits':'Leather','Goblins':'Goblin','Orcs':'Orc'}[kind]
                shoulder = humanoid(color, kind=='Orcs')
                if kind=='Bandits':
                    ball((0,-.04,1.14),(.245,.22,.265),'Burgundy')
                    cube((0,-.23,1.14),(.26,.025,.19),'Skin')
                    cube((0,-.25,1.06),(.28,.025,.09),'Dark')
                    rod((-.2,0,.91),(-.37,-.08,.67),.085,'Leather')
                    rod((.2,0,.91),(.39,-.1,1.01),.08,'Leather')
                    rod((.39,-.1,.88),(.39,-.1,1.43),.04,'Iron',top=.005)
                    cube((.39,-.1,1.02),(.23,.07,.05),'Gold')
                    rod((-.37,-.08,.67),(-.37,-.08,.96),.035,'Iron',top=0)
                else:
                    for direction in [-1,1]:
                        rod((direction*.14,0,1.17),(direction*.38,.005,1.29),.09,color,top=0)
                        cube((direction*.078,-.185,1.18),(.075,.025,.035),'Dark')
                    ball((0,-.18,1.06),(.14,.09,.08),color)
                    cube((0,-.248,1.04),(.14,.025,.025),'Dark')
                    if kind=='Goblins':
                        cone((0,.02,1.4),.2,0,.32,'Leather')
                        rod((-.21,0,.92),(-.36,-.07,.76),.065,color)
                        rod((.21,0,.92),(.37,-.07,.82),.065,color)
                        rod((.38,-.09,.3),(.38,-.09,1.5),.025,'Wood')
                        cone((.38,-.09,1.54),.07,0,.2,'Iron')
                        obj=cone((-.37,-.1,.74),.2,.2,.055,'Wood');obj.rotation_euler.x=math.pi/2
                    else:
                        for x in [-.115,.115]: rod((x,-.24,1.02),(x,-.25,1.14),.035,'Bone',top=0)
                        ball((-.29,0,.96),(.18,.19,.15),'Iron')
                        rod((-.26,0,.87),(-.39,-.08,.62),.11,color)
                        rod((.26,0,.9),(.41,-.08,1.02),.11,color)
                        rod((.42,-.08,.42),(.42,-.08,1.54),.035,'Wood')
                        mesh('AxeBlade',[(.43,-.13,1.48),(.67,-.13,1.58),(.67,-.13,1.22),(.43,-.13,1.3),(.43,-.04,1.48),(.67,-.04,1.58),(.67,-.04,1.22),(.43,-.04,1.3)],[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'Iron')
            bpy.ops.object.select_all(action='DESELECT')
            for obj in parts: obj.select_set(True)
            bpy.context.view_layer.objects.active=parts[0]
            bpy.ops.object.join()
            obj=bpy.context.object
            scene.cursor.location=(0,0,0)
            bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
            bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
            obj.name=name;obj.data.name=name+'_Mesh'
            obj['front_axis_blender']='-Y'
            obj.data.calc_loop_triangles()
            manifest.append({'name':name,'dimensions':list(obj.dimensions),'triangles':len(obj.data.loop_triangles),'materials':[m.name for m in obj.data.materials]})
            obj.hide_set(True)
        for name in NAMES: bpy.data.objects[name].hide_set(False)
        bpy.data.libraries.write(str(source_path),{scene},fake_user=True)
        exporter=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
        for row in manifest:
            row['export']=exporter(row['name'],str(OUT/'Staging'/(row['name']+'.fbx')))
        (OUT/'Integration/models.json').write_text(json.dumps({'models':manifest,'palette':PALETTE},indent=2),encoding='utf-8')
        print(json.dumps({'source':str(source_path),'models':manifest}))
    finally:
        bpy.context.window.scene=original

if __name__=='__main__': build()
