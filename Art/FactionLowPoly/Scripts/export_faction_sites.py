"""Export only the named source collection; preserve scene and selection.

For later source revisions call export(overwrite=True) explicitly.
"""
from pathlib import Path
import bpy
import json
import math
import runpy

def export(overwrite=False):
    root=Path('D:/Program/Unity/Project Y')
    out=root/'Art/FactionLowPoly'
    setup=runpy.run_path(str(out/'Scripts/build_faction_sites.py'))
    names,palette=setup['NAMES'],setup['PALETTE']
    scene=bpy.data.scenes['FactionStrongholds_Source']
    before=bpy.context.window.scene
    bpy.context.window.scene=scene
    try:
        exporter=runpy.run_path(str(root/'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
        reports=[]
        for name in names:
            obj=bpy.data.objects[name];obj.hide_set(False)
            obj.data.calc_loop_triangles()
            radial=max(math.hypot(v.co.x,v.co.y) for v in obj.data.vertices)
            assert radial <= .80, (name,radial)
            assert min(v.co.z for v in obj.data.vertices)>=-1e-6
            assert all(not p.use_smooth for p in obj.data.polygons)
            report={'name':name,'dimensions_blender':list(obj.dimensions),'radius':radial,
                    'triangles':len(obj.data.loop_triangles),'materials':[m.name for m in obj.data.materials]}
            report['export']=exporter(name,str(out/'Staging'/(name+'.fbx')),overwrite=overwrite)
            reports.append(report)
        path=out/'Source/FactionStrongholds.blend'
        if path.exists() and not overwrite: raise FileExistsError(path)
        source_scenes={scene}
        if 'FactionStrongholds_Overview' in bpy.data.scenes:
            source_scenes.add(bpy.data.scenes['FactionStrongholds_Overview'])
        bpy.data.libraries.write(str(path),source_scenes,fake_user=True)
        manifest={'source':str(path),'models':reports,'palette':{'M_Faction_'+k:'#'+v for k,v in palette.items()},
                  'units':'meters','unity_up':'+Y','unity_front':'+Z','single_cell_radius_limit':.80}
        (out/'Integration/asset-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
        print(json.dumps(manifest))
    finally:
        bpy.context.window.scene=before

if __name__=='__main__': export()
