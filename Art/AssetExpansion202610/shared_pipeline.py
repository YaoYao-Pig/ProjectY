"""Asset-only helpers. Execute in Blender via MCP; never touches existing scenes."""
import bpy, bmesh, json, math, runpy
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/Program/Unity/Project Y')
BASE = ROOT / 'Art/AssetExpansion202610'

def create_scene(group):
    name = 'AE202610_' + group
    assert name not in bpy.data.scenes, name
    scene = bpy.data.scenes.new(name)
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    collection = bpy.data.collections.new(name + '_Masters')
    scene.collection.children.link(collection)
    bpy.context.window.scene = scene
    for d in ['Source','Staging','Previews','References']:
        (BASE/group/d).mkdir(parents=True, exist_ok=True)
    return scene, collection

def finish_batch(group, scene, objects, metadata):
    export = runpy.run_path(str(ROOT/'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
    rows=[]
    bpy.context.window.scene=scene
    bpy.context.view_layer.update()
    for obj, info in zip(objects, metadata):
        assert obj.location.length < 1e-8 and obj.scale == Vector((1,1,1))
        mesh=obj.data; mesh.calc_loop_triangles()
        bm=bmesh.new();bm.from_mesh(mesh)
        bad_edges=sum(not e.is_manifold for e in bm.edges)
        zero_faces=sum(f.calc_area()<1e-12 for f in bm.faces)
        bm.free()
        assert zero_faces == 0, (obj.name, 'degenerate faces', zero_faces)
        row=dict(info,name=obj.name,dimensions_blender_xyz=list(obj.dimensions),
                 triangles=len(mesh.loop_triangles),nonmanifold_edges=bad_edges,
                 degenerate_faces=zero_faces,uv_layers=len(mesh.uv_layers),
                 materials=[m.name for m in mesh.materials],
                 export=export(obj.name,str(BASE/group/'Staging'/(obj.name+'.fbx')),overwrite=True))
        rows.append(row)
    used={m.name:m for o in objects for m in o.data.materials}
    palette=[]
    for name, mat in used.items():
        node=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None) if mat.use_nodes else None
        palette.append(dict(name=name,color_linear=list(mat.diffuse_color),
                            roughness=float(node.inputs['Roughness'].default_value) if node else .85,
                            metallic=float(node.inputs['Metallic'].default_value) if node else 0,
                            palette_srgb=mat.get('palette_srgb','')))
    (BASE/group/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
    (BASE/group/'materials.json').write_text(json.dumps(palette,indent=2),encoding='utf8')
    bpy.data.libraries.write(str(BASE/group/'Source'/(group+'.blend')),{scene},fake_user=True,compress=True)
    return rows

def setup_review(group):
    name='AE202610_Review_'+group
    if name in bpy.data.scenes:
        return bpy.data.scenes[name]
    scene=bpy.data.scenes.new(name)
    scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=512;scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.film_transparent=False
    scene.view_settings.view_transform='Standard'
    scene.view_settings.look='None'
    scene.world=bpy.data.worlds.new(name+'_World')
    scene.world.use_nodes=True
    bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.065,.077,.095,1)
    bg.inputs['Strength'].default_value=.8
    for suffix,pos,power,size in [('Key',(-3,-4,6),850,5),('Fill',(4,-1,3),500,4),('Rim',(0,4,5),700,3)]:
        d=bpy.data.lights.new(name+suffix,'AREA');d.energy=power;d.size=size
        o=bpy.data.objects.new(name+suffix,d);scene.collection.objects.link(o)
        o.location=pos;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    d=bpy.data.cameras.new(name+'_Camera');d.type='ORTHO'
    c=bpy.data.objects.new(name+'_Camera',d);scene.collection.objects.link(c);scene.camera=c
    return scene

def render_asset(group, name, views=('front','side','back','hero'), framing_scale=1.32):
    scene=setup_review(group);bpy.context.window.scene=scene
    source=bpy.data.objects[name]
    obj=source.copy();obj.data=source.data;scene.collection.objects.link(obj)
    obj.location=(0,0,0);obj.hide_render=False
    corners=[Vector(v) for v in obj.bound_box]
    lo=Vector(tuple(min(v[i] for v in corners) for i in range(3)))
    hi=Vector(tuple(max(v[i] for v in corners) for i in range(3)))
    center=(lo+hi)/2;span=max(hi-lo)
    # Normalize only the review copy; export and source remain in metres.
    obj.scale=(1/span,)*3;obj.location=-center/span
    scene.camera.data.ortho_scale=framing_scale
    camera_locations={'front':(0,-4,0),'side':(4,0,0),'back':(0,4,0),'hero':(2.6,-4,2.6),'top':(0,0,4)}
    paths=[]
    try:
        for view in views:
            c=scene.camera;c.location=camera_locations[view]
            c.rotation_euler=(-c.location).to_track_quat('-Z','Y').to_euler()
            path=BASE/group/'Previews'/(name+'_'+view+'.png')
            scene.render.filepath=str(path)
            bpy.ops.render.render(write_still=True,scene=scene.name)
            paths.append(str(path))
    finally:
        bpy.data.objects.remove(obj,do_unlink=True)
    return paths

def render_range(group,start,end):
    rows=json.loads((BASE/group/'manifest.json').read_text(encoding='utf8'))
    result=[]
    for row in rows[start:end]:
        result.append(dict(name=row['name'],paths=render_asset(group,row['name'])))
    print(json.dumps(result))
