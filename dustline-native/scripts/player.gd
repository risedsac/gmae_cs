extends CharacterBody3D

const W=preload("res://scripts/weapons.gd")
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
var camera: Camera3D
var capsule: CollisionShape3D
var view: SubViewport
var weapon_anchor: Node3D
var models: Array[Node3D]=[]
var view_anims: Array=[]
var view_anim_lock=0.
var view_anim_state=""
var magazines: Array=[]
var hands: Array=[]
var bolts: Array=[]
var magazine_base: Array[Vector3]=[]
var hand_base: Array[Vector3]=[]
var bolt_base: Array[Vector3]=[]
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
var reload_audio: AudioStreamPlayer
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
	build_viewmodel()

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
		models.append(model)
		var anim=find_animation_player(model);view_anims.append(anim)
		if authored and anim:
			for state in ["idle","walk","run"]:
				var clip=W.viewmodel_clip(state)
				if anim.has_animation(clip):anim.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		if authored:
			magazines.append(null);hands.append(null);bolts.append(null)
			magazine_base.append(Vector3.ZERO);hand_base.append(Vector3.ZERO);bolt_base.append(Vector3.ZERO)
		else:
			var magazine=find_part(model,"Magazine");var hand=find_part(model,"SupportArm");var bolt=find_part(model,"Bolt")
			magazines.append(magazine);hands.append(hand);bolts.append(bolt)
			magazine_base.append(magazine.position if magazine else Vector3.ZERO);hand_base.append(hand.position if hand else Vector3.ZERO);bolt_base.append(bolt.position if bolt else Vector3.ZERO)
		for part in model.find_children("*","MeshInstance3D",true,false):part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for kind in ["he","smoke"]:
		var utility=W.make_utility(kind);weapon_anchor.add_child(utility);utility_models[kind]=utility;utility.visible=false
		utility.position=Vector3(-.055,.015,.20);utility.rotation=Vector3(-.28,.24 if kind=="he" else -.12,.10)
		for part in utility.find_children("*","MeshInstance3D",true,false):part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:models[i].visible=i==weapon
	flash=OmniLight3D.new();flash.light_color=Color(1,.65,.18);flash.light_energy=0;flash.omni_range=2;weapon_anchor.add_child(flash);flash.position=Vector3(0,0,-1.3)

func find_animation_player(node: Node):
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var found=find_animation_player(child)
		if found:return found
	return null

func find_part(node: Node,prefix: String):
	for child in node.find_children("*","Node3D",true,false):
		if child.name.begins_with(prefix):return child
	return null

func viewmodel_is_authored(index: int) -> bool:
	return index>=0 and index<models.size() and bool(models[index].get_meta("authored_viewmodel",false))

func animation_length(index: int,state: String,fallback: float) -> float:
	if index<0 or index>=view_anims.size():return fallback
	var anim=view_anims[index]
	var clip=W.viewmodel_clip(state)
	if anim and not clip.is_empty() and anim.has_animation(clip):return anim.get_animation(clip).length
	return fallback

func play_view_animation(state: String,lock_animation=true,speed_scale=1.0):
	if not viewmodel_is_authored(weapon) or weapon>=view_anims.size():return
	var anim=view_anims[weapon]
	var clip=W.viewmodel_clip(state)
	if not anim or clip.is_empty() or not anim.has_animation(clip):return
	if anim.current_animation!=clip or state in ["draw","reload","fire"]:anim.play(clip,.045,speed_scale)
	view_anim_state=state
	if lock_animation:view_anim_lock=maxf(view_anim_lock,anim.get_animation(clip).length/maxf(absf(speed_scale),.01))

func reset_at(pos: Vector3):
	global_position=pos+Vector3.UP*.08;velocity=Vector3.ZERO;rotation.y=0;pitch=0;scoped=false;rescope_after_shot=false;spectator_index=0
	if hp<=0:armor=0
	hp=100;ammo=[30,12,30,5];reserve=[90,48,90,25];protection=0;dead_left=0
	collision_layer=2;collision_mask=1|4;camera.position=Vector3(0,1.63,0);camera.rotation=Vector3.ZERO
	reload_left=0;recoil=0;kick_position=Vector3.ZERO;kick_velocity=Vector3.ZERO;draw_left=0;flash_time=0;shot_cooldown=0;shot_queued=false;reload_queued=false
	view_anim_lock=0;view_anim_state="";utility_left=0;utility_kind="";utility_thrown=false
	for kind in utility_models:utility_models[kind].visible=false
	weapon=primary if primary>=0 else 1
	for i in 4:models[i].visible=i==weapon
	weapon_anchor.visible=true;update_view(0,0)

func _unhandled_input(event):
	if not game.active:return
	if hp<=0:
		if event.is_action_pressed("fire"):spectator_index+=1
		return
	if game.hud.shop.visible:return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var modifier=.32 if scoped else 1.;rotate_y(-event.relative.x*sensitivity*modifier);pitch=clampf(pitch-event.relative.y*sensitivity*modifier,-1.48,1.48);sway+=event.relative*.0006
	if event.is_action_pressed("fire"):shot_queued=true
	if event.is_action_pressed("reload"):reload_queued=true
	if event.is_action_pressed("rifle") and primary>=0:switch_weapon(primary)
	if event.is_action_pressed("pistol"):switch_weapon(1)
	if event.is_action_pressed("scope") and weapon==3 and utility_left<=0:scoped=not scoped;rescope_after_shot=false
	if event.is_action_pressed("he"):begin_utility("he")
	if event.is_action_pressed("smoke_grenade"):begin_utility("smoke")

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
	if not owned[index] or index==weapon or utility_left>0:return
	if is_instance_valid(reload_audio):reload_audio.stop()
	reload_left=0;reload_queued=false;shot_queued=false;weapon=index;scoped=false;rescope_after_shot=false;view_anim_lock=0;view_anim_state=""
	var draw_duration=minf(animation_length(index,"draw",.28),.65) if viewmodel_is_authored(index) else .28
	draw_left=draw_duration;shot_cooldown=draw_duration
	for i in 4:models[i].visible=i==weapon
	if viewmodel_is_authored(index):play_view_animation("draw",true,maxf(animation_length(index,"draw",draw_duration)/maxf(draw_duration,.01),1.))
	game.sound.local("equip",-20)

func request_reload():
	if utility_left>0 or reload_left>0 or ammo[weapon]==capacities[weapon] or reserve[weapon]<=0:return
	scoped=false;rescope_after_shot=false
	reload_duration=animation_length(weapon,"reload",W.DATA[weapon].reload) if viewmodel_is_authored(weapon) else W.DATA[weapon].reload
	reload_left=reload_duration
	if viewmodel_is_authored(weapon):play_view_animation("reload",true,1.)
	reload_audio=game.sound.local("pistol_reload" if weapon==1 else "rifle_reload",-11)

func update_spectator():
	var allies=game.team_alive(team)
	if allies.is_empty():return
	var ally=allies[spectator_index%allies.size()]
	var eye=ally.global_position+Vector3.UP*1.62
	camera.global_position=eye
	# Bots expose their current tactical target through last_known. Following it
	# fixes the old body-yaw-only spectator camera, which looked straight ahead
	# while the viewed teammate was aiming up/down at an opponent.
	if ally.visible_target or ally.memory>0:
		var target=ally.last_known+Vector3.UP*1.05
		if eye.distance_to(target)>.2:camera.look_at(target,Vector3.UP)
	else:
		camera.global_basis=ally.global_basis

func _physics_process(dt):
	if not game.active:return
	if hp<=0:
		update_spectator();return
	protection=maxf(0,protection-dt);shot_cooldown=maxf(0,shot_cooldown-dt);update_utility(dt)
	if rescope_after_shot and shot_cooldown==0:scoped=true;rescope_after_shot=false
	if reload_left>0:
		reload_left=maxf(0,reload_left-dt)
		if reload_left==0:
			var count=mini(capacities[weapon]-ammo[weapon],reserve[weapon]);ammo[weapon]+=count;reserve[weapon]-=count
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

func update_view(dt: float,speed: float):
	recoil=move_toward(recoil,0,dt*2.5);sway=sway.lerp(Vector2.ZERO,minf(1,dt*10));sway=sway.limit_length(.035);camera.rotation.x=pitch
	camera.fov=25 if scoped and weapon==3 else 80;weapon_anchor.visible=hp>0 and not (scoped and weapon==3)
	var authored=viewmodel_is_authored(weapon)
	var base=Vector3(0,-.119,0) if authored else (Vector3(.24,-.24,-.47) if weapon!=1 else Vector3(.20,-.16,-.45))
	var pose=Vector3.ZERO if authored else Vector3(.025,.07,-.015)
	breathing+=dt;motion_blend=lerpf(motion_blend,minf(speed/3.,1.),1-exp(-dt*9));kick_velocity+=(-kick_position*190.-kick_velocity*23.)*dt;kick_position+=kick_velocity*dt
	if authored:
		view_anim_lock=maxf(0,view_anim_lock-dt)
		base+=Vector3(-sway.x*.28,sway.y*.24,kick_position.z*.35+recoil*.010)
		pose+=Vector3(kick_position.x*.35,kick_position.y*.35,-sway.x*.16)
		if utility_left<=0 and reload_left<=0 and view_anim_lock<=0:
			var locomotion="run" if speed>3.1 else ("walk" if speed>.35 else "idle")
			if locomotion!=view_anim_state:play_view_animation(locomotion,false,1.)
	else:
		base+=Vector3(0,sin(breathing*1.7)*.0025,kick_position.z);pose+=Vector3(kick_position.x,kick_position.y,0);draw_left=maxf(0,draw_left-dt);var draw=draw_left/.28;base.y-=draw*draw*.22;pose.x-=draw*.20
		base+=Vector3(sin(bob*.5)*.006,absf(cos(bob))*.009,0)*motion_blend;base+=Vector3(-sway.x,sway.y,recoil*.035);pose+=Vector3(recoil*.025,-sway.x,-sway.x*.5)
		for i in 4:
			if magazines[i]:magazines[i].position=magazine_base[i];magazines[i].visible=true
			if hands[i]:hands[i].position=hand_base[i]
			if bolts[i]:bolts[i].position=bolt_base[i]
		if reload_left>0:
			var t=1-reload_left/reload_duration;var dip=smoothstep(0.,.15,t)*(1-smoothstep(.82,1.,t));base+=Vector3(-.10,.045,.04)*dip;pose.z-=dip*.43;pose.y-=dip*.12;pose.x+=dip*.04
			var reach=smoothstep(.10,.27,t)*(1-smoothstep(.76,.96,t));var extract=smoothstep(.27,.44,t)*(1-smoothstep(.52,.74,t));var grip_shift=Vector3(.015,-.15 if weapon!=1 else -.085,[.34,.03,.27,.34][weapon]);var mag_shift=Vector3(-.07,-.40,.10)*extract
			if magazines[weapon]:magazines[weapon].position=magazine_base[weapon]+mag_shift;magazines[weapon].visible=not (t>.44 and t<.52)
			if hands[weapon]:hands[weapon].position=hand_base[weapon]+grip_shift*reach+mag_shift
			if bolts[weapon] and t>.80:bolts[weapon].position=bolt_base[weapon]+Vector3(0,0,sin(clampf((t-.80)/.14,0,1)*PI)*.065)
		if weapon==3 and shot_cooldown>0 and reload_left<=0:
			var cycle=1-shot_cooldown/W.DATA[3].interval;var pull=sin(clampf((cycle-.14)/.62,0,1)*PI)
			if bolts[3]:bolts[3].position=bolt_base[3]+Vector3(0,0,pull*.14)
			pose.z+=pull*.10;base.y-=pull*.035
	weapon_anchor.position=base;weapon_anchor.rotation=pose;flash_time=maxf(0,flash_time-dt);flash.light_energy=2.8 if flash_time>0 else 0.

func take_damage(amount: int,head=false,source=null):
	if hp<=0 or protection>0 or not game.active or game.phase not in ["live","planted"]:return
	if is_instance_valid(source) and source.team==team:return
	var absorbed=mini(armor,roundi(amount*.35));armor-=absorbed;hp=maxi(0,hp-amount+absorbed);game.hurt_overlay=.55
	if hp==0:
		if is_instance_valid(reload_audio):reload_audio.stop()
		reload_left=0;utility_left=0;view_anim_lock=0;scoped=false;camera.fov=80;weapon_anchor.visible=false;velocity=Vector3.ZERO;collision_layer=0;collision_mask=0;game.actor_died(self,source,head)