"""Run in Blender through Blender MCP. Only owns the Dice_Source scene."""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/Program/Unity/Project Y')
OUT = ROOT / 'Art/Dice/Export'
OUT.mkdir(parents=True, exist_ok=True)
if bpy.data.scenes.get('Dice_Source'):
    raise RuntimeError('Dice_Source already exists; inspect before rebuilding')
scene = bpy.data.scenes.new('Dice_Source')
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
collection = bpy.data.collections.new('Dice_Models')
scene.collection.children.link(collection)
bpy.context.window.scene = scene

def material(name, color, metallic, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1)
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    return mat

body_mat = material('Dice_Obsidian', (.025, .047, .065), .45, .27)
gold_mat = material('Dice_Gold', (.83, .52, .19), .78, .22)
gem_mat = material('Dice_Aether', (.025,.45,.7), .35, .15)
gem_shader = next(n for n in gem_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
gem_shader.inputs['Emission Color'].default_value = (.015,.32,.65,1)
gem_shader.inputs['Emission Strength'].default_value = 1.6
number_font = bpy.data.fonts.load('C:/Windows/Fonts/georgiab.ttf')
palette = {4:(.095,.012,.032),6:(.025,.045,.10),8:(.012,.085,.057),10:(.012,.063,.105),12:(.065,.022,.12),20:(.018,.035,.12)}

def hull(name, points):
    bm = bmesh.new()
    vertices = [bm.verts.new(p) for p in points]
    bmesh.ops.convex_hull(bm, input=vertices)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.normal_update()
    bmesh.ops.dissolve_limit(bm, angle_limit=0.001, verts=list(bm.verts), edges=list(bm.edges))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return mesh

def dual(mesh, name):
    return hull(name, [p.normal / p.normal.dot(p.center) for p in mesh.polygons])

phi = (1 + math.sqrt(5)) / 2
ico = hull('Icosahedron', [(0,a,b*phi) for a in (-1,1) for b in (-1,1)] +
           [(a,b*phi,0) for a in (-1,1) for b in (-1,1)] + [(b*phi,0,a) for a in (-1,1) for b in (-1,1)])
anti = hull('PentagonalAntiprism', [(math.cos(i*math.pi/5),math.sin(i*math.pi/5),.5 if i%2==0 else -.5) for i in range(10)])
meshes = {
    4: hull('Tetrahedron',[(1,1,1),(1,-1,-1),(-1,1,-1),(-1,-1,1)]),
    6: hull('Cube',[(x,y,z) for x in (-1,1) for y in (-1,1) for z in (-1,1)]),
    8: hull('Octahedron',[(s if a==0 else 0,s if a==1 else 0,s if a==2 else 0) for a in range(3) for s in (-1,1)]),
    10: dual(anti,'Trapezohedron'),
    12: dual(ico,'Dodecahedron'),
    20: ico,
}

def vec(value):
    # FBX -Z forward / Y up, baked axis conversion into mesh.
    return dict(x=round(value.x,7),y=round(value.z,7),z=round(-value.y,7))

def label(parent, text, position, normal, up, size):
    curve = bpy.data.curves.new(parent.name+'_Number','FONT')
    curve.body = text
    curve.font = number_font
    curve.align_x = 'CENTER'
    curve.align_y = 'CENTER'
    curve.size = size
    curve.extrude = .0015
    curve.bevel_depth = .0004
    curve.resolution_u = 3
    obj = bpy.data.objects.new(parent.name+'_Number_'+text,curve)
    collection.objects.link(obj)
    obj.parent = parent
    obj.location = position
    right = up.cross(normal).normalized()
    from mathutils import Matrix
    obj.rotation_euler = Matrix((right,up,normal)).transposed().to_euler()
    curve.materials.append(gold_mat)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = bpy.data.meshes.new_from_object(evaluated)
    result = bpy.data.objects.new(obj.name+'_Mesh',mesh)
    collection.objects.link(result)
    result.parent = parent
    result.matrix_basis = obj.matrix_basis.copy()
    bpy.data.objects.remove(obj,do_unlink=True)
    return result

def ornament(parent, center, normal, points):
    vertices, polygons = [], []
    def band(outer, inner):
        start = len(vertices)
        for factor in (outer,inner):
            vertices.extend([center+(p-center)*factor+normal*.004 for p in points])
        n = len(points)
        for i in range(n): polygons.append((start+i,start+(i+1)%n,start+n+(i+1)%n,start+n+i))
    band(.88,.80)
    band(.735,.722)
    # A small arrowhead at each corner; the center stays clear for the reading.
    for p in points:
        radial=(p-center).normalized();side=radial.cross(normal).normalized()
        at=center+(p-center)*.77+normal*.005
        start=len(vertices)
        vertices.extend([at+radial*.04,at+side*.02,at-radial*.035,at-side*.02])
        polygons.append(tuple(range(start,start+4)))
    mesh=bpy.data.meshes.new(parent.name+'_Inlay')
    mesh.from_pydata(vertices,[],polygons);mesh.materials.append(gold_mat)
    obj=bpy.data.objects.new(mesh.name,mesh);collection.objects.link(obj);obj.parent=parent

def vertex_jewels(parent, source):
    verts,faces=[],[]
    for vertex in source.vertices:
        axis=vertex.co.normalized();up=axis.orthogonal().normalized();right=axis.cross(up).normalized()
        center=vertex.co*.955;start=len(verts);radius=.035
        verts.extend([center+axis*.025,center+up*radius,center+right*radius,center-up*radius,center-right*radius])
        faces.extend([(start,start+i,start+(i%4)+1) for i in range(1,5)])
    mesh=bpy.data.meshes.new(parent.name+'_Jewels');mesh.from_pydata(verts,[],faces);mesh.materials.append(gem_mat)
    obj=bpy.data.objects.new(mesh.name,mesh);collection.objects.link(obj);obj.parent=parent

manifest = []
for sides in (4,6,8,10,12,20):
    source = meshes[sides]
    scale = .72 / max(v.co.length for v in source.vertices)
    for v in source.vertices:
        v.co *= scale
    source.update()
    assert len(source.polygons)==sides, (sides,len(source.polygons))
    # Pair opposite faces to sum to N+1 (D10: 9); D4 uses the opposite apex.
    remaining = set(range(sides))
    values = {}
    low = 0 if sides==10 else 1
    high = sides-1 if sides==10 else sides
    while remaining:
        index = min(remaining)
        remaining.remove(index)
        values[index] = low
        low += 1
        if sides!=4:
            opposite = min(remaining, key=lambda j:source.polygons[index].normal.dot(source.polygons[j].normal))
            remaining.remove(opposite)
            values[opposite] = high
            high -= 1
    variants = ('D10','D100') if sides==10 else ('D'+str(sides),)
    for name in variants:
        root = bpy.data.objects.new(name,None)
        collection.objects.link(root)
        mesh = source.copy()
        mesh.name = name+'_Hull'
        body = bpy.data.objects.new(name+'_Body',mesh)
        collection.objects.link(body)
        body.parent = root
        mesh.materials.append(material(name+'_Enamel',palette[sides],.5,.23))
        mesh.materials.append(gold_mat)
        bevel = body.modifiers.new('Fine gold bevel','BEVEL')
        bevel.width = .032
        bevel.segments = 3
        bevel.material = 1
        faces = []
        polygons = [(p.index,p.normal.copy(),p.center.copy(),[mesh.vertices[i].co.copy() for i in p.vertices]) for p in mesh.polygons]
        vertex_jewels(root,source)
        for index,normal,center,points in polygons:
            ornament(root,center,normal,points)
            anchor = max(points,key=lambda v:v.length_squared) if sides==10 else points[0]
            up = (anchor-center).normalized()
            value = values[index]
            faces.append(dict(value=value*10 if name=='D100' else value, normal=vec(normal), up=vec(up),
                              axis=vec(-normal if sides==4 else normal)))
            for suffix, direction in [('Normal',normal),('Up',up),('Axis',-normal if sides==4 else normal)]:
                marker = bpy.data.objects.new(f'{name}_Face_{faces[-1]["value"]}_{suffix}',None)
                collection.objects.link(marker)
                marker.parent = root
                marker.location = direction
                marker.empty_display_size = .04
            if sides==4:
                # Three readings per face, each near its vertex. The upper apex is the result.
                for point in points:
                    opposite = min(polygons,key=lambda p:p[1].dot(point))
                    digit = values[opposite[0]]
                    toward = (point-center).normalized()
                    label(root,str(digit),center+(point-center)*.53+normal*.003,normal,toward,.20)
            else:
                text = f'{value*10:02d}' if name=='D100' else str(value)
                if value in (6,9) and name!='D100': text += '.'
                size = {6:.42,8:.29,10:.27,12:.30,20:.23}[sides]
                label(root,text,center+normal*.003,normal,up,size)
        # Collider is exported separately without text or bevels.
        collider = bpy.data.objects.new(name+'_Collider',source.copy())
        collection.objects.link(collider)
        collider.parent = root
        collider.hide_render = True
        collider.display_type = 'WIRE'
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        for child in root.children: child.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.export_scene.fbx(filepath=str(OUT/(name+'.fbx')),use_selection=True,object_types={'EMPTY','MESH'},
            axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',
            bake_space_transform=True,use_mesh_modifiers=True,use_triangles=True,bake_anim=False,add_leaf_bones=False)
        manifest.append(dict(name=name,sides=sides,faces=faces,vertices=[vec(v.co) for v in source.vertices]))
        root.location.x = (len(manifest)-1)*1.8

(OUT/'dice.json').write_text(json.dumps(dict(dice=manifest),indent=2),encoding='utf-8')
bpy.data.libraries.write(str(ROOT/'Art/Dice/DiceSet.blend'),{scene},fake_user=True)
print(json.dumps({'scene':scene.name,'models':[d['name'] for d in manifest], 'source':str(ROOT/'Art/Dice/DiceSet.blend'),
                  'exports':[str(OUT/(d['name']+'.fbx')) for d in manifest]}))
