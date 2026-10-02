"""Project Y 营造资源：在独立 Blender Scene 制作并导出，保留当前场景。"""
from pathlib import Path
import bpy
import math
import runpy
from mathutils import Vector

ROOT=Path('D:/Program/Unity/Project Y')
OUT=ROOT/'Art/Construction/Staging'
OUT.mkdir(parents=True,exist_ok=True)
(ROOT/'Art/Construction/Source').mkdir(parents=True,exist_ok=True)
assert 'Construction_Source' not in bpy.data.scenes, 'Construction source already exists; inspect it before rebuilding'
previous=bpy.context.window.scene
scene=bpy.data.scenes.new('Construction_Source');scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
bpy.context.window.scene=scene
palette=[('Craft_Wood','#66594a'),('Craft_Plank','#978066'),('Craft_Rope','#b29e74'),('Craft_Iron','#596366')]
materials=[]
def linear(x):return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4
for name,color in palette:
    mat=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    rgb=[linear(int(color[i:i+2],16)/255) for i in (1,3,5)]
    mat.diffuse_color=(*rgb,1);mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(*rgb,1);bsdf.inputs['Roughness'].default_value=.85
    materials.append(mat)

class Builder:
    def __init__(self,name):self.name=name;self.vertices=[];self.faces=[];self.slots=[]
    def box(self,center,size,slot=0,angle=0):
        base=len(self.vertices);c,s=math.cos(angle),math.sin(angle)
        for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]:
            x*=size[0]/2;y*=size[1]/2;z*=size[2]/2
            self.vertices.append((center[0]+x*c-y*s,center[1]+x*s+y*c,center[2]+z))
        for face in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:self.faces.append(tuple(base+i for i in face));self.slots.append(slot)
    def beam(self,a,b,width,slot=0):
        start=Vector(a);end=Vector(b);direction=end-start
        side=direction.cross(Vector((0,0,1)))
        if side.length<.001:side=Vector((1,0,0))
        side.normalize();up=direction.normalized().cross(side);base=len(self.vertices)
        for point in (start,end):
            for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]:self.vertices.append(tuple(point+width/2*(side*sx+up*sy)))
        for face in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:self.faces.append(tuple(base+i for i in face));self.slots.append(slot)
    def mesh(self):
        mesh=bpy.data.meshes.new(self.name);mesh.from_pydata(self.vertices,[],self.faces);mesh.materials.clear()
        for mat in materials:mesh.materials.append(mat)
        for face,slot in zip(mesh.polygons,self.slots):face.material_index=slot;face.use_smooth=False
        mesh.update();obj=bpy.data.objects.new(self.name,mesh);scene.collection.objects.link(obj);return obj

objects=[]
b=Builder('Craft_Fence')
for x in (-.62,0,.62):b.box((x,0,.40),(.12,.16,.8),0)
for z in (.25,.60):b.box((0,-.03,z),(1.40,.11,.11),1)
b.beam((-.6,.02,.18),(.6,.02,.68),.09,0)
for x in (-.62,.62):b.box((x,0,.06),(.22,.55,.12),0)
objects.append(b.mesh())
b=Builder('Craft_Wall')
for i in range(8):b.box((-.665+i*.19,0,.9),(.185,.15,1.8),1 if i%3 else 0)
for z in (.35,1.35):b.box((0,.115,z),(1.5,.12,.13),0)
for x in (-.60,.60):
    b.box((x,0,.08),(.20,1.15,.16),0);b.beam((x,.50,.12),(x,.1,1.15),.10,0)
objects.append(b.mesh())
for name,h in [('Craft_Step',.65),('Craft_Platform',1.4)]:
    b=Builder(name)
    for x in (-.48,.48):
        for y in (-.43,.43):b.box((x,y,(h-.1)/2),(.13,.13,h-.1),0)
    for i in range(6):b.box((-.5+i*.2,0,h-.075),(.195,1.05,.15),1)
    b.beam((-.48,.43,.10),(.48,.43,h-.18),.10,0);b.beam((.48,-.43,.10),(-.48,-.43,h-.18),.10,0)
    for x in (-.30,.30):b.beam((x,-.78,0),(x,-.50,h-.05),.075,0)
    for i in range(1,max(3,round(h/.22))+1):
        t=i/(max(3,round(h/.22))+1);b.box((0,-.78+.28*t,(h-.05)*t),(.67,.09,.075),1)
    objects.append(b.mesh())
b=Builder('Craft_WoodBundle')
for z in (.07,.18):
    for y in (-.16,0,.16):b.box((0,y,z),(.72,.145,.11),1)
for x in (-.22,.22):b.box((x,0,.14),(.05,.49,.27),2)
objects.append(b.mesh())
b=Builder('Craft_RopeCoil')
for z in (.055,.12):
    for radius in (.18,.245):
        for i in range(12):
            a=i*math.tau/12;c=(i+1)*math.tau/12
            b.beam((radius*math.cos(a),radius*math.sin(a),z),(radius*math.cos(c),radius*math.sin(c),z),.065,2)
objects.append(b.mesh())
b=Builder('Craft_IronParts')
for x,y,angle in [(-.16,-.12,.15),(.12,.10,-.2),(0,-.05,.4)]:b.box((x,y,.06),(.44,.13,.12),3,angle)
objects.append(b.mesh())
try:
    export=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
    for obj in objects:
        result=export(obj.name,str(OUT/(obj.name+'.fbx')),overwrite=False)
        print(obj.name,'dimensions',tuple(round(v,3) for v in obj.dimensions),'faces',len(obj.data.polygons),'bytes',result['bytes'])
    for i,obj in enumerate(objects):obj.location=(i%4*2.1,i//4*2.1,0)
    bpy.data.libraries.write(str(ROOT/'Art/Construction/Source/Construction.blend'),{scene},fake_user=True)
finally:bpy.context.window.scene=previous
print('Construction source and seven FBX files saved; previous scene restored.')
