"""Run once in the owned PawnAnimation_Studio scene through Blender MCP."""
import bpy
import bmesh
import json
from pathlib import Path
from mathutils import Vector

ROOT=Path('D:/Program/Unity/Project Y/Art/PawnAnimation')
scene=bpy.data.scenes['PawnAnimation_Studio'];bpy.context.window.scene=scene
body=bpy.data.objects['Pawn_Human_Animated']
assert not body.get('humanoid_rigged') and 'Pawn_Humanoid' not in bpy.data.objects
verts=body.data.vertices
links={v.index:set() for v in verts}
for edge in body.data.edges:
    a,b=edge.vertices;links[a].add(b);links[b].add(a)
groups=[];seen=set()
for v in verts:
    if v.index in seen:continue
    todo=[v.index];seen.add(v.index);component=[]
    while todo:
        index=todo.pop();component.append(index)
        for neighbor in links[index]:
            if neighbor not in seen:seen.add(neighbor);todo.append(neighbor)
    groups.append(component)

arms={}
for side,suffix in [(1,'l'),(-1,'r')]:
    shoulder=Vector((side*.29,0,1.25));old_elbow=Vector((side*.44,-.06,1.07));old_hand=Vector((side*.50,-.28,.98))
    direction=Vector((side,0,0));elbow=shoulder+direction*(old_elbow-shoulder).length;wrist=elbow+direction*(old_hand-old_elbow).length
    arms[suffix]=(shoulder,elbow,wrist)
    for ids in groups:
        center=sum((verts[i].co for i in ids),Vector())/len(ids)
        if center.x*side<.32:continue
        if center.z>1.1:origin,new_origin,rotation=shoulder,shoulder,(old_elbow-shoulder).rotation_difference(direction)
        elif center.z>1.0:origin,new_origin,rotation=old_elbow,elbow,(old_hand-old_elbow).rotation_difference(direction)
        else:origin,new_origin,rotation=Vector((side*.50,-.28,.985)),wrist+direction*.07,Vector((0,0,1)).rotation_difference(direction)
        for i in ids:verts[i].co=new_origin+rotation@(verts[i].co-origin)

# Add actual knee and torso loops before weighting; no bend is attempted on a single long polygon.
mesh=bmesh.new();mesh.from_mesh(body.data)
for height in [.56,.94,1.13]:
    bmesh.ops.bisect_plane(mesh,geom=list(mesh.verts)+list(mesh.edges)+list(mesh.faces),dist=.00001,
        plane_co=(0,0,height),plane_no=(0,0,1),clear_inner=False,clear_outer=False)
mesh.to_mesh(body.data);mesh.free();body.data.update()
rig_data=bpy.data.armatures.new('Pawn_HumanoidSkeleton');rig=bpy.data.objects.new('Pawn_Humanoid',rig_data);scene.collection.objects.link(rig)
for obj in bpy.context.selected_objects:obj.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
spec=[]
def bone(name,head,tail,parent=None):
    b=rig_data.edit_bones.new(name);b.head=head;b.tail=tail
    if parent:b.parent=rig_data.edit_bones[parent]
    spec.append({'name':name,'parent':parent,'head':list(head),'tail':list(tail)})
bone('root',(0,0,0),(0,0,.15))
bone('pelvis',(0,0,.82),(0,0,.94),'root')
bone('spine_01',(0,0,.94),(0,0,1.05),'pelvis')
bone('spine_02',(0,0,1.05),(0,0,1.18),'spine_01')
bone('spine_03',(0,0,1.18),(0,0,1.30),'spine_02')
bone('neck_01',(0,0,1.30),(0,0,1.38),'spine_03')
bone('Head',(0,0,1.38),(0,0,1.78),'neck_01')
for side,suffix in [(1,'l'),(-1,'r')]:
    shoulder,elbow,wrist=arms[suffix]
    bone('clavicle_'+suffix,(side*.04,0,1.25),shoulder,'spine_03')
    bone('upperarm_'+suffix,shoulder,elbow,'clavicle_'+suffix)
    bone('lowerarm_'+suffix,elbow,wrist,'upperarm_'+suffix)
    bone('hand_'+suffix,wrist,wrist+Vector((side*.17,0,0)),'lowerarm_'+suffix)
    bone('thigh_'+suffix,(side*.17,0,.82),(side*.17,0,.56),'pelvis')
    bone('calf_'+suffix,(side*.17,0,.56),(side*.17,0,.23),'thigh_'+suffix)
    bone('foot_'+suffix,(side*.17,0,.23),(side*.17,-.16,.15),'calf_'+suffix)
    bone('ball_'+suffix,(side*.17,-.16,.15),(side*.17,-.26,.15),'foot_'+suffix)
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
for b in spec:body.vertex_groups.new(name=b['name'])
# Classify disconnected parts by their center, not individual extreme vertices.
# A wide torso corner must never receive an arm weight.
links={v.index:set() for v in body.data.vertices}
for edge in body.data.edges:
    a,b=edge.vertices;links[a].add(b);links[b].add(a)
seen=set()
for vertex in body.data.vertices:
    if vertex.index in seen:continue
    todo=[vertex.index];seen.add(vertex.index);ids=[]
    while todo:
        i=todo.pop();ids.append(i)
        for other in links[i]:
            if other not in seen:seen.add(other);todo.append(other)
    center=sum((body.data.vertices[i].co for i in ids),Vector())/len(ids)
    suffix='l' if center.x>0 else 'r'
    for i in ids:
        z=body.data.vertices[i].co.z
        if abs(center.x)>.33:
            shoulder,elbow,wrist=arms[suffix]
            name=('upperarm_' if abs(center.x)<abs(elbow.x) else 'lowerarm_' if abs(center.x)<abs(wrist.x) else 'hand_')+suffix
        elif center.z>1.4:name='Head'
        elif center.z>1.27:name='neck_01'
        elif center.z>.8:name='pelvis' if z<.94 else 'spine_01' if z<1.13 else 'spine_03'
        elif center.z>.34:name=('thigh_' if z>=.56-.00001 else 'calf_')+suffix
        else:name='foot_'+suffix
        body.vertex_groups[name].add([i],1,'REPLACE')
body.parent=rig;modifier=body.modifiers.new('Humanoid skin','ARMATURE');modifier.object=rig
body['humanoid_rigged']=True
for poly in body.data.polygons:poly.use_smooth=False
bpy.context.view_layer.update()
assert all(len(v.groups)==1 and abs(sum(g.weight for g in v.groups)-1)<.0001 for v in body.data.vertices)
report={'bones':spec,'vertices':len(body.data.vertices),'triangles':sum(len(p.vertices)-2 for p in body.data.polygons),
    'highest_z':max(v.co.z for v in body.data.vertices),'lowest_z':min(v.co.z for v in body.data.vertices),'materials':[m.name for m in body.data.materials]}
(ROOT/'Integration/target-rig.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(ROOT/'Source/PawnHumanoid.blend'),{scene},fake_user=True)
print(json.dumps({'bones':len(spec),'vertices':report['vertices'],'top':report['highest_z'],'source':str(ROOT/'Source/PawnHumanoid.blend')}))
