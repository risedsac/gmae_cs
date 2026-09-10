extends RefCounted

# Shared by the buy menu, player and bot loadouts.
const DATA=[
	{"name":"AK-47","price":2700,"capacity":30,"reserve":90,"interval":.105,"reload":2.35,"damage":36,"head":112,"spread":.0018,"kick":.011,"sound":"rifle_shot"},
	{"name":"P9","price":0,"capacity":12,"reserve":48,"interval":.22,"reload":1.65,"damage":28,"head":84,"spread":.0025,"kick":.016,"sound":"pistol_shot"},
	{"name":"M4A1","price":3100,"capacity":30,"reserve":90,"interval":.089,"reload":2.7,"damage":32,"head":98,"spread":.0013,"kick":.008,"sound":"m4_shot"},
	{"name":"AWP","price":4750,"capacity":5,"reserve":25,"interval":1.4,"reload":3.1,"damage":120,"head":450,"spread":.0004,"kick":.048,"sound":"sniper_shot"}
]

const REALISTIC_ROOT="res://assets/third_party/realistic_weapons/"
const MANIFEST=REALISTIC_ROOT+"manifest.cfg"
const FIXED_PATHS=[
	REALISTIC_ROOT+"ak47/ak47_reloadable_fp.glb",
	"",
	REALISTIC_ROOT+"m4a1/steel_tide_m4a1.glb",
	""
]
const MANIFEST_KEYS=["ak47","pistol","m4a1","sniper"]
const REALISTIC_SCALE=[.82,1.0,.68,1.0]

static func make(index: int,generate=false) -> Node3D:
	if not generate:
		var upgraded=load_realistic_weapon(index)
		if upgraded:
			print("[DUSTLINE WEAPON] REALISTIC ",DATA[index].name," <- ",str(upgraded.get_meta("asset_source","unknown")))
			return upgraded
		push_warning("[DUSTLINE WEAPON] FALLBACK "+DATA[index].name+" -> original Dustline model")
	return make_legacy(index,generate)

static func file_exists(path: String) -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)

static func imported_resource(path: String) -> bool:
	if not file_exists(path):return false
	if ResourceLoader.exists(path):return true
	push_error("[DUSTLINE WEAPON] File exists but Godot has not imported it: "+path+". Run: ./engine/Godot.x86_64 --headless --path . --import")
	return false

static func realistic_path(index: int) -> String:
	if index<0 or index>=4:return ""
	var fixed_path=FIXED_PATHS[index]
	if not fixed_path.is_empty():
		if imported_resource(fixed_path):return fixed_path
		if not file_exists(fixed_path):push_warning("[DUSTLINE WEAPON] Missing realistic asset: "+fixed_path)
	if not file_exists(MANIFEST):
		if fixed_path.is_empty():push_warning("[DUSTLINE WEAPON] Missing manifest for "+DATA[index].name+": "+MANIFEST)
		return ""
	var cfg=ConfigFile.new()
	var err=cfg.load(MANIFEST)
	if err!=OK:
		push_error("[DUSTLINE WEAPON] Could not read manifest: "+MANIFEST+" error="+str(err))
		return ""
	var path=str(cfg.get_value("weapons",MANIFEST_KEYS[index],""))
	if path.is_empty():
		if fixed_path.is_empty():push_warning("[DUSTLINE WEAPON] No realistic path configured for "+DATA[index].name)
		return ""
	if imported_resource(path):return path
	if not file_exists(path):push_error("[DUSTLINE WEAPON] Manifest points to missing file for "+DATA[index].name+": "+path)
	return ""

static func load_realistic_weapon(index: int) -> Node3D:
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
	if not visual:
		push_error("[DUSTLINE WEAPON] PackedScene.instantiate failed: "+path)
		return null
	var root=Node3D.new();root.name=DATA[index].name
	root.set_meta("asset_source",path)
	visual.name="RealisticVisual"
	visual.scale=Vector3.ONE*REALISTIC_SCALE[index]
	if path.contains("stein_classic_weapons"):visual.rotation.y=PI/2
	root.add_child(visual)
	var donor=load("res://assets/"+("sidearm" if index==1 else "rifle")+".glb").instantiate()
	move_arm(donor,root,"MainArm")
	move_arm(donor,root,"SupportArm")
	donor.free()
	for part in visual.find_children("*","Node3D",true,false):
		if part.name=="Magazine":part.name="AuthoredMagazine"
		elif part.name=="Bolt" or part.name=="ChargingHandle":part.name="AuthoredAction"
	ensure_anchor(root,"Magazine")
	ensure_anchor(root,"Bolt")
	return root

static func move_arm(donor: Node3D,root: Node3D,prefix: String):
	for part in donor.find_children("*","Node3D",true,false):
		if part.name.begins_with(prefix):
			part.owner=null
			part.get_parent().remove_child(part)
			root.add_child(part)
			return

static func ensure_anchor(root: Node3D,prefix: String):
	for part in root.find_children("*","Node3D",true,false):
		if part.name.begins_with(prefix):return
	var anchor=Node3D.new();anchor.name=prefix;root.add_child(anchor)

static func make_legacy(index: int,generate=false) -> Node3D:
	if index>=2 and not generate:return load("res://assets/"+("m4a1" if index==2 else "awp")+".glb").instantiate()
	if index<2:return load("res://assets/"+("rifle" if index==0 else "sidearm")+".glb").instantiate()
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
		for i in 5:block(mag,Vector3(.04,-.195,-.58-i*.021),Vector3(.009,.23,.009),black)
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
		var knob=SphereMesh.new();knob.radius=.035;knob.height=.07;add_mesh(bolt,knob,Vector3(.20,.03,-.42),black)
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
