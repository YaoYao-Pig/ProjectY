"""Validate and stage selected arsenal FBX files; never writes Unity assets or design.json."""
import bpy,bmesh,json,math,hashlib,runpy
from pathlib import Path
ROOT=Path('D:/Program/Unity/Project Y/Art/ArsenalExpansion202610')
scene=bpy.data.scenes['ArsenalExpansion202610_Source'];bpy.context.window.scene=scene
design=json.loads((ROOT/'design.json').read_text(encoding='utf-8'))
rows=design['weapons']+design['attachments']
anchors={r['id']:r for r in json.loads((ROOT/'Integration/anchors.json').read_text())['weapons']}
weapons={r['id']:r for r in json.loads(Path('D:/Program/Unity/Project Y/Config/Tables/Equipment/EquipmentWeaponTable.json').read_text(encoding='utf-8'))['rows']}
grips={r['id']:r for r in json.loads(Path('D:/Program/Unity/Project Y/Config/Tables/Equipment/EquipmentGripTable.json').read_text(encoding='utf-8'))['rows']}
props=bpy.ops.export_scene.fbx.get_rna_type().properties
for key,value in {'apply_scale_options':'FBX_SCALE_UNITS','axis_forward':'-Z','axis_up':'Y','mesh_smooth_type':'OFF','path_mode':'RELATIVE'}.items():assert value in [e.identifier for e in props[key].enum_items]
export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
targets=globals().get('TARGET_IDS');prior={}
if targets and (ROOT/'Integration/models.json').exists():prior={r['id']:r for r in json.loads((ROOT/'Integration/models.json').read_text(encoding='utf-8'))}
report=[]
for row in rows:
    obj=bpy.data.objects[row['model']];mesh=obj.data;mesh.calc_loop_triangles()
    assert obj.parent is None and not obj.modifiers and not obj.constraints and not obj.animation_data
    assert tuple(obj.location)==(0,0,0) and tuple(obj.rotation_euler)==(0,0,0) and tuple(obj.scale)==(1,1,1)
    assert len(mesh.uv_layers)==1 and all(math.isfinite(c) for u in mesh.uv_layers[0].data for c in u.uv)
    assert all(p.area>1e-10 and not p.use_smooth for p in mesh.polygons),row['model']
    bm=bmesh.new();bm.from_mesh(mesh)
    boundary=sum(e.is_boundary for e in bm.edges);nonmanifold=sum(not e.is_manifold for e in bm.edges)
    assert boundary==0 and nonmanifold==0,(row['model'],boundary,nonmanifold);bm.free()
    sig=hashlib.sha256(repr(([tuple(v.co) for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons])).encode()).hexdigest()
    result={'id':row['id'],'name':row['model'],'kind':'weapon' if 'baseWeaponId' in row else 'attachment',
            'vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),'dimensions_blender_xyz':list(obj.dimensions),
            'materials':[mat.name for mat in mesh.materials],'origin':[0,0,0],'rotation':[0,0,0],'scale':[1,1,1],
            'uv_layers':1,'boundary_edges':boundary,'nonmanifold_edges':nonmanifold,'geometry_sha256':sig}
    if 'baseWeaponId' in row:
        base=weapons[row['baseWeaponId']];result['baseWeaponId']=row['baseWeaponId'];result['unity_grip']=grips[base['gripId']]
        result['unity_sockets']=anchors[row['id']]['sockets']
    else:result['slotKind']=row['slotKind']
    if targets is None or row['id'] in targets:result['export']=export(obj.name,str(ROOT/'Staging'/(obj.name+'.fbx')),overwrite=targets is not None)
    else:
        assert sig==prior[row['id']]['geometry_sha256'],'Unexpected untargeted geometry change';result['export']=prior[row['id']]['export']
    report.append(result)
assert len(report)==40 and len(set(r['geometry_sha256'] for r in report))==40
(ROOT/'Integration/models.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
palette=runpy.run_path(str(ROOT/'Scripts/geometry.py'))['PALETTE']
used={name.replace('M_MapLP_','') for r in report for name in r['materials']}
(ROOT/'Integration/palette.json').write_text(json.dumps({k:palette[k] for k in sorted(used)},indent=2),encoding='utf-8')
bpy.data.libraries.write(str(ROOT/'Source/ArsenalMasters.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print(json.dumps({'models':len(report),'triangles':sum(r['triangles'] for r in report),'fbx_bytes':sum(r['export']['bytes'] for r in report),'unique_geometry':40,'source':str(ROOT/'Source/ArsenalMasters.blend')}))
