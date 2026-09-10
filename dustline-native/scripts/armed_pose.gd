extends SkeletonModifier3D

var indices={}
var actor

func _process_modification():
	var s=get_skeleton()
	if not is_instance_valid(actor) or actor.hp<=0 or not is_instance_valid(actor.gun):return
	if indices.is_empty():
		for i in s.get_bone_count():
			for suffix in ["RightArm","RightForeArm","RightHand","LeftArm","LeftForeArm","LeftHand"]:
				if s.get_bone_name(i).ends_with(suffix):indices[suffix]=i
	if indices.size()!=6:return
	# Both hands follow the animated weapon, while hips/legs keep their locomotion animation.
	var right=actor.gun.to_global(Vector3(.09,-.13,-.23))
	var left=actor.gun.to_global(Vector3(-.08,-.09,-.79))
	if actor.reload_left>0:
		var t=1-actor.reload_left/2.35
		left+=actor.global_basis*Vector3(-.10,-sin(t*PI)*.30,sin(t*PI)*.16)
	solve(s,"Right",right,actor.to_global(Vector3(.42,1.08,-.10)))
	solve(s,"Left",left,actor.to_global(Vector3(-.35,1.08,-.30)))

func solve(s: Skeleton3D,side: String,target_world: Vector3,pole_world: Vector3):
	var inv=s.global_transform.affine_inverse()
	var shoulder=s.get_bone_global_pose(indices[side+"Arm"]).origin
	var elbow=s.get_bone_global_pose(indices[side+"ForeArm"]).origin
	var wrist=s.get_bone_global_pose(indices[side+"Hand"]).origin
	var target=inv*target_world
	var a=shoulder.distance_to(elbow);var b=elbow.distance_to(wrist)
	var axis=(target-shoulder).normalized()
	var distance=clampf(shoulder.distance_to(target),absf(a-b)+.001,a+b-.001)
	var along=(a*a-b*b+distance*distance)/(2*distance)
	var pole=inv*pole_world-shoulder
	var bend=(pole-axis*pole.dot(axis)).normalized()
	var elbow_target=shoulder+axis*along+bend*sqrt(maxf(0,a*a-along*along))
	point(s,side+"Arm",side+"ForeArm",elbow_target)
	point(s,side+"ForeArm",side+"Hand",shoulder+axis*distance)

func point(s: Skeleton3D,bone: String,child: String,target: Vector3):
	var id=indices[bone];var pose=s.get_bone_global_pose(id)
	var direction=(s.get_bone_global_pose(indices[child]).origin-pose.origin).normalized()
	var wanted=(target-pose.origin).normalized()
	if direction.length()>.1 and wanted.length()>.1:
		pose.basis=Basis(Quaternion(direction,wanted))*pose.basis
		s.set_bone_global_pose(id,pose)
