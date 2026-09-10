extends SceneTree
var game
func _initialize():call_deferred("run")
func snap(name_: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/revision3/"+name_+".png")
func run():
	root.size=Vector2i(1280,800)
	game=load("res://scripts/game.gd").new();root.add_child(game);game.test_mode=true
	await process_frame
	game.start();game.phase="live";game.time_left=115
	game.player.position=Vector3(20,0,-13)
	for bot in game.bots:bot.set_physics_process(false)
	for weapon in [0,1,2,3]:
		if weapon!=1:game.player.equip_primary(weapon)
		else:game.player.switch_weapon(1)
		game.player.draw_left=0
		for i in 4:await process_frame
		await snap("grip-"+str(weapon))
	game.player.equip_primary(0);game.player.draw_left=0;game.player.ammo[0]=14;game.player.request_reload()
	game.player.set_physics_process(false)
	for t in [.25,.45,.65,.85]:
		game.player.reload_left=game.player.reload_duration*(1-t);game.player.update_view(1./60,0)
		await process_frame;await snap("reload-"+str(t))
	game.player.weapon_anchor.visible=false;game.hud.visible=false
	var actor=game.bots[0];actor.global_position=Vector3(20,0,-17);actor.rotation.y=PI*.15
	game.player.camera.global_position=Vector3(22,1.5,-20.5);game.player.camera.look_at(actor.position+Vector3.UP*1.15)
	actor.update_pose(.1)
	for i in 6:await process_frame
	await snap("operator-idle")
	game.sound.silence();OS.delay_msec(100);game.queue_free();await process_frame;quit()
