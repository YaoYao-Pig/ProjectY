"""Validate grip-local originals, export explicit FBX, and archive this scene only."""
import bpy,bmesh,math,json,hashlib,runpy
from pathlib import Path
ROOT=Path('D:/Program/Unity/Project Y/Art/ProfessionArsenal20261025')
module=runpy.run_path(str(ROOT/'Scripts/weapon_build.py'),init_globals={'RESUME':True})
scene=module['scene']
export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
props=bpy.ops.export_scene.fbx.get_rna_type().properties
for k,v in {'apply_scale_options':'FBX_SCALE_UNITS','axis_forward':'-Z','axis_up':'Y','mesh_smooth_type':'OFF','path_mode':'RELATIVE'}.items():
    assert v in [e.identifier for e in props[k].enum_items]
report=[]
for i,(key,display,profession,kind,fn) in enumerate(module['ROWS']):
    name='Profession_'+key;obj=bpy.data.objects[name];mesh=obj.data
    assert tuple(obj.location)==(0,0,0) and tuple(obj.rotation_euler)==(0,0,0) and tuple(obj.scale)==(1,1,1)
    assert obj.parent is None and not obj.modifiers and not obj.constraints and not obj.animation_data
    assert obj.matrix_world.determinant()>0
    assert len(mesh.uv_layers)==1 and all(math.isfinite(v) for d in mesh.uv_layers[0].data for v in d.uv)
    assert all(p.area>1e-10 and not p.use_smooth for p in mesh.polygons),name
    mesh.calc_loop_triangles()
    bm=bmesh.new();bm.from_mesh(mesh)
    boundary=sum(e.is_boundary for e in bm.edges);nonmanifold=sum(not e.is_manifold for e in bm.edges)
    assert boundary==0 and nonmanifold==0,(name,boundary,nonmanifold)
    volume=bm.calc_volume(signed=True);assert volume>0,(name,volume);bm.free()
    dims=list(obj.dimensions);assert .7<max(dims)<2.5,(name,dims)
    signature=hashlib.sha256(repr(([tuple(v.co) for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons])).encode()).hexdigest()
    row={'id':8001+i,'modelKey':name,'name':display,'profession':profession,'kind':kind,'baseWeaponId':{'staff':1,'sword':40,'bow':46}[kind],
         'modelPath':'Assets/DynamicAsset/ProfessionArsenal20261025/Models/'+name+'.fbx',
         'prefabPath':'Assets/DynamicAsset/ProfessionArsenal20261025/Weapons/Weapon_'+str(8001+i)+'.prefab',
         'vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),'dimensions_blender_xyz':dims,
         'dimensions_unity_xyz':[dims[0],dims[2],dims[1]],'origin':[0,0,0],'rotation':[0,0,0],'scale':[1,1,1],
         'uv_layers':1,'boundary_edges':boundary,'nonmanifold_edges':nonmanifold,'signed_volume':volume,
         'materials':[mat.name for mat in mesh.materials],'geometry_sha256':signature,
         'export':export(name,str(ROOT/'Staging'/(name+'.fbx')),overwrite=bool(globals().get('OVERWRITE')))}
    report.append(row)
assert len(report)==12 and len({r['geometry_sha256'] for r in report})==12
(ROOT/'Integration/models.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
used={name.replace('M_MapLP_','') for row in report for name in row['materials']}
palette={key:module['g']['PALETTE'][key] for key in sorted(used)}
(ROOT/'Integration/palette.json').write_text(json.dumps(palette,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(ROOT/'Source/ProfessionWeapons.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print(json.dumps({'models':len(report),'triangles':sum(r['triangles'] for r in report),'fbx_bytes':sum(r['export']['bytes'] for r in report),'unique_geometry':12,'source':str(ROOT/'Source/ProfessionWeapons.blend')}))
