extends RigidBody3D
var game
var thrower
var kind="he"
var fuse=1.7
func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	collision_layer=8;collision_mask=1;mass=.4
	var material_=PhysicsMaterial.new();material_.bounce=.43;material_.friction=.6;physics_material_override=material_
	var shape=SphereShape3D.new();shape.radius=.10
	var collision=CollisionShape3D.new();collision.shape=shape;add_child(collision)
	var mesh=CylinderMesh.new();mesh.top_radius=.085;mesh.bottom_radius=.085;mesh.height=.18
	var m=MeshInstance3D.new();m.mesh=mesh
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(.23,.31,.13) if kind=="he" else Color(.49,.53,.53)
	m.material_override=mat;add_child(m)
	if kind=="smoke":fuse=2.2
func _physics_process(dt):
	if not game.active:return
	fuse-=dt
	if fuse<=0:game.detonate(self)
