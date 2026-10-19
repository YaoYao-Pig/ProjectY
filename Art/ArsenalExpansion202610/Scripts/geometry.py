"""Pure low-poly geometry helpers shared by this arsenal's Blender authoring scripts."""
import bpy,math,runpy
from mathutils import Vector
helpers=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py')
PALETTE=dict(helpers['PALETTE'],EqBronze='b29a65',EqIron='424e52',EqCyan='55c3be',EqAmber='e0a756',EqRuby='c65352',EqJade='80ac64',EqViolet='9a81be')
helpers['PALETTE'].update(PALETTE)
Mesh=helpers['MeshBuilder']
for key,hex_color in PALETTE.items():
    if 'M_MapLP_'+key in bpy.data.materials:continue
    material=bpy.data.materials.new('M_MapLP_'+key);material.use_nodes=True
    node=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    sockets={s.identifier:s for s in node.inputs}
    rgba=tuple(helpers['srgb_linear'](int(hex_color[i:i+2],16)/255) for i in (0,2,4))+(1,)
    sockets['Base Color'].default_value=rgba;sockets['Metallic'].default_value=.15 if key.startswith('Eq') else 0
    sockets['Roughness'].default_value=.7;material.diffuse_color=rgba;material['palette_srgb']='#'+hex_color

def beam(m,a,b,r,material='EqIron',sides=8,taper=1):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)))
    if u.length<.01:u=axis.cross(Vector((0,1,0)))
    u.normalize();v=axis.cross(u)
    points=[tuple(c+r*k*(math.cos(i*math.tau/sides)*u+math.sin(i*math.tau/sides)*v)) for c,k in ((a,1),(b,taper)) for i in range(sides)]
    m.part(points,[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]+[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)],material)

def ring(m,center,radius,tube=.012,material='EqBronze',normal=(0,0,1),sides=12,start=0,sweep=math.tau):
    center,axis=Vector(center),Vector(normal).normalized();u=axis.cross(Vector((0,0,1)))
    if u.length<.01:u=axis.cross(Vector((0,1,0)))
    u.normalize();v=axis.cross(u)
    closed=abs(sweep-math.tau)<1e-6;n=sides if closed else sides+1
    points=[]
    for j in range(n):
        a=start+sweep*j/sides;radial=u*math.cos(a)+v*math.sin(a)
        for i in range(4):
            t=i*math.pi/2;points.append(tuple(center+radial*(radius+tube*math.cos(t))+axis*tube*math.sin(t)))
    faces=[]
    for j in range(sides):
        for i in range(4):faces.append((j*4+i,j*4+(i+1)%4,((j+1)%n)*4+(i+1)%4,((j+1)%n)*4+i))
    if not closed:faces += [tuple(reversed(range(4))),tuple(range(sides*4,(sides+1)*4))]
    m.part(points,faces,material)

def crystal(m,center,radius,height,material='EqCyan',axis=(0,0,1)):
    center,axis=Vector(center),Vector(axis).normalized();u=axis.cross(Vector((0,1,0)))
    if u.length<.01:u=axis.cross(Vector((1,0,0)))
    u.normalize();v=axis.cross(u)
    points=[tuple(center-axis*height*.45)]+[tuple(center+radius*(u*math.cos(i*math.pi/3)+v*math.sin(i*math.pi/3))) for i in range(6)]+[tuple(center+axis*height*.55)]
    m.part(points,[(0,1+(i+1)%6,1+i) for i in range(6)]+[(7,1+i,1+(i+1)%6) for i in range(6)],material)

def plate(m,outline,y,depth,material):
    n=len(outline);points=[(x,y+s*depth/2,z) for s in (-1,1) for x,z in outline]
    m.part(points,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],material)

def lathe(m,rings,material,x=0,y=0,sides=8):
    points=[(x+r*math.cos(i*math.tau/sides),y+r*math.sin(i*math.tau/sides),z) for z,r in rings for i in range(sides)]
    faces=[tuple(reversed(range(sides))),tuple(range((len(rings)-1)*sides,len(rings)*sides))]
    for j in range(len(rings)-1):faces += [(j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i) for i in range(sides)]
    m.part(points,faces,material)

def blade(m,stations,depth,colors=('RockLight','EqIron'),x=0,y=0):
    points=[]
    for z,width in stations:points.extend([(x-width/2,y,z),(x,y-depth,z),(x+width/2,y,z),(x,y+depth,z)])
    faces=[(3,2,1,0)];materials=[colors[0]]
    for j in range(len(stations)-1):
        for i in range(4):faces.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i));materials.append(colors[i%len(colors)])
    faces.append(tuple(range((len(stations)-1)*4,len(stations)*4)));materials.append(colors[0]);m.part(points,faces,materials)

def grip(m,low=-.17,high=.18,r=.046,material='Timber'):
    beam(m,(0,0,low),(0,0,high),r,material)
    z=low+.03
    while z<high:
        beam(m,(0,0,z),(0,0,z+.012),r+.003,'EqBronze' if material=='Window' else 'EqIron',8);z+=.052
    beam(m,(0,0,low-.055),(0,0,low+.01),r*1.4,'EqBronze',8,.8)

def collar(m,z=0,r=.067):
    for h in (z-.045,z+.025):ring(m,(0,0,h),r,.014)
    for x in (-r,r):beam(m,(x,0,z-.045),(x,0,z+.025),.009)

def shaft_mount(m):
    collar(m,-.10,.061);collar(m,.10,.061);beam(m,(0,-.064,-.15),(0,-.064,.15),.019)

def rear_mount(m,width=.19,height=.25):
    m.box((0,.025,0),(width,.055,height),'EqIron')
    for z in (-height*.38,height*.38):m.box((0,.055,z),(width+.03,.025,.025),'EqBronze')

def rail_mount(m):
    # The rail socket is model-local. Components project toward -Y, away from the host.
    m.box((0,.015,0),(.08,.045,.21),'EqIron')
    for z in (-.075,.075):m.box((0,-.014,z),(.11,.020,.026),'EqBronze')

def edge_mount(m):
    m.box((0,.015,0),(.10,.04,.18),'EqIron')
    for z in (-.06,.06):m.box((0,-.015,z),(.16,.022,.018),'EqBronze')

def gear(m,center,radius,material='EqIron',teeth=10,depth=.035):
    x,y,z=center;outline=[]
    for i in range(teeth):
        for j,r in ((0,radius*.80),(1,radius),(2,radius),(3,radius*.80)):
            a=math.tau*(i+j/4)/teeth;outline.append((x+r*math.cos(a),z+r*math.sin(a)))
    plate(m,outline,y,depth,material)
