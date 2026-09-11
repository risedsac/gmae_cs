extends RefCounted

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
const REALISTIC_SCALE=[.82,1.0,.68,1.0]
const LEGACY_VIEWMODEL_PATHS=["res://assets/rifle.glb","res://assets/sidearm.glb","res://assets/m4a1.glb","res://assets/awp.glb"]
const UTILITY_ROOT="res://assets/third_party/realistic_utility/"
const AUTHORED_AK_VIEWMODEL="res://assets/third_party/fps_arms_ak74/FPS_AK74_Viewmodel.tscn"
const AUTHORED_ARMS_ROOT="res://assets/third_party/djmaesen_arms/"
const STATIC_ARM_PATHS=["",AUTHORED_ARMS_ROOT+"smg45_pistol_service_arms.glb",AUTHORED_ARMS_ROOT+"smg45_rifle_arms.glb",AUTHORED_ARMS_ROOT+"smg45_rifle_arms.glb"]
const RELOAD_ARMS_PATH=AUTHORED_ARMS_ROOT+"animated_reload_arms.glb"
const ARM_PRESENTATION_SCALE=[1.0,.64,.72,.72]
const RELOAD_CLIP_STEMS=["ak74","p226","m4a1","awm"]
const SOCKET_CONTRACTS=[
	{},
	{"primary":["PrimaryGripSocket"],"support":["SupportGripSocket"],"magazine":["Magazine"],"spare_magazine":["SpareMagazine"],"magazine_grip":["MagazineGripSocket"],"magazine_well":["MagazineWellSocket"],"action":["ChargingHandle"],"action_grip":["ChargingHandleSocket"]},
	{"primary":["PrimaryGrip"],"support":["ForegripContact"],"magazine":["Magazine"],"spare_magazine":["SpareMagazine"],"magazine_grip":["MagazineGripSocket"],"magazine_well":["MagazineWellSocket"],"action":["ChargingHandle"],"action_grip":["ChargingHandleSocket"]},
	{"primary":["PrimaryGripSocket"],"support":["SupportGripSocket"],"magazine":["Magazine"],"spare_magazine":["SpareMagazine"],"magazine_grip":["MagazineGripSocket"],"magazine_well":["MagazineWellSocket"],"action":["ChargingHandle"],"action_grip":["ChargingHandleSocket"]}
]
const VIEWMODEL_CLIPS={"draw":"Rig|AK_Draw","idle":"Rig|AK_Idle","reload":"Rig|AK_Reload_full","fire":"Rig|AK_Shot","walk":"Rig|AK_Walk","run":"Rig|AK_Run"}

static func make(index: int,generate=false) -> Node3D:
	if not generate:
		var upgraded=load_realistic_weapon(index,false)
		if upgraded:
			print("[DUSTLINE WEAPON] REALISTIC ",DATA[index].name," <- ",str(upgraded.get_meta("asset_source","unknown")))
			return upgraded
		push_warning("[DUSTLINE WEAPON] FALLBACK "+DATA[index].name+" -> original Dustline model")
	return make_legacy(index,generate)

static func make_player_viewmodel(index: int) -> Node3D:
	if index==0 and imported_resource(AUTHORED_AK_VIEWMODEL):
		var resource=ResourceLoader.load(AUTHORED_AK_VIEWMODEL,"",ResourceLoader.CACHE_MODE_REPLACE)
		if resource is PackedScene:
			var root=Node3D.new();root.name="AK-47 Authored Viewmodel";root.set_meta("authored_viewmodel",true);root.set_meta("asset_source",AUTHORED_AK_VIEWMODEL);root.set_meta("rig_bindings",{})
			var visual=(resource as PackedScene).instantiate();visual.name="FPSArmsAK74";root.add_child(visual)
			print("[DUSTLINE VIEWMODEL] AUTHORED AK-74M arms <- ",AUTHORED_AK_VIEWMODEL);return root
	var upgraded=load_realistic_weapon(index,true)
	if upgraded:upgraded.set_meta("authored_viewmodel",false);return upgraded
	var fallback=make_legacy(index,false);fallback.set_meta("authored_viewmodel",false);fallback.set_meta("rig_bindings",{});return fallback

static func viewmodel_clip(state: String) -> String:return str(VIEWMODEL_CLIPS.get(state,""))
static func reload_clip(index: int,empty_reload: bool) -> String:
	if index<0 or index>=RELOAD_CLIP_STEMS.size():return ""
	return "reload_"+RELOAD_CLIP_STEMS[index]+("_empty" if empty_reload else "_tactical")
static func viewmodel_bindings(root: Node3D) -> Dictionary:
	var value=root.get_meta("rig_bindings",{});return value if value is Dictionary else {}
static func file_exists(path: String) -> bool:return not path.is_empty() and FileAccess.file_exists(path)
static func imported_resource(path: String) -> bool:
	if not file_exists(path):return false
	if ResourceLoader.exists(path):return true
	push_error("[DUSTLINE WEAPON] File exists but Godot has not imported it: "+path);return false
static func realistic_path(index: int) -> String:
	if index<0 or index>=DEFAULT_PATHS.size():return ""
	var path=DEFAULT_PATHS[index]
	if imported_resource(path):return path
	if not file_exists(path):push_warning("[DUSTLINE WEAPON] Missing realistic asset: "+path)
	return ""

static func find_exact(root: Node,name_: String):
	if String(root.name)==name_:return root
	for child in root.get_children():
		var found=find_exact(child,name_)
		if found:return found
	return null
static func find_exact_any(root: Node,names: Array):
	for name_ in names:
		var found=find_exact(root,str(name_))
		if found:return found
	return null
static func required_contract_node(root: Node3D,index: int,key: String):
	var names: Array=SOCKET_CONTRACTS[index].get(key,[]);var node=find_exact_any(root,names)
	if not node:push_error("[DUSTLINE RIG] "+DATA[index].name+" missing exact node for "+key+": "+str(names))
	return node
static func optional_contract_node(root: Node3D,index: int,key: String):return find_exact_any(root,SOCKET_CONTRACTS[index].get(key,[]))

static func root_relative_transform(node: Node3D,root: Node3D) -> Transform3D:
	var chain: Array[Transform3D]=[];var current: Node=node
	while current!=null and current!=root:
		if current is Node3D:chain.push_front((current as Node3D).transform)
		current=current.get_parent()
	var result=Transform3D.IDENTITY
	for transform_ in chain:result=result*transform_
	return result

static func find_animation_player(node: Node):
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var found=find_animation_player(child)
		if found:return found
	return null

static func align_mount_marker(mount: Node3D,marker: Node3D,target_in_root: Transform3D):
	# Align translation + orientation only. Full affine inversion would cancel the
	# authored .64/.72 arm presentation scale and make the pistol hands enormous.
	var marker_in_mount=root_relative_transform(marker,mount)
	var marker_rotation=marker_in_mount.basis.orthonormalized();var target_rotation=target_in_root.basis.orthonormalized()
	mount.basis=target_rotation*marker_rotation.inverse()
	mount.position=target_in_root.origin-mount.basis*marker_in_mount.origin

static func calibrate_support_arm(root: Node3D,support_target: Node3D,left_arm: Node3D,left_grip: Node3D,index: int):
	var target=root_relative_transform(support_target,root);var current=root_relative_transform(left_grip,root);var delta=target.origin-current.origin
	var parent=left_arm.get_parent() as Node3D
	if parent:
		var parent_in_root=root_relative_transform(parent,root);left_arm.position+=parent_in_root.basis.inverse()*delta
	print("[DUSTLINE RIG] ",DATA[index].name," support correction=",snappedf(delta.length(),.0001)," m")

static func attach_static_arms(root: Node3D,index: int,bindings: Dictionary):
	var path=STATIC_ARM_PATHS[index]
	if path.is_empty() or not imported_resource(path):return
	var res=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REPLACE)
	if not res is PackedScene:return
	var mount=Node3D.new();mount.name="AuthoredArmsMount";root.add_child(mount)
	var arms=(res as PackedScene).instantiate();arms.name="AuthoredStaticArms";arms.scale=Vector3.ONE*ARM_PRESENTATION_SCALE[index];mount.add_child(arms)
	var right_grip=find_exact(arms,"RightGripFrame") as Node3D;var left_grip=find_exact(arms,"LeftGripFrame") as Node3D
	var right_arm=find_exact(arms,"RightArm") as Node3D;var left_arm=find_exact(arms,"LeftArm") as Node3D
	var primary=bindings.get("primary") as Node3D;var support=bindings.get("support") as Node3D
	if not right_grip or not left_grip or not right_arm or not left_arm or not primary or not support:
		push_error("[DUSTLINE RIG] authored static arm contract missing for "+DATA[index].name);mount.queue_free();return
	align_mount_marker(mount,right_grip,root_relative_transform(primary,root));calibrate_support_arm(root,support,left_arm,left_grip,index)
	bindings["arms_mount"]=mount;bindings["right_arm"]=right_arm;bindings["support_arm"]=left_arm;bindings["right_grip_marker"]=right_grip;bindings["support_grip_marker"]=left_grip

static func attach_reload_arms(root: Node3D,index: int,bindings: Dictionary):
	if not imported_resource(RELOAD_ARMS_PATH):return
	var res=ResourceLoader.load(RELOAD_ARMS_PATH,"",ResourceLoader.CACHE_MODE_REPLACE)
	if not res is PackedScene:return
	var primary=bindings.get("primary") as Node3D
	if not primary:return
	var mount=Node3D.new();mount.name="ReloadArmsMount";root.add_child(mount)
	var rig=(res as PackedScene).instantiate();rig.name="ReloadArmsRig";mount.add_child(rig)
	var right_grip=find_exact(rig,"RightGripFrame") as Node3D;var left_palm=find_exact(rig,"LeftPalmFrame") as Node3D;var left_mag=find_exact(rig,"LeftSidearmMagazineAnchorFrame") as Node3D
	var long_mesh=find_exact(rig,"LongGunReloadForearmsMesh") as Node3D;var side_mesh=find_exact(rig,"SidearmReloadForearmsMesh") as Node3D;var full_audit=find_exact(rig,"FullReloadArmsAuditMesh") as Node3D;var compatibility=find_exact(rig,"ReloadArmsMesh") as Node3D
	var anim=find_animation_player(rig)
	if not right_grip or not left_palm or not anim:push_error("[DUSTLINE RIG] animated reload arm contract missing for "+DATA[index].name);mount.queue_free();return
	align_mount_marker(mount,right_grip,root_relative_transform(primary,root))
	if long_mesh:long_mesh.visible=index!=1
	if side_mesh:side_mesh.visible=index==1
	if full_audit:full_audit.visible=false
	if compatibility:compatibility.visible=true
	mount.visible=false;bindings["reload_mount"]=mount;bindings["reload_rig"]=rig;bindings["reload_anim"]=anim;bindings["reload_left_palm"]=left_palm;bindings["reload_mag_anchor"]=left_mag if left_mag else left_palm

static func load_realistic_weapon(index: int,with_player_arms=false) -> Node3D:
	var path=realistic_path(index)
	if path.is_empty():return null
	var resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REPLACE)
	if not resource or not resource is PackedScene:push_error("[DUSTLINE WEAPON] Could not instantiate "+DATA[index].name+": "+path);return null
	var visual=(resource as PackedScene).instantiate();var root=Node3D.new();root.name=DATA[index].name;root.set_meta("asset_source",path);root.set_meta("weapon_index",index)
	visual.name="RealisticVisual";visual.scale=Vector3.ONE*REALISTIC_SCALE[index];root.add_child(visual)
	if not with_player_arms:return root
	var bindings={"visual":visual,"valid":true}
	bindings["primary"]=required_contract_node(visual,index,"primary");bindings["support"]=required_contract_node(visual,index,"support")
	bindings["magazine"]=required_contract_node(visual,index,"magazine");bindings["spare_magazine"]=optional_contract_node(visual,index,"spare_magazine")
	bindings["action"]=required_contract_node(visual,index,"action");bindings["magazine_well"]=optional_contract_node(visual,index,"magazine_well")
	var magazine=bindings.get("magazine") as Node3D;var action=bindings.get("action") as Node3D
	# Scope sockets to their real mechanisms first. Only fall back to an exact
	# scene-wide name for older exports; never use a prefix match.
	bindings["magazine_grip"]=find_exact(magazine,"MagazineGripSocket") if magazine else null
	if not bindings["magazine_grip"]:bindings["magazine_grip"]=required_contract_node(visual,index,"magazine_grip")
	bindings["action_grip"]=find_exact(action,"ChargingHandleSocket") if action else null
	if not bindings["action_grip"]:bindings["action_grip"]=required_contract_node(visual,index,"action_grip")
	for key in ["primary","support","magazine","magazine_grip","action","action_grip"]:
		if not bindings.get(key):bindings["valid"]=false
	if magazine:bindings["magazine_rest"]=magazine.transform
	var spare=bindings.get("spare_magazine") as Node3D
	if spare:bindings["spare_rest"]=spare.transform;spare.visible=false
	if action:bindings["action_rest"]=action.transform
	attach_static_arms(root,index,bindings);attach_reload_arms(root,index,bindings);root.set_meta("rig_bindings",bindings)
	print("[DUSTLINE RIG] ",DATA[index].name," exact_contract=",bindings.valid," skeletal_reload=",bindings.has("reload_anim"))
	return root

static func make_utility(kind: String) -> Node3D:
	var path=UTILITY_ROOT+("he_grenade.glb" if kind=="he" else "smoke_grenade.glb")
	if imported_resource(path):
		var resource=ResourceLoader.load(path)
		if resource is PackedScene:
			var root=Node3D.new();root.name="HE Grenade" if kind=="he" else "Smoke Grenade";var visual=(resource as PackedScene).instantiate();root.add_child(visual);fit_visual(visual,.18);return root
	var root=Node3D.new();root.name="HE Grenade" if kind=="he" else "Smoke Grenade"
	var body_mat=mat(Color(.18,.24,.11) if kind=="he" else Color(.32,.36,.34),.25,.62);var metal_mat=mat(Color(.17,.18,.17),.78,.30)
	var body=CylinderMesh.new();body.top_radius=.052;body.bottom_radius=.067;body.height=.13;body.radial_segments=16;add_mesh(root,body,Vector3.ZERO,body_mat)
	var neck=CylinderMesh.new();neck.top_radius=.022;neck.bottom_radius=.030;neck.height=.045;neck.radial_segments=12;add_mesh(root,neck,Vector3(0,.086,0),metal_mat)
	block(root,Vector3(.025,.105,0),Vector3(.018,.075,.035),metal_mat).rotation.z=-.32
	var ring=TorusMesh.new();ring.inner_radius=.016;ring.outer_radius=.023;ring.rings=12;ring.ring_segments=8;var pin=add_mesh(root,ring,Vector3(.062,.10,0),metal_mat);pin.rotation.x=PI/2;return root

static func mesh_bounds(root: Node3D) -> Dictionary:
	var minimum=Vector3(INF,INF,INF);var maximum=Vector3(-INF,-INF,-INF);var found=false
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		var transform_=root_relative_transform(mesh,root);var box=mesh.get_aabb()
		for i in 8:
			var p=transform_*box.get_endpoint(i);minimum=minimum.min(p);maximum=maximum.max(p);found=true
	return {"found":found,"min":minimum,"max":maximum}
static func fit_visual(root: Node3D,target_size: float):
	var measured=mesh_bounds(root)
	if measured.found:
		var extent: Vector3=measured.max-measured.min;var largest=maxf(extent.x,maxf(extent.y,extent.z))
		if largest>.0001:root.scale=Vector3.ONE*(target_size/largest)

static func make_legacy(index: int,generate=false) -> Node3D:
	if not generate:return load(LEGACY_VIEWMODEL_PATHS[index]).instantiate()
	# Retain the old generated M4/AWP fallback for source-only emergency use.
	if index<2:return load(LEGACY_VIEWMODEL_PATHS[index]).instantiate()
	var root=Node3D.new();root.name="M4A1" if index==2 else "AWP";var donor=load("res://assets/rifle.glb").instantiate()
	for part in donor.find_children("*","Node3D",true,false):
		if part.name in ["MainArm","SupportArm"]:
			for child in part.find_children("*","",true,false):child.owner=null
			part.owner=null;part.get_parent().remove_child(part);root.add_child(part)
	donor.free();var black=mat(Color(.055,.067,.073),.65,.34);var steel=mat(Color(.16,.18,.19),.8,.28);var grip=mat(Color(.045,.049,.049),.08,.83);var green=mat(Color(.23,.28,.15),.1,.78);var magazine=Node3D.new();magazine.name="Magazine";root.add_child(magazine)
	if index==2:
		block(root,Vector3(0,-.02,-.55),Vector3(.13,.16,.48),black);cylinder(root,Vector3(0,.005,-1.04),.032,.63,steel);block(root,Vector3(0,-.13,-.42),Vector3(.085,.22,.09),grip).rotation.x=-.23;block(magazine,Vector3(0,-.195,-.63),Vector3(.075,.28,.135),steel);block(root,Vector3(0,-.075,.12),Vector3(.14,.28,.035),black)
	else:
		block(root,Vector3(0,-.055,-.66),Vector3(.16,.14,.80),green);block(root,Vector3(0,-.08,-.06),Vector3(.13,.20,.35),green);cylinder(root,Vector3(0,.035,-1.13),.036,1.02,steel);block(magazine,Vector3(0,-.17,-.59),Vector3(.09,.14,.18),black);var bolt=Node3D.new();bolt.name="Bolt";root.add_child(bolt);block(bolt,Vector3(.10,.03,-.42),Vector3(.18,.025,.025),steel)
	return root

static func mat(color: Color,metal: float,rough: float) -> StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=rough;return m
static func add_mesh(root: Node3D,shape: Mesh,p: Vector3,m: Material) -> MeshInstance3D:
	var node=MeshInstance3D.new();node.mesh=shape;node.position=p;node.material_override=m;root.add_child(node);return node
static func block(root: Node3D,p: Vector3,size_: Vector3,m: Material) -> MeshInstance3D:
	var shape=BoxMesh.new();shape.size=size_;return add_mesh(root,shape,p,m)
static func cylinder(root: Node3D,p: Vector3,radius: float,length_: float,m: Material):
	var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=length_;shape.radial_segments=20;var node=add_mesh(root,shape,p,m);node.rotation.x=PI/2;return node
