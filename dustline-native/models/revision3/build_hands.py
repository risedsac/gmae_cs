"""Retarget para/MakeHuman CC0 anatomical hands, replacing the old geometric gloves.
Keeps each weapon's existing geometry and animated Magazine/Bolt pivots.
"""
import bpy, math, os, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
PROJECT=Path(__file__).resolve().parents[2]
SRC=PROJECT/'models/revision3/sources/fps-arms.blend'

def co(p): return Vector((p[0],-p[2],p[1]))
def basis(forward,across):
 y=forward.normalized();x=(across-y*across.dot(y)).normalized();z=x.cross(y).normalized()
 return Matrix((x,y,z)).transposed()
def material(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.84
 # Pack an exportable fabric map, not a Blender-only shader.
 import numpy as np
 rng=np.random.default_rng(19);yy,xx=np.mgrid[:256,:256];value=.86+rng.random((256,256))*.14+((xx+yy)%3==0)*.055
 rgba=np.ones((256,256,4),dtype=np.float32)
 for k in range(3):rgba[:,:,k]=np.power(value*color[k],1/2.2)
 im=bpy.data.images.new(name+' weave',256,256);im.pixels.foreach_set(rgba.ravel());im.pack()
 tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 return m

def sleeve(name,a,b,parent,mat):
 a,b=Vector(a),Vector(b);d=(b-a).normalized();u=d.cross(Vector((1,0,0))).normalized();v=d.cross(u)
 verts=[];faces=[];n=24;rings=18
 for j in range(rings):
  t=j/(rings-1);center=a.lerp(b,t)
  radius=(.067*(1-t)+.038*t)*(1+.035*math.sin(t*39))
  for k in range(n):
   angle=k/n*math.tau;r=radius*(1+.025*math.sin(angle*5+t*12))
   verts.append(co(center+u*math.cos(angle)*r+v*math.sin(angle)*r*.9))
 for j in range(rings-1):
  for k in range(n):faces.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.parent=parent;me.materials.append(mat)
 uv=me.uv_layers.new()
 for poly in me.polygons:
  poly.use_smooth=True
  for li in poly.loop_indices:
   i=me.loops[li].vertex_index;uv.data[li].uv=(i%n/n,i//n/(rings-1)*2)
 return o

for weapon in ['rifle','sidearm','m4a1','awp']:
 bpy.ops.wm.open_mainfile(filepath=str(SRC))
 rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
 mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
 rig.animation_data_clear();mesh.animation_data_clear()
 for pb in rig.pose.bones:
  for c in list(pb.constraints):pb.constraints.remove(c)
  pb.matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
 original_vertices=[v.co.copy() for v in mesh.data.vertices]
 saved=[]
 for side in ['R','L']:
  hand=rig.data.bones['hand.'+side]
  wrist=hand.head_local.copy()
  middle=rig.data.bones['f_middle.01.'+side].head_local
  across=rig.data.bones['f_pinky.01.'+side].head_local-rig.data.bones['f_index.01.'+side].head_local
  old=basis(middle-wrist,across)
  right=side=='R'
  if right:
   w=Vector((.064,-.18,{'rifle':-.215,'sidearm':-.255,'m4a1':-.34,'awp':-.30}[weapon]))
   forward=co((0,.08,-1));cross=co((0,-1,-.08));curl=co((-1,0,0))
  else:
   z={'rifle':-.90,'m4a1':-.92,'awp':-.95,'sidearm':-.30}[weapon]
   w=Vector((-.092,-.115 if weapon!="sidearm" else -.18,z+.04))
   forward=co((.15,1,-.06));cross=co((0,-.06,-1));curl=co((1,0,0))
  new=rig.matrix_world.inverted().to_3x3()@basis(forward,cross);rot=new@old.transposed();scale=.084
  curl=rig.matrix_world.inverted().to_3x3()@curl
  # Work in rig units, then bake into metres. Orient palms before curling each phalanx.
  dest=rig.matrix_world.inverted()@(co(w)/scale)
  transform=rot.to_4x4();transform.translation=dest-rot@wrist
  relevant=[b for b in rig.data.bones if b.name.endswith('.'+side) and (b.name.startswith(('hand.','palm_','f_','thumb.'))) and 'control' not in b.name]
  for b in relevant:
   rig.pose.bones[b.name].matrix=transform@b.matrix_local
   bpy.context.view_layer.update()
  bpy.context.view_layer.update()
  for finger in ['pinky','ring','middle','index','thumb']:
   prefix='thumb.' if finger=='thumb' else 'f_'+finger+'.'
   names=[prefix+f'{j:02d}.'+side for j in [1,2,3]]
   first=rig.data.bones[names[0]];head=transform@first.head_local
   d=(rot@(first.tail_local-first.head_local)).normalized()
   normal=curl-d*curl.dot(d);normal.normalize()
   angles=[26,84,137] if finger!='thumb' else [12,35,62]
   if right and finger=='index':angles=[4,35,64]
   for j,name in enumerate(names):
    b=rig.data.bones[name];rest=transform@b.matrix_local
    theta=math.radians(angles[j]);direction=(d*math.cos(theta)+normal*math.sin(theta)).normalized()
    rest_dir=(rot@(b.tail_local-b.head_local)).normalized()
    mat=(rest_dir.rotation_difference(direction).to_matrix()@rest.to_3x3()).to_4x4();mat.translation=head
    rig.pose.bones[name].matrix=mat
    head+=direction*b.length
    bpy.context.view_layer.update()
  if weapon=='rifle':
   print('POSE_JOINTS',side,[(n,tuple((rig.matrix_world@rig.pose.bones[n].matrix.translation)*scale)) for n in ['hand.'+side,'f_index.01.'+side,'f_middle.01.'+side,'thumb.01.'+side,'thumb.02.'+side,'thumb.03.'+side]],flush=True)
  deps=bpy.context.evaluated_depsgraph_get();evaluated=mesh.evaluated_get(deps);em=evaluated.to_mesh()
  # Cut on the wrist side of the anatomical hand, retaining a short cuff overlap.
  ids=set();forward_old=(middle-wrist).normalized()
  for v in mesh.data.vertices:
   total=sum(g.weight for g in v.groups if mesh.vertex_groups[g.group].name in [b.name for b in relevant])
   if total>.03 and (v.co-wrist).dot(forward_old)>-.20:ids.add(v.index)
  faces=[list(poly.vertices) for poly in mesh.data.polygons if all(i in ids for i in poly.vertices)]
  used=sorted(set(i for f in faces for i in f));mapping={v:i for i,v in enumerate(used)}
  verts=[]
  deform={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in relevant}
  for i in used:
   result=Vector((0,0,0));weight=0
   for group in mesh.data.vertices[i].groups:
    name=mesh.vertex_groups[group.group].name
    if name in deform:result+=(deform[name]@original_vertices[i])*group.weight;weight+=group.weight
   result/=max(.001,weight)
   verts.append(tuple((rig.matrix_world@result)*scale))
  uv=[]
  for poly in mesh.data.polygons:
   if all(i in ids for i in poly.vertices):uv.append([tuple(mesh.data.uv_layers.active.data[l].uv) for l in poly.loop_indices])
  saved.append((side,w,verts,[[mapping[i] for i in f] for f in faces],uv))
  evaluated.to_mesh_clear()
 # Import weapon, remove all old sleeve/glove meshes. Retain original coordinates and pivots.
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(PROJECT/'assets'/f'{weapon}.glb'))
 root=next(o for o in bpy.context.scene.objects if o.parent is None)
 for object_name in list(bpy.context.scene.objects.keys()):
  o=bpy.data.objects.get(object_name)
  if o and o.name.startswith(('MainArm','SupportArm')):
   for c in list(o.children_recursive):bpy.data.objects.remove(c,do_unlink=True)
   if o.name in bpy.data.objects:bpy.data.objects.remove(o,do_unlink=True)
 glove=material('Anatomical suede glove',(.095,.079,.050));cloth=material('Woven olive sleeve',(.035,.044,.033))
 for side,w,verts,faces,uv in saved:
  parent=bpy.data.objects.new('MainArm' if side=='R' else 'SupportArm',None);bpy.context.collection.objects.link(parent);parent.parent=root
  me=bpy.data.meshes.new('Hand topology');me.from_pydata(verts,[],faces);me.update()
  ob=bpy.data.objects.new('Anatomical glove '+side,me);bpy.context.collection.objects.link(ob);ob.parent=parent;me.materials.append(glove)
  layer=me.uv_layers.new()
  for poly,coords in zip(me.polygons,uv):
   poly.use_smooth=True
   for li,coord in zip(poly.loop_indices,coords):layer.data[li].uv=coord
  # Subdivision improves silhouettes while preserving the anatomical finger webbing.
  mod=ob.modifiers.new('Glove surface','SUBSURF');mod.levels=1
  bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
  end=w-Vector((0,.005,.005));start=(.36,-.50,.20) if side=='R' else (-.48,-.52,.08)
  sleeve('Sleeve '+side,start,end,parent,cloth)
 bpy.ops.wm.save_as_mainfile(filepath=str(PROJECT/'models/revision3'/f'{weapon}-hands.blend'))
 bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets'/f'{weapon}.glb'),export_format='GLB',export_animations=False,export_yup=True)
 print('ANATOMICAL_HANDS',weapon,flush=True)
# Avoid PulseAudio shutdown touching the desktop in the headless asset worker.
sys.stdout.flush();os._exit(0)
