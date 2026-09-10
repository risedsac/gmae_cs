extends SceneTree
var game
var failures=0
func check_(condition: bool,label: String):
	print("PASS " if condition else "FAIL ",label)
	if not condition:failures+=1
func _initialize():call_deferred("run")
func run():
	game=load("res://scripts/game.gd").new();root.add_child(game);game.test_mode=true
	await process_frame;game.player_team=1;game.start();game.phase="live"
	game.player.set_physics_process(false);game.player.global_position=Vector3(5,0,-28)
	check_(not game.world.corridor_clear(Vector3(10,0,0),Vector3(20,0,0)),"corridor smoothing cannot cross a building")
	check_(game.world.corridor_clear(Vector3(20,0,-14),Vector3(21,0,-18)),"open lane allows navigation lookahead")
	game.bomb_state="planted";game.phase="planted";game.bomb_position=Vector3(18,0,-23)
	var objectives=[];var handlers=0
	for bot in game.bots:
		if bot.team!=1:continue
		var target=game.objective_for(bot);objectives.append(target)
		if target.distance_to(game.bomb_position)<1:handlers+=1
	check_(handlers==1,"retake assigns exactly one AI directly to bomb")
	var distinct=true
	for i in objectives.size():
		for j in range(i+1,objectives.size()):
			if objectives[i].distance_to(objectives[j])<1.2:distinct=false
	check_(distinct,"retake teammates have separated cover destinations")
	var handler=game.objective_handlers.get(1)
	if is_instance_valid(handler):
		game.player.position=game.bomb_position+Vector3(.5,0,0)
		handler.position=game.bomb_position+Vector3(1.8,0,0);handler.visible_target=false
		game.bot_interaction(handler,.1)
		check_(game.interaction_actor==handler,"nearby idle human does not prevent teammate defusing")
		game.interact(game.player,true,.1)
		check_(game.interaction_actor==game.player,"human holding E can take over the defuse")
		check_(not game.bot_interaction(handler,.1),"AI yields the interaction to the human")
	var unique={};var previous
	for i in 20:
		var stream=game.sound.select_stream("rifle_shot")
		check_(stream!=previous,"shot variant does not repeat consecutively "+str(i))
		unique[stream.resource_path]=true;previous=stream
	check_(unique.size()==4,"all four recorded near shot variants are used")
	var summary=[]
	for trial in 2:
		seed(1700+trial);game.start();game.phase="live";game.time_left=115
		game.player.position=Vector3(5,0,-28)
		var initial_shots=0
		for bot in game.bots:initial_shots+=bot.shot_count
		var moving_frames=0;var sliding_frames=0;var longest_stall=0.;var stalls={};var max_travel={}
		for i in 3600:
			await physics_frame
			for bot in game.bots:
				max_travel[bot.index]=maxf(max_travel.get(bot.index,0),bot.navigation_distance)
				if bot.hp<=0 or game.phase not in ["live","planted"]:continue
				var speed=Vector2(bot.velocity.x,bot.velocity.z).length()
				if speed>1.5:
					moving_frames+=1
					if (-bot.global_basis.z).dot(Vector3(bot.velocity.x,0,bot.velocity.z).normalized())<.55:sliding_frames+=1
				var stalled=not bot.visible_target and not bot.points.is_empty() and bot.flat_distance(bot.goal)>2 and speed<.2 and game.interaction_actor!=bot
				stalls[bot.index]=stalls.get(bot.index,0.)+1./60 if stalled else 0.
				longest_stall=maxf(longest_stall,stalls[bot.index])
		var shots=-initial_shots
		for bot in game.bots:shots+=bot.shot_count
		var ratio=float(sliding_frames)/maxi(1,moving_frames)
		check_(shots>15,"trial %d produces sustained actual AI combat (%d shots)"%[trial,shots])
		check_(ratio<.04,"trial %d moving sideways under forward animation <4%% (%.2f%%)"%[trial,ratio*100])
		check_(longest_stall<4.,"trial %d no prolonged obstacle stall (max %.2fs)"%[trial,longest_stall])
		summary.append({"trial":trial,"shots":shots,"sideways_ratio":ratio,"longest_stall_seconds":longest_stall,"travel_metres":max_travel})
	FileAccess.open("res://tests/revision3/ai-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(summary,"\t"))
	game.sound.silence();game.queue_free();await process_frame;await process_frame;OS.delay_msec(100)
	print("AI_QUALITY_RESULT failures=",failures);quit(failures)
