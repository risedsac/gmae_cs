extends Node3D

# x, z, width, depth, height. Buildings double as authoritative collision and navigation.
const BUILDINGS = [
	[-18,19,12,18,7], [18,22,12,10,7], [-8,-1,10,16,7.5],
	[10,4,10,19,7], [9,-13,8,7,6.2], [-7,-18,14,2,6.6], [11,-18,12,2,6.6],
	[-10,-27,2,10,6], [9,-28,2,8,6],
	[0,32,50,2,8], [0,-33,50,2,8], [-25,0,2,68,12], [25,0,2,68,12]
]
const CRATES = [[16,-23,2.2,2.2,1.6], [20,-25,2.3,2.3,2], [-18,-24,2.3,2.3,1.8], [-21,-20,2,2,1.7], [2,-7,2,2,1.6], [-7,12,2,2,1.7], [18,10,2,2,1.6]]
const SITES={"A":Vector3(18,0,-23),"B":Vector3(-18,0,-24)}
const T_SPAWN=Vector3(0,0,25)
const CT_SPAWN=Vector3(0,0,-28)
var solids: Array[Rect2] = []
var cover_pairs: Array = []
var nav = AStarGrid2D.new()
var plaster: StandardMaterial3D
var stone: StandardMaterial3D
var blue: StandardMaterial3D
var wood: StandardMaterial3D
var crate_scene = preload("res://assets/crate/wooden_crate_02.gltf")

func _ready():
	seed(47521)
	plaster = pbr("beige_wall_001", Color(1,.94,.80), .33)
	stone = pbr("beige_wall_001", Color(.77,.65,.46), .5)
	blue = material(Color(.13,.28,.32), .78)
	wood = material(Color(.25,.19,.12), .87)
	box(Vector3(0,-.25,0), Vector3(120,.5,130), pbr("sandy_gravel_02",Color(.9,.84,.7),.4), true, false)
	for i in BUILDINGS.size():
		var b = BUILDINGS[i]
		var pos = Vector3(b[0],b[4]/2.,b[1])
		box(pos,Vector3(b[2],b[4],b[3]),plaster if i%3 else stone,true,true)
		# Roof coping and a darker foundation make silhouettes readable.
		box(pos+Vector3(0,b[4]/2.+.07,0),Vector3(b[2]+.18,.20,b[3]+.18),stone)
		box(Vector3(b[0],.18,b[1]),Vector3(b[2]+.06,.36,b[3]+.06),stone)
		if i < 8:
			facade(b)
	for b in CRATES:
		crate(Vector3(b[0],0,b[1]),Vector3(b[2],b[4],b[3]))
	crate(Vector3(-18,1.8,-24),Vector3(1.3,1.1,1.4), false)
	bomb_sites()
	arch()
	for p in [Vector3(22,0,-15),Vector3(-22,0,-8),Vector3(-2,0,-14)]:
		barrel(p)
	for p in [Vector3(-21,0,30),Vector3(21,0,-30),Vector3(19,0,30),Vector3(-22,0,-14)]:
		palm(p)
	# Buildings outside the playable perimeter give the town a skyline.
	for i in 16:
		var x = -48.+i*6.8
		var h = randf_range(8,15)
		box(Vector3(x,h/2,-43-randf()*6),Vector3(5,h,7),plaster)
		if i%3 == 0:
			var dome = SphereMesh.new(); dome.radius=2.4; dome.height=4.8
			mesh(dome,Vector3(x,h,-44),stone)
	minaret(Vector3(-17,0,-39))
	for z in [-9.,17.]:
		wire(Vector3(-12,6,z),Vector3(15,7,z-2))
	sign_text("A →",Vector3(5.98,2.7,0),Vector3(0,-PI/2,0),Color(.50,.17,.08),100)
	sign_text("← B",Vector3(-2.98,2.4,1),Vector3(0,PI/2,0),Color(.15,.28,.33),66)
	sign_text("OLD QUARTER",Vector3(2.5,5.7,-16.96),Vector3.ZERO,Color(.29,.24,.16),22)
	build_nav()
	lighting()

func material(color: Color, roughness: float) -> StandardMaterial3D:
	var m=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=roughness
	return m

func pbr(slug: String, tint: Color, tiling: float) -> StandardMaterial3D:
	var m=material(tint,.95)
	m.albedo_texture=load("res://assets/materials/"+slug+"_albedo.jpg")
	m.normal_enabled=true; m.normal_texture=load("res://assets/materials/"+slug+"_normal.jpg")
	m.normal_scale=.8; m.roughness_texture=load("res://assets/materials/"+slug+"_roughness.jpg")
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar=true; m.uv1_world_triplanar=true; m.uv1_scale=Vector3.ONE*tiling
	return m

func mesh(shape: Mesh,pos: Vector3,mat: Material) -> MeshInstance3D:
	var m=MeshInstance3D.new(); m.mesh=shape; m.material_override=mat; m.position=pos; add_child(m)
	return m

func box(pos: Vector3,size_: Vector3,mat: Material,collide=false, navigation=false) -> MeshInstance3D:
	var shape=BoxMesh.new(); shape.size=size_
	var m=mesh(shape,pos,mat)
	if collide:
		var body=StaticBody3D.new(); body.collision_layer=1; body.collision_mask=0; add_child(body); body.position=pos
		var c=CollisionShape3D.new(); var s=BoxShape3D.new(); s.size=size_; c.shape=s; body.add_child(c)
	if navigation:
		var rect=Rect2(Vector2(pos.x-size_.x/2,pos.z-size_.z/2),Vector2(size_.x,size_.z))
		solids.append(rect)
		# Both directions around every corner, verified against LOS at decision time.
		for side in [-1.,1.]:
			for corner in [-1.,1.]:
				cover_pairs.append([Vector3(pos.x+side*(size_.x/2+.7),0,pos.z+corner*(size_.z/2-.6)),Vector3(pos.x+side*(size_.x/2+.7),0,pos.z+corner*(size_.z/2+1.))])
				cover_pairs.append([Vector3(pos.x+corner*(size_.x/2-.6),0,pos.z+side*(size_.z/2+.7)),Vector3(pos.x+corner*(size_.x/2+1.),0,pos.z+side*(size_.z/2+.7))])
	return m

func facade(b):
	for side in [-1.,1.]:
		var x=b[0]+side*(b[2]/2.+.03)
		for j in range(1,int(b[3]/3.3)):
			var z=b[1]-b[3]/2.+j*3.3
			box(Vector3(x,3.9,z),Vector3(.14,1.75,1.17),wood)
			for slat in 8:
				box(Vector3(x+side*.08,3.14+slat*.21,z),Vector3(.07,.13,1.07),blue)
			box(Vector3(x+side*.12,2.92,z),Vector3(.36,.16,1.4),stone)
		# Ground level door, step is only trim outside the walk lane.
		var z=b[1]+b[3]*.28
		box(Vector3(x,1.25,z),Vector3(.08,2.5,1.45),wood)
		for slat in 6:
			box(Vector3(x+side*.06,1.25,z-.6+slat*.24),Vector3(.07,2.4,.20),blue)
		box(Vector3(x+side*.19,2.65,z),Vector3(.48,.18,1.8),stone)
		var cloth=material(Color(.57,.39,.21),1)
		var awn=box(Vector3(x+side*.8,3.0,z),Vector3(1.6,.06,2.6),cloth)
		awn.rotation.z=side*.16
		box(Vector3(x+side*1.55,2.78,z),Vector3(.08,.32,2.6),cloth)

func crate(pos: Vector3,size_: Vector3, navigation=true):
	var invisible=material(Color(0,0,0,0),1); invisible.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var collider=box(pos+Vector3(0,size_.y/2,0),size_,invisible,true,navigation)
	collider.visible=false
	var model=crate_scene.instantiate(); add_child(model)
	var bounds=AABB(); var first=true
	for m in model.find_children("*","MeshInstance3D",true,false):
		var bb=m.global_transform*m.get_aabb()
		bounds=bb if first else bounds.merge(bb); first=false
	model.scale=size_/bounds.size
	model.position=pos-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*model.scale

func arch():
	# Extruded curved opening; visual mesh and collision share the same surface.
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var a=i*PI/40.;var b=(i+1)*PI/40.
		var p=Vector2(2.5+cos(a)*2.5,2.75+sin(a)*2.5)
		var q=Vector2(2.5+cos(b)*2.5,2.75+sin(b)*2.5)
		var v=[Vector3(p.x,p.y,-17),Vector3(q.x,q.y,-17),Vector3(q.x,6.6,-17),Vector3(p.x,6.6,-17),Vector3(p.x,p.y,-19),Vector3(q.x,q.y,-19),Vector3(q.x,6.6,-19),Vector3(p.x,6.6,-19)]
		for face in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[3,7,6,2]]:
			for k in [face[0],face[1],face[2],face[0],face[2],face[3]]:st.add_vertex(v[k])
	st.generate_normals();var arch_mesh=st.commit()
	var arch_material=plaster.duplicate();arch_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh(arch_mesh,Vector3.ZERO,arch_material)
	var body=StaticBody3D.new();var c=CollisionShape3D.new();c.shape=arch_mesh.create_trimesh_shape();body.add_child(c);add_child(body)
	for i in 24:
		var a=(i+.5)*PI/24.
		var wedge=box(Vector3(2.5+cos(a)*2.65,2.75+sin(a)*2.65,-16.92),Vector3(.335,.30,.18),stone)
		wedge.rotation.z=a+PI/2
	for x in [-.12,5.12]:
		box(Vector3(x,1.37,-16.94),Vector3(.25,2.75,.18),stone)
	# Parted wooden double doors preserve a 2.4 m passage through mid.
	var iron=material(Color(.14,.16,.15),.55)
	for x in [.65,4.35]:
		box(Vector3(x,1.4,-18),Vector3(1.3,2.8,.22),wood,true,true)
		for plank in 7:
			box(Vector3(x-.54+plank*.18,1.4,-17.875),Vector3(.165,2.75,.025),wood)
		for y in [.4,1.3,2.3]:
			box(Vector3(x,y,-17.84),Vector3(1.26,.09,.04),iron)
			for bolt in 5:
				var rivet=SphereMesh.new();rivet.radius=.018;rivet.height=.036
				mesh(rivet,Vector3(x-.5+bolt*.25,y,-17.81),iron)


func barrel(pos: Vector3):
	var drum=CylinderMesh.new();drum.top_radius=.4;drum.bottom_radius=.4;drum.height=1.26
	mesh(drum,pos+Vector3.UP*.63,blue)
	for h in [.10,.42,.91,1.18]:
		var ring=CylinderMesh.new();ring.top_radius=.415;ring.bottom_radius=.415;ring.height=.035
		mesh(ring,pos+Vector3.UP*h,wood)
	var body=StaticBody3D.new();add_child(body);body.position=pos+Vector3.UP*.63
	var c=CollisionShape3D.new();var s=CylinderShape3D.new();s.radius=.4;s.height=1.26;c.shape=s;body.add_child(c)
	solids.append(Rect2(Vector2(pos.x-.43,pos.z-.43),Vector2(.86,.86)))

func palm(pos: Vector3):
	var trunk=CylinderMesh.new();trunk.top_radius=.15;trunk.bottom_radius=.27;trunk.height=8
	mesh(trunk,pos+Vector3.UP*4,wood)
	var leafmat=material(Color(.26,.32,.13),1); leafmat.cull_mode=BaseMaterial3D.CULL_DISABLED
	for j in 10:
		var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var direction=Vector3(cos(j*TAU/10),0,sin(j*TAU/10));var side=direction.cross(Vector3.UP)
		for k in 8:
			var t=k/8.;var t2=(k+1)/8.
			var a=pos+direction*t*3.9+Vector3.UP*(8+sin(t*PI)*.9-t*1.1)
			var b=pos+direction*t2*3.9+Vector3.UP*(8+sin(t2*PI)*.9-t2*1.1)
			var width=sin(t*PI)*.48+.025;var width2=sin(t2*PI)*.48+.025
			for v in [a-side*width,b-side*width2,b+side*width2,a-side*width,b+side*width2,a+side*width]:surface.add_vertex(v)
		surface.generate_normals();mesh(surface.commit(),Vector3.ZERO,leafmat)

func minaret(pos: Vector3):
	box(pos+Vector3.UP*8,Vector3(3.4,16,3.4),stone)
	box(pos+Vector3.UP*13,Vector3(4.1,.45,4.1),plaster)
	var cap=CylinderMesh.new();cap.top_radius=0;cap.bottom_radius=2;cap.height=3
	mesh(cap,pos+Vector3.UP*17.5,blue)

func wire(a: Vector3,b: Vector3):
	for i in 14:
		var t=i/14.;var t2=(i+1)/14.
		var p=a.lerp(b,t)-Vector3.UP*sin(t*PI)*1.2
		var q=a.lerp(b,t2)-Vector3.UP*sin(t2*PI)*1.2
		var cylinder=CylinderMesh.new();cylinder.top_radius=.016;cylinder.bottom_radius=.016;cylinder.height=p.distance_to(q)
		var m=mesh(cylinder,(p+q)/2,wood);m.quaternion=Quaternion(Vector3.UP,(q-p).normalized())

func sign_text(text_: String,pos: Vector3,rot: Vector3,color: Color,font_size_: int):
	var label=Label3D.new();label.text=text_;label.font_size=font_size_;label.pixel_size=.014
	label.modulate=color;label.outline_size=0;label.position=pos;label.rotation=rot;add_child(label)

func walkable(pos: Vector3, margin=.44) -> bool:
	if absf(pos.x)>23.4 or absf(pos.z)>30.8:return false
	for rect in solids:
		if rect.grow(margin).has_point(Vector2(pos.x,pos.z)):return false
	return true

func build_nav():
	nav.region=Rect2i(-47,-62,95,125);nav.cell_size=Vector2(.5,.5)
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE;nav.update()
	for x in range(-47,48):
		for z in range(-62,63):
			if not walkable(Vector3(x*.5,0,z*.5)):nav.set_point_solid(Vector2i(x,z))

func cell(pos: Vector3) -> Vector2i:
	var c=Vector2i(roundi(pos.x*2),roundi(pos.z*2))
	if nav.is_in_boundsv(c) and not nav.is_point_solid(c):return c
	for radius in range(1,9):
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				var n=c+Vector2i(x,y)
				if nav.is_in_boundsv(n) and not nav.is_point_solid(n):return n
	return Vector2i(0,46)

func path(from: Vector3,to: Vector3) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	for p in nav.get_point_path(cell(from),cell(to)):
		result.append(Vector3(p.x,0,p.y))
	return result

func lighting():
	var e=Environment.new();e.background_mode=Environment.BG_SKY
	var sky=Sky.new();var sm=ProceduralSkyMaterial.new()
	sm.sky_top_color=Color(.23,.45,.66);sm.sky_horizon_color=Color(.77,.82,.82)
	sm.ground_bottom_color=Color(.32,.27,.20);sm.ground_horizon_color=Color(.77,.80,.79)
	sky.sky_material=sm;e.sky=sky;e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color(.77,.85,1);e.ambient_light_energy=.38
	e.tonemap_mode=Environment.TONE_MAPPER_ACES
	e.fog_enabled=true;e.fog_light_color=Color(.78,.75,.65);e.fog_density=.0012;e.fog_sky_affect=.12
	var env=WorldEnvironment.new();env.environment=e;add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-49,-38,0)
	sun.light_color=Color(1,.94,.83);sun.light_energy=1.05;sun.shadow_enabled=true
	sun.directional_shadow_max_distance=85;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias=.025;sun.shadow_normal_bias=1.1;add_child(sun)

func bomb_sites():
	# The B approach is a roofed tunnel; the right flank is the exposed A long lane.
	box(Vector3(-18,3.5,1),Vector3(10,.45,18),stone,true,false)
	box(Vector3(-23,1.75,1),Vector3(.6,3.5,18),stone,true,true)
	for z in [-7.,0.,8.]:
		box(Vector3(-18,3.12,z),Vector3(9.6,.20,.30),wood)
	for site in SITES:
		var p=SITES[site]
		var paint=material(Color(.79,.31,.09),.94)
		for x in [-4.,4.]:box(p+Vector3(x,.012,0),Vector3(.09,.02,8),paint)
		for z in [-4.,4.]:box(p+Vector3(0,.012,z),Vector3(8,.02,.09),paint)
		sign_text(site,p+Vector3(0,.025,0),Vector3(-PI/2,0,0),Color(.8,.32,.1),190)
		sign_text(site+"  /  BOMB SITE",Vector3(p.x,2.8,-31.96),Vector3.ZERO,Color(.72,.25,.08),55)
	sign_text("← B   MID   A →",Vector3(0,2.1,30.97),Vector3(0,PI,0),Color(.22,.30,.32),38)
	sign_text("B TUNNELS",Vector3(-18,3.4,10.23),Vector3.ZERO,Color(.69,.61,.43),26)

func site_at(p: Vector3) -> String:
	for key in SITES:
		if absf(p.x-SITES[key].x)<=4 and absf(p.z-SITES[key].z)<=4:return key
	return ""

func route_to(site: String,team_: int) -> Array:
	if team_==1:return [Vector3(0,0,-26),SITES[site]]
	if site=="A":return [Vector3(9,0,16),Vector3(19,0,15),Vector3(21,0,0),Vector3(21,0,-14),Vector3(20,0,-21)]
	return [Vector3(-8,0,17),Vector3(-10,0,9),Vector3(-18,0,8),Vector3(-18,0,-9),Vector3(-18,0,-19),Vector3(-16,0,-24)]

func corridor_clear(a: Vector3,b: Vector3) -> bool:
	var count=maxi(1,ceili(a.distance_to(b)/.18))
	for i in range(1,count+1):
		if not walkable(a.lerp(b,float(i)/count),.40):return false
	return true
