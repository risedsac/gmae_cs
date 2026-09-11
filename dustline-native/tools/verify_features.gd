extends SceneTree

const W=preload("res://scripts/weapons.gd")
var failures: Array[String]=[]

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool,message: String) -> void:
	if condition:
		print("[DUSTLINE FEATURE] PASS: ",message)
	else:
		failures.append(message);push_error("[DUSTLINE FEATURE] FAIL: "+message)

func _has_mouse_binding(action: StringName,button: MouseButton) -> bool:
	if not InputMap.has_action(action):return false
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index==button:return true
	return false

func _prepare_player_weapon(player,index: int,rounds: int) -> void:
	player.cancel_reload();player.utility_left=0.;player.owned[index]=true;player.weapon=index
	player.ammo[index]=rounds;player.reserve[index]=maxi(int(W.DATA[index].reserve),1)
	for i in 4:player.models[i].visible=i==index
	player.reset_weapon_rig(index)

func _exercise_reload(player,index: int,rounds: int,label: String) -> void:
	_prepare_player_weapon(player,index,rounds)
	player.request_reload()
	_check(player.reload_left>0.,W.DATA[index].name+" "+label+" reload starts")
	if index>0:
		_check(player.reload_clip_name!="procedural_fallback",W.DATA[index].name+" "+label+" uses imported skeletal rig")
	if player.reload_left>0.:
		player.reload_left=player.reload_duration*.50;player.update_reload_presentation()
	player.cancel_reload()

func _run() -> void:
	var packed=load("res://main.tscn") as PackedScene
	if not packed:
		_check(false,"main scene loads");quit(1);return
	var game=packed.instantiate();root.add_child(game)
	game.start();game.phase="live";game.phase_left=0.;game.buy_left=35.
	var player=game.player

	# Asset + reload acceptance. AK keeps its independent authored path; the other
	# three must not silently fall back after bootstrap verification succeeds.
	player.owned=[true,true,true,true];player.primary=2
	for index in 4:
		var half=maxi(1,int(player.capacities[index]/2))
		_exercise_reload(player,index,half,"tactical")
		_exercise_reload(player,index,0,"empty")

	# Switching during reload must reuse switch_weapon(), which owns cancellation,
	# audio cleanup and draw/equip presentation.
	_prepare_player_weapon(player,2,5);player.request_reload();var had_reload=player.reload_left>0.
	player.switch_weapon(1)
	_check(had_reload and player.weapon==1 and player.reload_left==0.,"switching weapon cancels active reload")
	_check(player.reload_event_players.is_empty(),"switching weapon stops reload event audio")

	# Wheel cycling uses the same switch path and only owned weapons.
	_check(_has_mouse_binding("weapon_prev",MOUSE_BUTTON_WHEEL_UP),"wheel-up input action is registered")
	_check(_has_mouse_binding("weapon_next",MOUSE_BUTTON_WHEEL_DOWN),"wheel-down input action is registered")
	player.owned=[false,true,true,false];player.primary=2;player.weapon=1
	player.cycle_owned_weapon(1);_check(player.weapon==2,"wheel-down cycles pistol -> owned primary")
	player.cycle_owned_weapon(-1);_check(player.weapon==1,"wheel-up cycles owned primary -> pistol")

	# Runtime audio must actually be on the new multisample path, not merely have
	# generator code present in the repository.
	for sound in ["rifle_shot","pistol_shot","m4_shot","sniper_shot"]:
		_check(game.sound.realistic_streams.has(sound),sound+" multisample runtime profile active")
		if game.sound.realistic_streams.has(sound):
			var profile: Dictionary=game.sound.realistic_streams[sound]
			for role in ["near","world","distant","tail"]:
				_check((profile.get(role,[]) as Array).size()==4,sound+" "+role+" has four imported variants")

	# Shop double-click: emitting one left-button double-click invokes game.buy()
	# once. A repeated event is rejected by the existing 'already carried' rule.
	game.phase="freeze";game.buy_left=35.;player.hp=100;player.money=1000;player.grenades.he=0
	player.global_position=game.world.T_SPAWN if player.team==0 else game.world.CT_SPAWN
	game.hud.shop.visible=true;game.hud.on_shop_opened()
	var he_button=game.hud.shop_item_buttons.get("he") as Button
	var double_click=InputEventMouseButton.new();double_click.button_index=MOUSE_BUTTON_LEFT;double_click.pressed=true;double_click.double_click=true
	var before_money=player.money
	if he_button:he_button.emit_signal("gui_input",double_click)
	_check(player.grenades.he==1,"shop left double-click buys selected product")
	_check(player.money==before_money-int(game.BUY_CATALOG["he"].price),"one double-click charges exactly once")
	var after_first=player.money
	if he_button:he_button.emit_signal("gui_input",double_click)
	_check(player.money==after_first,"repeat double-click respects already-owned validation")
	game.hud.shop.visible=false

	# First-person spectator state shares one target for camera, viewmodel and HUD.
	var allies=game.bots.filter(func(bot):return bot.team==player.team and bot.hp>0)
	_check(not allies.is_empty(),"living teammate exists for spectator test")
	if not allies.is_empty():
		player.hp=0;player.weapon_anchor.visible=false;player.spectator_index=0;player.clear_spectator_target();player.update_spectator(.016)
		var ally=player.spectator_actor()
		_check(is_instance_valid(ally),"spectator acquires living teammate")
		if is_instance_valid(ally):
			_check(game.hud.observed_actor()==ally,"HUD and camera use the same spectator target")
			_check(player.weapon_anchor.visible,"spectator first-person weapon is visible")
			_check(player.models[int(ally.weapon)].visible,"spectator viewmodel matches teammate weapon")
			_check(not ally.model.visible and not ally.gun.visible,"spectated teammate third-person body and gun are hidden from view")
			var camera_forward=(-player.camera.global_basis.z).normalized();var gun_forward=(-ally.gun.global_basis.orthonormalized().z).normalized()
			_check(camera_forward.dot(gun_forward)>.999,"spectator camera follows teammate actual weapon aim basis")
			ally.reload_left=1.0;ally.ammo=0;player.update_spectator(.016)
			_check(player.spectator_last_reload,"spectator mirrors teammate reload state")
			ally.reload_left=0.;ally.shot_count+=1;ally.flash_clock=.04;player.update_spectator(.016)
			_check(player.spectator_last_shot_count==ally.shot_count,"spectator mirrors teammate shot event")
			if allies.size()>1:
				var old=ally;player.spectator_index=1;player.update_spectator(.016)
				_check(old.model.visible and old.gun.visible,"switching spectator target restores previous third-person model")
				ally=player.spectator_actor()
			if is_instance_valid(ally):
				var dying=ally;dying.hp=0;player.update_spectator(.016)
				_check(dying.model.visible,"spectated target death restores third-person body visibility")
				dying.hp=100;dying.model.visible=true;dying.gun.visible=true
			player.clear_spectator_target()
			_check(old_or_current_visible(allies),"leaving spectator target restores third-person visibility")

	game.sound.silence();game.queue_free()
	if failures.is_empty():
		print("[DUSTLINE FEATURE] OK: source acceptance checks passed")
		quit(0)
	else:
		push_error("[DUSTLINE FEATURE] FAILED with "+str(failures.size())+" failure(s)")
		quit(1)

func old_or_current_visible(allies: Array) -> bool:
	for ally in allies:
		if ally.hp>0 and (not ally.model.visible or not ally.gun.visible):return false
	return true
