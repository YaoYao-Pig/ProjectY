"""Validate source masters, write editable scene, and export selected masters only."""
import bpy, bmesh, json, runpy, hashlib, math
from pathlib import Path
ROOT=Path('D:/Program/Unity/Project Y/Art/EquipmentExpansion202610')
scene=bpy.data.scenes['EquipmentExpansion202610_Source']
bpy.context.window.scene=scene
manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
properties=bpy.ops.export_scene.fbx.get_rna_type().properties
for key,value in {'apply_scale_options':'FBX_SCALE_UNITS','axis_forward':'-Z','axis_up':'Y','mesh_smooth_type':'OFF','path_mode':'RELATIVE'}.items():
    assert value in [entry.identifier for entry in properties[key].enum_items]
export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
targets=globals().get('TARGET_IDS')
prior={r['id']:r for r in json.loads((ROOT/'Integration/models.json').read_text(encoding='utf-8'))} if targets else {}
report=[]
for row in manifest['assets']:
    obj=bpy.data.objects[row['model']]
    mesh=obj.data
    mesh.calc_loop_triangles()
    assert obj.parent is None and not obj.constraints and not obj.modifiers
    assert tuple(obj.location)==(0,0,0) and tuple(obj.rotation_euler)==(0,0,0) and tuple(obj.scale)==(1,1,1)
    assert len(mesh.uv_layers)==1 and all(math.isfinite(c) for u in mesh.uv_layers[0].data for c in u.uv)
    assert all(p.area>1e-10 and not p.use_smooth for p in mesh.polygons)
    assert 0<max(obj.dimensions)<.65
    edit=bmesh.new();edit.from_mesh(mesh)
    boundary=sum(e.is_boundary for e in edit.edges)
    nonmanifold=sum(not e.is_manifold for e in edit.edges)
    assert boundary==0 and nonmanifold==0,(row['model'],boundary,nonmanifold)
    edit.free()
    signature=hashlib.sha256(repr(([(tuple(v.co)) for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons])).encode()).hexdigest()
    data={'id':row['id'],'name':obj.name,'vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),
          'dimensions_blender_xyz':list(obj.dimensions),'materials':[m.name for m in mesh.materials],
          'origin':[0,0,0],'scale':[1,1,1],'uv_layers':1,'boundary_edges':boundary,'nonmanifold_edges':nonmanifold,
          'geometry_sha256':signature}
    if targets is None or row['id'] in targets:
        data['export']=export(obj.name,str(ROOT/'Staging'/(obj.name+'.fbx')),overwrite=targets is not None)
    else:
        assert signature==prior[row['id']]['geometry_sha256'],'Untargeted geometry changed'
        data['export']=prior[row['id']]['export']
    report.append(data)
assert len(report)==30 and len(set(row['geometry_sha256'] for row in report))==30
(ROOT/'Integration/models.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'Integration/palette.json').write_text(json.dumps(manifest['palette'],indent=2),encoding='utf-8')
bpy.data.libraries.write(str(ROOT/'Source/EquipmentAttachments.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
manifest['status']='models_exported'
manifest['sourceBlend']='Art/EquipmentExpansion202610/Source/EquipmentAttachments.blend'
manifest['modelReport']='Art/EquipmentExpansion202610/Integration/models.json'
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'models':len(report),'triangles':sum(r['triangles'] for r in report),
                  'min_triangles':min(r['triangles'] for r in report),'max_triangles':max(r['triangles'] for r in report),
                  'fbx_bytes':sum(r['export']['bytes'] for r in report),'unique_geometry':30,
                  'source':str(ROOT/'Source/EquipmentAttachments.blend')}))
