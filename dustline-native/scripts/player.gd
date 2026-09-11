extends CharacterBody3D

const W=preload("res://scripts/weapons.gd")
const ACTION_TRAVEL=[.075,.085,.070,.135]
const BOT_RELOAD_DURATION=2.35

var game
var team=0
var money=5000
var primary=-1
var owned=[false,true,false,false]
var grenades={"he":0,"smoke":0}
var kit=false
var scoped=false
var rescope_after_shot=false
var spectator_index=0
var spectator_target=null
var spectator_last_shot_count=-1
var spectator_last_reload=false
var spectator_reload_weapon=-1
var camera: Camera3D
var capsule: CollisionShape3D
var view: SubViewport
var weapon_anchor: Node3D
var models: Array[Node3D]=[]
var view_anims: Array=[]
var rigs: Array[Dictionary]=[]
var view_anim_lock=0.
var view_anim_state=""
var utility_models={}
var utility_kind=""
var utility_left=0.
var utility_thrown=false
var weapon=1
var ammo=[30,12,30,5]
var reserve=[90,48,90,25]
var capacities=[30,12,30,5]
var hp=100
var armor=0
var reload_left=0.
var reload_duration=0.
var reload_empty=false
var reload_event_cursor=0
var reload_event_players: Array=[]
var reload_clip_name=""
var shot_cooldown=0.
var recoil=0.
var sway=Vector2.ZERO
var pitch=0.
var sensitivity=.002
var protection=0.
var dead_left=0.
var step_clock=0.
var bob=0.
var shot_queued=false
var reload_queued=false
var flash: OmniLight3D
var flash_time=0.
var crouched=false
var shots_fired=0
var kick_position=Vector3.ZERO
var kick_velocity=Vector3.ZERO
var draw_left=0.
var breathing=0.
var motion_blend=0.

func _ready():
	collision_layer=2;collision_mask=1|4
	capsule=CollisionShape3D.new();var shape=CapsuleShape3D.new();shape.radius=.30;shape.height=1.8
	capsule.shape=shape;capsule.position.y=.9;add_child(capsule)
	floor_snap_length=.25;floor_max_angle=deg_to_rad(44)
	camera=Camera3D.new();camera.position.y=1.63;camera.fov=80;camera.near=.055;camera.far=160;add_child(camera);camera.current=true
	var listener=AudioListener3D.new();camera.add_child(listener);listener.make_current()
	ensure_wheel_inputs();build_viewmodel()

func ensure_wheel_inputs():
	for pair in [["weapon_prev",MOUSE_BUTTON_WHEEL_UP],["weapon_next",MOUSE_BUTTON_WHEEL_DOWN]]:
		if not InputMap.has_action(pair[0]):InputMap.add_action(pair[0])
		var already=false
		for existing in InputMap.action_get_events(pair[0]):
			if existing is InputEventMouseButton and existing.button_index==pair[1]:already=true
		if not already:
			var event=InputEventMouseButton.new();event.button_index=pair[1];InputMap.action_add_event(pair[0],event)

func build_viewmodel():
	var layer=CanvasLayer.new();layer.layer=1;add_child(layer)
	var container=SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(container)
	view=SubViewport.new();view.size=Vector2i(1440,900);view.transparent_bg=true;view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_2X;container.add_child(view)
	var vc=Camera3D.new();vc.fov=62;vc.near=.01;view.add_child(vc);vc.current=true
	var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_CANVAS
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.79,.86,1);e.ambient_light_energy=.85
	var sky=Sky.new();var sky_material=ProceduralSkyMaterial.new();sky_material.sky_top_color=Color(.48,.60,.73);sky_material.sky_horizon_color=Color(.85,.82,.74)
	sky.sky_material=sky_material;e.sky=sky;e.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=e;view.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.7;light.light_color=Color(1,.9,.77);view.add_child(light)
	weapon_anchor=Node3D.new();view.add_child(weapon_anchor)
	for index in 4:
		var model=W.make_player_viewmodel(index);weapon_anchor.add_child(model)
		var authored=bool(model.get_meta("authored_viewmodel",false))
		if not authored:model.scale=Vector3.ONE*.78
		models.append(model);rigs.append(W.viewmodel_bindings(model))
		var anim=find_animation_player(model);view_anims.append(anim)
		if authored and anim:
			for state in ["idle","walk","run"]:
				var clip=W.viewmodel_clip(state)
				if anim.has_animation(clip):anim.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		for part in model.find_children("*","MeshInstance3D",true,false):part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for kind in ["he","smoke"]:
		var utility=W.make_utility(kind);weapon_anchor.add_child(utility);utility_models[kind]=utility;utility.visible=false
		utility.position=Vector3(-.055,.015,.20);utility.rotation=Vector3(-.28,.24 if kind=="he" else -.12,.10)
		for part in utility.find_children("*","MeshInstance3D",true,false):part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:models[i].visible=i==weapon
	flash=OmniLight3D.new();flash.light_color=Color(1,.65,.18);flash.light_energy=0;flash.omni_range=2;weapon_anchor.add_child(flash);flash.position=Vector3(0,0,-1.3)
	for i in range(rigs.size()):reset_weapon_rig(i)

func find_animation_player(node: Node):
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var found=find_animation_player(child)
		if found:return found
	return null

func viewmodel_is_authored(index: int) -> bool:
	return index>=0 and index<models.size() and bool(models[index].get_meta("authored_viewmodel",false))

func animation_length(index: int,state: String,fallback: float) -> float:
	if index<0 or index>=view_anims.size():return fallback
	var anim=view_anims[index];var clip=W.viewmodel_clip(state)
	if anim and not clip.is_empty() and anim.has_animation(clip):return anim.get_animation(clip).length
	return fallback

func play_view_animation(state: String,lock_animation=true,speed_scale=1.0):
	play_view_animation_for(weapon,state,lock_animation,speed_scale)

func play_view_animation_for(index: int,state: String,lock_animation=true,speed_scale=1.0):
	if not viewmodel_is_authored(index) or index>=view_anims.size():return
	var anim=view_anims[index];var clip=W.viewmodel_clip(state)
	if not anim or clip.is_empty() or not anim.has_animation(clip):return
	if anim.current_animation!=clip or state in ["draw","reload","fire"]:anim.play(clip,.045,speed_scale)
	if index==weapon:
		view_anim_state=state
		if lock_animation:view_anim_lock=maxf(view_anim_lock,anim.get_animation(clip).length/maxf(absf(speed_scale),.01))

func rig_for(index: int) -> Dictionary:
	return rigs[index] if index>=0 and index<rigs.size() else {}

func prepare_non_ak_rest_pose(index: int):
	if index<=0:return
	var rig=rig_for(index);var anim=rig.get("reload_anim") as AnimationPlayer;var skeleton=rig.get("reload_skeleton") as Skeleton3D
	if not anim or not skeleton:return
	var clip=W.reload_clip(index,false)
	if not anim.has_animation(clip):return
	anim.play(clip,0.0);anim.seek(0.0,true);anim.pause()
	for key in ["left_shoulder","left_elbow","left_wrist"]:
		var bone=int(rig.get(key+"_bone",-1))
		if bone>=0:rig[key+"_rest_rotation"]=skeleton.get_bone_pose_rotation(bone)

func reset_weapon_rig(index: int):
	var rig=rig_for(index)
	if rig.is_empty():return
	var magazine=rig.get("magazine") as Node3D;var spare=rig.get("spare_magazine") as Node3D;var action=rig.get("action") as Node3D
	if magazine and rig.has("magazine_rest"):magazine.transform=rig.magazine_rest;magazine.visible=true
	if spare and rig.has("spare_rest"):spare.transform=rig.spare_rest;spare.visible=false
	if action and rig.has("action_rest"):action.transform=rig.action_rest
	var reload_mount=rig.get("reload_mount") as Node3D;var support_arm=rig.get("support_arm") as Node3D
	if index>0:
		if reload_mount:reload_mount.visible=true
		if support_arm:support_arm.visible=false
		prepare_non_ak_rest_pose(index)
	else:
		if reload_mount:reload_mount.visible=false
		if support_arm:support_arm.visible=true

func stop_reload_event_audio():
	for p in reload_event_players:
		if is_instance_valid(p):p.stop()
	reload_event_players.clear()

func cancel_reload():
	stop_reload_event_audio();reload_left=0;reload_duration=0;reload_event_cursor=0;reload_clip_name=""
	if weapon>=0:reset_weapon_rig(weapon)

func clear_spectator_target():
	if is_instance_valid(spectator_target):
		if is_instance_valid(spectator_target.model):spectator_target.model.visible=spectator_target.hp>0
		if is_instance_valid(spectator_target.gun):spectator_target.gun.visible=spectator_target.hp>0
		if is_instance_valid(spectator_target.friendly_label):spectator_target.friendly_label.visible=spectator_target.hp>0 and spectator_target.team==game.player_team
	if spectator_reload_weapon>=0:reset_weapon_rig(spectator_reload_weapon)
	spectator_target=null;spectator_last_shot_count=-1;spectator_last_reload=false;spectator_reload_weapon=-1

func set_spectator_target(ally):
	if spectator_target==ally:return
	clear_spectator_target();spectator_target=ally
	if not is_instance_valid(ally):return
	spectator_last_shot_count=ally.shot_count;spectator_reload_weapon=ally.weapon
	reset_weapon_rig(ally.weapon)
	if is_instance_valid(ally.model):ally.model.visible=false
	if is_instance_valid(ally.gun):ally.gun.visible=false
	if is_instance_valid(ally.friendly_label):ally.friendly_label.visible=false
	print("[DUSTLINE SPECTATE] target=",ally.callsign," weapon=",W.DATA[ally.weapon].name)

func spectator_actor():
	return spectator_target if hp<=0 and is_instance_valid(spectator_target) and spectator_target.hp>0 else null

func reset_at(pos: Vector3):
	clear_spectator_target()
	global_position=pos+Vector3.UP*.08;velocity=Vector3.ZERO;rotation.y=0;pitch=0;scoped=false;rescope_after_shot=false;spectator_index=0
	if hp<=0:armor=0
	hp=100;ammo=[30,12,30,5];reserve=[90,48,90,25];protection=0;dead_left=0
	collision_layer=2;collision_mask=1|4;camera.position=Vector3(0,1.63,0);camera.rotation=Vector3.ZERO;camera.fov=80
	cancel_reload();recoil=0;kick_position=Vector3.ZERO;kick_velocity=Vector3.ZERO;draw_left=0;flash_time=0;shot_cooldown=0;shot_queued=false;reload_queued=false
	view_anim_lock=0;view_anim_state="";utility_left=0;utility_kind="";utility_thrown=false
	for i in range(rigs.size()):reset_weapon_rig(i)
	for kind in utility_models:utility_models[kind].visible=false
	weapon=primary if primary>=0 else 1
	for i in 4:models[i].visible=i==weapon
	weapon_anchor.visible=true;update_view(0,0)

func _unhandled_input(event):
	if not game.active:return
	if hp<=0:
		if event.is_action_pressed("fire"):
			spectator_index+=1;clear_spectator_target()
		return
	if game.hud.shop.visible:return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var modifier=.32 if scoped else 1.;rotate_y(-event.relative.x*sensitivity*modifier);pitch=clampf(pitch-event.relative.y*sensitivity*modifier,-1.48,1.48);sway+=event.relative*.0006
	if event.is_action_pressed("weapon_prev"):cycle_owned_weapon(-1);return
	if event.is_action_pressed("weapon_next"):cycle_owned_weapon(1);return
	if event.is_action_pressed("fire"):shot_queued=true
	if event.is_action_pressed("reload"):reload_queued=true
	if event.is_action_pressed("rifle") and primary>=0:switch_weapon(primary)
	if event.is_action_pressed("pistol"):switch_weapon(1)
	if event.is_action_pressed("scope") and weapon==3 and utility_left<=0:scoped=not scoped;rescope_after_shot=false
	if event.is_action_pressed("he"):begin_utility("he")
	if event.is_action_pressed("smoke_grenade"):begin_utility("smoke")

func cycle_owned_weapon(direction: int):
	var order: Array[int]=[]
	if primary>=0 and primary<owned.size() and owned[primary]:order.append(primary)
	if owned[1]:order.append(1)
	for index in 4:
		if owned[index] and index not in order:order.append(index)
	if order.size()<2:return
	var current=order.find(weapon)
	if current<0:current=0
	var next=(current+direction)%order.size()
	if next<0:next+=order.size()
	switch_weapon(order[next])

func begin_utility(kind: String):
	if utility_left>0 or reload_left>0 or hp<=0 or grenades.get(kind,0)<=0 or game.phase not in ["live","planted"]:return
	utility_kind=kind;utility_left=.52;utility_thrown=false;scoped=false;shot_queued=false;reload_queued=false;view_anim_lock=0
	for model in models:model.visible=false
	for key in utility_models:utility_models[key].visible=key==kind
	game.sound.local("equip",-18)

func update_utility(dt: float):
	if utility_left<=0:return
	var utility=utility_models.get(utility_kind);utility_left=maxf(0,utility_left-dt);var t=1.-utility_left/.52
	if is_instance_valid(utility):utility.position=Vector3(-.055,-.04+sin(minf(t,1.)*PI)*.075,.20-.08*t);utility.rotation.z=.10-t*.42
	if not utility_thrown and utility_left<=.22:
		var direction=(-camera.global_basis.z+Vector3.UP*.08).normalized();utility_thrown=game.throw_grenade(self,utility_kind,direction,camera.global_position)
		if utility_thrown and is_instance_valid(utility):utility.visible=false
	if utility_left<=0:
		for key in utility_models:utility_models[key].visible=false
		for i in 4:models[i].visible=i==weapon
		utility_kind="";utility_thrown=false;view_anim_state=""

func equip_primary(index: int):
	for i in [0,2,3]:owned[i]=i==index
	primary=index;ammo[index]=capacities[index];reserve[index]=W.DATA[index].reserve;switch_weapon(index)

func switch_weapon(index: int):
	if index<0 or index>=owned.size() or not owned[index] or index==weapon or utility_left>0:return
	cancel_reload();reload_queued=false;shot_queued=false;weapon=index;scoped=false;rescope_after_shot=false;view_anim_lock=0;view_anim_state=""
	var draw_duration=minf(animation_length(index,"draw",.28),.65) if viewmodel_is_authored(index) else .28
	draw_left=draw_duration;shot_cooldown=draw_duration
	for i in 4:models[i].visible=i==weapon
	if viewmodel_is_authored(index):play_view_animation("draw",true,maxf(animation_length(index,"draw",draw_duration)/maxf(draw_duration,.01),1.))
	game.sound.local("equip",-20)

func start_non_ak_reload_rig_for(index: int,empty_reload: bool) -> bool:
	var rig=rig_for(index)
	if rig.is_empty() or not bool(rig.get("valid",false)):return false
	var anim=rig.get("reload_anim") as AnimationPlayer;var mount=rig.get("reload_mount") as Node3D;var support_arm=rig.get("support_arm") as Node3D
	var clip=W.reload_clip(index,empty_reload)
	if anim and not clip.is_empty() and anim.has_animation(clip):
		if mount:mount.visible=true
		if support_arm:support_arm.visible=false
		anim.play(clip,0.0);anim.seek(0.0,true);anim.pause();return true
	return false

func start_non_ak_reload_rig():
	reload_clip_name=W.reload_clip(weapon,reload_empty)
	if start_non_ak_reload_rig_for(weapon,reload_empty):
		print("[DUSTLINE RELOAD] ",W.DATA[weapon].name," clip=",reload_clip_name," mechanism=real")
	else:
		reload_clip_name="procedural_fallback"
		push_warning("[DUSTLINE RELOAD] "+W.DATA[weapon].name+" rig unavailable; using visible procedural fallback. Run tools/bootstrap-runtime-assets.sh to restore authored reload animation.")

func request_reload():
	if utility_left>0 or reload_left>0 or ammo[weapon]==capacities[weapon] or reserve[weapon]<=0:return
	scoped=false;rescope_after_shot=false;reload_empty=ammo[weapon]<=0;reload_event_cursor=0;stop_reload_event_audio()
	reload_duration=animation_length(weapon,"reload",W.DATA[weapon].reload) if viewmodel_is_authored(weapon) else W.DATA[weapon].reload
	reload_left=reload_duration
	if viewmodel_is_authored(weapon):play_view_animation("reload",true,1.)
	else:start_non_ak_reload_rig()

func set_node_from_root_transform(node: Node3D,root: Node3D,target: Transform3D):
	var parent=node.get_parent() as Node3D
	if parent:node.transform=(root.global_transform.affine_inverse()*parent.global_transform).affine_inverse()*target

func align_mechanism_grip_to_hand(node: Node3D,grip_marker: Node3D,hand_marker: Node3D,root: Node3D):
	var grip_in_node=node.global_transform.affine_inverse()*grip_marker.global_transform;var target_in_root=root.global_transform.affine_inverse()*hand_marker.global_transform
	set_node_from_root_transform(node,root,target_in_root*grip_in_node.affine_inverse())

func reload_hand_marker_for(index: int,rig: Dictionary) -> Node3D:
	if index==1:return rig.get("reload_mag_anchor") as Node3D
	return rig.get("reload_left_palm") as Node3D

func update_real_magazine_for(index: int,rig: Dictionary,t: float):
	var magazine=rig.get("magazine") as Node3D;var spare=rig.get("spare_magazine") as Node3D;var grip=rig.get("magazine_grip") as Node3D;var hand=reload_hand_marker_for(index,rig)
	if not magazine or not grip or not hand:return
	if t<.18:magazine.visible=true
	elif t<.43:magazine.visible=true;align_mechanism_grip_to_hand(magazine,grip,hand,models[index])
	elif t<.49:
		magazine.visible=false
		if spare:spare.visible=false
	elif t<.72:
		magazine.visible=false
		if spare:
			spare.visible=true
			var grip_in_mag=magazine.global_transform.affine_inverse()*grip.global_transform;var target_in_root=models[index].global_transform.affine_inverse()*hand.global_transform
			set_node_from_root_transform(spare,models[index],target_in_root*grip_in_mag.affine_inverse())
	else:
		if rig.has("magazine_rest"):magazine.transform=rig.magazine_rest
		magazine.visible=true
		if spare:spare.visible=false

func update_real_action_for(index: int,rig: Dictionary,t: float):
	var action=rig.get("action") as Node3D
	if not action or not rig.has("action_rest"):return
	action.transform=rig.action_rest
	var start=.76 if index==3 else .80;var end=.94
	if t>=start and t<=end:
		var phase=clampf((t-start)/maxf(end-start,.001),0.,1.);action.position+=Vector3(0,0,sin(phase*PI)*ACTION_TRAVEL[index])

func process_reload_sound_events(t: float):
	var schedule: Array=W.reload_events(weapon,reload_empty)
	while reload_event_cursor<schedule.size() and t>=float(schedule[reload_event_cursor].f):
		var p=game.sound.reload_event(weapon,str(schedule[reload_event_cursor].name),-12.)
		if is_instance_valid(p):reload_event_players.append(p)
		reload_event_cursor+=1

func update_reload_presentation():
	if reload_left<=0 or reload_duration<=0:return
	var t=clampf(1.-reload_left/reload_duration,0.,1.);process_reload_sound_events(t)
	if viewmodel_is_authored(weapon):return
	var rig=rig_for(weapon)
	if rig.is_empty() or reload_clip_name=="procedural_fallback":return
	var anim=rig.get("reload_anim") as AnimationPlayer
	if anim and not reload_clip_name.is_empty() and anim.has_animation(reload_clip_name):
		anim.play(reload_clip_name,0.0);anim.seek(anim.get_animation(reload_clip_name).length*t,true);anim.pause()
	update_real_magazine_for(weapon,rig,t);update_real_action_for(weapon,rig,t)

func complete_reload():
	var count=mini(capacities[weapon]-ammo[weapon],reserve[weapon]);ammo[weapon]+=count;reserve[weapon]-=count
	stop_reload_event_audio();reset_weapon_rig(weapon);reload_duration=0;reload_clip_name="";reload_event_cursor=0

func update_spectator_reload(ally,index: int):
	var is_reloading=ally.reload_left>0
	if is_reloading:
		var t=clampf(1.-ally.reload_left/BOT_RELOAD_DURATION,0.,1.)
		if index==0 and viewmodel_is_authored(index):
			var anim=view_anims[index] as AnimationPlayer;var clip=W.viewmodel_clip("reload")
			if anim and anim.has_animation(clip):
				if not spectator_last_reload:anim.play(clip,0.0)
				anim.seek(anim.get_animation(clip).length*t,true);anim.pause()
		else:
			var rig=rig_for(index);var clip=W.reload_clip(index,true);var anim=rig.get("reload_anim") as AnimationPlayer
			if not spectator_last_reload:start_non_ak_reload_rig_for(index,true)
			if anim and anim.has_animation(clip):anim.play(clip,0.0);anim.seek(anim.get_animation(clip).length*t,true);anim.pause()
			update_real_magazine_for(index,rig,t);update_real_action_for(index,rig,t)
	elif spectator_last_reload:
		reset_weapon_rig(index)
		if index==0 and viewmodel_is_authored(index):play_view_animation_for(index,"idle",false,1.)
	spectator_last_reload=is_reloading

func update_spectator(dt: float):
	var allies=game.team_alive(team)
	if allies.is_empty():clear_spectator_target();weapon_anchor.visible=false;return
	var ally=allies[spectator_index%allies.size()]
	if spectator_target!=ally:set_spectator_target(ally)
	if not is_instance_valid(ally):return
	if is_instance_valid(ally.model):ally.model.visible=false
	if is_instance_valid(ally.gun):ally.gun.visible=false
	var eye=ally.global_position+Vector3.UP*1.62
	var aim_basis=ally.global_basis
	if is_instance_valid(ally.gun):aim_basis=ally.gun.global_basis.orthonormalized()
	camera.global_transform=Transform3D(aim_basis,eye);camera.fov=80
	var index=int(ally.weapon)
	if spectator_reload_weapon!=index:
		if spectator_reload_weapon>=0:reset_weapon_rig(spectator_reload_weapon)
		spectator_reload_weapon=index;spectator_last_reload=false;reset_weapon_rig(index)
	for i in 4:models[i].visible=i==index
	for key in utility_models:utility_models[key].visible=false
	weapon_anchor.visible=true
	if int(ally.shot_count)!=spectator_last_shot_count:
		spectator_last_shot_count=int(ally.shot_count);flash_time=.045;kick_velocity+=Vector3(.38,0,1.15)
		if index==0 and ally.reload_left<=0:play_view_animation_for(index,"fire",true,1.8)
	update_spectator_reload(ally,index)
	breathing+=dt;kick_velocity+=(-kick_position*190.-kick_velocity*23.)*dt;kick_position+=kick_velocity*dt
	var speed=Vector2(ally.velocity.x,ally.velocity.z).length();var authored=viewmodel_is_authored(index)
	var base=Vector3(0,-.119,0) if authored else (Vector3(.24,-.24,-.47) if index!=1 else Vector3(.20,-.16,-.45));var pose=Vector3.ZERO if authored else Vector3(.025,.07,-.015)
	var bot_bob=float(ally.navigation_distance) if "navigation_distance" in ally else breathing
	base+=Vector3(sin(bot_bob*3.5)*.004,absf(cos(bot_bob*3.5))*.006,kick_position.z)
	pose+=Vector3(kick_position.x,kick_position.y,0)
	if ally.reload_left>0 and not authored:
		var rt=1.-ally.reload_left/BOT_RELOAD_DURATION;var working=smoothstep(.04,.18,rt)*(1.-smoothstep(.86,1.,rt));base+=Vector3(-.035,.018,.025)*working;pose.z-=working*.10
	weapon_anchor.position=base;weapon_anchor.rotation=pose
	flash_time=maxf(0,flash_time-dt);flash.light_energy=2.8 if ally.flash_clock>0 or flash_time>0 else 0.

func _physics_process(dt):
	if not game.active:return
	if hp<=0:update_spectator(dt);return
	protection=maxf(0,protection-dt);shot_cooldown=maxf(0,shot_cooldown-dt);update_utility(dt)
	if rescope_after_shot and shot_cooldown==0:scoped=true;rescope_after_shot=false
	if reload_left>0:
		reload_left=maxf(0,reload_left-dt);update_reload_presentation()
		if reload_left==0:complete_reload()
	var wants_crouch=Input.is_action_pressed("crouch")
	if not wants_crouch and crouched:
		var query=PhysicsShapeQueryParameters3D.new();var shape=CapsuleShape3D.new();shape.height=1.8;shape.radius=.30
		query.shape=shape;query.transform=Transform3D(Basis(),global_position+Vector3.UP*.9);query.collision_mask=1;query.exclude=[get_rid()]
		wants_crouch=not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	crouched=wants_crouch;capsule.shape.height=1.2 if crouched else 1.8;capsule.position.y=capsule.shape.height/2
	camera.position.y=lerpf(camera.position.y,1.06 if crouched else 1.63,minf(1,dt*12))
	var movement=Input.get_vector("left","right","forward","back") if game.phase in ["live","planted"] and not game.hud.shop.visible else Vector2.ZERO
	var direction=global_basis*Vector3(movement.x,0,movement.y);var speed=2.25 if Input.is_action_pressed("walk") else 5.1
	if crouched:speed=1.65
	if weapon==3:speed*=.8
	if scoped:speed*=.65
	var accel=30. if is_on_floor() else 7.;velocity.x=move_toward(velocity.x,direction.x*speed,accel*dt);velocity.z=move_toward(velocity.z,direction.z*speed,accel*dt)
	if not is_on_floor():velocity.y-=22*dt
	if is_on_floor() and Input.is_action_just_pressed("jump") and not crouched and game.phase in ["live","planted"] and not game.hud.shop.visible:velocity.y=6.2
	move_and_slide()
	if global_position.y < -5:take_damage(1000);return
	var flat_speed=Vector2(velocity.x,velocity.z).length()
	if flat_speed>.5 and is_on_floor():
		bob+=dt*flat_speed*2.4;step_clock-=dt
		if step_clock<=0:step_clock=.44 if speed>3 else .6;game.sound.local("step"+str(randi()%6),-22 if speed>3 else -32);game.noise(global_position,11. if speed>3 else 2.5,self)
	camera.rotation.x=pitch;game.interact(self,Input.is_action_pressed("interact") and not game.hud.shop.visible,dt)
	if utility_left<=0 and (shot_queued or (weapon in [0,2] and Input.is_action_pressed("fire"))):fire()
	shot_queued=false
	if reload_queued:request_reload();reload_queued=false
	update_view(dt,flat_speed)

func fire():
	if utility_left>0 or reload_left>0 or shot_cooldown>0 or hp<=0 or game.phase not in ["live","planted"] or game.hud.shop.visible or game.interaction_actor==self:return
	if ammo[weapon]<=0:request_reload();return
	ammo[weapon]-=1;shots_fired+=1;shot_cooldown=W.DATA[weapon].interval
	var spread=W.DATA[weapon].spread
	if weapon==3 and not scoped:spread=.045
	spread+=Vector2(velocity.x,velocity.z).length()*.003
	if not is_on_floor():spread+=.035
	if crouched:spread*=.65
	spread+=recoil*.010
	var ray_dir=-camera.global_basis.z;ray_dir=(ray_dir+camera.global_basis.x*randfn(0,spread)+camera.global_basis.y*randfn(0,spread)).normalized()
	var origin=camera.global_position;var hit=game.ray(origin,origin+ray_dir*100,1|4,[get_rid()]);var target=origin+ray_dir*80 if hit.is_empty() else hit.position
	var muzzle=camera.global_position+camera.global_basis*Vector3(.20,-.22,-.5);var near_hit=game.ray(origin,muzzle,1,[get_rid()])
	if not near_hit.is_empty():hit=near_hit;target=near_hit.position;muzzle=origin
	else:
		var muzzle_hit=game.ray(muzzle,target+ray_dir*.05,1|4,[get_rid()])
		if not muzzle_hit.is_empty():hit=muzzle_hit;target=muzzle_hit.position
	if not hit.is_empty():
		if hit.collider.has_method("take_damage"):
			var head=target.y-hit.collider.global_position.y>1.43;var damage=W.DATA[weapon].head if head else W.DATA[weapon].damage
			if hit.collider.team!=team:hit.collider.take_damage(damage,head,self);game.hit_marker=.16
		else:game.impact(target,hit.normal)
	game.tracer(muzzle,target,Color(1,.74,.30));game.noise(global_position,42.,self);game.sound.local(W.DATA[weapon].sound,-5 if weapon!=3 else -4)
	if viewmodel_is_authored(weapon):play_view_animation("fire",true,1.8)
	recoil=minf(recoil+.19,1.5);pitch=clampf(pitch+W.DATA[weapon].kick,-1.48,1.48)
	if weapon==3:rescope_after_shot=scoped;scoped=false
	flash_time=.045;kick_velocity+=Vector3(.55 if weapon!=3 else 1.0,randf_range(-.10,.10),1.8 if weapon!=3 else 3.1)

func update_shot_mechanism():
	if viewmodel_is_authored(weapon) or reload_left>0:return
	var rig=rig_for(weapon);var action=rig.get("action") as Node3D
	if not action or not rig.has("action_rest"):return
	action.transform=rig.action_rest
	if weapon==1 and shot_cooldown>0:
		var cycle=1.-shot_cooldown/maxf(W.DATA[1].interval,.001);var pulse=sin(clampf(cycle/.72,0.,1.)*PI);action.position+=Vector3(0,0,pulse*.045)
	elif weapon==3 and shot_cooldown>0:
		var cycle=1.-shot_cooldown/maxf(W.DATA[3].interval,.001);var pull=sin(clampf((cycle-.14)/.62,0.,1.)*PI);action.position+=Vector3(0,0,pull*ACTION_TRAVEL[3])

func apply_non_ak_skeletal_motion(speed: float):
	if weapon<=0 or reload_left>0:return
	var rig=rig_for(weapon);var skeleton=rig.get("reload_skeleton") as Skeleton3D
	if not skeleton:return
	var move=minf(speed/3.2,1.);var cycle=bob;var draw=clampf(draw_left/.28,0.,1.)
	var fire_phase=0.
	if shot_cooldown>0:fire_phase=sin(clampf(1.-shot_cooldown/maxf(W.DATA[weapon].interval,.001),0.,1.)*PI)
	var shoulder_sway=sin(breathing*1.7)*.006+sin(cycle*.5)*.018*move-draw*.10-fire_phase*.018
	var elbow_sway=cos(cycle)*.026*move+draw*.14+fire_phase*.028
	var wrist_sway=sin(cycle+.8)*.018*move-draw*.08-fire_phase*.045
	var entries=[
		["left_shoulder",Vector3(0,0,1),shoulder_sway],
		["left_elbow",Vector3(1,0,0),elbow_sway],
		["left_wrist",Vector3(1,0,0),wrist_sway]
	]
	for entry in entries:
		var key=str(entry[0]);var bone=int(rig.get(key+"_bone",-1))
		if bone>=0 and rig.has(key+"_rest_rotation"):
			var rest_rotation: Quaternion=rig[key+"_rest_rotation"]
			skeleton.set_bone_pose_rotation(bone,rest_rotation*Quaternion(entry[1],float(entry[2])))

func update_view(dt: float,speed: float):
	recoil=move_toward(recoil,0,dt*2.5);sway=sway.lerp(Vector2.ZERO,minf(1,dt*10));sway=sway.limit_length(.035);camera.rotation.x=pitch
	camera.fov=25 if scoped and weapon==3 else 80;weapon_anchor.visible=hp>0 and not (scoped and weapon==3)
	var authored=viewmodel_is_authored(weapon);var base=Vector3(0,-.119,0) if authored else (Vector3(.24,-.24,-.47) if weapon!=1 else Vector3(.20,-.16,-.45));var pose=Vector3.ZERO if authored else Vector3(.025,.07,-.015)
	breathing+=dt;motion_blend=lerpf(motion_blend,minf(speed/3.,1.),1-exp(-dt*9));kick_velocity+=(-kick_position*190.-kick_velocity*23.)*dt;kick_position+=kick_velocity*dt
	if authored:
		view_anim_lock=maxf(0,view_anim_lock-dt);base+=Vector3(-sway.x*.28,sway.y*.24,kick_position.z*.35+recoil*.010);pose+=Vector3(kick_position.x*.35,kick_position.y*.35,-sway.x*.16)
		if utility_left<=0 and reload_left<=0 and view_anim_lock<=0:
			var locomotion="run" if speed>3.1 else ("walk" if speed>.35 else "idle")
			if locomotion!=view_anim_state:play_view_animation(locomotion,false,1.)
	else:
		base+=Vector3(0,sin(breathing*1.7)*.0025,kick_position.z);pose+=Vector3(kick_position.x,kick_position.y,0);draw_left=maxf(0,draw_left-dt);var draw=draw_left/.28;base.y-=draw*draw*.22;pose.x-=draw*.20
		base+=Vector3(sin(bob*.5)*.006,absf(cos(bob))*.009,0)*motion_blend;base+=Vector3(-sway.x,sway.y,recoil*.035);pose+=Vector3(recoil*.025,-sway.x,-sway.x*.5)
		if reload_left>0:
			var t=1.-reload_left/maxf(reload_duration,.001);var working=smoothstep(.04,.18,t)*(1.-smoothstep(.86,1.,t));base+=Vector3(-.035,.018,.025)*working;pose.z-=working*.10
			if reload_clip_name=="procedural_fallback":
				var fallback=smoothstep(.06,.28,t)*(1.-smoothstep(.72,.97,t));base+=Vector3(-.09,-.10,.08)*fallback;pose+=Vector3(-.28,.16,-.42)*fallback
		else:apply_non_ak_skeletal_motion(speed)
		update_shot_mechanism()
	weapon_anchor.position=base;weapon_anchor.rotation=pose;flash_time=maxf(0,flash_time-dt);flash.light_energy=2.8 if flash_time>0 else 0.

func take_damage(amount: int,head=false,source=null):
	if hp<=0 or protection>0 or not game.active or game.phase not in ["live","planted"]:return
	if is_instance_valid(source) and source.team==team:return
	var absorbed=mini(armor,roundi(amount*.35));armor-=absorbed;hp=maxi(0,hp-amount+absorbed);game.hurt_overlay=.55
	if hp==0:
		cancel_reload();clear_spectator_target();utility_left=0;view_anim_lock=0;scoped=false;camera.fov=80;weapon_anchor.visible=false;velocity=Vector3.ZERO;collision_layer=0;collision_mask=0;game.actor_died(self,source,head)
