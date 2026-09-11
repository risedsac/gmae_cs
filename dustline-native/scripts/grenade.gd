extends RigidBody3D

const W=preload("res://scripts/weapons.gd")
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
	var visual=W.make_utility(kind);visual.name="GrenadeVisual";add_child(visual)
	visual.rotation_degrees=Vector3(90,0,0) if kind=="smoke" else Vector3.ZERO
	if kind=="smoke":fuse=2.2

func _physics_process(dt):
	if not game.active:return
	fuse-=dt
	if fuse<=0:game.detonate(self)
