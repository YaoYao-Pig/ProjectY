import bpy,runpy,json
from pathlib import Path
from mathutils import Vector
BASE=Path('D:/Program/Unity/Project Y/Art/AssetExpansion202610/ShipwreckWeapons')
g=runpy.run_path(str(BASE/'Scripts/build_shipwreck_weapons.py'))
scene=bpy.data.scenes['AE202610_ShipwreckWeapons'];collection=bpy.data.collections['AE202610_ShipwreckWeapons_Masters'];bpy.context.window.scene=scene
m=g['M']();g['serpentbow'](m)
old=bpy.data.objects['SWW_SeaserpentRecurve'];oldmesh=old.data
bpy.data.objects.remove(old,do_unlink=True)
if oldmesh.users==0:bpy.data.meshes.remove(oldmesh)
obj=m.finish('SWW_SeaserpentRecurve',collection)
rows=json.loads((BASE/'catalog.json').read_text(encoding='utf8'))
info=next(r for r in rows if r['id']==obj.name);obj['lore_zh']=info['lore_zh'];obj['grip_origin']='0,0,0 in metres'
g['PIPE']['finish_batch']('ShipwreckWeapons',scene,[bpy.data.objects[r['id']] for r in rows],rows)
g['PIPE']['render_asset']('ShipwreckWeapons',obj.name)
review=g['PIPE']['setup_review']('ShipwreckWeapons');bpy.context.window.scene=review
source=bpy.data.objects['SWW_DrownedBellMaul'];copy=source.copy();copy.data=source.data;review.collection.objects.link(copy);copy.hide_render=False
corners=[Vector(v) for v in copy.bound_box];lo=Vector(tuple(min(v[i] for v in corners) for i in range(3)));hi=Vector(tuple(max(v[i] for v in corners) for i in range(3)))
center=(lo+hi)/2;span=max(hi-lo);copy.scale=(1/span,)*3;copy.location=-center/span
review.camera.location=(-4,-1,.5);review.camera.rotation_euler=(-review.camera.location).to_track_quat('-Z','Y').to_euler();review.camera.data.ortho_scale=1.32
review.render.filepath=str(BASE/'Previews/SWW_DrownedBellMaul_left.png');bpy.ops.render.render(write_still=True,scene=review.name)
bpy.data.objects.remove(copy,do_unlink=True)
bpy.context.window.scene=bpy.data.scenes['EquipmentTools_Source']
print('Bow string now outside entire wooden limb; four views and bell cavity detail saved; original scene restored')
