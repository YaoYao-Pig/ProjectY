"""通过 Blender MCP 制作王城静态资源；独立场景，不修改已有作品。"""
import bpy
import math
import json
import runpy
from pathlib import Path
from mathutils import Vector

ROOT=Path('D:/Program/Unity/Project Y')
OUT=ROOT/'Art/RoyalTownLowPoly'
helper=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/mesh_helpers.py'))
Mesh=helper['MeshBuilder'];palette=helper['PALETTE']
palette.update(RoyalStone='b5a080',RoyalIvory='e1d1af',RoyalShade='938570',RoyalRoof='674653',
    RoyalRoofShade='4d3c48',RoyalGold='b79c60',RoyalGlass='354f53',RoyalHedge='3f6347',RoyalLeaf='668150',RoyalWater='508f9e')
# 先创建共享材质，节点按类型寻找以支持中文 Blender。
for key,color in palette.items():
    name='M_MapLP_'+key
    if name in bpy.data.materials:continue
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    rgba=tuple(helper['srgb_linear'](int(color[i:i+2],16)/255) for i in (0,2,4))+(1,)
    mat.diffuse_color=rgba;node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value=rgba;node.inputs['Roughness'].default_value=.86;node.inputs['Metallic'].default_value=0
    mat['palette_srgb']='#'+color
assert 'RoyalTown_Source' not in bpy.data.scenes,'王城源已存在，请定向修改，禁止覆盖重建'
scene=bpy.data.scenes.new('RoyalTown_Source');scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
bpy.context.window.scene=scene
collection=bpy.data.collections.new('RoyalTown_Masters');scene.collection.children.link(collection)
models=[]

def finish(b,name):
    obj=b.finish(name,collection);models.append(obj);return obj

def ring(b,x,y,levels,n,key,phase=0):
    """同心多边形截面：台基、柱、喷泉和穹顶共用，保留平面法线。"""
    vertices=[(x+r*math.cos(phase+i*math.tau/n),y+r*math.sin(phase+i*math.tau/n),z) for z,r in levels for i in range(n)]
    faces=[tuple(reversed(range(n))),tuple(range((len(levels)-1)*n,len(levels)*n))]
    for j in range(len(levels)-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    b.part(vertices,faces,key)

def beam(b,a,c,width,key):
    direction=Vector(c)-Vector(a);rotation=Vector((0,0,1)).rotation_difference(direction.normalized())
    verts=[]
    for t in [0,1]:
        for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]:verts.append(tuple(Vector(a)+direction*t+rotation@Vector((x*width/2,y*width/2,0))))
    b.part(verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],key)

def extrude(b,points,y,depth,key):
    n=len(points);v=[(x,y+d,z) for d in [-depth/2,depth/2] for x,z in points]
    b.part(v,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],key)

def arch(b,x,y,z,width,spring,trim=.2,depth=.3,fill=False):
    """真实拱圈；门楼不填洞，窗洞才补深色背板。"""
    r=width/2
    for side in [-1,1]:b.box((x+side*(r+trim/2),y,z+spring/2),(trim,depth,spring),'RoyalIvory')
    for i in range(10):
        a=i*math.pi/10;c=(i+1)*math.pi/10
        p=[(x+rr*math.cos(t),z+spring+rr*math.sin(t)) for rr,t in [(r,a),(r,c),(r+trim,c),(r+trim,a)]]
        extrude(b,p,y,depth,'RoyalIvory')
    if fill:
        p=[(x-r,z),(x+r,z)]+[(x+r*math.cos(i*math.pi/10),z+spring+r*math.sin(i*math.pi/10)) for i in range(11)]
        extrude(b,p,y+.05,.08,'RoyalGlass')
        b.box((x,y-.11,z+spring*.6),(.09,.09,spring*1.2),'RoyalGold')
        b.box((x,y-.11,z+spring*.65),(width,.09,.09),'RoyalIvory')
    b.box((x,y,z-.1),(width+trim*3,depth+.17,.2),'RoyalIvory')

def append(b,part,x,y,angle=0):
    c,s=math.cos(angle),math.sin(angle)
    b.part([(x+vx*c-vy*s,y+vx*s+vy*c,z) for vx,vy,z in part.vertices],part.faces,[part.material_keys[i] for i in part.face_materials])

def facade(b,x,y,width,floors,angle=0):
    p=Mesh();count=max(1,int(width/3.0));spacing=width/count
    for floor in range(floors):
        bottom=1.1+floor*4.05
        for i in range(count):arch(p,(i-(count-1)/2)*spacing,0,bottom,1.35,1.85,.17,.34,True)
        for i in range(count+1):
            px=(i-count/2)*spacing
            p.box((px,-.02,bottom+1.5),(.3,.42,3.3),'RoyalStone')
            p.box((px,-.1,bottom+3.12),(.55,.55,.24),'RoyalIvory')
    append(b,p,x,y,angle)

def roof(b,x,y,w,d,z,height):
    """折面孟莎屋顶与收分屋脊，檐口轮廓比密集瓦纹更重要。"""
    levels=[(z,w,d),(z+.5,w+.2,d+.2),(z+height*.77,w*.63,d*.62),(z+height,w*.43,d*.40)]
    v=[]
    for h,a,c in levels:
        for px,py in [(-a/2,-c/2),(a/2,-c/2),(a/2,c/2),(-a/2,c/2)]:v.append((x+px,y+py,h))
    f=[(12,13,14,15)]
    for j in range(3):
        for i in range(4):f.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
    b.part(v,f,['RoyalRoof']+['RoyalRoofShade' if i%4==0 else 'RoyalRoof' for i in range(12)])
    for i in range(4):
        for j in range(3):beam(b,v[j*4+i],v[(j+1)*4+i],.16,'RoyalIvory')
    b.box((x,y,z+height+.1),(w*.46,d*.43,.2),'RoyalGold')

def balustrade(b,x,y,length,z,angle=0):
    p=Mesh();p.box((0,0,z+.1),(length,.38,.2),'RoyalStone');p.box((0,0,z+1.02),(length+.1,.38,.18),'RoyalIvory')
    count=max(2,int(length/.68))
    for i in range(count+1):
        xx=-length/2+i*length/count
        ring(p,xx,0,[(z+.2,.12),(z+.39,.17),(z+.55,.11),(z+.8,.15),(z+.94,.11)],6,'RoyalIvory')
    for xx in [-length/2,length/2]:p.box((xx,0,z+.56),(.37,.46,.95),'RoyalStone')
    append(b,p,x,y,angle)

def body(b,x,y,w,d,h,floors):
    b.box((x,y,h/2),(w,d,h),'RoyalStone')
    for z in [.16,.65]+[4.6+i*4.05 for i in range(floors-1)]+[h-.15,h+.18]:
        b.box((x,y,z),(w+.5,d+.5,.22 if z>.7 else .32),'RoyalIvory')
    facade(b,x,y-d/2-.14,w-.8,floors)
    facade(b,x,y+d/2+.14,w-.8,floors,math.pi)
    facade(b,x+w/2+.14,y,d-.8,floors,math.pi/2)
    facade(b,x-w/2-.14,y,d-.8,floors,-math.pi/2)

def pinnacle(b,x,y,z):
    ring(b,x,y,[(z,.32),(z+.55,.22),(z+.85,.3),(z+1.9,0)],6,'RoyalIvory')

# 宫殿整栋建模：后部主楼与双翼形成真正的开放中庭。
b=Mesh();body(b,0,6,41,12,13.2,3);roof(b,0,6,42,13,13.5,4)
for x in [-16.6,16.6]:
    body(b,x,-6,8.8,12,11.8,2);roof(b,x,-6,9.4,12.5,12.1,4.3)
    body(b,x,-8,9,8,12.8,3);roof(b,x,-8,9.6,8.6,13.1,6)
    ring(b,x,-8,[(19.1,.7),(20,.5),(21.6,0)],8,'RoyalGold')
    for dx in [-4.2,4.2]:
        for dy in [-3.7,3.7]:pinnacle(b,x+dx,-8+dy,13.2)
# 中央八角鼓座、肋骨穹顶、通透钟亭与高尖塔。
ring(b,0,6,[(13.5,6),(14,6.3),(17,6.3),(17.4,6.8)],8,'RoyalStone',math.pi/8)
for i in range(8):
    a=i*math.tau/8;part=Mesh();arch(part,0,0,14,1.5,1.5,.22,.32,True)
    append(b,part,5.9*math.sin(a),6-5.9*math.cos(a),a)
levels=[(17.4,6.8),(18,6.8),(20,6.25),(23,4.65),(25,2.6),(25.8,1.8)]
ring(b,0,6,levels,12,'RoyalRoof',math.pi/12)
for i in range(12):
    a=math.pi/12+i*math.tau/12
    for (z,r),(zz,rr) in zip(levels,levels[1:]):beam(b,(r*math.cos(a),6+r*math.sin(a),z),(rr*math.cos(a),6+rr*math.sin(a),zz),.19,'RoyalIvory')
ring(b,0,6,[(25.8,2),(26.2,2),(26.3,1.7)],8,'RoyalIvory')
for i in range(8):
    a=i*math.tau/8;ring(b,1.4*math.cos(a),6+1.4*math.sin(a),[(26.2,.19),(29,.19)],6,'RoyalIvory')
ring(b,0,6,[(29,2),(29.4,1.8),(30.4,.8),(30.7,.2),(34,0)],8,'RoyalRoof')
for x in [-10,-5,5,10]:pinnacle(b,x,-.3,13.7)
for x in [-16.6,16.6]:balustrade(b,x,-12.5,9,0)
arch(b,0,-.48,.2,2.7,3.5,.33,.65,True)
for x in [-2,2]:ring(b,x,-.48,[(0,.36),(.3,.42),(.5,.27),(5.5,.27),(5.7,.42)],8,'RoyalIvory')
b.box((0,-.45,5.9),(4.8,.9,.42),'RoyalIvory')
extrude(b,[(-2.5,6.1),(2.5,6.1),(0,7.5)],-.48,.5,'RoyalStone');ring(b,0,-.5,[(7.5,.24),(8.2,0)],6,'RoyalGold')
finish(b,'Royal_Palace')

# 双塔之间只有高位拱圈，地面中央通道保持开放。
b=Mesh()
for x in [-8.8,8.8]:
    body(b,x,0,5.2,5.8,9.7,2);roof(b,x,0,5.8,6.4,10,4.2);pinnacle(b,x,0,14.2)
arch(b,0,0,0,11.6,4.8,.9,2.4,False)
b.box((0,0,11.65),(12,2.5,1.1),'RoyalStone');balustrade(b,0,-1.1,12,12.2);balustrade(b,0,1.1,12,12.2)
ring(b,0,0,[(12.2,.4),(13.1,.55),(13.6,0)],6,'RoyalGold')
finish(b,'Royal_Gatehouse')

b=Mesh();ring(b,0,0,[(0,3.1),(.22,3.1),(.32,2.9)],8,'RoyalStone',math.pi/8)
for i in range(8):
    a=math.pi/8+i*math.tau/8;x,y=2.35*math.cos(a),2.35*math.sin(a)
    ring(b,x,y,[(.3,.25),(.55,.32),(3.7,.19),(3.9,.32)],8,'RoyalIvory')
ring(b,0,0,[(3.9,3),(4.2,3.2),(5.6,1.8),(6.4,.35)],8,'RoyalRoof',math.pi/8);pinnacle(b,0,0,6.4)
finish(b,'Royal_Pavilion')

b=Mesh();ring(b,0,0,[(0,2.8),(.22,2.8),(.25,2.5)],12,'RoyalStone')
ring(b,0,0,[(.26,2.4),(.3,2.4)],12,'RoyalWater')
for i in range(12):
    a=i*math.tau/12;c=(i+1)*math.tau/12;beam(b,(2.6*math.cos(a),2.6*math.sin(a),.5),(2.6*math.cos(c),2.6*math.sin(c),.5),.35,'RoyalIvory')
ring(b,0,0,[(.3,.6),(1.3,.35),(1.5,1.55),(1.7,1.55),(1.76,1.4)],12,'RoyalIvory')
ring(b,0,0,[(1.77,1.3),(1.8,1.3)],12,'RoyalWater')
ring(b,0,0,[(1.8,.3),(2.6,.25),(2.8,.85),(3,.85)],10,'RoyalIvory')
ring(b,0,0,[(3,.7),(3.03,.7)],10,'RoyalWater');ring(b,0,0,[(3,.17),(3.7,.14),(4.1,0)],8,'RoyalGold')
finish(b,'Royal_Fountain')

b=Mesh();b.box((0,0,.13),(1.4,1.2,.26),'RoyalStone');b.box((0,0,.75),(.95,.8,1),'RoyalIvory')
b.box((0,0,1.32),(1.2,1,.18),'RoyalStone')
ring(b,0,0,[(1.4,.32),(2.4,.5),(3.15,.32)],6,'RoyalShade')
ring(b,0,0,[(3.18,.22),(3.55,.27),(3.73,.13)],8,'RoyalIvory')
beam(b,(-.3,0,2.8),(-.55,-.2,2.1),.27,'RoyalIvory');beam(b,(.32,0,2.8),(.6,-.2,3.05),.25,'RoyalIvory')
beam(b,(.65,-.22,1.4),(.65,-.22,4.6),.08,'RoyalGold');ring(b,.65,-.22,[(4.45,.18),(4.9,0)],4,'RoyalGold')
finish(b,'Royal_Statue')

b=Mesh();b.box((0,0,.1),(9,5.8,.2),'RoyalStone');b.box((0,0,.24),(8.7,5.5,.22),'Earth')
for y in [-2.4,2.4]:b.box((0,y,.65),(8.2,.5,.9),'RoyalHedge')
for x in [-4,4]:b.box((x,0,.65),(.5,4.8,.9),'RoyalHedge')
for a,c in [((-3,-1.5,.57),(3,1.5,.57)),((-3,1.5,.57),(3,-1.5,.57))]:beam(b,a,c,.55,'RoyalLeaf')
ring(b,0,0,[(.35,.8),(1,.8),(1.45,.35)],8,'RoyalHedge')
for x in [-2.8,2.8]:
    for y in [-1.2,1.2]:ring(b,x,y,[(.4,.4),(.65,.5),(.8,.3)],6,'RoyalGold')
finish(b,'Royal_Parterre')

b=Mesh();ring(b,0,0,[(0,.28),(.6,.26)],7,'Timber')
ring(b,0,0,[(.4,.28),(.8,.68),(2,.63),(3.2,.42),(4.4,0)],7,'RoyalHedge')
finish(b,'Royal_Cypress')

# 桥栏采用归一化跨径/宽度，但真实高度独立缩放；桥面只由导航几何提供。
b=Mesh()
for y in [-.5,.5]:
    b.box((0,y,.07),(1,.045,.14),'RoyalStone');b.box((0,y,1.05),(1,.045,.16),'RoyalIvory')
    for i in range(17):b.box((-.5+i/16,y,.6),(.012,.03,.85),'RoyalIvory')
    for x in [-.5,0,.5]:b.box((x,y,.62),(.032,.066,1.24),'RoyalStone')
finish(b,'Royal_Bridge')
b=Mesh();balustrade(b,0,0,8,0)
# 仅归一化 X，之后按台地沿线长度摆放，不拉伸栏杆高度。
b.vertices=[(x/8,y,z) for x,y,z in b.vertices];finish(b,'Royal_Balustrade')

b=Mesh();b.box((0,-1.25,1.6),(9,.45,3.2),'RoyalStone')
for x in [-3,0,3]:
    arch(b,x,-1.53,.18,2.1,1.4,.25,.24,True)
    for px in [x-1.48,x+1.48]:b.box((px,-1.52,1.6),(.22,.45,3.2),'RoyalIvory')
for z in [.12,3.08]:b.box((0,-1.5,z),(9,.65,.24),'RoyalIvory')
b.vertices=[(x/9,y,z) for x,y,z in b.vertices];finish(b,'Royal_Retaining')

for folder in ['Source','Exports','Previews','Integration']:(OUT/folder).mkdir(parents=True,exist_ok=True)
report=[]
for obj in models:
    obj.data.calc_loop_triangles()
    report.append(dict(name=obj.name,triangles=len(obj.data.loop_triangles),dimensions=list(obj.dimensions),materials=[m.name for m in obj.data.materials]))
(OUT/'Integration/models.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'Integration/palette.json').write_text(json.dumps({'M_MapLP_'+k:'#'+v for k,v in palette.items()},indent=2),encoding='utf-8')
bpy.data.libraries.write(str(OUT/'Source/RoyalTown.blend'),{scene},fake_user=True,compress=True)
print(json.dumps(report))
