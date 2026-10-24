"""Build isolated editable faction strongholds through Blender MCP.

Source + staging only; never clear the user's scene or overwrite a source.
Blender -Y is the authored front. The project exporter converts to Unity +Z.
"""
from pathlib import Path
import json
import math
import runpy
import bpy
from mathutils import Vector

ROOT = Path('D:/Program/Unity/Project Y')
OUT = ROOT / 'Art/FactionLowPoly'
NAMES = ['Faction_OrcStockade', 'Faction_GoblinCamp', 'Faction_ElfGrove']
PALETTE = {'Soil': '948365', 'Grass': '759754', 'Forest': '567747',
           'Wood': '66594a', 'CutWood': '948365', 'Hide': '875241',
           'Canvas': 'c9b994', 'Dark': '383b37', 'Bone': 'ded0ad',
           'Leaf': '557c43', 'LeafLight': '759754', 'Teal': '397a79',
           'Iron': '898379', 'Gold': 'c7a264'}

def linear(v):
    v /= 255
    return v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4

def build():
    assert not any(n in bpy.data.objects for n in NAMES), 'Edit existing faction sources instead.'
    path = OUT / 'Source/FactionStrongholds.blend'
    assert not path.exists(), 'Refusing to overwrite source.'
    for sub in ['Source', 'Staging', 'Previews', 'Integration']:
        (OUT/sub).mkdir(parents=True, exist_ok=True)
    original = bpy.context.window.scene
    scene = bpy.data.scenes.new('FactionStrongholds_Source')
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    bpy.context.window.scene = scene
    materials = {}
    for key, rgb in PALETTE.items():
        mat = bpy.data.materials.new('M_Faction_'+key)
        mat.use_nodes = True
        color = tuple(linear(int(rgb[i:i+2],16)) for i in (0,2,4))+(1,)
        mat.diffuse_color = color
        node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        node.inputs['Base Color'].default_value = color
        node.inputs['Roughness'].default_value = .92
        materials[key] = mat
    parts = []
    def finish(obj, label, color):
        obj.name = label
        obj.data.materials.append(materials[color])
        for p in obj.data.polygons: p.use_smooth = False
        parts.append(obj)
        return obj
    def cube(label, p, size, color):
        bpy.ops.mesh.primitive_cube_add(size=1, location=p)
        obj = bpy.context.object
        obj.scale = size
        return finish(obj,label,color)
    def cone(label,p,r,top,h,color,n=8):
        bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=top,depth=h,location=p)
        return finish(bpy.context.object,label,color)
    def rod(label,a,b,r,color,top=None,n=6):
        a,b=Vector(a),Vector(b)
        obj=cone(label,(a+b)/2,r,r if top is None else top,(b-a).length,color,n)
        obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
        return obj
    def ball(label,p,size,color):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=p)
        obj=bpy.context.object
        obj.scale=size
        return finish(obj,label,color)
    def mesh(label,verts,faces,color):
        data=bpy.data.meshes.new(label+'_Mesh')
        data.from_pydata(verts,[],faces);data.update()
        obj=bpy.data.objects.new(label,data);scene.collection.objects.link(obj)
        return finish(obj,label,color)
    def tent(label,x,y,w,d,z,h,color):
        verts=[(x-w/2,y-d/2,z),(x+w/2,y-d/2,z),(x,y-d/2,z+h),
               (x-w/2,y+d/2,z),(x+w/2,y+d/2,z),(x,y+d/2,z+h)]
        mesh(label,verts,[(0,2,1),(3,4,5),(0,3,5,2),(1,2,5,4),(0,1,4,3)],color)
        mesh(label+'_Entrance',[(x-w*.16,y-d/2-.006,z),(x+w*.16,y-d/2-.006,z),
             (x,y-d/2-.006,z+h*.65),(x-w*.16,y-d/2+.012,z),
             (x+w*.16,y-d/2+.012,z),(x,y-d/2+.012,z+h*.65)],
             [(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],'Dark')
    def palisade(radius,count,height,color,skip_front):
        for i in range(count):
            angle=2*math.pi*i/count
            x,y=radius*math.cos(angle),radius*math.sin(angle)
            if y < -.34 and abs(x) < skip_front: continue
            h=height*(1+.10*math.sin(i*2.7))
            cone('StockadeLog',(x,y,.07+h/2),.045,.045,h,color,5)
            cone('LogPoint',(x,y,.07+h+.055),.045,0,.11,'CutWood',5)
    reports=[]
    try:
        for name in NAMES:
            parts.clear()
            if name.endswith('OrcStockade'):
                cone('EarthFooting',(0,0,.035),.76,.73,.07,'Soil',12)
                palisade(.66,29,.39,'Wood',.35)
                tent('WarTent',0,.16,.80,.60,.08,.61,'Hide')
                rod('RidgePole',(0,-.17,.69),(0,.52,.69),.035,'Wood')
                for x in [-.29,.29]:
                    rod('GatePost',(x,-.52,.07),(x,-.50,.67),.072,'Wood',.055)
                    rod('BoneTusk',(x,-.52,.63),(x*.82,-.51,.97),.072,'Bone',.008)
                rod('GateLintel',(-.34,-.50,.64),(.34,-.50,.64),.060,'Wood')
                ball('Skull',(0,-.54,.73),(.13,.065,.12),'Bone')
                for x in [-.045,.045]:
                    cube('EyeSocket',(x,-.602,.75),(.035,.013,.034),'Dark')
                for x in [-.42,.42]:
                    rod('TentStake',(x,.16,.08),(x*.73,.16,.62),.025,'Wood')
                rod('BannerPole',(.38,.35,.08),(.38,.35,1.14),.027,'Wood')
                mesh('WarBanner',[(.38,.33,.99),(.66,.33,.99),(.62,.33,.73),(.38,.33,.78),
                     (.38,.35,.99),(.66,.35,.99),(.62,.35,.73),(.38,.35,.78)],
                     [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'Hide')
            elif name.endswith('GoblinCamp'):
                cone('GrassFooting',(0,0,.035),.76,.73,.07,'Grass',12)
                palisade(.66,22,.24,'Wood',.36)
                for x,y,r in [(-.28,-.08,.24),(.20,-.12,.25)]:
                    cone('MudHut',(x,y,.23),r*.88,r*.76,.30,'Soil',6)
                    roof=cone('PatchworkRoof',(x,y,.48),r*1.15,.035,.35,'Canvas',6)
                    roof.rotation_euler.z=.16 if x<0 else -.25
                    cube('Door',(x,y-r*.79,.18),(.12,.022,.21),'Dark')
                    rod('RoofStake',(x,y,.53),(x+.02,y,.72),.018,'Wood')
                # Three uneven splayed legs and offset platform create a crooked silhouette.
                for a,b in [((-.20,.32,.07),(-.16,.35,.79)),((.29,.28,.07),(.18,.36,.83)),((.06,.61,.07),(.04,.51,.84))]:
                    rod('LookoutLeg',a,b,.033,'Wood')
                platform=cube('CrookedDeck',(.02,.39,.82),(.55,.43,.07),'Wood')
                platform.rotation_euler.y=.08
                for x in [-.21,.25]:
                    rod('GuardRailPost',(x,.26,.83),(x-.02,.27,1.06),.02,'Wood')
                rod('GuardRail',(-.23,.27,1.06),(.23,.27,1.04),.025,'Wood')
                rod('CanopyPost',(.02,.49,.82),(.10,.48,1.21),.035,'Wood')
                canopy=cone('LookoutCanopy',(.07,.41,1.22),.36,.025,.28,'Hide',5)
                canopy.rotation_euler.y=-.12
                for i in range(4):
                    cube('LadderRung',(-.02,.14-i*.025,.28+i*.13),(.16,.035,.025),'CutWood')
                for x in [-.10,.07]: rod('LadderRail',(x,.12,.09),(x,.23,.81),.018,'Wood')
            else:
                cone('ForestFooting',(0,0,.035),.76,.73,.07,'Forest',12)
                # Two visibly tall trees with a broad inhabited platform between them.
                for x,y,h in [(-.31,.18,1.79),(.32,.28,2.03)]:
                    rod('TallTree',(x,y,.07),(x*.90,y,h),.115,'Wood',.055,7)
                    for a in [0,2.15,4.25]:
                        root=(x+math.cos(a)*.19,y+math.sin(a)*.19,.07)
                        rod('Root',root,(x,y,.32),.055,'Wood',.07,5)
                    for dx,dy,dz in [(-.17,.01,-.12),(.19,.02,0),(0,-.11,.15)]:
                        rod('Bough',(x,y,h-.47),(x+dx,y+dy,h+dz-.14),.035,'Wood',.016)
                        ball('BroadleafCrown',(x+dx,y+dy,h+dz),(.28,.27,.29),'Leaf' if dx<.1 else 'LeafLight')
                cone('LivingPlatform',(.01,.16,.80),.49,.49,.08,'CutWood',10)
                cone('TreehouseWall',(.01,.18,1.0),.235,.23,.34,'Canvas',6)
                cone('LeafRoof',(.01,.18,1.31),.34,.04,.35,'Teal',6)
                cube('TreehouseDoor',(.01,-.026,.98),(.12,.025,.23),'Dark')
                for x in [-.29,.29]:
                    rod('BalconyPost',(x,-.12,.83),(x,-.12,1.01),.02,'Wood')
                rod('BalconyRail',(-.29,-.12,1.01),(.29,-.12,1.01),.022,'CutWood')
                for i in range(6):
                    cube('Stair',(.02,-.51+i*.054,.12+i*.115),(.27,.105,.075),'CutWood')
                rod('StairStringer',(-.13,-.53,.07),(-.13,-.19,.78),.025,'Wood')
                rod('StairStringer',(.17,-.53,.07),(.17,-.19,.78),.025,'Wood')
                cone('RuneStone',(-.42,-.32,.22),.12,.075,.31,'Iron',5)
                cube('RuneMark',(-.42,-.421,.23),(.025,.01,.11),'Gold')
            bpy.ops.object.select_all(action='DESELECT')
            for obj in parts: obj.select_set(True)
            bpy.context.view_layer.objects.active=parts[0]
            bpy.ops.object.join()
            obj=bpy.context.object;scene.cursor.location=(0,0,0)
            bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
            bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
            obj.name=name;obj.data.name=name+'_Mesh'
            if name.endswith('ElfGrove'):
                for vertex in obj.data.vertices:
                    if vertex.co.z > .071:
                        vertex.co.x *= .94
                        vertex.co.y *= .94
                obj.data.update()
                bpy.context.view_layer.update()
            obj['front_axis_blender']='-Y';obj['unity_front']='+Z';obj['single_cell_radius']=.78
            obj.data.calc_loop_triangles()
            radial=max(math.hypot(v.co.x,v.co.y) for v in obj.data.vertices)
            assert radial <= .80, (name,radial)
            assert min(v.co.z for v in obj.data.vertices)>=-1e-6
            reports.append({'name':name,'dimensions_blender':list(obj.dimensions),
                            'triangles':len(obj.data.loop_triangles),'radius':radial,
                            'materials':[m.name for m in obj.data.materials]})
            obj.hide_set(True)
        for name in NAMES: bpy.data.objects[name].hide_set(False)
        exporter=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
        for row in reports:
            row['export']=exporter(row['name'],str(OUT/'Staging'/(row['name']+'.fbx')))
        bpy.data.libraries.write(str(path),{scene},fake_user=True)
        manifest={'source':str(path),'models':reports,'palette':{'M_Faction_'+k:'#'+v for k,v in PALETTE.items()},
                  'units':'meters','unity_up':'+Y','unity_front':'+Z','single_cell_radius_limit':.80}
        (OUT/'Integration/asset-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
        print(json.dumps(manifest))
    finally:
        bpy.context.window.scene=original

if __name__=='__main__': build()
