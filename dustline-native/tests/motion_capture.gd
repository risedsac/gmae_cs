extends SceneTree
var game
var label: Label
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(960,600)
	game=load("res://scripts/game.gd").new();root.add_child(game);game.test_mode=true
	await process_frame;game.start();game.phase="live";game.time_left=115
	var layer=CanvasLayer.new();layer.layer=10;root.add_child(layer)
	label=Label.new();label.position=Vector2(26,20);label.add_theme_font_override("font",load("res://assets/fonts/NotoSansCJK-Regular.ttc"));label.add_theme_font_size_override("font_size",20);label.add_theme_color_override("font_outline_color",Color.BLACK);label.add_theme_constant_override("outline_size",5);layer.add_child(label)
	for bot in game.bots:bot.set_physics_process(false);bot.model.visible=false;bot.gun.visible=false;bot.friendly_label.visible=false
	game.hud.visible=false;game.player.set_physics_process(false);game.player.weapon_anchor.visible=false
	game.player.global_position=Vector3(-5,0,29)
	var actor=game.bots[0];actor.reset_at(Vector3(0,0,23));actor.set_physics_process(true)
	label.text="AI 自主行进 · 转向与跑步混合"
	for i in 75:
		game.player.camera.global_position=actor.global_position+Vector3(-3,1.6,3.4)
		game.player.camera.look_at(actor.global_position+Vector3.UP*1.0)
		await process_frame
		if i in [20,45,70]:await save_frame("run-"+str(i))
	actor.reset_at(Vector3(21,0,-11));actor.hp=1000;actor.grenades={"he":0,"smoke":0}
	var opponent=game.bots[4];opponent.reset_at(Vector3(21,0,-22));opponent.hp=1000;opponent.grenades={"he":0,"smoke":0};opponent.set_physics_process(true)
	label.text="AI 交火 · 停步点射与间歇侧移（高生命测试场景）"
	for i in 210:
		game.player.camera.global_position=actor.global_position+Vector3(-3,1.7,3.0)
		game.player.camera.look_at(actor.global_position+Vector3(0,1,-1.3))
		await process_frame
		if i in [30,100,200]:await save_frame("combat-"+str(i))
	print("CAPTURE_COMBAT_SHOTS ",actor.shot_count," / ",opponent.shot_count)
	for bot in game.bots:bot.set_physics_process(false);bot.model.visible=false;bot.gun.visible=false;bot.friendly_label.visible=false
	game.player.reset_at(Vector3(20,0,-13));game.player.set_physics_process(true);game.player.equip_primary(0);game.player.draw_left=0;game.player.ammo[0]=14;game.hud.visible=true
	label.text="第一人称 · 握持、换弹、射击与录音音效"
	for i in 135:
		if i==8:game.player.request_reload()
		if i in [101,111,121]:game.player.fire()
		await process_frame
		if i in [28,48,68,95,122]:await save_frame("view-action-"+str(i))
	game.sound.silence();print("MOTION_CAPTURE_COMPLETE");quit()
func save_frame(name_: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/revision3/"+name_+".png")
