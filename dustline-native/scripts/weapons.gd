extends RefCounted

# Shared by the buy menu, player and bot loadouts.
const DATA=[
	{"name":"AK-47","price":2700,"capacity":30,"reserve":90,"interval":.105,"reload":2.35,"damage":36,"head":112,"spread":.0018,"kick":.011,"sound":"rifle_shot"},
	{"name":"P9","price":0,"capacity":12,"reserve":48,"interval":.22,"reload":1.65,"damage":28,"head":84,"spread":.0025,"kick":.016,"sound":"pistol_shot"},
	{"name":"M4A1","price":3100,"capacity":30,"reserve":90,"interval":.089,"reload":2.7,"damage":32,"head":98,"spread":.0013,"kick":.008,"sound":"m4_shot"},
	{"name":"AWP","price":4750,"capacity":5,"reserve":25,"interval":1.4,"reload":3.1,"damage":120,"head":450,"spread":.0004,"kick":.048,"sound":"sniper_shot"}
]

# Optional authored replacement visuals from Quaternius Ultimate Guns Pack (CC0).
# Run tools/install-quaternius-guns.sh to install them. The original Dustline
# models remain as a fallback so the project still opens when the pack is absent.
const PACK_ROOT="res://assets/third_party/quaternius/ultimate_guns/"
const PACK_FILES=["ak74.glb","p226.glb","scarl.glb","awm.glb"]
const PACK_SCALE=[1.00,1.00,1.00,1.00]
const PACK_ROTATION=[
	Vector3(0,PI,0),
	Vector3(0,PI,0),
	Vector3(0,PI,0),
	Vector3(0,PI,0)
]
const PACK_OFFSET=[
	Vector3(0,0,0),
	Vector3(0,0,0),
	Vector3(0,0,0),
	Vector3(0,0,0)
]

static func make(index: int,generate=false) -> Node3D:
	if not generate:
		var upgraded=load_pack_weapon(index)
		if upgraded:return upgraded
	return make_legacy(index,generate)

static func load_pack_weapon(index: int) -> Node3D:
	if index<0 or index>=PACK_FILES.size():return null
	var path=PACK_ROOT+PACK_FILES[index]
	if not ResourceLoader.exists(path):return null
	var scene=load(path)
	if not scene:return null
	var visual=scene.instantiate()
	if not visual:return null
	var root=Node3D.new();root.name=DATA[index].name
	visual.name="PackVisual"
	visual.scale=Vector3.ONE*PACK_SCALE[index]
	visual.rotation=PACK_ROTATION[index]
	visual.position=PACK_OFFSET[index]
	root.add_child(visual)
	# Keep the existing first-person arms so the new weapon pack improves the
	# gun silhouettes without throwing away the current hand/reload presentation.
	var donor=load("res://assets/"+("sidearm" if index==1 else "rifle")+".glb").instantiate()
	move_arm(donor,root,"MainArm")
	move_arm(donor,root,"SupportArm")
	donor.free()
	# The Quaternius source models are static. Dummy mechanism anchors preserve
	# the player's existing reload/bolt animation contract without requiring the
	# source GLBs to be destructively edited.
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
