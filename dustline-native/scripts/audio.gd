extends Node

var streams={}
var players: Array[AudioStreamPlayer3D]=[]
var ui_players: Array[AudioStreamPlayer]=[]
var cursor=0
var last_variant={}
const GUNS=["rifle_shot","pistol_shot","m4_shot","sniper_shot"]

func _ready():
	for file in ["rifle_shot","pistol_shot","rifle_reload","pistol_reload","step0","step1","step2","step3","step4","step5","m4_shot","sniper_shot","bomb_beep","buy","pin","planted","round_win","explosion","smoke_hiss"]:
		streams[file]=load("res://assets/audio/"+file+".wav")
	for gun in GUNS:
		for suffix in ["","_far","_occluded"]:
			for i in 4:
				var key=gun+suffix+"_"+str(i)
				streams[key]=load("res://assets/audio/"+key+".wav")
	for i in 48:
		var p=AudioStreamPlayer3D.new();p.max_distance=55;p.unit_size=5;p.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.max_db=0;add_child(p);players.append(p)
	for i in 24:
		var p=AudioStreamPlayer.new();add_child(p);ui_players.append(p)
	if AudioServer.get_bus_effect_count(0)==0:
		var limiter=AudioEffectHardLimiter.new();limiter.ceiling_db=-1.;limiter.release=.08;AudioServer.add_bus_effect(0,limiter)
	set_volume(.65)

func set_volume(value: float):
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value,.001)))

func play_at(sound: String,pos: Vector3,volume=-6.):
	var p=players[cursor%players.size()];cursor+=1
	var suffix=""
	var game=get_parent()
	if sound in GUNS and is_instance_valid(game.player):
		var ear=game.player.camera.global_position
		if not game.ray(ear,pos,1).is_empty():suffix="_occluded";volume-=8
		elif ear.distance_to(pos)>18:suffix="_far"
	p.stop();p.stream=select_stream(sound,suffix);p.global_position=pos;p.volume_db=volume;p.pitch_scale=1.;p.play()

func local(sound: String,volume=-6.) -> AudioStreamPlayer:
	for p in ui_players:
		if not p.playing:
			p.stream=select_stream(sound);p.volume_db=volume;p.pitch_scale=1;p.play();return p
	return null

func silence():
	for p in players:p.stop()
	for p in ui_players:p.stop()

func _exit_tree():
	silence()

func select_stream(sound: String,suffix="") -> AudioStream:
	if sound not in GUNS:return streams[sound]
	var key=sound+suffix
	var previous=int(last_variant.get(key,-1))
	var variant=randi()%3
	if variant>=previous and previous>=0:variant+=1
	last_variant[key]=variant
	return streams[key+"_"+str(variant)]
