extends SceneTree

const RELOAD_ARMS := "res://assets/third_party/djmaesen_arms/animated_reload_arms.glb"
const STATIC_ARMS := [
	"res://assets/third_party/djmaesen_arms/smg45_pistol_service_arms.glb",
	"res://assets/third_party/djmaesen_arms/smg45_rifle_arms.glb",
]
const WEAPONS := [
	{
		"name":"P9",
		"path":"res://assets/third_party/realistic_weapons/fallback/p226_reloadable.glb",
		"primary":"PrimaryGripSocket",
		"support":"SupportGripSocket",
		"clip":"p226",
	},
	{
		"name":"M4A1",
		"path":"res://assets/third_party/realistic_weapons/m4a1/steel_tide_m4a1.glb",
		"primary":"PrimaryGrip",
		"support":"ForegripContact",
		"clip":"m4a1",
	},
	{
		"name":"AWP",
		"path":"res://assets/third_party/realistic_weapons/fallback/awm_reloadable.glb",
		"primary":"PrimaryGripSocket",
		"support":"SupportGripSocket",
		"clip":"awm",
	},
]
const AUDIO_ROOT := "res://assets/audio/realistic_weapons/"
const AUDIO_PROFILES := ["ak74","p226","m4a1","awm"]
const AUDIO_ROLES := ["near","world","distant","tail"]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	push_error("[DUSTLINE VERIFY] "+message)

func _require_imported(path: String) -> bool:
	if not FileAccess.file_exists(path):
		_fail("missing source file: "+path)
		return false
	if not ResourceLoader.exists(path):
		_fail("file exists but is not imported by Godot: "+path)
		return false
	return true

func _find_exact(root: Node,name_: String):
	if String(root.name)==name_:
		return root
	for child in root.get_children():
		var found=_find_exact(child,name_)
		if found:
			return found
	return null

func _find_animation_player(root: Node):
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found=_find_animation_player(child)
		if found:
			return found
	return null

func _find_skeleton(root: Node):
	if root is Skeleton3D:
		return root
	for child in root.get_children():
		var found=_find_skeleton(child)
		if found:
			return found
	return null

func _verify_weapon(spec: Dictionary) -> void:
	var path:=str(spec.path)
	if not _require_imported(path):
		return
	var resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REPLACE)
	if not resource is PackedScene:
		_fail(str(spec.name)+" did not import as PackedScene: "+path)
		return
	var root=(resource as PackedScene).instantiate()
	var required=[str(spec.primary),str(spec.support),"Magazine","ChargingHandle"]
	for node_name in required:
		if not _find_exact(root,node_name):
			_fail(str(spec.name)+" missing required node: "+node_name)
	var magazine=_find_exact(root,"Magazine")
	var action=_find_exact(root,"ChargingHandle")
	if magazine and not _find_exact(magazine,"MagazineGripSocket"):
		_fail(str(spec.name)+" MagazineGripSocket is not under Magazine")
	if action and not _find_exact(action,"ChargingHandleSocket"):
		_fail(str(spec.name)+" ChargingHandleSocket is not under ChargingHandle")
	root.free()

func _verify_reload_arms() -> void:
	for path in STATIC_ARMS:
		_require_imported(path)
	if not _require_imported(RELOAD_ARMS):
		return
	var resource=ResourceLoader.load(RELOAD_ARMS,"",ResourceLoader.CACHE_MODE_REPLACE)
	if not resource is PackedScene:
		_fail("animated reload arms did not import as PackedScene")
		return
	var root=(resource as PackedScene).instantiate()
	for node_name in ["RightGripFrame","LeftPalmFrame","LeftSidearmMagazineAnchorFrame"]:
		if not _find_exact(root,node_name):
			_fail("animated reload arms missing node: "+node_name)
	var skeleton=_find_skeleton(root) as Skeleton3D
	if not skeleton:
		_fail("animated reload arms missing actual Skeleton3D")
	else:
		for bone_name in ["L_arm_01","L_elbow_02","L_wrist_03"]:
			if skeleton.find_bone(bone_name)<0:
				_fail("animated reload arms Skeleton3D missing bone: "+bone_name)
	var anim=_find_animation_player(root) as AnimationPlayer
	if not anim:
		_fail("animated reload arms missing AnimationPlayer")
	else:
		for spec in WEAPONS:
			for suffix in ["tactical","empty"]:
				var clip="reload_"+str(spec.clip)+"_"+suffix
				if not anim.has_animation(clip):
					_fail("animated reload arms missing clip: "+clip)
	root.free()

func _verify_audio() -> void:
	for profile in AUDIO_PROFILES:
		var ready_count:=0
		for role in AUDIO_ROLES:
			for i in 4:
				var path=AUDIO_ROOT+profile+"/"+role+"_"+str(i)+".wav"
				if _require_imported(path):
					ready_count+=1
		if ready_count==16:
			print("[DUSTLINE VERIFY] audio ",profile," = 16/16 imported")

func _run() -> void:
	print("[DUSTLINE VERIFY] checking imported runtime assets...")
	_verify_reload_arms()
	for spec in WEAPONS:
		_verify_weapon(spec)
	_verify_audio()
	if failures.is_empty():
		print("[DUSTLINE VERIFY] OK: weapon sockets, real reload Skeleton3D/clips and all four 16-sample firearm profiles are imported")
		quit(0)
	else:
		push_error("[DUSTLINE VERIFY] FAILED with "+str(failures.size())+" error(s)")
		quit(1)