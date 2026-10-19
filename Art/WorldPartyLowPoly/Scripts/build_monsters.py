"""Two full-size combat bodies and their independent single-cell world miniatures."""
from pathlib import Path
import json
import math
import runpy
import bpy
from mathutils import Vector

ROOT=Path('D:/Program/Unity/Project Y')
OUT=ROOT/'Art/WorldPartyLowPoly'
def build():
    assert 'Monster_Direwolf' not in bpy.data.objects
    original=bpy.context.window.scene
    scene=bpy.data.scenes.new('WorldParty_Monsters');bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    mats={}
    palette={'Fur':'898379','FurDark':'66594a','Stone':'9e9685','StoneDark':'66594a','Moss':'557c43','Eye':'c7a264','Dark':'383b37','Bone':'ded0ad'}
    for name,color in palette.items():
        mat=bpy.data.materials.new('M_WorldMonster_'+name);mat.use_nodes=True
        rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
        rgba=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
        mat.diffuse_color=rgba;node=mat.node_tree.nodes.get('Principled BSDF');node.inputs['Base Color'].default_value=rgba;node.inputs['Roughness'].default_value=.95;mats[name]=mat
    parts=[]
    def material(obj,name):
        obj.data.materials.append(mats[name]);parts.append(obj);return obj
    def ball(pos,size,name,sub=1):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=pos)
        obj=bpy.context.object;obj.scale=size;return material(obj,name)
    def rod(a,b,radius,name,top=None):
        a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=radius,radius2=radius if top is None else top,depth=(b-a).length,location=(a+b)/2)
        obj=bpy.context.object;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return material(obj,name)
    def join(name):
        bpy.ops.object.select_all(action='DESELECT')
        for obj in parts:obj.select_set(True)
        bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();obj=bpy.context.object
        scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
        obj.location=(0,0,0);obj.name=name;obj.data.name=name+'_Mesh';parts.clear();return obj
    try:
        # Long body follows the two-cell q axis; feet touch the ground at z=0.
        ball((-.1,0,.92),(1.03,.43,.53),'Fur',2)
        ball((-.76,0,1.18),(.55,.49,.62),'FurDark')
        ball((-1.08,-.015,1.5),(.46,.33,.43),'Fur')
        ball((-1.4,-.015,1.36),(.38,.23,.2),'FurDark')
        ball((-1.64,-.015,1.39),(.1,.17,.09),'Dark')
        for y in [-.21,.21]:
            rod((-1.02,y,1.71),(-.98,y*1.5,2.08),.15,'FurDark',top=0)
            ball((-1.26,y*1.38,1.56),(.065,.035,.045),'Eye')
            rod((-1.4,y*.72,1.3),(-1.4,y*.72,1.19),.045,'Bone',top=0)
        for x in [-.68,.63]:
            for y in [-.28,.28]:
                rod((x,y,.95),(x+.09,y,.44),.16,'FurDark',top=.105)
                rod((x+.09,y,.44),(x-.08,y,.13),.1,'Fur')
                ball((x-.14,y,.11),(.23,.15,.12),'FurDark')
        rod((.75,0,1.05),(1.3,0,.87),.2,'FurDark',top=.13)
        rod((1.3,0,.87),(1.55,.08,1.24),.13,'FurDark',top=.02)
        wolf=join('Monster_Direwolf');wolf.hide_set(True)
        # A broad low-poly boulder creature fills four cells as one connected silhouette.
        ball((0,0,1.8),(1.0,.72,1.15),'Stone',2)
        ball((0,-.07,2.89),(.55,.49,.63),'StoneDark')
        ball((0,-.19,2.96),(.49,.4,.5),'Stone')
        for x in [-.23,.23]:ball((x,-.55,3.03),(.12,.045,.065),'Eye')
        for side in [-1,1]:
            ball((side*.91,.03,2.33),(.53,.53,.58),'StoneDark')
            rod((side*.98,.02,2.23),(side*1.21,-.08,1.43),.35,'Stone',top=.31)
            ball((side*1.22,-.11,1.22),(.41,.43,.43),'Stone')
            ball((side*.49,.05,.72),(.46,.48,.7),'StoneDark')
            ball((side*.49,-.2,.26),(.5,.61,.28),'Stone')
            ball((side*.99,.03,2.67),(.28,.39,.12),'Moss')
        for x,y,z in [(-.5,.17,2.71),(.49,.2,2.71),(.04,.46,2.5)]:
            rod((x,y,z),(x,y,z+.48),.24,'StoneDark',top=.045)
        beast=join('Monster_Stonebeast');beast.hide_set(True)
        for body,name,scale in [(wolf,'WorldParty_Direwolves',.34),(beast,'WorldParty_Stonebeast',.45)]:
            obj=body.copy();obj.data=body.data.copy();obj.name=name;obj.data.name=name+'_Mesh';scene.collection.objects.link(obj);obj.hide_set(False)
            for v in obj.data.vertices:v.co*=scale;v.co.z+=.15
            bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.69,depth=.12,location=(0,0,.06));base=bpy.context.object;base.data.materials.append(bpy.data.materials['M_WorldParty_Base'])
            parts.extend([obj,base]);join(name)
        for obj in [wolf,beast]:obj.hide_set(False)
        source=OUT/'Source/WorldMonsters.blend';assert not source.exists();bpy.data.libraries.write(str(source),{scene},fake_user=True)
        exporter=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx'];rows=[]
        for name in ['Monster_Direwolf','Monster_Stonebeast','WorldParty_Direwolves','WorldParty_Stonebeast']:
            obj=bpy.data.objects[name];obj.data.calc_loop_triangles()
            rows.append(dict(name=name,dimensions=list(obj.dimensions),triangles=len(obj.data.loop_triangles),export=exporter(name,str(OUT/'Staging'/(name+'.fbx')))))
        (OUT/'Integration/monsters.json').write_text(json.dumps({'models':rows,'palette':palette},indent=2),encoding='utf-8');print(json.dumps(rows))
    finally:bpy.context.window.scene=original
if __name__=='__main__':build()
