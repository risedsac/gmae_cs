"""Bevel and consolidate the original M4/AWP meshes, preserving reload groups."""
import bpy,math
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for name in ['m4a1','awp']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(root/'assets'/f'{name}.glb'))
 groups={}
 for obj in list(bpy.context.scene.objects):
  if obj.type!='MESH':continue
  ancestors=[];parent=obj.parent
  while parent:ancestors.append(parent.name);parent=parent.parent
  if any('Arm' in n for n in ancestors):continue
  modifier=obj.modifiers.new('Machined edge radius','BEVEL');modifier.width=.0025;modifier.segments=3;modifier.limit_method='ANGLE';modifier.angle_limit=math.radians(35)
  bpy.context.view_layer.objects.active=obj
  bpy.ops.object.modifier_apply(modifier=modifier.name)
  normals=obj.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');normals.keep_sharp=True
  bpy.ops.object.modifier_apply(modifier=normals.name)
  group='Magazine' if any(n.startswith('Magazine') for n in ancestors) else ('Bolt' if any(n.startswith('Bolt') for n in ancestors) else 'Receiver')
  groups.setdefault(group,[]).append(obj)
 for name_,objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:obj.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name=name_+'Mesh'
 bpy.ops.wm.save_as_mainfile(filepath=str(root/'models'/f'{name}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(root/'assets'/f'{name}.glb'),export_format='GLB',export_animations=False,export_yup=True)
 print('FINISHED',name)
