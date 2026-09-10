"""Blend cloth weights across shoulder/elbow/knee joints instead of rigid limb chunks."""
import bpy, os, sys
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[2]
backup=P/'models/revision3/operator-before-skinning.glb'
if not backup.exists():backup.write_bytes((P/'assets/operator.glb').read_bytes())
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(backup))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH');rig.data.pose_position='REST'
bpy.context.view_layer.update()
cloth=set()
for poly in mesh.data.polygons:
 name=mesh.data.materials[poly.material_index].name.lower()
 if 'navy' in name or 'uniform' in name:
  cloth.update(poly.vertices)
changes=0
for side in ['Left','Right']:
 for parent,child,width in [(side+'Arm',side+'ForeArm',.085),(side+'UpLeg',side+'Leg',.075)]:
  pb=next(b for b in rig.data.bones if b.name.endswith(parent));cb=next(b for b in rig.data.bones if b.name.endswith(child))
  joint=rig.matrix_world@cb.head_local
  group_p=mesh.vertex_groups.get(pb.name);group_c=mesh.vertex_groups.get(cb.name)
  # Bone lengths from imported glTF are display lengths; use joint-head direction.
  axis=(joint-rig.matrix_world@pb.head_local).normalized()
  for i in cloth:
   v=mesh.data.vertices[i]
   if not any(g.group in [group_p.index,group_c.index] and g.weight>.1 for g in v.groups):continue
   world=mesh.matrix_world@v.co;along=(world-joint).dot(axis)
   if abs(along)>width:continue
   t=max(0,min(1,(along+width)/(2*width)));t=t*t*(3-2*t)
   for g in list(v.groups):mesh.vertex_groups[g.group].remove([i])
   group_p.add([i],1-t,'REPLACE');group_c.add([i],t,'REPLACE');changes+=1
rig.data.pose_position='POSE'
bpy.ops.wm.save_as_mainfile(filepath=str(P/'models/revision3/operator-skinned.blend'))
bpy.ops.export_scene.gltf(filepath=str(P/'assets/operator.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_yup=True)
print('CLOTH_WEIGHT_BLENDS',changes,flush=True);sys.stdout.flush();os._exit(0)
