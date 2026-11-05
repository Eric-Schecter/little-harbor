extends Node

const ROOT = 'res://assets/audio/harbor/'
var clips = {}
var voices: Array[AudioStreamPlayer] = []
var water: AudioStreamPlayer
var cursor = 0
var gain = 0.0
var enabled = true
var events = {'ballista':0,'catapult':0,'firepot':0,'hull_hit':0,'water_hit':0,'arrow_hit':0,'stone_hit':0,'ship_cannon':0}
var impact_cooldowns = {'arrow_hit':0.0,'stone_hit':0.0,'hull_hit':0.0}
var variation = 0

func _ready():
	if AudioServer.get_bus_index('Harbor') < 0:
		AudioServer.add_bus()
		var index = AudioServer.bus_count-1
		AudioServer.set_bus_name(index,'Harbor')
		var limiter = AudioEffectHardLimiter.new()
		limiter.pre_gain_db = 0
		limiter.ceiling_db = -4
		AudioServer.add_bus_effect(index,limiter)
	for name_ in ['firepot','hull_hit','water_hit','sailing_loop']:
		clips[name_] = load(ROOT+name_+'.wav')
	for name_ in ['ballista','catapult','arrow_hit','stone_hit']:
		clips[name_] = load(ROOT+'foley-v2/'+name_+'.wav')
	clips['ship_cannon'] = load('res://assets/audio/harbor/ui/ship_cannon.wav')
	for specialty in ['rapid','heavy','scatter','siege','flame','oil']:
		for suffix in ['release','hit']:
			var key = specialty+'_'+suffix
			clips[key] = load(ROOT+'specialties-v1/'+key+'.wav')
			events[key] = 0
			if suffix == 'hit': impact_cooldowns[key] = 0.0
	for i in 16:
		var voice = AudioStreamPlayer.new()
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		voice.bus = 'Harbor'
		add_child(voice)
		voices.append(voice)
	water = AudioStreamPlayer.new()
	water.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	water.bus = 'Harbor'
	var loop: AudioStreamWAV = clips.sailing_loop.duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = loop.data.size()/2
	water.stream = loop
	water.pitch_scale = 1.0
	water.volume_db = -80
	add_child(water)

func play(name_: String, db = -10.0, pitch = 1.0):
	if not enabled or not clips.has(name_): return
	var voice = voices[cursor]
	cursor = (cursor+1)%voices.size()
	voice.stream = clips[name_]
	voice.pitch_scale = pitch*([0.98,1.0,1.02][variation%3] if name_ != 'water_hit' else 1.0)
	variation += 1
	voice.volume_db = db
	voice.play()
	events[name_] += 1

func weapon(level: int):
	play('ballista' if level < 4 else 'catapult' if level < 7 else 'firepot',-13 if level < 4 else -15)

func impact(level: int, sunk: bool):
	var name_ = 'arrow_hit' if level > 0 and level < 4 else 'stone_hit' if level < 7 else 'hull_hit'
	# Each material has its own short concurrency guard; arrows cannot mute stones.
	if impact_cooldowns[name_] <= 0:
		play(name_,-10 if name_ == 'arrow_hit' else -9 if name_ == 'stone_hit' else -15)
		impact_cooldowns[name_] = .035
		if enabled and name_ != 'hull_hit': events.hull_hit += 1
	if sunk: play('water_hit',-19)

func update_state(delta: float, sailing: int, allowed: bool):
	enabled = allowed
	for key in impact_cooldowns: impact_cooldowns[key] = maxf(0,impact_cooldowns[key]-delta)
	if not allowed:
		reset()
		return
	var target = db_to_linear(-23+minf(sailing,5)*1.4) if sailing > 0 else 0.0
	gain = move_toward(gain,target,delta*.35)
	if gain > .001:
		if not water.playing: water.play()
		water.volume_db = linear_to_db(gain)
	else:
		water.stop()
		water.volume_db = -80

func reset():
	for key in impact_cooldowns: impact_cooldowns[key] = 0
	gain = 0
	if water: water.stop(); water.volume_db = -80
	for voice in voices: voice.stop()

func _exit_tree():
	reset()
	if water: water.stream = null
	for voice in voices: voice.stream = null

func specialty_name(family: int, branch: int) -> String:
	return [['rapid','heavy'],['scatter','siege'],['flame','oil']][family][branch-1]

func specialty_weapon(family: int, branch: int, tier: int):
	if branch == 0:
		if family == 2: play('oil_release',-16)
		else: weapon([1,4,7][family])
		return
	play(specialty_name(family,branch)+'_release',(-13 if family == 0 else -14)+maxi(0,tier-2)*1.4,clampf(1.0-(tier-3)*0.025,0.94,1.05))

func specialty_impact(family: int, branch: int, sunk: bool, tier: int = 3):
	if branch == 0:
		if family == 2: play('oil_hit',-14)
		else: impact([1,4,7][family],sunk); return
	else:
		var key = specialty_name(family,branch)+'_hit'
		if impact_cooldowns[key] <= 0:
			play(key,(-11 if family == 0 else -12)+maxi(0,tier-2)*1.5)
			if tier >= 3:
				if family == 0 and branch == 2: play('hull_hit',-18+(tier-3),0.76)
				elif family == 1: play('stone_hit',-18+(tier-3),0.78 if branch == 2 else 1.12)
				elif family == 2 and branch == 1: play('firepot',-19+(tier-3),0.82)
				elif family == 2: play('oil_hit',-21+(tier-3),0.76)
			impact_cooldowns[key] = 0.06
			if enabled: events.hull_hit += 1
	if sunk: play('water_hit',-19)
