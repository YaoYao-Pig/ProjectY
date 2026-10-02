"""Update only the mast mesh, FBX and its records; preserve other source assets."""
import bpy,bmesh,json,runpy
from pathlib import Path
root=Path(__file__).parent
builder=runpy.run_path(str(root/'build_structure.py'))
name='S2_Mast_Tall';old_scene=bpy.context.window.scene
try:
    scene=bpy.data.scenes['AE202610_ShipwreckV2'];col=bpy.data.collections['AE202610_ShipwreckV2_Masters']
    bpy.context.window.scene=scene
    target=bpy.data.objects[name];old_mesh=target.data;mesh_name=old_mesh.name
    m=builder['Mesh']();builder['mast'](m)
    replacement=m.finish(name+'_SailRevision',col);target.data=replacement.data
    target['palette_srgb']=replacement['palette_srgb']
    bpy.data.objects.remove(replacement,do_unlink=True)
    if old_mesh.users==0:bpy.data.meshes.remove(old_mesh)
    target.data.name=mesh_name;bpy.context.view_layer.update()
    mesh=target.data;mesh.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(mesh)
    nonmanifold=sum(not e.is_manifold for e in bm.edges);degenerate=sum(f.calc_area()<1e-12 for f in bm.faces);bm.free()
    assert nonmanifold==0 and degenerate==0
    cloth_slot=next(i for i,mat in enumerate(mesh.materials) if mat.name=='M_MapLP_SWCloth')
    cloth_ids={i for p in mesh.polygons if p.material_index==cloth_slot for i in p.vertices}
    cloth=[mesh.vertices[i].co for i in cloth_ids]
    geometry=dict(sail_width=max(v.x for v in cloth)-min(v.x for v in cloth),sail_height=max(v.z for v in cloth)-min(v.z for v in cloth),
                  minimum_cloth_height_above_deck=min(v.z for v in cloth),mast_height=target.dimensions.z,
                  measurement='actual Blender cloth vertices; final FBX whole bounds checked in Unity')
    (root/'Integration/sail_geometry.json').write_text(json.dumps(geometry,indent=2),encoding='utf8')
    export=runpy.run_path(str(root.parent.parent/'MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
    info=export(name,str(root/'Staging'/f'{name}.fbx'),overwrite=True)
    rows=json.loads((root/'manifest.json').read_text(encoding='utf8'))
    row=next(r for r in rows if r['name']==name)
    row.update(dimensions_blender_xyz=list(target.dimensions),triangles=len(mesh.loop_triangles),
               nonmanifold_edges=nonmanifold,degenerate_faces=degenerate,materials=[mat.name for mat in mesh.materials],export=info,
               design_zh='约41.2米断桅、52.8×23.3米大残帆；保留原基座。帆最低8米，绳锚4.2米，整体随下舱剖切。',review_status='sail_revision_pending')
    (root/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
    bpy.data.libraries.write(str(root/'Source/ShipwreckV2.blend'),{scene},fake_user=True,compress=True)
    builder['P']['render_asset']('ShipwreckV2',name,framing_scale=1.6)
    print(json.dumps(dict(name=name,dimensions_blender=list(target.dimensions),triangles=row['triangles'],nonmanifold_edges=nonmanifold,degenerate_faces=degenerate)))
finally:bpy.context.window.scene=old_scene
