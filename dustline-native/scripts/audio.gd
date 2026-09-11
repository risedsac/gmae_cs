extends Node

var streams={}
var realistic_streams={}
var reload_event_streams={}
var players: Array[AudioStreamPlayer3D]=[]
var ui_players: Array[AudioStreamPlayer]=[]
var cursor=0
var last_variant={}
var last_real_variant={}
var logged_local_guns={}
const GUNS=["rifle_shot","pistol_shot","m4_shot","sniper_shot"]
const REAL_AUDIO_ROOT="res://assets/audio/realistic_weapons/"
const SFX_ROOT="res://assets/audio/realistic_sfx/"
const RELOAD_EVENT_ROOT=SFX_ROOT+"reload_events/"
const REAL_PROFILE={
	"rifle_shot":"ak74","pistol_shot":"p226","m4_shot":"m4a1","sniper_shot":"awm"
}
const RELOAD_PROFILES=["ak74","p226","m4a1","awm"]
const SHOT_TAIL_DB=-15.0
const SHOT_MECHANICAL_DB=-25.0

func _ready():
	for file in ["rifle_shot","pistol_shot","rifle_reload","pistol_reload","step0","step1","step2","step3","step4","step5","m4_shot","sniper_shot","bomb_beep","buy","pin","planted","round_win","explosion","smoke_hiss"]:
		streams[file]=load("res://assets/audio/"+file+".wav")
	streams["equip"]=streams["pin"]
	install_recorded_sfx()
	for gun in GUNS:
		for suffix in ["","_far","_occluded"]:
			for i in 4:
				var key=gun+suffix+"_"+str(i)
				streams[key]=load("res://assets/audio/"+key+".wav")
		load_realistic_profile(gun)
	for i in 80:
		var p=AudioStreamPlayer3D.new()
		p.max_distance=90;p.unit_size=4.5;p.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.attenuation_filter_cutoff_hz=20500;p.attenuation_filter_db=-18;p.max_db=1
		add_child(p);players.append(p)
	for i in 48:
		var p=AudioStreamPlayer.new();add_child(p);ui_players.append(p)
	if AudioServer.get_bus_effect_count(0)==0:
		var limiter=AudioEffectHardLimiter.new();limiter.ceiling_db=-1.;limiter.release=.08;AudioServer.add_bus_effect(0,limiter)
	set_volume(.65)

func install_recorded_sfx():
	optional_replace("pistol_reload",[SFX_ROOT+"pistol_reload.wav"])
	optional_replace("rifle_reload",[SFX_ROOT+"rifle_reload.wav"])
	optional_replace("pin",[SFX_ROOT+"equipment_click.wav"])
	optional_replace("equip",[SFX_ROOT+"equipment_click.wav"])
	optional_replace("shot_mech",[SFX_ROOT+"equipment_click.wav"])
	optional_replace("explosion",[SFX_ROOT+"explosion.wav"])
	optional_replace("smoke_hiss",[SFX_ROOT+"smoke_hiss.wav",SFX_ROOT+"smoke_hiss.ogg"])
	optional_replace("buy",[SFX_ROOT+"ui_confirm.wav",SFX_ROOT+"ui_confirm.ogg"])
	for profile in RELOAD_PROFILES:
		for event in ["mag_out","mag_in","action_pull","action_release"]:
			var path=RELOAD_EVENT_ROOT+profile+"_"+event+".wav"
			if ResourceLoader.exists(path):reload_event_streams[profile+":"+event]=load(path)

func optional_replace(key: String,paths: Array):
	for path in paths:
		if ResourceLoader.exists(path):
			streams[key]=load(path);print("[DUSTLINE AUDIO] ",key," <- ",path);return

func load_realistic_profile(sound: String):
	var profile=str(REAL_PROFILE.get(sound,""))
	if profile.is_empty():return
	var loaded={"near":[],"world":[],"distant":[],"tail":[]};var complete=true
	for role in ["near","world","distant","tail"]:
		for i in 4:
			var path=REAL_AUDIO_ROOT+profile+"/"+role+"_"+str(i)+".wav"
			if ResourceLoader.exists(path):(loaded[role] as Array).append(load(path))
			else:complete=false
	if complete:
		realistic_streams[sound]=loaded
		print("[DUSTLINE AUDIO] multisample firearm profile ready: ",sound," -> ",profile," (4 dry/world/distant/tail takes)")
	else:push_warning("[DUSTLINE AUDIO] incomplete multisample profile for "+profile+"; using legacy four-variant fallback")

func set_volume(value: float):AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value,.001)))

func choose_real_variant(sound: String,role: String) -> int:
	if not realistic_streams.has(sound):return -1
	var array_: Array=realistic_streams[sound].get(role,[])
	if array_.is_empty():return -1
	var key=sound+":"+role;var previous=int(last_real_variant.get(key,-1));var variant=randi()%array_.size()
	if array_.size()>1 and variant==previous:variant=(variant+1+randi()%(array_.size()-1))%array_.size()
	last_real_variant[key]=variant;return variant

func free_ui_player() -> AudioStreamPlayer:
	for p in ui_players:
		if not p.playing:return p
	return ui_players[randi()%ui_players.size()]

func free_3d_player() -> AudioStreamPlayer3D:
	var p=players[cursor%players.size()];cursor+=1;return p

func play_ui_stream(stream: AudioStream,volume: float,pitch=1.0) -> AudioStreamPlayer:
	var p=free_ui_player();p.stop();p.stream=stream;p.volume_db=volume;p.pitch_scale=pitch;p.play();return p

func play_3d_stream(stream: AudioStream,pos: Vector3,volume: float,cutoff=20500.0,filter_db=-12.0) -> AudioStreamPlayer3D:
	var p=free_3d_player();p.stop();p.global_position=pos;p.stream=stream;p.volume_db=volume;p.pitch_scale=1.0
	p.attenuation_filter_cutoff_hz=cutoff;p.attenuation_filter_db=filter_db;p.play();return p

func environment_tail_offset(pos: Vector3) -> float:
	# Cheap runtime openness probe: unlike the old baked reflection mix, the tail
	# level now follows the current space. More nearby surfaces => stronger tail;
	# open exterior space => substantially less tail.
	var game=get_parent()
	if not game or not game.has_method("ray"):return -4.
	var directions=[Vector3.UP,Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1),Vector3(0,.45,-1).normalized()]
	var blocked=0
	for dir in directions:
		if not game.ray(pos,pos+dir*12.,1).is_empty():blocked+=1
	return lerpf(-8.,2.,float(blocked)/float(directions.size()))

func play_real_tail_local(sound: String,index: int,volume: float):
	var tails: Array=realistic_streams[sound].get("tail",[])
	if index<0 or index>=tails.size():return
	var game=get_parent();var pos=game.player.camera.global_position if is_instance_valid(game.player) else Vector3.ZERO
	play_ui_stream(tails[index],volume+SHOT_TAIL_DB+environment_tail_offset(pos))

func play_real_tail_at(sound: String,index: int,pos: Vector3,volume: float,blocked: bool,distance: float):
	var tails: Array=realistic_streams[sound].get("tail",[])
	if index<0 or index>=tails.size():return
	var cutoff=3200. if blocked else (8000. if distance>24 else 12500.)
	play_3d_stream(tails[index],pos,volume+SHOT_TAIL_DB+environment_tail_offset(pos)-(4. if blocked else 0.),cutoff,-16.)

func play_at(sound: String,pos: Vector3,volume=-6.):
	var game=get_parent();var distance=0.;var blocked=false
	if sound in GUNS and is_instance_valid(game.player):
		var ear=game.player.camera.global_position;distance=ear.distance_to(pos);blocked=not game.ray(ear,pos,1).is_empty()
	if sound in GUNS and realistic_streams.has(sound):
		var role="distant" if distance>24 else "world";var variant=choose_real_variant(sound,role);var options: Array=realistic_streams[sound][role]
		var cutoff=2200. if blocked else (9000. if distance>26 else 20500.)
		play_3d_stream(options[variant],pos,volume-(7. if blocked else 0.),cutoff,-20. if blocked else -12.);play_real_tail_at(sound,variant,pos,volume,blocked,distance);return
	var suffix=""
	if sound in GUNS:
		if blocked:suffix="_occluded";volume-=8
		elif distance>18:suffix="_far"
	play_3d_stream(select_stream(sound,suffix),pos,volume,2200. if blocked else 20500.,-20. if blocked else -12.)

func local(sound: String,volume=-6.) -> AudioStreamPlayer:
	if sound in GUNS and realistic_streams.has(sound):
		var variant=choose_real_variant(sound,"near");var options: Array=realistic_streams[sound]["near"];var dry=play_ui_stream(options[variant],volume,1.0)
		play_real_tail_local(sound,variant,volume)
		if streams.has("shot_mech"):play_ui_stream(streams["shot_mech"],volume+SHOT_MECHANICAL_DB,randf_range(.985,1.015))
		if not logged_local_guns.has(sound):
			logged_local_guns[sound]=true;print("[DUSTLINE AUDIO PLAY] ",sound," variant=",variant," dry=",dry.stream.resource_path," tail=runtime-space")
		return dry
	return play_ui_stream(select_stream(sound),volume,randf_range(.994,1.006) if sound in GUNS else 1.)

func reload_event(weapon_index: int,event: String,volume=-13.) -> AudioStreamPlayer:
	if weapon_index<0 or weapon_index>=RELOAD_PROFILES.size():return local("equip",volume)
	var profile=RELOAD_PROFILES[weapon_index];var key=profile+":"+event
	if reload_event_streams.has(key):return play_ui_stream(reload_event_streams[key],volume,1.0)
	return local("equip",volume-4.)

func silence():
	for p in players:p.stop()
	for p in ui_players:p.stop()

func _exit_tree():silence()

func select_stream(sound: String,suffix="") -> AudioStream:
	if sound not in GUNS:return streams.get(sound,streams["buy"])
	var key=sound+suffix;var previous=int(last_variant.get(key,-1));var variant=randi()%3
	if variant>=previous and previous>=0:variant+=1
	last_variant[key]=variant;return streams[key+"_"+str(variant)]
