extends Node3D

const W=preload("res://scripts/weapons.gd")
const BUY_CATALOG={
	"ak":{"name":"AK-47","price":2700,"category":"主武器","weapon":0},
	"m4":{"name":"M4A1","price":3100,"category":"主武器","weapon":2},
	"awp":{"name":"AWP","price":4750,"category":"主武器","weapon":3},
	"he":{"name":"高爆手雷","price":300,"category":"投掷物"},
	"smoke":{"name":"烟雾弹","price":300,"category":"投掷物"},
	"armor":{"name":"护甲","price":650,"category":"装备"},
	"kit":{"name":"拆弹器","price":400,"category":"装备","team":1}
}
var world
var player
var bots: Array=[]
var sound
var hud
var active=false
var started=false
var finished=false
var difficulty=1
var player_team=0
var kills=0
var deaths=0
var time_left=115.
var hit_marker=0.
var hurt_overlay=0.
var message=""
var message_left=0.
var effects: Array=[]
var marks: Array=[]
var elapsed=0.
var test_mode=false
var phase="freeze"
var phase_left=12.
var buy_left=35.
var round_number=0
var scores=[0,0]
var winner=-1
var round_reason=""
var plan="A"
var bomb_state="carried"
var bomb_carrier
var bomb_position=Vector3.ZERO
var bomb_left=40.
var planted_site=""
var interaction_actor
var interaction_progress=0.
var interaction_duration=3.2
var bomb_visual: Node3D
var beep_left=0.
var smokes: Array=[]
var projectiles: Array=[]
var round_elapsed=0.
var resolving_blast=false
var objective_handlers={}

func _ready():
	inputs()
	world=preload("res://scripts/world.gd").new();world.name="DesertQuarter";add_child(world)
	sound=preload("res://scripts/audio.gd").new();add_child(sound)
	player=preload("res://scripts/player.gd").new();player.game=self;player.name="Player";add_child(player);player.reset_at(Vector3(0,0,25))
	for i in 9:
		var bot=preload("res://scripts/bot.gd").new();bot.game=self;bot.index=i
		bot.callsign=["VIPER","NOMAD","RAVEN","GHOST","FALCON","COBRA","ATLAS","ECHO","WOLF"][i]
		bot.name=bot.callsign;bot.position=Vector3(0,0,-28);bots.append(bot);add_child(bot)
	make_bomb_visual()
	var layer=CanvasLayer.new();layer.layer=5;add_child(layer)
	hud=preload("res://scripts/hud.gd").new();hud.game=self;layer.add_child(hud)
	process_mode=Node.PROCESS_MODE_ALWAYS;get_tree().paused=true
	player.process_mode=Node.PROCESS_MODE_PAUSABLE;sound.process_mode=Node.PROCESS_MODE_PAUSABLE
	for bot in bots:bot.process_mode=Node.PROCESS_MODE_PAUSABLE
	if "--smoke" in OS.get_cmdline_user_args():smoke_check()
	if "--capture" in OS.get_cmdline_user_args():capture_frames()

func inputs():
	var keys={"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"walk":KEY_SHIFT,"crouch":KEY_CTRL,"jump":KEY_SPACE,"reload":KEY_R,"rifle":KEY_1,"pistol":KEY_2,"pause":KEY_ESCAPE,"score":KEY_TAB,"buy":KEY_B,"interact":KEY_E,"he":KEY_G,"smoke_grenade":KEY_H,"plan":KEY_Q}
	for action in keys:
		if not InputMap.has_action(action):InputMap.add_action(action)
		var event=InputEventKey.new();event.physical_keycode=keys[action];InputMap.action_add_event(action,event)
	for pair in [["fire",MOUSE_BUTTON_LEFT],["scope",MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):InputMap.add_action(pair[0])
		var e=InputEventMouseButton.new();e.button_index=pair[1];InputMap.action_add_event(pair[0],e)

func actors() -> Array:
	return [player]+bots

func team_alive(team_: int) -> Array:
	return actors().filter(func(a):return a.team==team_ and a.hp>0)

func spawn_for(team_: int,slot: int) -> Vector3:
	return Vector3((slot-2)*1.55,0,(25. if team_==0 else -29.)+(slot%2)*1.5)

func start():
	kills=0;deaths=0;scores=[0,0];round_number=0;finished=false;started=true
	player.team=player_team;player.money=5000;player.owned=[false,true,false,false];player.primary=-1;player.grenades={"he":0,"smoke":0};player.kit=false;player.hp=0
	for i in bots.size():
		bots[i].team=player_team if i<4 else 1-player_team
		bots[i].score_kills=0;bots[i].score_deaths=0;bots[i].set_team_appearance()
	next_round();resume()

func next_round():
	for item in effects:if is_instance_valid(item[0]):item[0].queue_free()
	effects.clear()
	for mark in marks:if is_instance_valid(mark):mark.queue_free()
	marks.clear()
	for smoke in smokes:if is_instance_valid(smoke.node):smoke.node.queue_free()
	smokes.clear()
	for projectile in projectiles:if is_instance_valid(projectile):projectile.queue_free()
	projectiles.clear();sound.silence()
	objective_handlers.clear()
	round_number+=1;phase="freeze";phase_left=12;buy_left=35;time_left=115;round_elapsed=0
	plan="A" if round_number%2 else "B";winner=-1;round_reason="";planted_site=""
	bomb_state="carried";bomb_left=40;interaction_actor=null;interaction_progress=0
	var slots=[0,0]
	for actor in actors():
		var survived=actor.hp>0
		if actor==player and not survived:
			player.owned=[false,true,false,false];player.primary=-1;player.grenades={"he":0,"smoke":0};player.kit=false
		actor.reset_at(spawn_for(actor.team,slots[actor.team]));slots[actor.team]+=1
		actor.rotation.y=0 if actor.team==0 else PI
	bomb_carrier=player if player.team==0 else team_alive(0)[0]
	bomb_visual.visible=false
	if hud:hud.shop.visible=false
	feed("第 %d 回合 · B 购买 · %s"%[round_number,"你携带 C4，前往 A 或 B 点" if player.team==0 else "防守 A / B，阻止安包"])

func resume():
	active=true;get_tree().paused=false;hud.menu.visible=false
	if not test_mode:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if hud.shop.visible else Input.MOUSE_MODE_CAPTURED

func pause():
	active=false;get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	player.shot_queued=false;player.reload_queued=false;sound.silence();hud.shop.visible=false;hud.show_menu()

func end_round(team_: int,reason: String):
	if phase=="end":return
	winner=team_;round_reason=reason;scores[team_]+=1;phase="end";phase_left=6
	interaction_actor=null;interaction_progress=0;hud.shop.visible=false
	player.money=mini(16000,player.money+(3250 if player.team==team_ else 1900))
	feed(("进攻方" if team_==0 else "防守方")+"获胜 · "+reason)
	sound.local("round_win",-13)
	if not test_mode:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		if hud.shop.visible:toggle_buy()
		elif active:pause()
		elif started and not finished:resume()
	if event.is_action_pressed("buy") and active:toggle_buy()
	if event.is_action_pressed("plan") and active and player.team==0:
		plan="B" if plan=="A" else "A"
		for bot in bots:if bot.team==0:bot.route_stage=0
		feed("队伍路线："+plan+" 点")

func in_buy_zone() -> bool:
	return player.global_position.distance_to(world.T_SPAWN if player.team==0 else world.CT_SPAWN)<8.5

func can_open_buy() -> bool:
	return active and phase in ["freeze","live"] and player.hp>0 and in_buy_zone()

func can_buy() -> bool:
	return can_open_buy() and buy_left>0

func buy_state(item: String) -> Dictionary:
	if not BUY_CATALOG.has(item):return {"enabled":false,"status":"不可用","reason":"未知商品","price":0}
	var info: Dictionary=BUY_CATALOG[item];var reason=""
	if not active or phase not in ["freeze","live"]:reason="购买阶段已结束"
	elif player.hp<=0:reason="已阵亡"
	elif not in_buy_zone():reason="离开购买区"
	elif buy_left<=0:reason="购买时间结束"
	elif item=="kit" and player.team!=1:reason="仅 CT"
	elif info.has("weapon") and player.primary==int(info.weapon):reason="已装备"
	elif item in ["he","smoke"] and player.grenades[item]>=1:reason="已携带"
	elif item=="kit" and player.kit:reason="已装备"
	elif item=="armor" and player.armor>=100:reason="已装备"
	elif player.money<int(info.price):reason="金钱不足"
	return {"enabled":reason.is_empty(),"status":"购买" if reason.is_empty() else reason,"reason":reason,"price":int(info.price),"name":str(info.name),"category":str(info.category)}

func toggle_buy():
	if hud.shop.visible:
		hud.shop.visible=false
	elif can_open_buy():
		hud.shop.visible=true;hud.on_shop_opened()
	else:
		feed("只能在己方出生区的购买阶段打开商店")
	player.shot_queued=false
	if not test_mode:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if hud.shop.visible else Input.MOUSE_MODE_CAPTURED

func buy(item: String) -> bool:
	var state=buy_state(item)
	if not bool(state.enabled):
		hud.set_shop_feedback(str(state.reason),false);hud.refresh_shop();return false
	var info: Dictionary=BUY_CATALOG[item];player.money-=int(info.price)
	if info.has("weapon"):player.equip_primary(int(info.weapon))
	elif item in ["he","smoke"]:player.grenades[item]+=1
	elif item=="armor":player.armor=100
	elif item=="kit":player.kit=true
	sound.local("buy",-18)
	var text="购买成功 · %s · 余额 $%d"%[str(info.name),player.money]
	hud.set_shop_feedback(text,true);hud.refresh_shop();return true

func _physics_process(dt):
	if not active:return
	elapsed+=dt;message_left=maxf(0,message_left-dt);hit_marker=maxf(0,hit_marker-dt);hurt_overlay=maxf(0,hurt_overlay-dt)
	for i in range(effects.size()-1,-1,-1):
		effects[i][1]-=dt
		if effects[i][1]<=0:effects[i][0].queue_free();effects.remove_at(i)
	update_smokes(dt)
	if phase=="end":
		phase_left-=dt
		if phase_left<=0:
			if scores[winner]>=5:finished=true;pause()
			else:next_round()
		return
	buy_left=maxf(0,buy_left-dt)
	if hud.shop.visible:hud.refresh_shop()
	if phase=="freeze":
		phase_left-=dt
		if phase_left<=0:phase="live";feed("行动开始 · "+plan+" 点路线")
		return
	round_elapsed+=dt
	if bomb_state=="dropped":
		for actor in team_alive(0):
			if actor.global_position.distance_to(bomb_position)<1.3:bomb_carrier=actor;bomb_state="carried";bomb_visual.visible=false;feed("C4 已被拾取");break
	if bomb_state=="planted":
		bomb_left=maxf(0,bomb_left-dt);beep_left-=dt
		if beep_left<=0:
			beep_left=lerpf(.13,.9,bomb_left/40.);sound.play_at("bomb_beep",bomb_position,-10)
		if bomb_left<=0:
			resolving_blast=true;explode(bomb_position,12,400,null);resolving_blast=false
			bomb_state="exploded";bomb_visual.visible=false;end_round(0,"C4 爆炸");return
	else:
		time_left=maxf(0,time_left-dt)
		if time_left<=0:end_round(1,"进攻时间耗尽");return
	check_elimination()

func check_elimination():
	if phase not in ["live","planted"] or resolving_blast:return
	if team_alive(1).is_empty():end_round(0,"防守方全灭")
	elif team_alive(0).is_empty() and bomb_state!="planted":end_round(1,"进攻方全灭")

func interact(actor,wants: bool,dt: float):
	if not wants or actor.hp<=0 or phase not in ["live","planted"]:stop_interact(actor);return
	var valid=false;var duration=3.2
	if bomb_state=="carried" and actor==bomb_carrier:
		valid=world.site_at(actor.global_position)!="" and Vector2(actor.velocity.x,actor.velocity.z).length()<.5 and actor.is_on_floor()
	elif bomb_state=="planted" and actor.team==1:
		valid=actor.global_position.distance_to(bomb_position)<2.5 and ray(actor.global_position+Vector3.UP,bomb_position+Vector3.UP*.15,1).is_empty()
		duration=5. if actor.kit else 10.
	if not valid:stop_interact(actor);return
	if is_instance_valid(interaction_actor) and interaction_actor!=actor:
		if actor==player:interaction_actor=null;interaction_progress=0
		else:return
	interaction_actor=actor;interaction_duration=duration;interaction_progress+=dt
	if interaction_progress>=duration:
		if bomb_state=="carried":
			objective_handlers.clear()
			bomb_state="planted";bomb_position=actor.global_position;planted_site=world.site_at(bomb_position);bomb_carrier=null;phase="planted";bomb_left=40
			bomb_visual.global_position=bomb_position+Vector3.UP*.10;bomb_visual.visible=true
			if actor==player:player.money=mini(16000,player.money+300)
			feed(planted_site+" 点 C4 已安装 · 防守方按住 E 拆弹");sound.local("planted",-12)
		else:bomb_state="defused";bomb_visual.visible=false;end_round(1,"C4 已拆除")
		interaction_actor=null;interaction_progress=0

func stop_interact(actor):
	if interaction_actor==actor:interaction_actor=null;interaction_progress=0

func actor_died(actor,source=null,head=false):
	stop_interact(actor)
	if bomb_carrier==actor:
		objective_handlers.clear();bomb_carrier=null;bomb_state="dropped";bomb_position=actor.global_position
		bomb_visual.global_position=bomb_position+Vector3.UP*.1;bomb_visual.visible=true
	if actor==player:deaths+=1
	else:actor.score_deaths+=1
	if is_instance_valid(source) and source!=actor:
		if source==player:kills+=1;player.money=mini(16000,player.money+300)
		else:source.score_kills+=1
		feed(("你" if source==player else source.callsign)+("  爆头  " if head else "  击杀  ")+("你" if actor==player else actor.callsign))
	check_elimination()

func objective_for(bot) -> Vector3:
	var allies=team_alive(bot.team);var slot=allies.find(bot)
	if bomb_state=="planted" or (bomb_state=="dropped" and bot.team==0):
		var handler=interaction_actor if is_instance_valid(interaction_actor) else objective_handlers.get(bot.team)
		if not is_instance_valid(handler) or handler.hp<=0:
			var best=INF;handler=null
			for ally in allies:
				if ally==player:continue
				var distance=world.path(ally.global_position,bomb_position).size()
				if distance>0 and distance<best:best=distance;handler=ally
			objective_handlers[bot.team]=handler
		if (bot.team==1 or bomb_state=="dropped") and bot==handler:return bomb_position
		var ring=4.0 if bot.team==0 else 3.8
		for turn in 8:
			var angle=slot*TAU/maxi(1,allies.size())+turn*.42;var p=bomb_position+Vector3(cos(angle)*ring,0,sin(angle)*ring)
			if world.walkable(p):return p
		return bot.global_position
	if bot.team==0:
		var route=world.route_to(plan,0);bot.route_stage=mini(bot.route_stage,route.size()-1)
		if bot.flat_distance(route[bot.route_stage])<2.2 and bot.route_stage<route.size()-1:bot.route_stage+=1
		var target=route[bot.route_stage];var forward=(target-bot.global_position).normalized();var side=Vector3(-forward.z,0,forward.x)
		var offset=side*((slot%3)-1)*1.05-forward*(slot%2)*.7
		if bot!=bomb_carrier and world.walkable(target+offset):target+=offset
		return target
	var anchors=[Vector3(20,0,-24),Vector3(16,0,-27),Vector3(-20,0,-26),Vector3(-15,0,-24),Vector3(2.5,0,-23)]
	return anchors[slot%anchors.size()]

func bot_interaction(bot,dt: float) -> bool:
	var should=false
	if bot.team==0 and bot==bomb_carrier and world.site_at(bot.global_position)!="" and not bot.visible_target and bot.is_on_floor():should=true
	if bot.team==1 and bomb_state=="planted" and bot.global_position.distance_to(bomb_position)<2.4:
		should=interaction_actor!=player and objective_handlers.get(1,bot)==bot and (not bot.visible_target or bomb_left<12)
	if should:bot.velocity=Vector3.ZERO
	interact(bot,should,dt);return should

func ray(from: Vector3,to: Vector3,mask=1,exclude=[]) -> Dictionary:
	var rids: Array[RID]=[];rids.assign(exclude)
	var q=PhysicsRayQueryParameters3D.create(from,to,mask,rids);q.hit_from_inside=true
	return get_world_3d().direct_space_state.intersect_ray(q)

func smoke_blocks(from: Vector3,to: Vector3) -> bool:
	var delta=to-from;var length_sq=delta.length_squared()
	if length_sq<.001:return false
	for smoke in smokes:
		if smoke.age<.4 or smoke.left<1:return false
		var t=clampf((smoke.pos-from).dot(delta)/length_sq,0,1)
		if (from+delta*t).distance_to(smoke.pos)<smoke.radius:return true
	return false

func clear_sight(from: Vector3,to: Vector3) -> bool:
	return not smoke_blocks(from,to) and ray(from,to,1).is_empty()

func noise(pos: Vector3,radius: float,source=null):
	for bot in bots:
		if is_instance_valid(source) and bot.team==source.team:continue
		var effective=radius if ray(pos+Vector3.UP,bot.global_position+Vector3.UP,1).is_empty() else radius*.55
		if bot.global_position.distance_to(pos)<effective:bot.hear(pos)

func throw_grenade(actor,kind: String,direction: Vector3,origin: Vector3) -> bool:
	if not active or phase not in ["live","planted"] or actor.hp<=0 or actor.grenades[kind]<=0:return false
	actor.grenades[kind]-=1
	var grenade=preload("res://scripts/grenade.gd").new();grenade.game=self;grenade.thrower=actor;grenade.kind=kind
	add_child(grenade);projectiles.append(grenade)
	var spawn=origin+direction*.55
	if not ray(origin,spawn,1).is_empty():spawn=origin
	grenade.global_position=spawn;grenade.linear_velocity=direction*13+Vector3.UP*3.4
	grenade.angular_velocity=Vector3(7,3,9);sound.play_at("pin",origin,-17);return true

func detonate(grenade):
	if phase in ["live","planted"]:
		if grenade.kind=="smoke":add_smoke(grenade.global_position)
		else:explode(grenade.global_position,7,110,grenade.thrower)
	projectiles.erase(grenade);grenade.queue_free()

func add_smoke(pos: Vector3):
	var node=Node3D.new();add_child(node);node.position=Vector3(pos.x,maxf(pos.y,0)+1.1,pos.z)
	var material_=StandardMaterial3D.new();material_.albedo_color=Color(.60,.62,.60,.94);material_.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material_.cull_mode=BaseMaterial3D.CULL_DISABLED;material_.roughness=1;material_.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 13:
		var mesh=SphereMesh.new();mesh.radius=2.1;mesh.height=4.2
		var m=MeshInstance3D.new();m.mesh=mesh;m.material_override=material_;node.add_child(m)
		m.position=Vector3(cos(i*2.4)*1.8,sin(i*1.7)*.65,sin(i*2.4)*1.8) if i else Vector3.ZERO
	smokes.append({"node":node,"pos":node.position,"radius":3.8,"left":18.,"age":0.});sound.play_at("smoke_hiss",pos,-17)

func update_smokes(dt: float):
	for i in range(smokes.size()-1,-1,-1):
		var s=smokes[i];s.left-=dt;s.age+=dt;s.node.scale=Vector3.ONE*minf(1,minf(s.age/1.1,s.left/1.5))
		if s.left<=0:s.node.queue_free();smokes.remove_at(i)

func explode(pos: Vector3,radius: float,damage: int,source):
	sound.play_at("explosion",pos,-4)
	var light=OmniLight3D.new();light.light_color=Color(1,.55,.18);light.light_energy=9;light.omni_range=radius*2;add_child(light);light.position=pos+Vector3.UP;effects.append([light,.15])
	var sphere=MeshInstance3D.new();var m=SphereMesh.new();m.radius=1.5;m.height=3;sphere.mesh=m
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(1,.51,.12,.4);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material_override=mat;add_child(sphere);sphere.position=pos;effects.append([sphere,.20])
	for actor in actors():
		if actor.hp<=0 or (is_instance_valid(source) and actor.team==source.team):continue
		var d=actor.global_position.distance_to(pos)
		if d<radius and ray(pos+Vector3.UP*.3,actor.global_position+Vector3.UP,1).is_empty():actor.take_damage(roundi(damage*(1-d/radius)),false,source)

func make_bomb_visual():
	bomb_visual=Node3D.new();add_child(bomb_visual)
	W.block(bomb_visual,Vector3.ZERO,Vector3(.34,.16,.22),W.mat(Color(.17,.19,.13),.2,.7))
	W.block(bomb_visual,Vector3(0,.09,0),Vector3(.13,.025,.085),W.mat(Color(.4,.8,.27),.1,.3));bomb_visual.visible=false

func feed(text_: String):message=text_;message_left=3.5

func tracer(from: Vector3,to: Vector3,color: Color):
	var mesh_=ImmediateMesh.new();mesh_.surface_begin(Mesh.PRIMITIVE_LINES);mesh_.surface_add_vertex(from);mesh_.surface_add_vertex(to);mesh_.surface_end()
	var m=MeshInstance3D.new();m.mesh=mesh_;var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=color;m.material_override=mat;add_child(m);effects.append([m,.045])

func impact(pos: Vector3,normal: Vector3):
	if normal.length()<.1:return
	var mark=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(.065,.065);mark.mesh=quad
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(.14,.12,.09);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.material_override=mat;add_child(mark);mark.position=pos+normal*.008;mark.quaternion=Quaternion(Vector3.BACK,normal);marks.append(mark)
	if marks.size()>80:marks.pop_front().queue_free()

func smoke_check():
	test_mode=true;await get_tree().process_frame;start()
	for i in 180:await get_tree().physics_frame
	print("SMOKE_OK actors=",actors().size()," T=",team_alive(0).size()," CT=",team_alive(1).size()," phase=",phase)
	sound.silence();OS.delay_msec(100);get_tree().quit()

func capture_frames():
	test_mode=true;await get_tree().process_frame;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/v2-menu.png")
	start();hud.shop.visible=true;hud.on_shop_opened()
	for i in 3:await get_tree().process_frame
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://tests/v2-buy.png")
	hud.shop.visible=false;phase="live";player.equip_primary(2)
	for bot in bots:bot.set_physics_process(false)
	player.position=Vector3(20,0,-13);player.pitch=0
	for i in 4:await get_tree().process_frame
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://tests/v2-a.png")
	player.position=Vector3(-18,0,-15);player.equip_primary(3)
	for i in 4:await get_tree().process_frame
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://tests/v2-b.png")
	player.scoped=true;add_smoke(Vector3(-18,0,-22))
	for i in 90:await get_tree().process_frame
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://tests/v2-scope-smoke.png")
	sound.silence();OS.delay_msec(100);print("CAPTURE_OK");get_tree().quit()
