"""Original tactical uniform/gear mesh using the existing attributed animation rig."""
import sys, os, math
sys.path.insert(0,os.path.dirname(__file__))
from model_geometry import *

bpy.ops.import_scene.gltf(filepath=os.path.join(OUT,'soldier.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
for obj in list(bpy.context.scene.objects):
    if obj.type=='MESH': bpy.data.objects.remove(obj,do_unlink=True)
# Imported glTF joint display lengths are 100x larger than their child offsets.
# Changing display length along the same axis preserves bind orientations.
bpy.context.view_layer.objects.active=rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for bone in rig.data.edit_bones: bone.length *= .01
bpy.ops.object.mode_set(mode='OBJECT')
rig.data.pose_position='REST'
navy=material('Navy ripstop uniform',(.060,.079,.092),0,.91,'fabric')
gear=material('Ranger green carrier',(.132,.137,.095),0,.89,'fabric')
webbing=material('Woven carrier webbing',(.17,.178,.128),0,.86,'fabric')
mask=material('Charcoal balaclava',(.027,.032,.033),0,.98,'fabric')
skin=material('Eye opening skin',(.40,.245,.154),0,.88)
eye=material('Eyes',(.022,.016,.014),0,.25)
lens=material('Smoke eye protection',(.035,.053,.054),.12,.19)
objects=[]
def bind(o,bone):
    bpy.context.view_layer.objects.active=o
    if o.type=='CURVE':
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.ops.object.convert(target='MESH')
    for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
    world=o.matrix_world.copy(); o.parent=rig; o.matrix_world=world
    group=o.vertex_groups.new(name='mixamorig:'+bone); group.add(list(range(len(o.data.vertices))),1,'REPLACE')
    mod=o.modifiers.new('Uniform skin','ARMATURE'); mod.object=rig
    objects.append(o); return o
def bx(name,p,size,mat,bone,bevel=.009): return bind(box(name,p,size,mat,None,bevel),bone)
def el(name,p,size,mat,bone): return bind(ellipsoid(name,p,size,mat,None),bone)
def ln(name,points,r,mat,bone): return bind(line(name,points,r,mat,None),bone)
def garment(name,a,b,radii,mat,bone):
    av,bv=Vector(a),Vector(b); d=(bv-av).normalized()
    u=d.cross(Vector((0,0,1))).normalized(); v=d.cross(u).normalized()
    verts=[]; n=22; rings=len(radii)
    for j,r in enumerate(radii):
        t=j/(rings-1); center=av.lerp(bv,t)
        for k in range(n):
            theta=k/n*math.pi*2; radial=r*(1+.03*math.sin(k*2+j*1.8))
            verts.append(co(center+(u*math.cos(theta)+v*math.sin(theta))*radial))
    faces=[]
    for j in range(rings-1):
        for k in range(n): faces.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
    faces += [tuple(range(n-1,-1,-1)),tuple(range((rings-1)*n,rings*n))]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj); finish(obj,name,mat,None,0,True)
    uv=mesh.uv_layers.new()
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            idx=mesh.loops[li].vertex_index; uv.data[li].uv=(idx%n/n,idx//n/rings)
    return bind(obj,bone)

el('Shirt torso',(0,1.275,.024),(.226,.274,.135),navy,'Spine1')
el('Trousers seat',(0,1.029,.017),(.195,.15,.123),navy,'Hips')
bx('Duty belt',(0,1.035,.016),(.391,.051,.255),rubber,'Hips',.018)
bx('Belt buckle',(0,1.034,-.12),(.07,.044,.024),edge,'Hips',.005)
bx('Plate carrier front',(0,1.302,-.09),(.383,.363,.12),gear,'Spine2',.043)
bx('Plate carrier rear',(0,1.30,.148),(.36,.363,.055),gear,'Spine2',.035)
for x in [-.14,.14]:
    bx('Shoulder strap',(x,1.48,.015),(.067,.05,.25),webbing,'Spine2',.013)
    bx('Carrier side',(x*1.35,1.245,.017),(.048,.16,.215),gear,'Spine1',.014)
for y in [1.27,1.32,1.37,1.42]:
    bx('MOLLE row',(0,y,-.154),(.308,.019,.012),webbing,'Spine2',.003)
    for x in [-.12,-.06,0,.06,.12]: bx('MOLLE stitch',(x,y,-.162),(.004,.025,.004),stitch,'Spine2',.001)
for x in [-.118,0,.118]:
    bx('Rifle magazine pouch',(x,1.175,-.177),(.102,.166,.066),gear,'Spine2',.01)
    bx('Pouch flap',(x,1.232,-.212),(.099,.052,.019),webbing,'Spine2',.009)
    bx('Pouch pull tab',(x,1.202,-.224),(.019,.052,.007),rubber,'Spine2',.003)
bx('Radio',(.227,1.303,.078),(.065,.17,.071),rubber,'Spine2',.012)
ln('Radio aerial',[(.227,1.38,.08),(.234,1.64,.08)],.004,black,'Spine2')
ln('Comms cable',[(.226,1.355,.065),(.21,1.46,.01),(.155,1.50,-.06)],.005,black,'Spine2')
bx('Callsign patch',(0,1.436,-.155),(.126,.038,.005),rubber,'Spine2',.004)
for x in [-.037,-.018,.002,.027]: bx('Patch embroidery',(x,1.436,-.16),(.008,.02,.003),stitch,'Spine2',.001)
bx('Rear utility pouch',(0,1.192,.203),(.25,.12,.065),gear,'Spine1',.016)

for sign,side in [(-1,'Left'),(1,'Right')]:
    x=.099*sign
    garment('Cargo thigh',(x,1.028,.007),(x,.56,-.016),[.119,.123,.12,.115,.112,.105,.105,.098,.091],navy,side+'UpLeg')
    garment('Trouser lower leg',(x,.59,-.015),(x,.157,.027),[.095,.099,.097,.098,.096,.085,.091,.082,.074,.075],navy,side+'Leg')
    el('Knee articulation',(x,.582,-.001),(.097,.104,.094),navy,side+'Leg')
    bx('Knee pad',(x,.564,-.09),(.135,.166,.044),rubber,side+'Leg',.029)
    bx('Knee pad inset',(x,.566,-.115),(.102,.097,.009),gear,side+'Leg',.016)
    bx('Cargo pocket',(x+sign*.107,.815,.00),(.052,.187,.136),navy,side+'UpLeg',.022)
    bx('Cargo flap',(x+sign*.137,.884,-.001),(.012,.051,.127),webbing,side+'UpLeg',.008)
    bx('Combat boot',(x,.105,-.06),(.169,.189,.291),rubber,side+'Foot',.039)
    bx('Boot sole',(x,.035,-.061),(.18,.053,.300),black,side+'Foot',.017)
    for y in [.128,.155,.183]: ln('Boot laces',[(x-.045,y,-.142),(x+.04,y,-.151)],.003,stitch,side+'Foot')
    garment('Shirt upper sleeve',(.20*sign,1.475,.058),(.445*sign,1.479,.057),[.102,.105,.098,.092,.088,.084,.089],navy,side+'Arm')
    garment('Shirt forearm',(.438*sign,1.479,.057),(.674*sign,1.479,.059),[.089,.093,.085,.081,.076,.074,.068],navy,side+'ForeArm')
    el('Elbow reinforcement',(.436*sign,1.473,.072),(.061,.085,.083),gear,side+'ForeArm')
    bx('Sleeve rank patch',(.263*sign,1.494,-.037),(.10,.087,.012),gear,side+'Arm',.014)
    garment('Glove cuff',(.658*sign,1.479,.057),(.700*sign,1.479,.057),[.068,.071,.067],leather,side+'Hand')
    el('Gloved hand',(.734*sign,1.479,.058),(.073,.046,.059),glove,side+'Hand')
    for k in range(4):
        z=.022+k*.026
        ln('Gloved finger',[(.77*sign,1.478,z),(.824*sign,1.474,z),(.829*sign,1.45,z)],.012,glove,side+'Hand')
    ln('Gloved thumb',[(.71*sign,1.453,.025),(.746*sign,1.431,-.004),(.785*sign,1.442,-.008)],.016,glove,side+'Hand')

el('Neck gaiter',(0,1.537,.055),(.075,.091,.08),mask,'Neck')
el('Balaclava head',(0,1.674,.043),(.115,.142,.114),mask,'Head')
el('Covered jaw',(0,1.604,.010),(.083,.063,.085),mask,'Head')
el('Brow opening',(0,1.689,-.056),(.089,.023,.015),skin,'Head')
for x in [-.035,.035]:
    el('Eye',(x,1.690,-.071),(.013,.008,.004),eye,'Head')
    bx('Goggle lens',(x,1.690,-.08),(.061,.026,.014),lens,'Head',.009)
ln('Goggle bridge',[(-.014,1.691,-.086),(0,1.696,-.09),(.014,1.691,-.086)],.005,rubber,'Head')
el('Helmet shell',(0,1.763,.046),(.132,.088,.136),gear,'Head')
ln('Helmet rim',[(math.sin(a)*.129,1.732,.046+math.cos(a)*.134) for a in [i*math.pi/24 for i in range(49)]],.006,rubber,'Head')
bx('Helmet front mount',(0,1.769,-.088),(.05,.042,.017),rubber,'Head',.007)
for sign in [-1,1]:
    bx('Helmet rail',(sign*.129,1.758,.035),(.015,.033,.096),rubber,'Head',.007)
    el('Headset earcup',(sign*.119,1.675,.055),(.028,.058,.045),rubber,'Head')
    ln('Chin strap',[(sign*.105,1.727,-.007),(sign*.079,1.581,-.005),(0,1.568,-.039)],.008,leather,'Head')
ln('Headset microphone',[(-.133,1.673,.043),(-.132,1.633,-.045),(-.062,1.625,-.089)],.005,black,'Head')
el('Microphone foam',(-.059,1.625,-.089),(.019,.011,.011),rubber,'Head')

bpy.ops.object.select_all(action='DESELECT')
for obj in objects: obj.select_set(True)
bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); mesh=objects[0]; mesh.name='TacticalOperator'
rig.data.pose_position='POSE'
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); mesh.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'operator.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_yup=True,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK,'outputs/Dustline-operator.blend'))

world=bpy.context.scene.world; world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.19,.23,.28,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5
for pos,power in [((-2,3,-3),180),((2,2,1),140)]:
    bpy.ops.object.light_add(type='AREA',location=co(pos)); l=bpy.context.object; l.data.energy=power; l.data.shape='DISK'; l.data.size=2
    l.rotation_euler=(co((0,1,0))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=co((1.9,1.6,-3.4))); cam=bpy.context.object; cam.rotation_euler=(co((0,1.0,0))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.lens=48
scene=bpy.context.scene; scene.camera=cam; scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.render.resolution_x=850; scene.render.resolution_y=1050; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.filepath=os.path.join(WORK,'work/operator-studio.png')
bpy.ops.render.render(write_still=True)
print('Tactical uniform exported on the attributed animation rig.')
