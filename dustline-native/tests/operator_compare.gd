extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://scripts/game.gd").new();root.add_child(game);game.test_mode=true
	await process_frame;game.start();game.phase="live"
	for bot in game.bots:bot.set_physics_process(false)
	game.player.set_physics_process(false);game.player.weapon_anchor.visible=false;game.hud.visible=false
	var actor=game.bots[0];actor.global_position=Vector3(20,0,-17);actor.rotation.y=PI*.15
	actor.model.visible=false
	var original=load("res://assets/operator-source.glb").instantiate();actor.add_child(original)
	for s in original.find_children("*","Skeleton3D",true,false):
		var mod=load("res://scripts/armed_pose.gd").new();mod.actor=actor;s.add_child(mod)
	for a in original.find_children("*","AnimationPlayer",true,false):
		for clip in a.get_animation_list():
			if "idle" in clip.to_lower():a.play(clip)
	game.player.camera.global_position=Vector3(21.8,1.55,-19.8);game.player.camera.look_at(actor.position+Vector3.UP*1.1)
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/revision3/operator-source.png")
	game.sound.silence();OS.delay_msec(100);quit()
