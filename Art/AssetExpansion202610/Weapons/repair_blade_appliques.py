"""Targeted revision 3: five sword models only; no palette or Unity changes."""
import bpy,bmesh,json,runpy,hashlib
from pathlib import Path
R=Path('D:/Program/Unity/Project Y/Art/AssetExpansion202610/Weapons')
NAMES=['AEW_Sword_VeteranRemnant','AEW_Sword_MarshHeron','AEW_Sword_EclipseVow','AEW_Greatsword_GraveBell','AEW_Greatsword_TideAnchor']

def material_snapshot():
    result=[]
    for m in bpy.data.materials:
        if m.name.startswith('M_MapLP_AEW_'):
            node=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            result.append((m.name,list(m.diffuse_color),list(node.inputs['Base Color'].default_value),node.inputs['Roughness'].default_value,node.inputs['Metallic'].default_value))
    return sorted(result)

def repair():
    before_materials=material_snapshot();palette_hash=hashlib.sha256((R/'materials.json').read_bytes()).hexdigest()
    rows=json.loads((R/'manifest.json').read_text(encoding='utf8'));lookup={r['name']:r for r in rows}
    before={r['name']:hashlib.sha256((R/'Staging'/(r['name']+'.fbx')).read_bytes()).hexdigest() for r in rows}
    source=bpy.data.scenes['AE202610_Weapons'];masters=bpy.data.collections['AE202610_Weapons_Masters'];previous=bpy.context.scene
    code=runpy.run_path(str(R/'build_weapons.py'));pipe=runpy.run_path(str(R.parent/'shared_pipeline.py'))
    exporter=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
    try:
        bpy.context.window.scene=source
        for name in NAMES:
            row=lookup[name];old=bpy.data.objects[name];assert old in list(masters.objects)
            oldmesh=old.data;bpy.data.objects.remove(old,do_unlink=True)
            if oldmesh.users==0:bpy.data.meshes.remove(oldmesh)
            m=code['M']();code['sword'](m,row['variant'],row['category']=='Greatsword')
            obj=m.finish(name,masters);obj['lore_zh']=row['lore_zh'];obj['asset_category']=row['category'];obj['grip_origin']='mesh local zero in metres';obj['geometry_revision']=3
            bpy.context.view_layer.update();mesh=obj.data;mesh.calc_loop_triangles()
            bm=bmesh.new();bm.from_mesh(mesh);bad=sum(not e.is_manifold for e in bm.edges);zero=sum(f.calc_area()<1e-12 for f in bm.faces);bm.free()
            assert bad==0 and zero==0,(name,bad,zero)
            row.update(dimensions_blender_xyz=list(obj.dimensions),triangles=len(mesh.loop_triangles),nonmanifold_edges=bad,degenerate_faces=zero,uv_layers=len(mesh.uv_layers),materials=[m.name for m in mesh.materials],export=exporter(name,str(R/'Staging'/(name+'.fbx')),overwrite=True),geometry_revision=3,applique_contract='Every strip/repair plate/rivet is clipped to the blade front triangles. Back faces embed 0.8 mm in the metal; no fixed-Y floating plane.')
        assert before_materials==material_snapshot(),'Unexpected material mutation'
        assert palette_hash==hashlib.sha256((R/'materials.json').read_bytes()).hexdigest()
        (R/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
        bpy.data.libraries.write(str(R/'Source/Weapons.blend'),{source},fake_user=True,compress=True)
        for name in NAMES:pipe['render_asset']('Weapons',name)
        after={r['name']:hashlib.sha256((R/'Staging'/(r['name']+'.fbx')).read_bytes()).hexdigest() for r in rows}
        changed=[name for name in before if before[name]!=after[name]]
        assert set(changed)==set(NAMES),changed
        audit=dict(revision=3,changed_models=changed,unchanged_models=50,materials_unchanged=True,materials_json_sha256=palette_hash,live_materials_unchanged=True,rendered_views=20,review_scope='Sword and Greatsword categories only; visual rereview pending',before_fbx_sha256={n:before[n] for n in NAMES},after_fbx_sha256={n:after[n] for n in NAMES})
        (R/'blade_applique_revision3.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf8')
        print(json.dumps(audit))
    finally:bpy.context.window.scene=previous

if __name__=='__main__':repair()
