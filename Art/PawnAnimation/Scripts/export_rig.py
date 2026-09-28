"""Export an isolated rig copy in Unity's +Z facing convention. Run through Blender MCP."""
import bpy
import math
from pathlib import Path
from mathutils import Matrix

root=Path('D:/Program/Unity/Project Y/Art/PawnAnimation')
scene=bpy.data.scenes['PawnAnimation_Studio'];bpy.context.window.scene=scene
rig=bpy.data.objects['Pawn_Humanoid'];body=bpy.data.objects['Pawn_Human_Animated']
assert bpy.context.mode=='OBJECT'
selected=list(bpy.context.selected_objects);active=bpy.context.view_layer.objects.active
rig_copy=rig.copy();rig_copy.data=rig.data.copy();scene.collection.objects.link(rig_copy)
body_copy=body.copy();body_copy.data=body.data.copy();scene.collection.objects.link(body_copy)
try:
    turn=Matrix.Rotation(math.pi,4,'Z')
    rig_copy.data.transform(turn);body_copy.data.transform(turn)
    body_copy.parent=rig_copy
    for modifier in body_copy.modifiers:
        if modifier.type=='ARMATURE':modifier.object=rig_copy
    for bone in rig_copy.pose.bones:bone.matrix_basis.identity()
    for obj in selected:obj.select_set(False)
    rig_copy.select_set(True);body_copy.select_set(True);bpy.context.view_layer.objects.active=rig_copy
    bpy.context.view_layer.update()
    result=bpy.ops.export_scene.fbx(filepath=str(root/'Staging/PawnHumanoid.fbx'),
        use_selection=True,object_types={'ARMATURE','MESH'},global_scale=1,apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',add_leaf_bones=False,
        bake_anim=False,use_mesh_modifiers=True,mesh_smooth_type='FACE',armature_nodetype='NULL',
        primary_bone_axis='Y',secondary_bone_axis='X')
    assert result=={'FINISHED'}
    print('Exported Unity-facing Humanoid:',root/'Staging/PawnHumanoid.fbx')
finally:
    mesh=body_copy.data;armature=rig_copy.data
    bpy.data.objects.remove(body_copy,do_unlink=True);bpy.data.objects.remove(rig_copy,do_unlink=True)
    bpy.data.meshes.remove(mesh);bpy.data.armatures.remove(armature)
    for obj in selected:obj.select_set(True)
    bpy.context.view_layer.objects.active=active
