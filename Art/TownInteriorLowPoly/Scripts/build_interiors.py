"""在独立 Blender 场景制作米制城镇建筑；保留旧源作品与旧 FBX。"""
import bpy,bmesh,math,json,runpy
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y');OUT=ROOT/'Art/TownInteriorLowPoly'
scene=bpy.data.scenes.get('WalkTown_Source') or bpy.data.scenes.new('WalkTown_Source');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
collection=bpy.data.collections.get('WalkTown_Masters')
if collection is None:collection=bpy.data.collections.new('WalkTown_Masters');scene.collection.children.link(collection)
helper=runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/mesh_helpers.py'));Mesh=helper['MeshBuilder']
helper['PALETTE'].update(InteriorBrick='896455',InteriorSlate='485b67',InteriorWood='806951',InteriorLinen='cdbd98',InteriorGlow='cb803d',
 RoyalStone='b5a080',RoyalIvory='e1d1af',RoyalShade='938570',RoyalRoof='674653',RoyalRoofShade='4d3c48',RoyalGold='b79c60',RoyalGlass='354f53')
for key,color in helper['PALETTE'].items():
    name='M_MapLP_'+key
    if name in bpy.data.materials:continue
    material=bpy.data.materials.new(name);material.use_nodes=True
    rgba=tuple(helper['srgb_linear'](int(color[i:i+2],16)/255) for i in (0,2,4))+(1,)
    material.diffuse_color=rgba;node=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value=rgba;node.inputs['Roughness'].default_value=.87;node.inputs['Metallic'].default_value=0
    material['palette_srgb']='#'+color
kit=json.loads((OUT/'Integration/kit-design.json').read_text(encoding='utf-8'))
owned=[name for item in kit for name in [item['shell'],item['cover']]]+['WalkTown_Row'+v for v in 'ABC']
for name in owned:
    obj=bpy.data.objects.get(name)
    if obj:
        assert obj.name in collection.objects,'禁止覆盖不属于本次集合的对象'
        mesh=obj.data;bpy.data.objects.remove(obj,do_unlink=True)
        if mesh.users==0:bpy.data.meshes.remove(mesh)
models=[]
def finish(mesh,name):
    obj=mesh.finish(name,collection);models.append(obj);return obj
def cylinder(m,x,y,z,radius,height,key,sides=8,top=None):
    top=radius if top is None else top
    vertices=[(x+r*math.cos(i*math.tau/sides),y+r*math.sin(i*math.tau/sides),h) for h,r in [(z,radius),(z+height,top)] for i in range(sides)]
    m.part(vertices,[tuple(reversed(range(sides))),tuple(range(sides,sides*2))]+[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)],key)
def append(m,other,x=0,y=0,z=0):
    m.part([(vx+x,vy+y,vz+z) for vx,vy,vz in other.vertices],other.faces,[other.material_keys[i] for i in other.face_materials])
def frame(m,x,y,bottom,width,height):
    m.box((x,y,bottom+height/2),(width,.07,height),'Window')
    for xx in [x-width/2,x+width/2]:m.box((xx,y-.06,bottom+height/2),(.09,.12,height+.15),'Timber')
    for zz in [bottom,bottom+height]:m.box((x,y-.06,zz),(width+.14,.13,.09),'Timber')
    m.box((x,y-.08,bottom+height*.5),(.065,.13,height),'TimberLight')
    m.box((x,y-.08,bottom+height*.5),(width,.13,.06),'TimberLight')
def shell(m,hx,hy,bottom,top,door_width,door_height,key='Plaster',center_y=0):
    height=top-bottom;z=(top+bottom)/2
    m.box((0,center_y+hy,z),(2*hx,.28,height),key)
    for x in [-hx,hx]:m.box((x,center_y,z),(.28,hy*2,height),key)
    side=hx-door_width/2
    for sign in [-1,1]:m.box((sign*(door_width/2+side/2),center_y-hy,z),(side,.28,height),key)
    if top>door_height:
        low=max(bottom,door_height);m.box((0,center_y-hy,(low+top)/2),(door_width,.28,top-low),key)
def seat(m,x,y):
    m.box((x,y,.47),(.46,.48,.085),'TimberLight')
    for dx in [-.17,.17]:
        for dy in [-.18,.18]:m.box((x+dx,y+dy,.23),(.07,.07,.46),'Timber')
    m.box((x,y+.2,.78),(.46,.09,.58),'Timber')
def table(m,x,y):
    m.box((x,y,.78),(1.55,.9,.10),'TimberLight')
    for dx in [-.62,.62]:
        for dy in [-.31,.31]:m.box((x+dx,y+dy,.37),(.10,.10,.74),'Timber')
    for side in [-1,1]:
        m.box((x,y+side*.84,.47),(1.65,.32,.10),'Timber')
        for dx in [-.60,.60]:m.box((x+dx,y+side*.84,.23),(.11,.22,.46),'Timber')
    cylinder(m,x+.3,y,.84,.10,.18,'Plaster',8);cylinder(m,x-.27,y,.84,.18,.04,'Stone',8)
def barrel(m,x,y):
    cylinder(m,x,y,0,.34,.89,'Timber',10,top=.32)
    for z in [.13,.70]:cylinder(m,x,y,z,.352,.06,'RockDark',10)
def shelf(m,x,y):
    for z in [.10,.65,1.25,1.85]:m.box((x,y,z),(1.75,.62,.10),'TimberLight')
    for dx in [-.84,.84]:m.box((x+dx,y,1),(.11,.67,2),'Timber')
    for z in [.72,1.32]:
        for dx in [-.52,-.17,.18,.53]:cylinder(m,x+dx,y,z,.12,.25,'Shore' if dx>0 else 'Plaster',7)

def library(m,x,y):
    # 公会使用卷宗书架，不能与商店的瓶罐陈列共用同一套细节。
    for z in [.10,.70,1.32,1.94]:m.box((x,y,z),(1.75,.62,.10),'TimberLight')
    for dx in [-.84,.84]:m.box((x+dx,y,1),(.11,.67,2),'Timber')
    for shelf_z in [.18,.78,1.40]:
        for i in range(8):
            h=.34+(i%3)*.05;key=['RoyalRoof','InteriorSlate','Plaster','TimberLight'][i%4]
            m.box((x-.65+i*.185,y-.04,shelf_z+h/2),(.13,.37,h),key)

def weapon_rack(m,x,y):
    for dx in [-.72,.72]:m.box((x+dx,y,1),(.12,.56,2),'Timber')
    for z in [.12,1.65]:m.box((x,y,z),(1.60,.18,.12),'TimberLight')
    for dx in [-.45,0,.45]:
        m.box((x+dx,y-.16,.83),(.09,.08,1.12),'Stone')
        m.box((x+dx,y-.16,1.46),(.34,.10,.08),'RoyalGold');m.box((x+dx,y-.16,1.65),(.11,.11,.30),'Timber')
def forge(m,x,y):
    m.box((x,y,.60),(1.7,1.15,1.2),'InteriorBrick')
    m.box((x,y-.62,.86),(1.12,.06,.64),'RockDark');m.box((x,y-.66,.70),(.9,.04,.23),'InteriorGlow')
    m.box((x,y,1.32),(1.95,1.38,.24),'Stone')
    for xx in [-.58,.58]:m.box((x+xx,y-.48,1.54),(.18,.28,.55),'InteriorBrick')
def anvil(m,x,y):
    cylinder(m,x,y,0,.36,.65,'Timber',8)
    m.box((x,y,.79),(1.10,.42,.25),'RockDark');m.box((x+.60,y,.85),(.38,.28,.12),'RockDark')
    m.box((x-.34,y+.27,.96),(.44,.12,.12),'Timber')
def sign(m,x,y,kind):
    m.box((x,y+.22,2.75),(.10,.10,.75),'Timber');m.box((x,y,3.07),(.10,.72,.10),'Timber')
    m.box((x,y-.23,2.70),(.88,.12,.64),'TimberLight')
    if kind=='Tavern':m.box((x-.08,y-.30,2.70),(.27,.06,.34),'Plaster');m.box((x+.14,y-.31,2.70),(.12,.05,.21),'Plaster')
    elif kind=='Forge':m.box((x,y-.31,2.65),(.07,.06,.40),'Timber');m.box((x,y-.31,2.84),(.40,.06,.13),'Stone')
    elif kind=='Shop':m.box((x,y-.31,2.71),(.31,.06,.31),'RoyalGold')
    else:
        m.beam((x-.22,y-.31,2.49),(x+.22,y-.31,2.91),.09,.07,'RoyalGold');m.beam((x+.22,y-.31,2.49),(x-.22,y-.31,2.91),.09,.07,'RoyalGold')
# 共享 FBX 预设经 Unity 轴向烘焙后 X 取反；用最终 Unity 地格坐标放置家具。
def fixture_position(q,r):return -math.sqrt(3)*1.5*(q+r/2),-2.25*r
for item in kit:
    kind=item['kind'];core,cover=Mesh(),Mesh()
    if kind=='Palace':
        # 保留原模型的高层和穹顶，仅复制并裁切本次副本；旧作品不受影响。
        source=bpy.data.objects['Royal_Palace'];bm=bmesh.new();bm.from_mesh(source.data)
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,4.5),plane_no=(0,0,1),clear_inner=True)
        temporary=bpy.data.meshes.new('WalkTown_Palace_Clipped');bm.to_mesh(temporary);bm.free()
        cover.part([tuple(v.co) for v in temporary.vertices],[tuple(p.vertices) for p in temporary.polygons],
            [source.data.materials[p.material_index].name.removeprefix('M_MapLP_') for p in temporary.polygons]);bpy.data.meshes.remove(temporary)
        core.box((0,6,.025),(41,12,.05),'RoyalIvory')
        shell(core,20.5,6,.05,1.05,3.6,4.1,'RoyalStone',6)
        shell(cover,20.5,6,1.05,4.5,3.6,4.1,'RoyalStone',6)
        for x in [-16.6,16.6]:
            core.box((x,-6,.525),(8.8,12,1.05),'RoyalStone');cover.box((x,-6,2.775),(8.8,12,3.45),'RoyalStone')
        for x in [-18,-14,-10,-6,6,10,14,18]:
            frame(cover,x,-.19,1.4,1.35,1.8)
            core.box((x,-.24,.53),(.25,.30,1.06),'RoyalIvory');cover.box((x,-.24,2.7),(.25,.30,3.3),'RoyalIvory')
        for q,r in item['fixtures']:
            x,y=fixture_position(q,r)
            if (q,r)==(2,-4):
                core.box((x,y,.12),(2.2,1.6,.24),'RoyalStone');seat(core,x,y);core.box((x,y+.30,1.35),(1.0,.18,1.4),'RoyalGold')
            else:
                cylinder(core,x,y,0,.42,.20,'RoyalStone',10);cylinder(core,x,y,.20,.27,.85,'RoyalIvory',10)
                cylinder(cover,x,y,1.05,.27,3.45,'RoyalIvory',10)
        core.box((0,5,.058),(2.4,9.2,.04),'RoyalRoof')
    else:
        hx,hy=item['halfWidth'],item['halfDepth']
        floor='InteriorWood' if kind in ['Tavern','Shop'] else 'Stone'
        core.box((0,0,.025),(hx*2,hy*2,.05),floor)
        shell(core,hx,hy,.05,1.05,3.0,2.4,'PlasterShade')
        shell(cover,hx,hy,1.05,3.2,3.0,2.4,'Plaster')
        for x in [-hx,-5.0,-2.7,2.7,5.0,hx]:
            core.box((x,-hy-.13,.55),(.15,.18,1.1),'Timber');cover.box((x,-hy-.13,2.1),(.15,.18,2.1),'Timber')
        for x in [-5.9,-3.8,3.8,5.9]:frame(cover,x,-hy-.17,1.3,1.12,1.27)
        cover.box((0,-hy-.16,3.18),(hx*2+.22,.23,.21),'Timber')
        for x in [-1.6,1.6]:
            core.box((x,-hy-.16,.54),(.18,.27,1.08),'Stone');cover.box((x,-hy-.16,1.78),(.18,.27,1.48),'Stone')
        cover.box((0,-hy-.16,2.48),(3.38,.29,.18),'Stone')
        height=6.35 if kind=='Tavern' else 6.75 if kind=='Guild' else 3.2
        if height>3.2:
            cover.box((0,0,(height+3.2)/2),(hx*2+.20,hy*2+.24,height-3.2),'PlasterShade')
            for x in [-6,-3,0,3,6]:frame(cover,x,-hy-.20,4.08,1.1,1.45)
            for x in [-hx,-4,0,4,hx]:cover.box((x,-hy-.24,4.78),(.17,.16,3.18),'Timber')
            cover.box((0,-hy-.25,6.32),(hx*2+.26,.19,.18),'Timber')
        # 大体量拆成不同屋脊与附属体，避免四家店只换招牌。
        if kind=='Forge':
            cover.ridge_roof(hx+.22,hy+.32,3.42,5.15)
            cover.box((4.5,1.2,4.55),(1.35,1.10,5.1),'InteriorBrick');cover.box((4.5,1.2,7.2),(1.60,1.35,.24),'Stone')
            for x in [-5.8,-3.6]:core.box((x,-hy-.28,.5),(.16,.18,1),'Timber');cover.box((x,-hy-.28,1.9),(.16,.18,1.8),'Timber')
            cover.box((-4.7,-hy-.24,2.70),(3.9,.72,.18),'InteriorSlate')
        elif kind=='Shop':
            cover.ridge_roof(hx+.22,hy+.28,3.44,5.38)
            for i in range(7):cover.box((-5.4+i*.75,-hy-.36,2.82),(.76,1.0,.12),'InteriorLinen' if i%2 else 'Window')
            for x in [-5.3,4.9]:core.box((x,-hy-.28,.52),(1.5,.55,1.04),'TimberLight')
        else:
            cover.ridge_roof(hx+.27,hy+.32,height+.22,height+2.15)
            cover.box((-5.4,1.2,height+1.3),(.72,.84,2.2),'InteriorBrick')
            if kind=='Guild':
                cover.box((4.8,1.0,6.0),(2.6,3.0,2.0),'Plaster');tower=Mesh();tower.ridge_roof(1.5,1.7,7.1,9.3);append(cover,tower,4.8,1.0)
                core.box((5.2,-hy-.22,.9),(1.7,.16,1.8),'Timber');cover.box((5.2,-hy-.33,1.65),(1.35,.05,.65),'Plaster')
        if kind in ['Forge','Guild']:
            # 哑光蓝灰屋顶区别于酒馆与商店的赤陶色。
            if 'InteriorSlate' not in cover.material_keys:cover.material_keys.append('InteriorSlate')
            index=cover.material_keys.index('InteriorSlate')
            cover.face_materials=[index if cover.material_keys[i] in ['Roof','RoofShade'] else i for i in cover.face_materials]
        sign(cover,-2.1,-hy-.35,kind)
        for i,(q,r) in enumerate(item['fixtures']):
            x,y=fixture_position(q,r)
            if kind=='Tavern':
                if i==0:
                    core.box((x,y,.52),(1.7,.75,1.04),'Timber');core.box((x,y,1.08),(1.94,.94,.10),'TimberLight')
                    cylinder(core,x+.3,y,1.14,.10,.20,'Plaster',8)
                elif i==1:barrel(core,x-.38,y);barrel(core,x+.38,y)
                else:table(core,x,y)
            elif kind=='Forge':forge(core,x,y) if i==0 else anvil(core,x,y) if i==2 else shelf(core,x,y)
            elif kind=='Shop':shelf(core,x,y)
            else:
                if i==2:
                    table(core,x,y);core.box((x,y,.848),(1.10,.61,.025),'InteriorLinen')
                    core.box((x+.18,y,.867),(.32,.29,.02),'InteriorSlate')
                elif i==0:library(core,x,y)
                else:weapon_rack(core,x,y)
    finish(core,item['shell']);finish(cover,item['cover'])

for variant,heights in [('A',[3.15,6.25,3.3]),('B',[6.4,3.25,6.1]),('C',[3.2,6.6,6.2])]:
    row=Mesh();widths=[3.6,4.0,3.6];left=-sum(widths)/2
    for i,(width,height) in enumerate(zip(widths,heights)):
        house=Mesh();depth=5.25+(i%2)*.25
        house.box((0,0,height/2),(width,depth,height),'Plaster' if i%2 else 'PlasterShade')
        front=-depth/2-.08
        house.box((-.55,front,1.12),(1.0,.12,2.24),'Timber')
        for x in [-1.12,.02]:house.box((x,front-.05,1.16),(.12,.17,2.32),'Stone')
        house.box((-.55,front-.05,2.34),(1.30,.18,.16),'Stone');frame(house,width*.27,front-.04,1.20,.74,1.08)
        if height>4:frame(house,-width*.24,front-.06,4.08,.84,1.25);frame(house,width*.24,front-.06,4.08,.84,1.25)
        for x in [-width/2+.06,width/2-.06]:house.box((x,front,height/2),(.12,.16,height),'Timber')
        for z in [.20,3.1,height-.05]:
            if z<=height:house.box((0,front,z),(width,.18,.14),'Timber')
        house.ridge_roof(width/2+.10,depth/2+.16,height+.12,height+1.55)
        house.box((width*.27,.9,height+.7),(.42,.48,1.20),'InteriorBrick')
        if (i+ord(variant))%3==0:
            if 'InteriorSlate' not in house.material_keys:house.material_keys.append('InteriorSlate')
            n=house.material_keys.index('InteriorSlate');house.face_materials=[n if house.material_keys[k] in ['Roof','RoofShade'] else k for k in house.face_materials]
        append(row,house,left+width/2,0);left+=width
    finish(row,'WalkTown_Row'+variant)
for folder in ['Source','Staging','Previews','Integration']:(OUT/folder).mkdir(parents=True,exist_ok=True)
report=[]
for obj in models:
    obj.data.calc_loop_triangles();report.append(dict(name=obj.name,dimensions=list(obj.dimensions),triangles=len(obj.data.loop_triangles),materials=[m.name for m in obj.data.materials]))
(OUT/'Integration/models.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'Integration/palette.json').write_text(json.dumps({'M_MapLP_'+k:'#'+v for k,v in helper['PALETTE'].items()},indent=2),encoding='utf-8')
bpy.data.libraries.write(str(OUT/'Source/WalkableTown.blend'),{scene},fake_user=True,compress=True)
print(json.dumps(report))
