extends Node

var streams={}
var realistic_streams={}
var players: Array[AudioStreamPlayer3D]=[]
var ui_players: Array[AudioStreamPlayer]=[]
var cursor=0
var last_variant={}
const GUNS=["rifle_shot","pistol_shot","m4_shot","sniper_shot"]
const REAL_AUDIO_ROOT="res://assets/audio/realistic_weapons/"
const SFX_ROOT="res://assets/audio/realistic_sfx/"
const REAL_PROFILE={
	"rifle_shot":"ak74",
	"pistol_shot":"p226",
	"m4_shot":"m4a1",
	"sniper_shot":"awm"
}

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
	for i in 64:
		var p=AudioStreamPlayer3D.new()
		p.max_distance=80;p.unit_size=4.5;p.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.attenuation_filter_cutoff_hz=20500;p.attenuation_filter_db=-18;p.max_db=1
		add_child(p);players.append(p)
	for i in 32:
		var p=AudioStreamPlayer.new();add_child(p);ui_players.append(p)
	if AudioServer.get_bus_effect_count(0)==0:
		var limiter=AudioEffectHardLimiter.new();limiter.ceiling_db=-1.;limiter.release=.08;AudioServer.add_bus_effect(0,limiter)
	set_volume(.65)

func install_recorded_sfx():
	optional_replace("pistol_reload",[SFX_ROOT+"pistol_reload.wav"])
	optional_replace("rifle_reload",[SFX_ROOT+"rifle_reload.wav"])
	optional_replace("pin",[SFX_ROOT+"equipment_click.wav"])
	optional_replace("equip",[SFX_ROOT+"equipment_click.wav"])
	optional_replace("explosion",[SFX_ROOT+"explosion.wav"])
	optional_replace("smoke_hiss",[SFX_ROOT+"smoke_hiss.wav",SFX_ROOT+"smoke_hiss.ogg"])
	optional_replace("buy",[SFX_ROOT+"ui_confirm.wav",SFX_ROOT+"ui_confirm.ogg"])

func optional_replace(key: String,paths: Array):
	for path in paths:
		if ResourceLoader.exists(path):
			streams[key]=load(path)
			print("[DUSTLINE AUDIO] ",key," <- ",path)
			return

func load_realistic_profile(sound: String):
	var profile=str(REAL_PROFILE.get(sound,""))
	if profile.is_empty():return
	var roles={"near":profile+"_player_near.wav","world":profile+"_world.wav","distant":profile+"_enemy_distant.wav"}
	var loaded={}
	for role in roles:
		var path=REAL_AUDIO_ROOT+profile+"/"+roles[role]
		if ResourceLoader.exists(path):loaded[role]=load(path)
	if loaded.has("near") and loaded.has("world") and loaded.has("distant"):
		realistic_streams[sound]=loaded
		print("[DUSTLINE AUDIO] real firearm profile ready: ",sound," -> ",profile)

func set_volume(value: float):
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value,.001)))

func play_at(sound: String,pos: Vector3,volume=-6.):
	var p=players[cursor%players.size()];cursor+=1
	var game=get_parent();var distance=0.;var blocked=false
	if sound in GUNS and is_instance_valid(game.player):
		var ear=game.player.camera.global_position;distance=ear.distance_to(pos);blocked=not game.ray(ear,pos,1).is_empty()
	p.stop();p.global_position=pos;p.pitch_scale=randf_range(.992,1.008) if sound in GUNS else 1.
	p.attenuation_filter_cutoff_hz=2200. if blocked else (9000. if distance>26 else 20500.)
	p.attenuation_filter_db=-20. if blocked else -12.
	if sound in GUNS and realistic_streams.has(sound):
		var role="distant" if distance>24 else "world";p.stream=realistic_streams[sound][role];p.volume_db=volume-(7. if blocked else 0.)
	else:
		var suffix=""
		if sound in GUNS:
			if blocked:suffix="_occluded";volume-=8
			elif distance>18:suffix="_far"
		p.stream=select_stream(sound,suffix);p.volume_db=volume
	p.play()

func local(sound: String,volume=-6.) -> AudioStreamPlayer:
	for p in ui_players:
		if not p.playing:
			if sound in GUNS and realistic_streams.has(sound):p.stream=realistic_streams[sound]["near"]
			else:p.stream=select_stream(sound)
			p.volume_db=volume;p.pitch_scale=randf_range(.994,1.006) if sound in GUNS else 1.;p.play();return p
	return null

func silence():
	for p in players:p.stop()
	for p in ui_players:p.stop()

func _exit_tree():silence()

func select_stream(sound: String,suffix="") -> AudioStream:
	if sound not in GUNS:return streams.get(sound,streams["buy"])
	var key=sound+suffix;var previous=int(last_variant.get(key,-1));var variant=randi()%3
	if variant>=previous and previous>=0:variant+=1
	last_variant[key]=variant;return streams[key+"_"+str(variant)]
