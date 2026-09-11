extends RefCounted

# Shared by buy menu, player and bot loadouts.
const DATA=[
	{"name":"AK-47","price":2700,"capacity":30,"reserve":90,"interval":.105,"reload":2.35,"damage":36,"head":112,"spread":.0018,"kick":.011,"sound":"rifle_shot"},
	{"name":"P9","price":0,"capacity":12,"reserve":48,"interval":.22,"reload":1.65,"damage":28,"head":84,"spread":.0025,"kick":.016,"sound":"pistol_shot"},
	{"name":"M4A1","price":3100,"capacity":30,"reserve":90,"interval":.089,"reload":2.7,"damage":32,"head":98,"spread":.0013,"kick":.008,"sound":"m4_shot"},
	{"name":"AWP","price":4750,"capacity":5,"reserve":25,"interval":1.4,"reload":3.1,"damage":120,"head":450,"spread":.0004,"kick":.048,"sound":"sniper_shot"}
]

const REALISTIC_ROOT="res://assets/third_party/realistic_weapons/"
const DEFAULT_PATHS=[
	REALISTIC_ROOT+"ak47/ak47_reloadable_fp.glb",
	REALISTIC_ROOT+"fallback/p226_reloadable.glb",
	REALISTIC_ROOT+"m4a1/steel_tide_m4a1.glb",
	REALISTIC_ROOT+"fallback/awm_reloadable.glb"
]
# World/BOT presentation scale. Player viewmodels are fitted automatically to
# the original Dustline viewmodel bounds instead of reusing these values.
const REALISTIC_SCALE=[.82,1.0,.68,1.0]
const LEGACY_VIEWMODEL_PATHS=[
	"res://assets/rifle.glb",
	"res://assets/sidearm.glb",
	"res://assets/m4a1.glb",
	"res://assets/awp.glb"
]
const PLAYER_VISUAL_NUDGE=[
	Vector3.ZERO,
	Vector3(0.0,-.006,-.012),
	Vector3(0.0,-.008,-.018),
	Vector3(0.0,-.012,-.025)
]
const UTILITY_ROOT="res://assets/third_party/realistic_utility/"
const AUTHORED_AK_VIEWMODEL="res://assets/third_party/fps_arms_ak74/FPS_AK74_Viewmodel.tscn"
const VIEWMODEL_CLIPS={
	"draw":"Rig|AK_Draw",
	"idle":"Rig|AK_Idle",
	"reload":"Rig|AK_Reload_full",
	"fire":"Rig|AK_Shot",
	"walk":"Rig|AK_Walk",
	"run":"Rig|AK_Run"
}

# World/BOT/store constructor: only the weapon model. Do not transplant FPS
# arms into third-person actors or UI previews.
static func make(index: int,generate=false) -> Node3D:
	if not generate:
		var upgraded=load_realistic_weapon(index,false)
		if upgraded:
			print("[DUSTLINE WEAPON] REALISTIC ",DATA[index].name," <- ",str(upgraded.get_meta("asset_source","unknown")))
			return upgraded
		push_warning("[DUSTLINE WEAPON] FALLBACK "+DATA[index].name+" -> original Dustline model")
	return make_legacy(index,generate)

# Player-only constructor. AK uses the authored arms+weapon rig. P9/M4/AWP use
# the realistic gun but align it to the exact volume previously occupied by the
# old Dustline gun, so the existing hands actually wrap the replacement weapon.
static func make_player_viewmodel(index: int) -> Node3D:
	if index==0 and imported_resource(AUTHORED_AK_VIEWMODEL):
		var resource=ResourceLoader.load(AUTHORED_AK_VIEWMODEL,"",ResourceLoader.CACHE_MODE_REPLACE)
		if resource is PackedScene:
			var root=Node3D.new();root.name="AK-47 Authored Viewmodel"
			root.set_meta("authored_viewmodel",true);root.set_meta("asset_source",AUTHORED_AK_VIEWMODEL)
			var visual=(resource as PackedScene).instantiate();visual.name="FPSArmsAK74";root.add_child(visual)
			print("[DUSTLINE VIEWMODEL] AUTHORED AK-74M arms <- ",AUTHORED_AK_VIEWMODEL)
			return root
	var upgraded=load_realistic_weapon(index,true)
	if upgraded:
		upgraded.set_meta("authored_viewmodel",false)
		return upgraded
	var fallback=make_legacy(index,false);fallback.set_meta("authored_viewmodel",false);return fallback

static func viewmodel_clip(state: String) -> String:
	return str(VIEWMODEL_CLIPS.get(state,""))

static func file_exists(path: String) -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)

static func imported_resource(path: String) -> bool:
	if not file_exists(path):return false
	if ResourceLoader.exists(path):return true
	push_error("[DUSTLINE WEAPON] File exists but Godot has not imported it: "+path+". Run Godot --headless --path . --import")
	return false

static func realistic_path(index: int) -> String:
	if index<0 or index>=DEFAULT_PATHS.size():return ""
	var path=DEFAULT_PATHS[index]
	if imported_resource(path):return path
	if not file_exists(path):push_warning("[DUSTLINE WEAPON] Missing realistic asset: "+path)
	return ""

static func load_realistic_weapon(index: int,with_player_arms=false) -> Node3D:
	var path=realistic_path(index)
	if path.is_empty():return null
	var resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REPLACE)
	if not resource:
		push_error("[DUSTLINE WEAPON] ResourceLoader failed for "+DATA[index].name+": "+path)
		return null
	if not resource is PackedScene:
		push_error("[DUSTLINE WEAPON] Expected PackedScene but got "+resource.get_class()+" for "+path)
		return null
	var visual=(resource as PackedScene).instantiate()
	if not visual:return null
	var root=Node3D.new();root.name=DATA[index].name;root.set_meta("asset_source",path)
	visual.name="RealisticVisual";root.add_child(visual)

	if with_player_arms:
		var donor_resource=ResourceLoader.load(LEGACY_VIEWMODEL_PATHS[index])
		if donor_resource is PackedScene:
			var donor=(donor_resource as PackedScene).instantiate()
			# Match the replacement gun to the old gun's root-space bounding box.
			# The hands were authored around that old volume, so this gives us a
			# deterministic grip alignment without magic per-model absolute coords.
			align_visual_to_legacy(visual,donor,index)
			move_arm_preserving_pose(donor,root,"MainArm")
			move_arm_preserving_pose(donor,root,"SupportArm")
			donor.free()
		else:
			visual.scale=Vector3.ONE*REALISTIC_SCALE[index]
	else:
		visual.scale=Vector3.ONE*REALISTIC_SCALE[index]

	for part in visual.find_children("*","Node3D",true,false):
		if part.name=="Magazine":part.name="AuthoredMagazine"
		elif part.name=="Bolt" or part.name=="ChargingHandle":part.name="AuthoredAction"
	if with_player_arms:
		ensure_anchor(root,"Magazine");ensure_anchor(root,"Bolt")
	return root

static func node_is_under_arm(node: Node,stop: Node) -> bool:
	var current: Node=node
	while current!=null and current!=stop:
		if current.name.begins_with("MainArm") or current.name.begins_with("SupportArm"):return true
		current=current.get_parent()
	return false

static func mesh_bounds(root: Node3D,skip_arms=false) -> Dictionary:
	var minimum=Vector3(INF,INF,INF)
	var maximum=Vector3(-INF,-INF,-INF)
	var found=false
	if root is MeshInstance3D and (not skip_arms or not node_is_under_arm(root,root)):
		var box=(root as MeshInstance3D).get_aabb()
		for i in 8:
			var p=box.get_endpoint(i);minimum=minimum.min(p);maximum=maximum.max(p);found=true
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if skip_arms and node_is_under_arm(mesh,root):continue
		var transform_=root_relative_transform(mesh,root)
		var box=mesh.get_aabb()
		for i in 8:
			var p=transform_*box.get_endpoint(i);minimum=minimum.min(p);maximum=maximum.max(p);found=true
	return {"found":found,"min":minimum,"max":maximum}

static func align_visual_to_legacy(visual: Node3D,legacy: Node3D,index: int):
	# Reset source presentation transform before measuring authored geometry.
	visual.position=Vector3.ZERO;visual.rotation=Vector3.ZERO;visual.scale=Vector3.ONE
	var source=mesh_bounds(visual,false)
	var target=mesh_bounds(legacy,true)
	if not source.found or not target.found:
		visual.scale=Vector3.ONE*REALISTIC_SCALE[index]
		push_warning("[DUSTLINE VIEWMODEL] Could not calculate gun bounds for "+DATA[index].name)
		return
	var source_min: Vector3=source.min;var source_max: Vector3=source.max
	var target_min: Vector3=target.min;var target_max: Vector3=target.max
	var source_size=source_max-source_min;var target_size=target_max-target_min
	# All validated runtime GLBs use X lateral / Y up / -Z muzzle-forward. Z
	# therefore gives the most stable length match and ignores tall optics.
	var scale=REALISTIC_SCALE[index]
	if source_size.z>.001 and target_size.z>.001:scale=target_size.z/source_size.z
	else:
		var source_longest=maxf(source_size.x,maxf(source_size.y,source_size.z))
		var target_longest=maxf(target_size.x,maxf(target_size.y,target_size.z))
		if source_longest>.001:scale=target_longest/source_longest
	scale=clampf(scale,.08,8.0)
	var source_center=(source_min+source_max)*.5
	var target_center=(target_min+target_max)*.5
	visual.scale=Vector3.ONE*scale
	visual.position=target_center-source_center*scale+PLAYER_VISUAL_NUDGE[index]
	print("[DUSTLINE VIEWMODEL ALIGN] ",DATA[index].name," scale=",snappedf(scale,.001)," pos=",visual.position)

static func root_relative_transform(node: Node3D,root: Node3D) -> Transform3D:
	var chain: Array[Transform3D]=[]
	var current: Node=node
	while current!=null and current!=root:
		if current is Node3D:chain.push_front((current as Node3D).transform)
		current=current.get_parent()
	var result=Transform3D.IDENTITY
	for transform_ in chain:result=result*transform_
	return result

static func move_arm_preserving_pose(donor: Node3D,root: Node3D,prefix: String):
	for part in donor.find_children("*","Node3D",true,false):
		if part.name.begins_with(prefix):
			var pose=root_relative_transform(part,donor)
			part.owner=null;part.get_parent().remove_child(part);root.add_child(part);part.transform=pose
			return

static func ensure_anchor(root: Node3D,prefix: String):
	for part in root.find_children("*","Node3D",true,false):
		if part.name.begins_with(prefix):return
	var anchor=Node3D.new();anchor.name=prefix;root.add_child(anchor)

static func make_utility(kind: String) -> Node3D:
	var path=UTILITY_ROOT+("he_grenade.glb" if kind=="he" else "smoke_grenade.glb")
	if imported_resource(path):
		var resource=ResourceLoader.load(path)
		if resource is PackedScene:
			var root=Node3D.new();root.name="HE Grenade" if kind=="he" else "Smoke Grenade"
			var visual=(resource as PackedScene).instantiate();root.add_child(visual);fit_visual(visual,.18);return root
	var root=Node3D.new();root.name="HE Grenade" if kind=="he" else "Smoke Grenade"
	var body_mat=mat(Color(.18,.24,.11) if kind=="he" else Color(.32,.36,.34),.25,.62)
	var metal_mat=mat(Color(.17,.18,.17),.78,.30)
	var body=CylinderMesh.new();body.top_radius=.052;body.bottom_radius=.067;body.height=.13;body.radial_segments=16
	add_mesh(root,body,Vector3.ZERO,body_mat)
	var neck=CylinderMesh.new();neck.top_radius=.022;neck.bottom_radius=.030;neck.height=.045;neck.radial_segments=12
	add_mesh(root,neck,Vector3(0,.086,0),metal_mat)
	block(root,Vector3(.025,.105,0),Vector3(.018,.075,.035),metal_mat).rotation.z=-.32
	var ring=TorusMesh.new();ring.inner_radius=.016;ring.outer_radius=.023;ring.rings=12;ring.ring_segments=8
	var pin=add_mesh(root,ring,Vector3(.062,.10,0),metal_mat);pin.rotation.x=PI/2
	return root

static func fit_visual(root: Node3D,target_size: float):
	var measured=mesh_bounds(root,false)
	if measured.found:
		var extent: Vector3=measured.max-measured.min
		var largest=maxf(extent.x,maxf(extent.y,extent.z))
		if largest>.0001:root.scale=Vector3.ONE*(target_size/largest)

static func make_legacy(index: int,generate=false) -> Node3D:
	if not generate:return load(LEGACY_VIEWMODEL_PATHS[index]).instantiate()
	if index<2:return load(LEGACY_VIEWMODEL_PATHS[index]).instantiate()
	var root=Node3D.new();root.name="M4A1" if index==2 else "AWP"
	var donor=load("res://assets/rifle.glb").instantiate()
	for part in donor.find_children("*","Node3D",true,false):
		if part.name in ["MainArm","SupportArm"]:
			for child in part.find_children("*","",true,false):child.owner=null
			part.owner=null;part.get_parent().remove_child(part);root.add_child(part)
	donor.free()
	var black=mat(Color(.055,.067,.073),.65,.34)
	var steel=mat(Color(.16,.18,.19),.8,.28)
	var grip=mat(Color(.045,.049,.049),.08,.83)
	var green=mat(Color(.23,.28,.15),.1,.78)
	var mag=Node3D.new();mag.name="Magazine";root.add_child(mag)
	if index==2:
		block(root,Vector3(0,-.02,-.55),Vector3(.13,.16,.48),black)
		block(root,Vector3(0,.067,-.55),Vector3(.10,.035,.56),steel)
		for i in 18:block(root,Vector3(0,.09,-.81+i*.029),Vector3(.105,.02,.013),black)
		cylinder(root,Vector3(0,.005,-1.04),.032,.63,steel)
		block(root,Vector3(0,-.005,-.90),Vector3(.135,.12,.32),black)
		for i in 9:
			block(root,Vector3(.071,-.015,-.77-i*.034),Vector3(.016,.085,.014),steel)
			block(root,Vector3(-.071,-.015,-.77-i*.034),Vector3(.016,.085,.014),steel)
		cylinder(root,Vector3(0,.005,-1.39),.045,.105,black)
		block(root,Vector3(0,.07,-1.22),Vector3(.025,.15,.025),black)
		block(root,Vector3(0,-.13,-.42),Vector3(.085,.22,.09),grip).rotation.x=-.23
		block(mag,Vector3(0,-.195,-.63),Vector3(.075,.28,.135),steel).rotation.x=.07
		cylinder(root,Vector3(0,-.015,-.15),.04,.27,steel)
		block(root,Vector3(0,-.065,.005),Vector3(.12,.22,.22),grip)
		block(root,Vector3(0,-.075,.12),Vector3(.14,.28,.035),black)
		block(root,Vector3(0,.12,-.48),Vector3(.08,.06,.05),black)
	else:
		block(root,Vector3(0,-.055,-.66),Vector3(.16,.14,.80),green)
		block(root,Vector3(0,-.08,-.06),Vector3(.13,.20,.35),green)
		block(root,Vector3(0,-.07,.11),Vector3(.15,.25,.06),grip)
		block(root,Vector3(0,-.17,-.38),Vector3(.075,.20,.09),green).rotation.x=-.25
		cylinder(root,Vector3(0,.035,-1.13),.036,1.02,steel)
		cylinder(root,Vector3(0,.035,-1.65),.055,.10,black)
		block(mag,Vector3(0,-.17,-.59),Vector3(.09,.14,.18),black)
		for z in [-.44,-.73]:block(root,Vector3(0,.13,z),Vector3(.09,.16,.05),black)
		cylinder(root,Vector3(0,.23,-.61),.055,.53,black)
		cylinder(root,Vector3(0,.23,-.88),.085,.14,black)
		cylinder(root,Vector3(0,.23,-.31),.065,.12,black)
		cylinder(root,Vector3(0,.23,-.959),.075,.004,mat(Color(.06,.20,.24),.9,.06))
		var bolt=Node3D.new();bolt.name="Bolt";root.add_child(bolt)
		block(bolt,Vector3(.10,.03,-.42),Vector3(.18,.025,.025),steel)
		var knob=SphereMesh.new();knob.radius=.035;knob.height=.07;add_mesh(root,knob,Vector3(.20,.03,-.42),black)
		for x in [-.08,.08]:block(root,Vector3(x,-.10,-1.12),Vector3(.022,.18,.026),steel).rotation.z=x*3
	return root

static func mat(color: Color,metal: float,rough: float) -> StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=rough;return m

static func add_mesh(root: Node3D,shape: Mesh,p: Vector3,m: Material) -> MeshInstance3D:
	var node=MeshInstance3D.new();node.mesh=shape;node.position=p;node.material_override=m;root.add_child(node);return node

static func block(root: Node3D,p: Vector3,size_: Vector3,m: Material) -> MeshInstance3D:
	var shape=BoxMesh.new();shape.size=size_;return add_mesh(root,shape,p,m)

static func cylinder(root: Node3D,p: Vector3,radius: float,length_: float,m: Material):
	var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=length_;shape.radial_segments=20
	var node=add_mesh(root,shape,p,m);node.rotation.x=PI/2;return node
