extends Node2D

const GOLD = Color('#f3c34f')
const INK = Color('#101821')
const WHITE = Color('#e6edf0')
const TYPES = ['walker','runner','worker','armored','brute','exploder']
var font: Font = ThemeDB.fallback_font
var bold: Font = ThemeDB.fallback_font
var slots: Array[int] = [1,1,0,0,0,1,1,0,0,0,0,0,0,0,0]
var cooldown: Array[float] = [0.0,0.0,0.0,0.0,0.0]
var enemies: Array = []
var shots: Array = []
var particles: Array = []
var decals: Array = []
var coins = 100
var health = 420.0
var max_health = 420.0
var wave = 0
var remaining = 0
var killed = 0
var spawn_time = 0.0
var next_time = 0.0
var clock = 0.0
var grenade_cd = 0.0
var over_cd = 0.0
var over_time = 0.0
var active = false
var paused = false
var menu = true
var workshop = false
var aim_grenade = false
var selected = -1
var drag = -1
var press = Vector2.ZERO
var pointer = Vector2.ZERO
var speed = 1.0
var toast = ''
var toast_time = 0.0
var shake = 0.0
var music: AudioStreamPlayer
var sounds = {}
var muted = false
var best = 0
var best_before_test = 0
var upgrades = [0,0,0]
var demo = false
var testing = false
var focused: Dictionary = {}
var first_kill_x = -1.0
var offscreen_kills = 0

func _ready():
	randomize()
	load_assets('res://assets/audio/harbor/ui')
	bold = load('res://assets/fonts/Bungee-Regular.ttf')
	font = load('res://assets/fonts/BarlowCondensed-SemiBold.ttf')
	var save = ConfigFile.new()
	if save.load('user://progress.cfg') == OK: best = int(save.get_value('progress','best',0))
	music = AudioStreamPlayer.new()
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(music)
	music.volume_db = -22
	if uses_music() and sounds.has('music_prep'): music.stream = sounds.music_prep; music.play()
	if '--demo' in OS.get_cmdline_user_args():
		start_game()
		slots = [2,3,4,4,5,1,1,2,2,3,0,4,0,0,0]
		coins = 1263
		wave = 3
		call_wave()
		for i in 20: spawn_enemy(float(i)*0.07, Vector2(randf_range(80,850),randf_range(210,745)))
		demo = true
	if '--balance-preview' in OS.get_cmdline_user_args():
		start_game()
		call_wave()
	if '--balance-test' in OS.get_cmdline_user_args(): balance_test.call_deferred()
	if '--self-test' in OS.get_cmdline_user_args(): self_test.call_deferred()
	if '--capture' in OS.get_cmdline_user_args(): capture.call_deferred()
	if '--integration-test' in OS.get_cmdline_user_args():
		best_before_test = best
		integration_test.call_deferred()

func uses_music() -> bool:
	return true

func load_assets(_path: String):
	for key in ['ui_buy','ui_merge','ui_upgrade','ui_invalid','wave_start','wave_clear','defeat','ui_discover','explosion_small']:
		sounds[key] = load('res://assets/audio/harbor/ui/'+key+'.wav')

func set_music(key: String):
	if testing or not sounds.has(key): return
	if music.stream != sounds[key]:
		music.stop()
		music.stream = sounds[key]
		music.play()

func sfx(key: String, volume = -14.0):
	if muted or not sounds.has(key): return
	var p = AudioStreamPlayer.new()
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(p)
	p.stream = sounds[key]
	p.volume_db = volume
	p.pitch_scale = randf_range(0.96,1.04)
	p.finished.connect(p.queue_free)
	p.play()

func text_at(s: String, p: Vector2, size = 20, color = WHITE, heavy = false):
	draw_string(bold if heavy else font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func panel(r: Rect2, color = Color('#202e3b'), border = Color('#566879'), radius = 8):
	var st = StyleBoxFlat.new()
	st.bg_color = color
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(radius)
	st.shadow_color = Color(0,0,0,0.35)
	st.shadow_size = 5
	st.shadow_offset = Vector2(0,4)
	draw_style_box(st,r)

func button(r: Rect2, label: String, sub = '', gold = false, key = ''):
	var hovered = r.has_point(pointer)
	panel(r,Color('#e2ae39') if gold else Color('#293c4c') if hovered else Color('#1c2c3b'),GOLD if gold else Color('#536b7d'))
	if gold: draw_line(r.position+Vector2(6,5),r.position+Vector2(r.size.x-6,5),Color('#ffe794'),2)
	text_at(label,r.position+Vector2(16,25),20,INK if gold else WHITE)
	if sub != '': text_at(sub,r.position+Vector2(16,49),15,Color('#493b20') if gold else Color('#95b7ca'))
	if key != '': text_at(key,r.position+Vector2(r.size.x-22,20),12,INK if gold else Color('#9daebe'),true)

func slot_rect(i: int) -> Rect2:
	var c = 0 if i < 5 else 1+(i-5)%2
	var r = i if i < 5 else (i-5)/2
	return Rect2(1156+c*146,111+r*141,129,129)

func slot_at(p: Vector2) -> int:
	for i in 15:
		if slot_rect(i).has_point(p): return i
	return -1

func start_game():
	menu = false
	paused = false
	workshop = false
	health = 420
	max_health = 420
	coins = 100
	wave = 0
	killed = 0
	enemies.clear(); particles.clear(); shots.clear(); decals.clear()
	slots = [1,1,0,0,0,1,1,0,0,0,0,0,0,0,0]
	upgrades = [0,0,0]
	cooldown = [0.0,0.0,0.0,0.0,0.0]
	over_time = 0
	selected = -1
	drag = -1
	aim_grenade = false
	first_kill_x = -1
	offscreen_kills = 0
	focused = {}
	active = false
	next_time = 8.0
	grenade_cd = 0
	over_cd = 0
	toast_msg('BUILD • MERGE • PROTECT THE HARBOR')

func toast_msg(s: String):
	toast = s
	toast_time = 2.6

func build_tower():
	var price = 12+upgrades[2]*8
	if coins < price: toast_msg('NOT ENOUGH COINS'); sfx('ui_invalid'); return
	for i in range(5,15):
		if slots[i] == 0:
			slots[i] = 1+upgrades[2]
			coins -= price
			sfx('ui_buy')
			burst(slot_rect(i).get_center(),GOLD,14)
			return
	toast_msg('WORKSHOP FULL — MERGE MATCHING TURRETS')
	sfx('ui_invalid')

func move_tower(a: int, b: int):
	if a == b or a < 0 or b < 0 or slots[a] == 0: return
	if slots[a] == slots[b] and slots[a] < 12:
		slots[b] += 1
		slots[a] = 0
		burst(slot_rect(b).get_center(),GOLD,28)
		sfx('ui_merge')
		toast_msg('MERGED!  LEVEL '+str(slots[b]))
	else:
		var tmp = slots[b]; slots[b] = slots[a]; slots[a] = tmp
		sfx('ui_drop')
	selected = -1

func call_wave():
	if active or health <= 0: return
	wave += 1
	remaining = 7+wave*3
	spawn_time = 0.5
	active = true
	next_time = 0
	sfx('wave_start')
	set_music('music_boss' if wave%10 == 0 else 'music_wave1' if wave < 11 else 'music_wave2')
	toast_msg(('BOSS INCOMING — ' if wave%10 == 0 else 'WAVE ')+str(wave))
	if wave%10 == 0:
		spawn_enemy(0,Vector2(-100,450),true)
		shake = 10

func spawn_enemy(_offset = 0.0, pos = Vector2(-70,0), boss = false):
	var kind = TYPES[randi_range(0,mini(5,wave/3))]
	if boss: kind = ['demolisher','matriarch','colossus'][mini(2,wave/10-1)]
	if pos.y == 0: pos.y = randf_range(205,745)
	var hp = (42.0+wave*14+wave*wave*3.0)*({'walker':1.0,'runner':0.65,'worker':1.25,'armored':2.1,'brute':3.2,'exploder':1.0}.get(kind,25.0))
	enemies.append({'p':pos,'kind':kind,'hp':hp,'max':hp,'speed':randf_range(51,63)*(1.6 if kind == 'runner' else 0.7 if boss else 1.0)*(1+minf(wave,30)*0.012),'phase':randf()*TAU,'hit':0.0,'attack':0.0,'boss':boss})

func burst(pos: Vector2, color: Color, count: int):
	for i in count:
		particles.append({'p':pos,'v':Vector2.from_angle(randf()*TAU)*randf_range(50,240),'life':randf_range(0.25,0.65),'color':color,'size':randf_range(2,7)})

func hit_enemy(e: Dictionary, damage: float, _weapon_level: int = 0):
	var before: float = maxf(0,e.hp)
	e.hp -= damage
	damage_feedback(e,minf(before,damage),before)
	e.hit = 0.1
	burst(e.p+Vector2(8,-48),Color('#859d30'),4)
	if e.hp <= 0:
		if first_kill_x < 0: first_kill_x = e.p.x
		if e.p.x < 0: offscreen_kills += 1
		coins += (100 if e.boss else 4+wave/3)
		killed += 1
		decals.append({'p':e.p,'kind':e.kind,'phase':e.phase,'time':14.0})
		burst(e.p+Vector2(0,-35),Color('#75972e'),12)
		if e.boss: sfx('boss_death'); shake = 16; toast_msg('BOSS DEFEATED  +100')
		elif killed%4 == 0: sfx('splat',-22)

func throw_grenade(p: Vector2):
	if grenade_cd > 0: return
	grenade_cd = maxf(8,20-upgrades[1]*3)
	aim_grenade = false
	shake = 16
	burst(p,Color('#ffcd66'),75)
	particles.append({'p':p,'v':Vector2.ZERO,'life':0.5,'color':Color('#ffaf34'),'size':150.0})
	for e in enemies:
		if e.p.distance_to(p+Vector2(0,30)) < 190: hit_enemy(e,170+wave*12)
	sfx('explosion')

func overdrive():
	if over_cd > 0: return
	over_time = 7
	over_cd = 32
	sfx('overdrive')
	toast_msg('RALLY HORN — FIRE RATE × 3')

func can_target(e: Dictionary, i: int) -> bool:
	# Both normal targeting and player focus obey visibility and weapon range.
	if e.get('hp',0) <= 0 or e.p.x < 48 or e.p.x > 1060: return false
	var muzzle = slot_rect(i).get_center()+Vector2(-50,0)
	var reach = 680.0+minf(6,slots[i]-1)*12.0
	return muzzle.distance_to(e.p+Vector2(6,-50)) <= reach

func acquire_target(i: int):
	if not focused.is_empty() and can_target(focused,i): return focused
	var target = null
	var nearest = INF
	for e in enemies:
		if not can_target(e,i): continue
		var distance_ = e.p.distance_to(slot_rect(i).get_center())
		if distance_ < nearest:
			nearest = distance_
			target = e
	return target

func _process(delta):
	pointer = get_global_mouse_position()
	var dt = minf(delta,0.05)*speed
	clock += delta
	toast_time = maxf(0,toast_time-delta)
	shake = maxf(0,shake-delta*35)
	if not menu and not paused and not workshop and health > 0:
		grenade_cd = maxf(0,grenade_cd-dt)
		over_cd = maxf(0,over_cd-dt)
		over_time = maxf(0,over_time-dt)
		if active:
			spawn_time -= dt
			if remaining > 0 and spawn_time <= 0:
				spawn_enemy()
				remaining -= 1
				spawn_time = fleet_spawn_interval()
			if remaining == 0 and enemies.is_empty():
				active = false
				next_time = 9
				coins += 24+wave*3
				health = minf(max_health,health+10)
				best = maxi(best,wave)
				var save = ConfigFile.new(); save.set_value('progress','best',best); save.save('user://test-progress.cfg' if testing else 'user://progress.cfg')
				toast_msg('WAVE CLEARED  +'+str(24+wave*3))
				sfx('wave_clear')
				set_music('music_prep')
		else:
			next_time -= dt
			if next_time <= 0: call_wave()
		for e in enemies:
			if e.hp <= 0: continue
			e.phase += dt*5
			e.hit = maxf(0,e.hit-dt)
			advance_enemy(e,dt)
		for i in 5:
			cooldown[i] -= dt
			if slots[i] == 0 or cooldown[i] > 0: continue
			var target = acquire_target(i)
			if target != null:
				fire_tower(i,target)
		enemies = enemies.filter(func(e): return e.hp > 0)
		if health <= 0: sfx('defeat'); active = false
	for sh in shots:
		if not (paused or workshop): sh.life -= dt
	shots = shots.filter(func(sh): return sh.life > 0)
	for p in particles:
		p.life -= dt
		p.p += p.v*dt
		p.v *= maxf(0,1-dt*4)
	particles = particles.filter(func(p): return p.life > 0)
	for d in decals: d.time -= dt
	decals = decals.filter(func(d): return d.time > 0)
	if music.stream and not music.playing and not muted and not music.stream_paused: music.play()
	queue_redraw()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		var k = event.keycode
		if k == KEY_ESCAPE or k == KEY_P:
			if aim_grenade: aim_grenade = false
			elif workshop: workshop = false
			elif not menu: paused = not paused
			return
		if menu:
			if k == KEY_ENTER or k == KEY_SPACE: start_game()
			return
		if k == KEY_U: workshop = not workshop; return
		if paused or workshop: return
		match k:
			KEY_B: build_tower()
			KEY_G: aim_grenade = grenade_cd <= 0
			KEY_O: overdrive()
			KEY_SPACE,KEY_ENTER: call_wave()
			KEY_1: speed = 1
			KEY_2: speed = 2
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if event.pressed:
			if menu:
				if Rect2(595,425,410,73).has_point(p): start_game()
				return
			if health <= 0: start_game(); return
			if workshop:
				for i in 3:
					if Rect2(449,329+i*91,700,73).has_point(p):
						var cost = 60+upgrades[i]*60
						if coins >= cost and upgrades[i] < 5:
							coins -= cost; upgrades[i] += 1; sfx('ui_upgrade')
				return
			if Rect2(1538,8,44,43).has_point(p): paused = not paused; return
			if paused: paused = false; return
			if aim_grenade:
				if p.x < 1060 and p.y > 60 and p.y < 820: throw_grenade(p)
				return
			if p.y >= 832:
				if p.x < 176: build_tower()
				elif p.x < 320: aim_grenade = grenade_cd <= 0
				elif p.x < 480: overdrive()
				elif p.x < 633: workshop = true
				elif p.x > 1515: speed = 2 if speed == 1 else 1
				elif p.x > 1440:
					muted = not muted; music.volume_db = -80 if muted else -22
				elif not active: call_wave()
				return
			var idx = slot_at(p)
			if idx >= 0:
				if selected >= 0 and idx != selected: move_tower(selected,idx)
				elif slots[idx] > 0: drag = idx; press = p; sfx('ui_pick',-20)
			elif p.x < 1060:
				for e in enemies:
					if (e.p+Vector2(0,-55)).distance_to(p) < 60:
						focused = e; burst(p,GOLD,5); break
		elif drag >= 0:
			var idx = slot_at(p)
			if idx >= 0 and idx != drag: move_tower(drag,idx)
			elif p.distance_to(press) < 12: selected = drag if selected != drag else -1
			drag = -1

func self_test():
	testing = true
	muted = true
	music.stop()
	music.stream = null
	start_game()
	assert(ResourceLoader.exists('res://assets/harbor/ships-q.png'))
	assert(sounds.has('ui_buy'))
	coins = 500
	slots[5] = 1; slots[6] = 1
	move_tower(5,6)
	assert(slots[5] == 0 and slots[6] == 2)
	move_tower(6,2)
	assert(slots[2] == 2 and slots[6] == 0)
	build_tower()
	assert(slots[5] == 1 and coins == 488)
	call_wave()
	assert(wave == 1 and active and remaining == 10)
	spawn_enemy(0,Vector2(400,400))
	var e = enemies.back()
	hit_enemy(e,99999)
	assert(e.hp <= 0 and killed == 1)
	enemies.clear()
	spawn_enemy(0,Vector2(500,400))
	throw_grenade(Vector2(500,365))
	call('update_stone_rain',0.7)
	assert(grenade_cd > 0 and enemies.back().hp <= 0)
	overdrive()
	assert(over_time == 7 and over_cd == 32)
	wave = 9; active = false; call_wave()
	assert(enemies.back().boss and wave == 10)
	print('PASS: assets, merge, deploy, build, wave, damage, reward, grenade, overdrive and boss')
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func capture():
	await get_tree().create_timer(12.0 if '--balance-preview' in OS.get_cmdline_user_args() else 1.2).timeout
	await RenderingServer.frame_post_draw
	var name_ = 'balance-gameplay' if '--balance-preview' in OS.get_cmdline_user_args() else 'gameplay' if not menu else 'menu'
	get_viewport().get_texture().get_image().save_png('res://captures/'+name_+'.png')
	print('CAPTURE: '+name_)
	get_tree().quit()

func _exit_tree():
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null

func input_click(pos: Vector2):
	for down in [true,false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pos
		event.pressed = down
		_unhandled_input(event)

func integration_test():
	seed(70421)
	testing = true
	muted = true
	music.stop()
	if menu: input_click(Vector2(700,450))
	assert(not menu)
	input_click(slot_rect(5).get_center())
	input_click(slot_rect(6).get_center())
	assert(slots[6] == 2 and slots[5] == 0)
	input_click(slot_rect(6).get_center())
	input_click(slot_rect(2).get_center())
	assert(slots[2] == 2 and slots[6] == 0)
	input_click(Vector2(80,850))
	assert(coins == 88 and slots[5] == 1)
	input_click(workshop_button_position())
	assert(workshop)
	input_click(Vector2(700,350))
	assert(upgrades[0] == 1 and coins == 28)
	workshop = false
	setup_campaign_test()
	var cleared_wave = 0
	var defeated_wave = 0
	for w in range(1,31):
		call_wave()
		assert(wave == w)
		var ticks = 0
		while active and health > 0 and ticks < 6000:
			campaign_test_actions()
			_process(0.05)
			ticks += 1
		print('WAVE CHECK ',w,' hp=',health,' ticks=',ticks,' enemies=',enemies.size(),' remaining=',remaining)
		if health <= 0:
			defeated_wave = w
			assert(w >= 20, 'Max-tier autoplay must reach late waves')
			break
		assert(not active, 'Campaign stalled at wave '+str(w))
		cleared_wave = w
	var cfg = ConfigFile.new()
	assert(cfg.load('user://test-progress.cfg') == OK)
	assert(int(cfg.get_value('progress','best',0)) >= cleared_wave)
	if defeated_wave > 0:
		print('AUTOPLAY DEFEATED wave=',defeated_wave,'; cleared=',cleared_wave)
		start_game()
		assert(health == max_health and enemies.is_empty())
		wave = 30
	call_wave()
	assert(wave == 31 and active)
	print('PASS: endless entry, merge, build, upgrades, late-wave combat, defeat/reset if needed, wave-31 entry and save readback')
	# Do not keep a test completion as the real player record.
	cfg.set_value('progress','best',best_before_test)
	cfg.save('user://test-progress.cfg')
	get_tree().quit()

func balance_test():
	var previous_best = best
	testing = true
	muted = true
	music.stop()
	music.stream = null
	seed(70421)
	start_game()
	wave = 0
	call_wave()
	spawn_enemy(0,Vector2(-30,400))
	var hidden = enemies.back()
	focused = hidden
	for i in 5: assert(not can_target(hidden,i))
	hidden.p = Vector2(100,400)
	for i in 5: assert(not can_target(hidden,i))
	enemies.clear()
	focused = {}
	var peak = 0
	for tick in 1600:
		_process(0.05)
		peak = maxi(peak,enemies.size())
		if not active or health <= 0: break
	assert(first_kill_x > 450 and offscreen_kills == 0)
	assert(peak >= 5)
	print('WAVE 1: first kill x=',first_kill_x,' peak alive=',peak,' wall=',health)
	start_game()
	slots = [1,1,1,1,1,0,0,0,0,0,0,0,0,0,0]
	wave = 4
	call_wave()
	for tick in 2400:
		_process(0.05)
		if not active or health <= 0: break
	assert(health < max_health, 'Unupgraded defense must face wall pressure by wave 5')
	assert(offscreen_kills == 0)
	print('WAVE 5, five level-1 turrets: wall=',health,' remaining=',enemies.size())
	print('PASS: offscreen immunity, focus range, visible horde, and pressure without upgrades')
	var save = ConfigFile.new()
	save.set_value('progress','best',previous_best)
	save.save('user://test-progress.cfg' if testing else 'user://progress.cfg')
	get_tree().quit()

func fire_tower(i: int, target: Dictionary):
	var lv = slots[i]
	cooldown[i] = maxf(0.12,0.82-lv*0.045)/(3 if over_time > 0 else 1)
	var from = slot_rect(i).get_center()+Vector2(-50,0)
	var end = target.p+Vector2(6,-50)
	shots.append({'a':from,'b':end,'life':0.12,'level':lv})
	hit_enemy(target,(8+pow(1.65,lv)*4)*(1+upgrades[0]*0.18),lv)
	burst(from,Color('#ffdc75'),3)
	sfx('gun_light' if lv < 3 else 'gun_burst' if lv < 5 else 'cannon_heavy',-24)

func setup_campaign_test():
	slots = [12,12,12,12,12,0,0,0,0,0,0,0,0,0,0]

func campaign_test_actions():
	pass

func advance_enemy(e: Dictionary, dt: float):
	if e.p.x < 1040:
		e.p.x = minf(1040,e.p.x+e.speed*dt*e.get('slow_factor',1.0))
	else:
		e.attack -= dt
		if e.attack <= 0:
			health -= 30 if e.boss else 5
			e.attack = 1.3
			shake = 5
			sfx('wall_hit',-19)

func workshop_button_position() -> Vector2:
	return Vector2(540,850)

func damage_feedback(_enemy: Dictionary, _damage: float, _before: float):
	pass

func fleet_spawn_interval() -> float:
	return maxf(0.30,0.98-wave*0.022)
