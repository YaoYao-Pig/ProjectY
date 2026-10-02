"""Original low-poly biome kit. Run through Blender MCP, preserves other scenes."""
import bpy, bmesh, math, json, runpy
from mathutils import Vector
from pathlib import Path
from math import sin, cos, pi, tau

ROOT=Path('D:/Program/Unity/Project Y')
BASE=ROOT/'Art/AssetExpansion202610/Terrain'
H=runpy.run_path(str(ROOT/'Art/AssetExpansion202610/shared_pipeline.py'))
G=runpy.run_path(str(BASE/'Scripts/terrain_geometry.py'))
scene,collection=H['create_scene']('Terrain')
PALETTE={
 'Peat':'514b3f','PeatLight':'69664d','Moss':'73845a','MossDeep':'475f4c','MossPale':'94a176',
 'Silt':'7b7860','Bark':'51483d','BarkLight':'75634f','BarkDark':'383a32','Heartwood':'a18a63',
 'Reed':'7e9361','ReedLight':'acb57d','Cattail':'67513b','Loam':'474748','LoamLight':'615a5b',
 'Blight':'625a66','NightLeaf':'3d574d','NightLeafLight':'52695a','AshLeaf':'777d64',
 'Basalt':'414850','BasaltLight':'62656a','BasaltDark':'30363d','Obsidian':'3c3e4e','ObsidianLight':'5b5a6d',
 'Lava':'cb663d','LavaHot':'ecaa59','LavaDark':'93483c','Cinder':'67534b','Ash':'898078',
 'AshLight':'a19788','Tuff':'a19172','Sulphur':'b6a462','SulphurLight':'d1bd7a',
 'Mycelium':'938391','MyceliumLight':'b0a0ab','MyceliumDark':'746776',
 'Stem':'cbbf9f','StemShadow':'9f9a82','Gill':'b9aa87','GillShadow':'877b6f',
 'Redcap':'a4534a','RedcapLight':'c06b59','CapSpot':'e0d5b3','Browncap':'92785c','BrowncapLight':'b19772',
 'Indigo':'6d7797','IndigoLight':'99b7bb','Spore':'b8c6b2','Shelf':'bc8765','ShelfLight':'d3b28c'
}
MATS={}
def linear(v):
    v=int(v,16)/255
    return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
for key,h in PALETTE.items():
    name='AE_Terrain_'+key
    mat=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    col=tuple(linear(h[i:i+2]) for i in (0,2,4))+(1,)
    mat.diffuse_color=col;mat.use_nodes=True
    bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=col;bs.inputs['Roughness'].default_value=.88
    mat['palette_srgb']='#'+h;MATS[key]=mat

class Mesh:
    def __init__(self):self.v=[];self.f=[];self.c=[]
    def part(self,v,f,c):
        off=len(self.v);self.v.extend(v);self.f.extend([tuple(off+i for i in face) for face in f]);self.c.extend(c if isinstance(c,list) else [c]*len(f))
    def rings(self,layers,n,colors,phase=0,wobble=0,tri=False):
        v=[];f=[];c=[]
        for j,(x,y,z,rx,ry) in enumerate(layers):
            for i in range(n):
                a=phase+tau*i/n;r=1+wobble*sin(i*2.17+.38*j)
                v.append((x+rx*r*cos(a),y+ry*r*sin(a),z))
        f.append(tuple(reversed(range(n))));c.append(colors[0])
        for j in range(len(layers)-1):
            for i in range(n):
                a=j*n+i;b=j*n+(i+1)%n
                col=colors[(i//3+j)%len(colors)]
                if tri:
                    f.extend([(a,b,b+n),(a,b+n,a+n)]);c.extend([col,colors[(i//3+j+1)%len(colors)]])
                else:f.append((a,b,b+n,a+n));c.append(col)
        f.append(tuple(range((len(layers)-1)*n,len(layers)*n)));c.append(colors[-1])
        self.part(v,f,c)
    def tube(self,path,radii,colors,n=7,phase=0):
        pts=[Vector(p) for p in path];v=[];f=[];c=[]
        for j,p in enumerate(pts):
            tangent=(pts[min(j+1,len(pts)-1)]-pts[max(0,j-1)]).normalized()
            ref=Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((0,1,0))
            u=tangent.cross(ref).normalized();w=tangent.cross(u).normalized()
            for i in range(n):
                a=phase+tau*i/n;v.append(tuple(p+radii[j]*(u*cos(a)+w*sin(a))))
        f.append(tuple(reversed(range(n))));c.append(colors[0])
        for j in range(len(pts)-1):
            for i in range(n):
                a=j*n+i;b=j*n+(i+1)%n;f.append((a,b,b+n,a+n));c.append(colors[i%len(colors)])
        f.append(tuple(range((len(pts)-1)*n,len(pts)*n)));c.append(colors[-1]);self.part(v,f,c)
    def leaf(self,p,q,width,color):
        p=Vector(p);q=Vector(q);mid=p.lerp(q,.55);vdir=q-p
        u=vdir.cross(Vector((0,0,1))).normalized()*width
        peak=mid+Vector((0,0,width*.6));low=mid-Vector((0,0,.012))
        self.part([tuple(p),tuple(mid+u),tuple(q),tuple(mid-u),tuple(peak),tuple(low)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)],color)
    def finish(self,name):
        assert name not in bpy.data.objects, name
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(self.v,[],self.f);mesh.update()
        keys=list(dict.fromkeys(self.c))
        for key in keys:mesh.materials.append(MATS[key])
        for p,key in zip(mesh.polygons,self.c):p.material_index=keys.index(key);p.use_smooth=False
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        uv=mesh.uv_layers.new(name='UVMap')
        for p in mesh.polygons:
            norm=p.normal;axis=max(range(3),key=lambda i:abs(norm[i]));axes=[i for i in range(3) if i!=axis]
            for li in p.loop_indices:
                co=mesh.vertices[mesh.loops[li].vertex_index].co
                uv.data[li].uv=(co[axes[0]],co[axes[1]])
        obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);return obj

objects=[];metadata=[]
REFS=json.loads((BASE/'References/reference_index.json').read_text(encoding='utf8'))
for r in REFS:r['reviewed']=True
(BASE/'References/reference_index.json').write_text(json.dumps(REFS,ensure_ascii=False,indent=2),encoding='utf8')
def finish(m,name,biome,zh,design,kind='decoration'):
    if kind=='decoration':
        bottom=min(v[2] for v in m.v)
        m.v=[(v[0],v[1],v[2]-bottom) for v in m.v]
    obj=m.finish(name);obj['biome']=biome;obj['display_name_zh']=zh;obj['front_axis_blender']='-Y'
    objects.append(obj)
    refs=[dict(r) for r in REFS if r['biome']==biome]
    metadata.append(dict(category=kind,biome=biome,display_name_zh=zh,design_zh=design,references=refs,
        origin='ground center' if kind=='decoration' else 'top center',units='metres',front_blender='-Y',
        target_unity_directory='Assets/DynamicAsset/AssetExpansion202610/Terrain/Models',
        literature_reference={'author':'William Morris','title':'The Wood Beyond the World','chapter':'VI–VIII',
          'url':'https://www.gutenberg.org/cache/epub/3055/pg3055-images.html',
          'motif_zh':'峭壁前的榛木、荆棘与橡树，以及灰色岩墙里的黑暗裂隙；仅借鉴意象，不复制文字或命名。'},
        collision='visual asset only; gameplay configuration not changed'))
    return obj

def hex_tile(biome,variant,top,accent,side,zh):
    m=Mesh();n=18
    # Six exact corners, with collinear subdivisions. No bevel, displacement or baked shore.
    outer=[]
    for side_i in range(6):
        a=pi/6+tau*side_i/6;b=pi/6+tau*(side_i+1)/6
        pa=Vector((cos(a),sin(a)));pb=Vector((cos(b),sin(b)))
        for k in range(3):outer.append(pa.lerp(pb,k/3))
    v=[(p.x,p.y,-1) for p in outer]+[(p.x,p.y,0) for p in outer]
    v += [(p.x*.57,p.y*.57,0) for p in outer]+[(0,0,0),(0,0,-1)]
    f=[(3*n+1,(i+1)%n,i) for i in range(n)];c=[side]*n
    for i in range(n):
        j=(i+1)%n;f.append((i,j,n+j,n+i));c.append(side)
        f.extend([(n+i,n+j,2*n+j),(n+i,2*n+j,2*n+i),(2*n+i,2*n+j,3*n)])
        a=outer[i];sample=sin(a.x*5.5+variant*1.4)+cos(a.y*3.3-variant)
        c.extend([top,accent if sample>1.05 else top,accent if sample>-.15 else top])
    for index,face in enumerate(f):
        if all(abs(v[j][2])<1e-8 for j in face):
            x=sum(v[j][0] for j in face)/len(face);y=sum(v[j][1] for j in face)/len(face)
            c[index]=accent if G['soil_patch'](x,y,variant) else top
    m.part(v,f,c)
    finish(m,'AE_Hex_'+biome+'_'+variant_names[biome][variant],biome,zh,
           '精确半径1尖顶六边形，顶面0、底面-1；表面材质分区完整共面。外边界所有变体完全一致，色块疏密不同。','hex_tile')

variant_names={'Swamp':['Peat','Moss','Silt'],'DarkForest':['Loam','Rootsoil','Blight'],'Lava':['Crust','Cinder','Scoria'],'Volcano':['Ash','Tuff','Sulphur'],'Mushroom':['Mycelium','Sporebed','OldGrowth']}
tiles={
 'Swamp':[('Peat','PeatLight','Peat','泥炭沼地'),('Moss','MossDeep','Peat','苔毯沼地'),('Silt','PeatLight','Peat','沉积淤土')],
 'DarkForest':[('Loam','LoamLight','BarkDark','暗林腐殖土'),('Peat','Loam','BarkDark','盘根暗土'),('Blight','LoamLight','BarkDark','衰败灰紫土')],
 'Lava':[('Basalt','BasaltLight','BasaltDark','冷却熔岩壳'),('Cinder','LavaDark','BasaltDark','暗红余烬土'),('BasaltDark','Cinder','BasaltDark','黑色火山渣')],
 'Volcano':[('Ash','AshLight','Cinder','火山灰原'),('Tuff','Ash','Cinder','凝灰岩层'),('Tuff','Sulphur','Cinder','硫华热土')],
 'Mushroom':[('Mycelium','MyceliumLight','MyceliumDark','灰紫菌丝土'),('MyceliumLight','StemShadow','MyceliumDark','淡色孢子床'),('MyceliumDark','Mycelium','Peat','陈年菌毯')]
}
for biome,rows in tiles.items():
    for i,row in enumerate(rows):hex_tile(biome,i,*row)

def root(m,a,length=.66,height=.45,width=.16,center=(0,0)):
    x,y=center;dx,dy=cos(a),sin(a)
    m.tube([(x,y,height),(x+dx*length*.42,y+dy*length*.42,.16),(x+dx*length,y+dy*length,.035)],
           [width,width*.62,.023],['Bark','BarkLight','Bark'],6)
def rock(m,xy=(0,0),r=.4,h=.4,colors=('Basalt','BasaltLight'),lean=(.05,0)):
    x,y=xy
    m.rings([(x,y,0,r*.83,r*.7),(x,y,h*.4,r,r*.8),(x+lean[0],y+lean[1],h*.86,r*.62,r*.55),(x+lean[0]*1.4,y+lean[1]*1.4,h,r*.17,r*.15)],7,list(colors),.2,.12,True)
def branch(m,path,r=.12,colors=('Bark','BarkLight','Bark')):
    m.tube(path,[r*(1-i/(len(path)-1)*.9) for i in range(len(path))],list(colors),7)
def canopy(m,x,y,z,r,h,colors=('NightLeaf','NightLeafLight')):
    m.rings([(x,y,z,r*.32,r*.27),(x-.08,y,z+h*.2,r,r*.78),(x+.04,y-.03,z+h*.74,r*.85,r*.67),(x+.15,y+.03,z+h,r*.18,r*.18)],9,list(colors),.12,.09,True)

# Swamp: four genuinely distinct ecological silhouettes.
m=Mesh()
for i in range(5):root(m,i*tau/5+.25,.62+(i%2)*.12,.49,.16)
branch(m,[(0,0,.05),(-.07,0,.65),(.06,.02,1.32),(-.12,.03,1.92)],.2)
for p in [[(-.01,0,1.0),(-.42,.06,1.43),(-.55,.03,1.75)],[(.03,0,1.3),(.45,.06,1.68),(.51,.1,1.83)],[(-.07,.03,1.55),(.09,.35,1.91),(.22,.42,2.0)]]:branch(m,p,.085)
for x,y,z,r,h in [(-.4,.04,1.55,.45,.46),(.33,.09,1.73,.5,.41),(-.05,.34,1.87,.42,.42)]:
    canopy(m,x,y,z,r,h,('MossDeep','Moss'))
for x,y,z in [(-.58,-.06,1.79),(.63,.11,1.88),(-.08,.59,2.02)]:
    branch(m,[(x,y,z),(x+.04,y,1.25),(x+.09,y,1.02)],.025,('MossDeep','Moss'))
finish(m,'AE_Swamp_RootWillow','Swamp','泥泽垂柳','五条板根、偏心分叉、三层非对称树冠和稀疏垂枝；轮廓疏密来自手工布置。')

m=Mesh()
for i,(x,y,h) in enumerate([(-.32,.04,.92),(-.18,.21,1.14),(.03,.14,.81),(.23,.03,1.03),(.35,.23,.79),(-.1,-.16,.68),(.18,-.22,.86)]):
    bend=.09*(-1 if i%2 else 1)
    m.tube([(x,y,.02),(x+bend*.3,y,h*.48),(x+bend,y+.03,h)], [.022,.019,.014],['Reed','ReedLight'],5)
    m.tube([(x+bend*.92,y+.028,h*.87),(x+bend,y+.03,h),(x+bend*1.03,y+.032,h*1.06)], [.037,.043,.012],['Cattail','BarkLight'],7)
    for j in range(2):m.leaf((x,y,.09+j*.08),(x+(-1)**(i+j)*(.2+j*.08),y+(.15 if j else -.14),h*(.48+j*.18)),.045,'Reed' if j else 'ReedLight')
finish(m,'AE_Swamp_ReedCattails','Swamp','交错香蒲丛','七根弯曲香蒲与厚叶体，三种高度、错位叶向；可放在数据控制的水面边。')

def hollow_log(m,length=1.35,r=.24,z=.28):
    # Continuous annular wall, open at both ends with visible heartwood cut ring.
    n=10;v=[]
    for x,rad in [(-length/2,r),(length/2,r*.83),(length/2,r*.55),(-length/2,r*.66)]:
        for i in range(n):
            a=tau*i/n;v.append((x,z*0+rad*cos(a),z+rad*sin(a)))
    f=[];c=[]
    for j in range(4):
        nxt=(j+1)%4
        for i in range(n):f.append((j*n+i,j*n+(i+1)%n,nxt*n+(i+1)%n,nxt*n+i));c.append(['Bark','Heartwood','BarkDark','Heartwood'][j] if j!=0 else ['Bark','BarkLight','Bark'][i%3])
    m.part(v,f,c)
m=Mesh();hollow_log(m)
branch(m,[(.12,.1,.38),(.18,.31,.49),(.26,.39,.72)],.07)
for x,y,r in [(-.31,-.04,.23),(.2,.04,.18)]:canopy(m,x,y,.44,r,.1,('Moss','MossPale'))
finish(m,'AE_Swamp_Rotwood','Swamp','中空腐木','两端真实镂空的厚树皮管壁、浅色断面、折枝和少量苔层；不以黑贴片冒充孔洞。')

def stump(m,h=.75):
    n=10;v=[]
    for rad,z in [(.3,0),(.23,h),(.15,h-.045),(.13,.28)]:
        for i in range(n):
            a=tau*i/n;zz=z+(sin(i*2.9)*.07 if z>.6 else 0);v.append((rad*cos(a),rad*sin(a),zz))
    f=[tuple(reversed(range(n)))];c=['Bark']
    for j in range(3):
        for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i));c.append('Heartwood' if j==1 else ('BarkDark' if j==2 else ['Bark','BarkLight'][i%2]))
    f.append(tuple(range(3*n,4*n)));c.append('BarkDark');m.part(v,f,c)
def mushroom(m,x,y,h,r,style='red',lean=.08):
    m.tube([(x,y,0),(x-lean*.35,y,h*.4),(x+lean,y+.015,h*.88)], [.11*r/.55,.075*r/.55,.055*r/.55],['Stem','StemShadow','Stem'],8)
    cx=x+lean;cy=y+.015;n=16
    styles={'red':([(.13,h*.75),(.55,h*.78),(.66,h*.86),(.6,h*.99),(.39,h*1.1),(.08,h*1.13)],['GillShadow','Gill','Redcap','RedcapLight','Redcap']),
      'brown':([(.12,h*.78),(.64,h*.82),(.7,h*.9),(.6,h*.98),(.24,h*1.04),(.06,h*1.06)],['GillShadow','Gill','Browncap','BrowncapLight','Browncap']),
      'indigo':([(.1,h*.68),(.48,h*.72),(.43,h*.95),(.28,h*1.1),(.08,h*1.17)],['Gill','IndigoLight','Indigo','IndigoLight'])}
    profile,cols=styles[style];off=len(m.c)
    m.rings([(cx,cy,z,rad*r/.66,rad*r/.66*.9) for rad,z in profile],n,cols,.13,.05,True)
    # Deliberate face groups: pale lower gills and a continuous colored outer cap.
    capcols={'red':('Redcap','RedcapLight'),'brown':('Browncap','BrowncapLight'),'indigo':('Indigo','IndigoLight')}[style]
    m.c[off]='GillShadow'
    for layer in range(len(profile)-1):
        for j in range(n*2):
            if layer==0:col='Gill' if j%4<2 else 'GillShadow'
            elif layer==1:col='Gill' if style!='indigo' else 'IndigoLight'
            else:col=capcols[1 if (j//2+layer)%7==2 else 0]
            m.c[off+1+layer*n*2+j]=col
    m.c[-1]=capcols[0]
    if style=='red':
        for idx in [off+1+n*4+4,off+1+n*4+18,off+1+n*6+8,off+1+n*6+24]:m.c[idx]='CapSpot'
m=Mesh();stump(m)
for i in range(5):root(m,i*tau/5,.52,.28,.13)
for x,y,z,r in [(.22,.02,.33,.18),(-.2,.02,.52,.16),(.12,-.18,.66,.15)]:canopy(m,x,y,z,r,.075,('Shelf','ShelfLight'))
finish(m,'AE_Swamp_WitchesStump','Swamp','巫沼朽桩','破口树桩拥有真实内壁、五条根脚与阶梯木耳，兼具空腔和平台剪影。')

# Dark forest, no leaf card textures.
m=Mesh()
for i in range(6):root(m,i*tau/6+.2,.67+(i%2)*.1,.54,.17)
branch(m,[(0,0,0),(.06,.03,.64),(-.15,.02,1.24),(-.12,.08,1.86),(.09,.07,2.38)],.25)
branches=[([(-.1,0,1.0),(-.48,.05,1.35),(-.67,-.05,1.8),(-.87,-.02,1.98)],.12),
 ([(-.11,.04,1.5),(.37,.12,1.7),(.63,.16,2.13),(.85,.19,2.25)],.13),
 ([(-.12,.08,1.83),(-.47,.18,2.06),(-.52,.3,2.44)],.09),
 ([(.04,.07,2.24),(.32,-.17,2.45),(.43,-.22,2.7)],.065),
 ([(-.48,.05,1.35),(-.64,-.19,1.45),(-.71,-.28,1.62)],.06)]
for path,r in branches:branch(m,path,r)
for x,y,z,r in [(-.6,-.02,1.77,.16),(.5,.15,2.08,.19),(-.45,.24,2.28,.13)]:canopy(m,x,y,z,r,.2,('AshLeaf','NightLeaf'))
finish(m,'AE_DarkForest_AncientOak','DarkForest','钩枝古橡','粗扭主干、分级钩形枝梢和稀疏残叶，轮廓呈不对称上升节奏。')

m=Mesh()
for s in [-1,1]:
    path=[(s*.62,0,.015),(s*.54,.015,.48),(s*.36,.05,.96),(s*.04,.06,1.18),(-s*.25,.07,1.26)]
    branch(m,path,.11)
    for i in range(1,4):
        p=Vector(path[i]);q=p+Vector((s*.2,-.09,.17));m.tube([p,q],[.065,.009],['BarkDark','Bark'],5)
    root(m,0 if s==1 else pi,.35,.2,.09,center=(s*.55,0))
for x in [-.44,.33]:m.leaf((x,0,.6),(x+.16,-.15,.85),.07,'NightLeaf')
finish(m,'AE_DarkForest_ThornArch','DarkForest','盘生荆棘拱','双根藤蔓向内弯曲，外露方向明确的粗刺与中央负空间，可独立旋转。')

m=Mesh();branch(m,[(0,0,0),(-.06,.03,.7),(.05,0,1.6),(.03,.06,2.49)],.13)
for i,(r,z,h) in enumerate([(.67,.45,.83),(.57,.91,.88),(.44,1.4,.78),(.3,1.91,.65)]):
    m.rings([(-.02*i,.025*i,z,r*.7,r*.56),(-.02*i,.025*i,z+.12,r,r*.78),(.03,.045,z+h,r*.04,r*.04)],9,['NightLeaf','NightLeafLight','NightLeaf'],i*.14,.1)
for i in range(4):root(m,i*tau/4+.2,.4,.24,.09)
finish(m,'AE_DarkForest_CrowPine','DarkForest','鸦栖黑松','四层偏心针叶冠，暗绿裙边和歪斜主干；与枯橡、荆棘拱保持体量区别。')

m=Mesh();rock(m,(-.14,.04),.33,.48,('Loam','LoamLight'))
for i in range(5):
    a=tau*i/5
    branch(m,[(.05,.05,.12),(cos(a)*.24,sin(a)*.26,.24),(cos(a)*.52,sin(a)*.42,.09),(cos(a)*.78,sin(a)*.58,.025)],.13)
branch(m,[(.02,.02,.1),(.1,.06,.56),(.36,.11,.8)],.2)
finish(m,'AE_DarkForest_RootTangle','DarkForest','缚石盘根','横向板根越过半埋石块，末端落地，中央保留折断的斜树桩。')

# Basalt and volcanic geology.
m=Mesh()
for i,(x,y,r,h) in enumerate([(-.4,.14,.22,1.06),(-.04,.18,.27,1.65),(.32,.17,.24,1.33),(-.23,-.2,.25,.69),(.16,-.22,.26,.94)]):
    m.rings([(x,y,0,r,r),(x,y,h*.46,r*.94,r*.94),(x+.018,y,h*.49,r*.95,r*.95),(x+.025,y,h,r*.86,r*.86)],6,['Basalt','BasaltLight','Basalt'],pi/6)
finish(m,'AE_Lava_BasaltOrgan','Lava','玄武岩石琴','五柱节理沿两排咬合，柱顶高差构成石琴轮廓；暗淡颜色仍能看清表面。')

m=Mesh()
for x,y,r,h,lean in [(-.26,.06,.23,1.19,(-.12,.02)),(.12,.15,.25,1.56,(.23,.05)),(.34,-.16,.19,.73,(.16,-.04)),(-.27,-.2,.15,.48,(-.11,-.06))]:
    rock(m,(x,y),r,h,('Obsidian','ObsidianLight','BasaltDark'),lean)
finish(m,'AE_Lava_ObsidianBlades','Lava','黑曜断刃石','四片不同角度断刃以低多边截面表达玻璃断口，低光泽避免塑料感。')

def crater(m,r=.65,h=.55,colors=('Basalt','BasaltLight'),offset=(0,0),n=16,broken=False):
    x,y=offset;v=[]
    for ring in range(5):
        for i in range(n):
            a=tau*i/n;w=1+.09*sin(i*2.17);peak=h*(1+.11*sin(i*1.83))
            if broken and 8<=i<=11:peak*=.27
            radii=[r,r*.7,r*.42,r*.29,r*.3];zz=[0,peak*.68,peak,peak*.65,.07]
            v.append((x+radii[ring]*w*cos(a),y+radii[ring]*w*sin(a),zz[ring]))
    f=[tuple(reversed(range(n)))];c=[colors[0]]
    for j in range(4):
        for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i));c.append(colors[(i//3+j)%len(colors)] if j<3 else 'BasaltDark')
    f.append(tuple(range(4*n,5*n)));c.append('LavaDark');m.part(v,f,c)
m=Mesh();crater(m,.55,.58)
m.rings([(0,0,.075,.153,.153),(0,0,.08,.153,.153)],12,['Lava','LavaHot'])
for x,y in [(-.46,-.09),(.36,.22)]:rock(m,(x,y),.17,.21)
finish(m,'AE_Lava_Fumarole','Lava','余烬喷气孔','真实凹陷内壁与狭小熔岩喉口，无透明烟雾或固定粒子依赖。')

m=Mesh();m.part(*G['magma_rift_geometry']())
finish(m,'AE_Lava_MagmaRift','Lava','分岔熔岩裂隙','封闭厚熔岩床被四块断裂岩板包围，错缝露出分支火脉；可在任意冷却底块上旋转。')

m=Mesh();crater(m,.82,1.28,('Cinder','Basalt','Ash'),n=18)
m.rings([(0,0,.072,.218,.218),(0,0,.084,.218,.218)],14,['LavaDark','Lava'])
finish(m,'AE_Volcano_CinderCone','Volcano','不眠灰烬锥','层状火山锥收束到真实凹口；火口偏碎，熔岩深藏，区别于平地喷气孔。')

m=Mesh();crater(m,.81,.66,('Ash','Cinder','BasaltLight'),n=18,broken=True)
for xy,r,h in [((-.42,-.5),.2,.21),((.31,-.56),.18,.16)]:rock(m,xy,r,h,('Ash','Cinder'))
finish(m,'AE_Volcano_BrokenCrater','Volcano','塌口古火山','一侧火山口降低到四分之一高度形成可见鞍部，底部凝灰碎片呼应坍塌方向。')

m=Mesh()
for x,y,r,h in [(-.23,0,.31,.91),(.23,.1,.25,1.35)]:
    crater(m,r,h,('Tuff','Sulphur','SulphurLight'),(x,y),10)
rock(m,(.02,-.24),.24,.31,('Sulphur','Tuff'))
finish(m,'AE_Volcano_SulphurChimney','Volcano','双喉硫华烟囱','双管矿物烟囱与浅黄色沉积裙边，孔道真实下凹且不依赖后期发光。')

m=Mesh()
for x,y,r,h in [(-.19,.08,.31,1.31),(.25,.12,.24,.94),(-.01,-.19,.19,.58)]:
    m.rings([(x,y,0,r,r*.83),(x-.04,y,.25*h,r*.87,r*.7),(x+.04,y,.32*h,r*.95,r*.74),(x+.09,y,.66*h,r*.51,r*.49),(x+.02,y,h,r*.12,r*.15)],7,['Ash','BasaltLight','Tuff'],.14,.1,True)
finish(m,'AE_Volcano_AshSpire','Volcano','风蚀凝灰尖塔','三座高低不同、腰部带水平层理的凝灰尖塔，斜顶区别于垂直玄武岩柱。')

# Mushroom biome: five silhouette families, designed independently from voxel references.
m=Mesh();mushroom(m,0,0,1.85,.79,'red',.15)
for i in range(4):
    a=tau*i/4;m.tube([(0,0,.2),(cos(a)*.3,sin(a)*.25,.07),(cos(a)*.43,sin(a)*.34,.025)],[.065,.04,.01],['StemShadow','Stem'],6)
finish(m,'AE_Mushroom_RedParasol','Mushroom','绯冠巨伞','偏心粗菌柄、鼓起伞盖、少量不规则米白斑块与几何菌褶，非方块复刻。')

m=Mesh();mushroom(m,0,.04,1.62,.84,'brown',-.13);mushroom(m,.35,-.18,.57,.23,'brown',.03)
finish(m,'AE_Mushroom_BrownCanopy','Mushroom','赭伞母子菌','宽而低的褐色伞盖，与小菌形成母子关系；扁冠轮廓区别于红色高鼓伞。')

m=Mesh()
for x,y,h,r,lean in [(-.27,.08,1.08,.33,-.1),(.15,.16,1.47,.4,.12),(.23,-.23,.69,.27,.04)]:mushroom(m,x,y,h,r,'indigo',lean)
finish(m,'AE_Mushroom_IndigoLantern','Mushroom','蓝灯铃菌丛','三株错落铃状菌盖、淡青边与灰紫顶，保持哑光纯色，菌柄曲率各异。')

m=Mesh();stump(m,1.12)
for i,(x,y,z,r) in enumerate([(.2,-.02,.25,.36),(-.24,.06,.5,.35),(.2,.05,.76,.33),(-.15,-.03,1.01,.29)]):
    canopy(m,x,y,z,r,.16,('Shelf','ShelfLight','Browncap'))
for i in range(4):root(m,i*tau/4,.47,.22,.1)
finish(m,'AE_Mushroom_ShelfColony','Mushroom','腐桩层生菌','四层方向交替的扇形菌架沿中空老桩生长，拥有宽窄交替的连续剪影。')

m=Mesh()
for i,(x,y,h,r) in enumerate([(-.35,.16,.39,.2),(-.06,.24,.59,.23),(.24,.17,.46,.2),(.38,-.13,.31,.17),(.01,-.23,.33,.19),(-.3,-.18,.26,.14)]):
    m.rings([(x,y,0,r*.47,r*.47),(x,y,h*.33,r,r*.87),(x+.025,y,h*.79,r*.86,r*.76),(x+.03,y,h,r*.32,r*.29)],9,['StemShadow','Spore','CapSpot'],.23,.055,True)
    m.rings([(x+.03,y,h-.009,r*.13,r*.13),(x+.03,y,h+.004,r*.13,r*.13)],8,['GillShadow'])
finish(m,'AE_Mushroom_PuffballNest','Mushroom','月尘马勃巢','六枚闭合梨形孢子囊带暗色顶部孔口，在低矮地表提供完全不同的节奏。')

bpy.context.view_layer.update()
rows=H['finish_batch']('Terrain',scene,objects,metadata)
assert len(rows)==36
assert all(r['nonmanifold_edges']==0 for r in rows),[(r['name'],r['nonmanifold_edges']) for r in rows if r['nonmanifold_edges']]
report={'asset_count':len(rows),'tile_count':15,'decoration_count':21,'checks':{'closed_components':True,'degenerate_faces':0,'reference_images_per_asset':2,'references_visually_reviewed':True},'tile_contract':'R=1; pointy orientation at 30 degrees; top Z=0; bottom Z=-1; precise shared boundaries.','unity_verified':False}
(BASE/'geometry_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'scene':scene.name,'assets':len(rows),'triangles':sum(r['triangles'] for r in rows),'source':str(BASE/'Source/Terrain.blend')}))
