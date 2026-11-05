extends "res://scripts/game.gd"

var sea_time = 0.0
var harbor_audio: Node
var tower_sheet: Texture2D
var ship_sheet: Texture2D
var harbor_bg: Texture2D
var bolts: Array = []
var pending_hits: Array = []
var recoil = [0.0,0.0,0.0,0.0,0.0]
var port_impacts: Array = []
var enemy_cannonballs: Array = []
var cannon_flashes: Array = []
var dock_hit = [0.0,0.0,0.0,0.0,0.0]

var water_color = Color('#51b7be')

func _ready():
	super._ready()
	if ResourceLoader.exists('res://assets/harbor/harbor-quay-q.png'): harbor_bg = load('res://assets/harbor/harbor-quay-q.png')
	if ResourceLoader.exists('res://assets/harbor/ships-q.png'): ship_sheet = load('res://assets/harbor/ships-q.png')
	if ResourceLoader.exists('res://assets/harbor/towers-q.png'): tower_sheet = load('res://assets/harbor/towers-q.png')
	music.stop()
	music.stream = load('res://assets/audio/harbor/little-harbor-bgm.wav')
	if music.stream is AudioStreamWAV:
		music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.stream.loop_begin = 0
		music.stream.loop_end = music.stream.data.size()/4
	music.volume_db = -40
	music.play()
	harbor_audio = preload('res://scripts/harbor_audio.gd').new()
	add_child(harbor_audio)
	if '--audio-test' in OS.get_cmdline_user_args(): audio_test.call_deferred()
	if '--audio-preview' in OS.get_cmdline_user_args(): audio_preview.call_deferred()
	DisplayServer.window_set_title('Little Harbor — Keep the Lighthouse')
	if '--harbor-test' in OS.get_cmdline_user_args(): harbor_test.call_deferred()

func uses_music() -> bool:
	return false

func set_music(_key: String):
	pass

func sfx(key: String, volume = -14.0):
	if key in ['gun_light','gun_burst','cannon_heavy','splat']: return
	if key == 'wall_hit' and harbor_audio:
		harbor_audio.play('hull_hit',-12)
		return
	if key in ['ui_drop','ui_pick'] and harbor_audio:
		harbor_audio.play('hull_hit',-24)
		return
	# Combat uses dedicated clips triggered by real projectiles and impacts.
	var mapping = {'boss_death':'wave_clear','overdrive':'ui_discover','explosion':'explosion_small'}
	if key.begins_with('zombie') or key.begins_with('vo_'): return
	super.sfx(mapping.get(key,key),volume-3)

func hit_enemy(e: Dictionary, damage: float, weapon_level: int = 0):
	if testing:
		super.hit_enemy(e,damage,weapon_level)
		return
	pending_hits.append({'enemy':e,'damage':damage,'time':0.36,'level':weapon_level})

func start_game():
	if harbor_audio: harbor_audio.reset()
	pending_hits.clear()
	bolts.clear()
	port_impacts.clear()
	enemy_cannonballs.clear()
	cannon_flashes.clear()
	dock_hit.fill(0.0)
	super.start_game()

func _process(delta):
	music.stream_paused = paused or workshop or muted or testing
	music.volume_db = move_toward(music.volume_db,-18.0 if active else -15.0,minf(delta,0.05)*18)
	if not paused and not workshop and health > 0:
		sea_time += delta
		if not menu: update_enemy_cannonballs(minf(delta,0.05)*speed)
		for i in 5: dock_hit[i] = maxf(0,dock_hit[i]-delta*speed*3)
		for effect in port_impacts: effect.t += minf(delta,0.05)*speed
		port_impacts = port_impacts.filter(func(effect): return effect.t < 0.9)
	for i in 5: recoil[i] = maxf(0,recoil[i]-delta*4)
	if not paused and not workshop and not menu:
		for h in pending_hits:
			h.time -= delta*speed
			if h.time <= 0 and h.enemy.hp > 0:
				resolve_projectile(h)
				if harbor_audio:
					if h.has('family'): harbor_audio.specialty_impact(h.family,h.branch,h.enemy.hp <= 0,h.get('tier',3))
					else: harbor_audio.impact(h.level,h.enemy.hp <= 0)
		pending_hits = pending_hits.filter(func(h): return h.time > 0)
	super._process(delta)
	if harbor_audio:
		var sailing = 0
		for enemy in enemies:
			if enemy.hp > 0 and enemy.p.x > 0 and enemy.p.x < port_anchor(enemy)+1: sailing += 1
		harbor_audio.update_state(delta,sailing,not (menu or paused or workshop or muted or testing or health <= 0))
	for sh in shots:
		sh.delay = sh.get('delay',0.0)-delta*speed if not (paused or workshop) else sh.get('delay',0.0)
		if not (paused or workshop) and not sh.has('launched') and sh.delay <= 0:
			sh.launched = true
			if harbor_audio:
				if sh.has('family'):
					if sh.get('index',0) == 0: harbor_audio.specialty_weapon(sh.family,sh.branch,sh.get('tier',1))
				else: harbor_audio.weapon(sh.level)
			var bolt = sh.duplicate()
			bolt.t = 0.0; bolt.lv = sh.level
			bolts.append(bolt)
			for i in 5:
				if absf(slot_rect(i).get_center().y-sh.a.y) < 5: recoil[i] = 1.0
	if not paused and not workshop:
		for b in bolts: b.t += delta*speed*2.8
	bolts = bolts.filter(func(b): return b.t < 1.0)

func panel(r: Rect2, _color = Color('#202e3b'), _border = Color('#566879'), radius = 16):
	var box = StyleBoxFlat.new()
	box.bg_color = Color('#fff0ce')
	box.border_color = Color('#ba9471')
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0.12,0.24,0.23,0.22)
	box.shadow_offset = Vector2(0,5)
	box.shadow_size = 5
	draw_style_box(box,r)
	draw_line(r.position+Vector2(8,7),r.position+Vector2(r.size.x-8,7),Color('#fff2d1'),2)

func button(r: Rect2, label: String, sub = '', gold = false, key = ''):
	panel(r)
	if gold: draw_style_box(button_style(Color('#f2c17e')),r.grow(-4))
	elif r.has_point(pointer): draw_style_box(button_style(Color('#fff0cf')),r.grow(-4))
	text_at(label,r.position+Vector2(14,25),20,Color('#3d4c47'))
	if sub != '': text_at(sub,r.position+Vector2(14,46),15,Color('#7e725b'))
	if key != '': text_at(key,r.position+Vector2(r.size.x-20,18),12,Color('#947049'))

func button_style(c: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(12); return s

func ellipse(p: Vector2, radii: Vector2, c: Color):
	draw_set_transform(p,0,radii)
	draw_circle(Vector2.ZERO,1,c)
	draw_set_transform(Vector2.ZERO)

func ocean():
	draw_rect(Rect2(0,0,1600,900),water_color)
	if harbor_bg: draw_texture_rect(harbor_bg,Rect2(0,0,1600,900),false)
	for i in 55:
		var p = Vector2(fmod(i*163.7+sea_time*7,1030),110+fmod(i*89.3,680))
		var a = 0.06+0.06*sin(sea_time*1.4+i)
		draw_arc(p,13+(i%5)*4,0.12,1.1,9,Color(0.9,1,0.94,a),1.5)
	# Five timber spurs meet the shoreline. Workshops stand on the landward side.
	for i in 5:
		var r = slot_rect(i)
		var p = Vector2(r.position.x+2+sin(dock_hit[i]*35)*dock_hit[i]*3,r.position.y+24)
		for support in [9,114]:
			draw_line(p+Vector2(support,72),p+Vector2(support,96),Color('#8b6444'),9,true)
		draw_rect(Rect2(p+Vector2(0,5),Vector2(125,86)),Color(0.14,0.3,0.27,0.22))
		draw_rect(Rect2(p,Vector2(125,86)),Color('#ac815b'))
		for j in 7:
			draw_rect(Rect2(p+Vector2(j*17+3,3),Vector2(16,80)),Color('#d4a576') if j%2 == 0 else Color('#dfb487'))
		for yy in [8,76]:
			draw_line(p+Vector2(1,yy),p+Vector2(124,yy),Color('#ab7b55'),5)
		for xx in [10,115]:
			for yy in [7,77]: draw_circle(p+Vector2(xx,yy),5,Color('#e6c08a'))

		if dock_hit[i] > 0:
			draw_rect(Rect2(p,Vector2(8,86)),Color(1.0,0.79,0.40,dock_hit[i]*0.7))

func tower(lv: int, center: Vector2, angle = PI, size_ = 1.0):
	var family = mini(2,(lv-1)/3)
	var tier = (lv-1)%3
	if tower_sheet:
		var cell = Vector2(tower_sheet.get_width()/3.0,tower_sheet.get_height())
		var extent = Vector2(117,110)*size_*(1+tier*0.035)
		draw_set_transform(center,clampf(wrapf(angle-PI,-PI,PI),-0.22,0.22))
		draw_texture_rect_region(tower_sheet,Rect2(-extent*Vector2(0.5,0.55),extent),Rect2(Vector2(family*cell.x,0),cell))
		draw_set_transform(Vector2.ZERO)
		return
	ellipse(center+Vector2(0,24),Vector2(42,19)*size_,Color(0.17,0.25,0.20,0.25))
	draw_set_transform(center,0,Vector2.ONE*size_)
	var base = PackedVector2Array([Vector2(-38,-8),Vector2(0,-25),Vector2(38,-8),Vector2(38,24),Vector2(0,41),Vector2(-38,24)])
	draw_colored_polygon(base,Color('#a39a7b'))
	draw_colored_polygon(PackedVector2Array([Vector2(-38,-8),Vector2(0,9),Vector2(0,41),Vector2(-38,24)]),Color('#b9af8c'))
	draw_colored_polygon(PackedVector2Array([Vector2(-38,-8),Vector2(0,-25),Vector2(38,-8),Vector2(0,9)]),Color('#f0ddb4'))
	for y in [9,23]: draw_line(Vector2(1,y),Vector2(36,y-16),Color('#827c66'),1)
	draw_set_transform(center,angle,Vector2.ONE*size_)
	draw_circle(Vector2.ZERO,26,Color('#76523a'))
	draw_circle(Vector2.ZERO,22,Color('#bf8e51'))
	if family == 0:
		draw_line(Vector2(-23,0),Vector2(40,0),Color('#584537'),12)
		draw_line(Vector2(-23,-2),Vector2(40,-2),Color('#d0a76b'),6)
		draw_polyline(PackedVector2Array([Vector2(13,-34-tier*3),Vector2(27,-22),Vector2(31,0),Vector2(27,22),Vector2(13,34+tier*3)]),Color('#765032'),7,true)
		draw_line(Vector2(13,-34-tier*3),Vector2(-11,0),Color('#eee2b6'),1.5)
		draw_line(Vector2(-11,0),Vector2(13,34+tier*3),Color('#eee2b6'),1.5)
		draw_line(Vector2(-16,0),Vector2(49,0),Color('#f0dfb9'),3)
		draw_colored_polygon(PackedVector2Array([Vector2(53,0),Vector2(42,-5),Vector2(42,5)]),Color('#71968d'))
	elif family == 1:
		for y in [-17,17]: draw_line(Vector2(-20,y),Vector2(27,y),Color('#674931'),9)
		draw_line(Vector2(-10,0),Vector2(32,-8),Color('#c7985d'),12)
		draw_circle(Vector2(34,-8),16,Color('#78543d'))
		draw_circle(Vector2(34,-8),11,Color('#aaa797'))
		draw_line(Vector2(-17,-22),Vector2(3,0),Color('#e5c68e'),5)
		draw_line(Vector2(-17,22),Vector2(3,0),Color('#e5c68e'),5)
	else:
		draw_rect(Rect2(-25,-22,48,44),Color('#a66a39'))
		for y in [-16,0,16]: draw_line(Vector2(-27,y),Vector2(26,y),Color('#624735'),4)
		for x in [-15,13]:
			draw_circle(Vector2(x,0),15,Color('#cf8854'))
			draw_circle(Vector2(x-3,-4),9,Color('#f1ba78'))
			draw_line(Vector2(x,-13),Vector2(x+6,-21),Color('#74583c'),3)
	draw_circle(Vector2(-9,-13),4,Color('#f2d491'))
	draw_set_transform(Vector2.ZERO)

func ship(e: Dictionary, sinking = 0.0):
	var pose = port_attack_pose(e) if sinking <= 0 else Vector2.ZERO
	var impact = e.get('impact_time',0.0)/0.24 if sinking <= 0 else 0.0
	var jolt = e.get('impact_strength',0.0)*impact
	var p: Vector2 = e.p+Vector2(pose.x-sin(impact*PI)*jolt,-45-sin(impact*PI)*jolt*0.25)
	var boss = e.get('boss',false)
	var variant = 3 if boss else 1 if e.kind == 'runner' else 2 if e.kind in ['armored','worker','brute'] else 0
	var size_ = Vector2(155,145)*(1.7 if boss else 0.82 if variant == 1 else 1.0)
	var bob = sin(sea_time*2.3+e.phase)*2.2
	if sinking <= 0:
		# Short low contact foam and tapering downstream wake.
		for j in 5:
			var tail = p+Vector2(-size_.x*0.32-j*15,12)
			var alpha = (1-j/5.0)*0.27
			draw_line(tail+Vector2(0,-7-j*2),tail+Vector2(-13,-9-j*2),Color(0.92,1,0.93,alpha),2)
			draw_line(tail+Vector2(0,7+j*2),tail+Vector2(-13,9+j*2),Color(0.92,1,0.93,alpha),2)
		ellipse(p+Vector2(0,18),Vector2(size_.x*0.36,13),Color(0.13,0.41,0.43,0.20))
	var tilt = sin(sea_time*1.6+e.phase)*0.025+sinking*0.7+pose.y+sin(impact*PI*2)*jolt*0.008
	draw_set_transform(p+Vector2(0,bob+sinking*16),tilt,Vector2(1,1-sinking*0.45))
	if ship_sheet:
		var cell = Vector2(ship_sheet.get_width()/2.0,ship_sheet.get_height()/2.0)
		var src = Rect2(Vector2(variant%2,variant/2)*cell,cell)
		draw_texture_rect_region(ship_sheet,Rect2(-size_*Vector2(0.5,0.7),size_),src,Color(1+impact*0.8,1+impact*0.65,1+impact*0.35,1-sinking))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-50,-5),Vector2(35,-5),Vector2(60,6),Vector2(28,27),Vector2(-40,22)]),Color('#a06a3e'))
		draw_line(Vector2(0,0),Vector2(0,-70),Color('#745139'),5)
		draw_colored_polygon(PackedVector2Array([Vector2(3,-66),Vector2(44,-22),Vector2(3,-17)]),Color('#fae6bb'))
	if sinking <= 0: draw_ship_cannons(e,size_)
	draw_set_transform(Vector2.ZERO)
	if sinking <= 0: draw_enemy_health(e,p,size_)

func _draw():
	if menu: draw_menu(); return
	ocean()
	draw_combat_ground()
	for d in decals:
		if d.time > 11: ship(d,clampf((14-d.time)/3,0,1))
		else:
			var p: Vector2 = d.p+Vector2(0,-30)
			for j in 3: draw_line(p+Vector2(j*13-15,sin(sea_time+j)*3),p+Vector2(j*13-5,4+sin(sea_time+j)*3),Color('#b79260'),4)
	for e in enemies: ship(e)
	for i in 15:
		var r = slot_rect(i)
		if i >= 5:
			panel(r)
			for j in range(1,5): draw_line(r.position+Vector2(8,j*24),r.position+Vector2(121,j*24),Color(0.55,0.38,0.23,0.13),1)
		if i == selected: draw_rect(r.grow(-2),Color('#f4c46f'),false,4)
		if slots[i] > 0 and i != drag:
			var a = PI
			if i < 5:
				var target = acquire_target(i)
				if target != null: a = (target.p+Vector2(0,-50)-r.get_center()).angle()
			tower(slots[i],r.get_center()+Vector2(recoil[i]*5 if i < 5 else 0,0),a)
			draw_circle(r.end-Vector2(19,18),15,Color('#e8bb68'))
			text_at(str(slots[i]),r.end-Vector2(25,11),19,Color('#634f36'),true)
		elif i >= 5: text_at('+',r.get_center()+Vector2(-7,8),25,Color('#b39b76'))
	draw_enemy_cannonballs()
	draw_port_impacts()
	for b in bolts: draw_tower_projectile(b)
	for p in particles:
		if p.size > 30:
			draw_arc(p.p,p.size*(1-p.life*1.5),0,TAU,32,Color(0.95,1,0.92,p.life),3)
		else: draw_circle(p.p,p.size*minf(1,p.life*3),Color(0.94,0.85,0.58,minf(1,p.life*3)))
	if aim_grenade:
		draw_circle(pointer,175,Color(1,0.95,0.7,0.14))
		draw_arc(pointer,175,0,TAU,64,Color('#fff0bd'),2)
	draw_hud()
	if drag >= 0 and slots[drag] > 0: tower(slots[drag],pointer,PI,1.1)
	if toast_time > 0:
		var w = font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x
		panel(Rect2(555-w/2-22,118,w+44,48))
		text_at(toast,Vector2(555-w/2,150),27,Color('#50634d'))
	if workshop: draw_workshop()
	if paused: draw_overlay('PAUSED','P / ESC to sail on')
	if health <= 0: draw_overlay('HARBOR OVERRUN','Click to rebuild your defenses')

func draw_menu():
	ocean()
	panel(Rect2(420,100,740,665))
	text_at('LITTLE',Vector2(660,204),40,Color('#447f7a'),true)
	text_at('HARBOR',Vector2(565,285),68,Color('#3c706b'),true)
	text_at('KEEP THE LIGHTHOUSE',Vector2(617,331),24,Color('#ab7c45'))
	for i in 3: tower(i*3+1,Vector2(650+i*145,379),-2.6,0.62)
	button(Rect2(595,425,410,73),'ENDLESS VOYAGE  ›','DEFEND THE HARBOR • BEAT YOUR RECORD',true)
	text_at('BEST WAVE  '+str(best),Vector2(711,601),18,Color('#70856b'))
	text_at('A flagship arrives every 10 waves',Vector2(636,553),23,Color('#70856b'))
	text_at('Merge matching towers • Deploy on the five piers',Vector2(585,678),21,Color('#6d775f'))
	text_at('Q / W / E Build    G Stone rain    O Rally horn',Vector2(634,714),19,Color('#8d876b'))

func draw_hud():
	panel(Rect2(-5,-8,1610,66))
	text_at('WAVE  '+str(wave)+' / ∞',Vector2(22,35),21,Color('#4a7065'),true)
	text_at(str(enemies.size()+remaining)+' sails on the horizon' if active else 'Prepare the harbor',Vector2(245,34),21,Color('#7a8267'))
	draw_circle(Vector2(1148,28),12,Color('#e4ad49'))
	text_at(str(coins),Vector2(1170,39),27,Color('#6f5835'),true)
	draw_rect(Rect2(1305,18,210,20),Color('#bbc0a0'))
	draw_rect(Rect2(1308,21,204*maxf(0,health/max_health),14),Color('#7ca38a'))
	text_at(str(maxi(0,int(health)))+' / '+str(int(max_health)),Vector2(1367,34),15,Color('#fff3d2'))
	draw_pause_button()
	panel(Rect2(-5,820,1610,85))
	button(Rect2(18,834,155,52),'BUILD  '+str(12+upgrades[2]*8),'TIER '+str(1+upgrades[2]),true,'B')
	button(Rect2(186,834,130,52),'STONE RAIN','Ready' if grenade_cd <= 0 else str(int(ceil(grenade_cd)))+'s',false,'G')
	button(Rect2(329,834,146,52),'RALLY HORN','Ready' if over_cd <= 0 else str(int(ceil(over_cd)))+'s',false,'O')
	button(Rect2(488,834,142,52),'WORKSHOP','Harbor upgrades',false,'U')
	if not active: button(Rect2(664,834,226,52),'NEXT FLEET  ›',str(maxi(0,int(ceil(next_time))))+'s • SPACE',true)
	else: text_at('Guard the five piers',Vector2(675,866),21,Color('#75816a'))
	draw_sound_button()
	button(Rect2(1520,834,62,52),str(int(speed))+'×')

func draw_overlay(title: String, sub: String):
	draw_rect(Rect2(0,0,1600,900),Color(0.1,0.3,0.31,0.65))
	panel(Rect2(420,315,760,240))
	text_at(title,Vector2(467,410),39,Color('#477970'),true)
	text_at(sub,Vector2(490,473),25,Color('#897958'))

func draw_workshop():
	draw_rect(Rect2(0,0,1600,900),Color(0.1,0.3,0.31,0.65))
	panel(Rect2(410,200,780,490))
	text_at('HARBOR WORKSHOP',Vector2(450,258),34,Color('#477970'),true)
	text_at('Prepare your defenses for the next fleet',Vector2(450,294),22,Color('#897958'))
	for i in 3:
		var cost = 60+upgrades[i]*60
		button(Rect2(449,329+i*91,700,73),['TOWER DAMAGE  +18%','STONE RAIN COOLDOWN  -3s','BUILD TIER  +1'][i]+'    Lv.'+str(upgrades[i]),str(cost)+' GOLD • UPGRADE',coins >= cost)
	text_at('U / ESC to return to the harbor',Vector2(631,659),20,Color('#897958'))

func harbor_test():
	muted = true
	start_game()
	slots.fill(0)
	active = true
	remaining = 0
	spawn_enemy(0,Vector2(650,450))
	var enemy = enemies.back()
	var before: float = enemy.hp
	hit_enemy(enemy,99999)
	assert(enemy.hp == before)
	paused = true
	_process(0.05)
	assert(pending_hits.size() == 1 and enemy.hp == before)
	paused = false
	for i in 8: _process(0.05)
	assert(enemy.hp <= 0 and pending_hits.is_empty())
	spawn_enemy(0,Vector2(650,450))
	hit_enemy(enemies.back(),9999)
	start_game()
	assert(pending_hits.is_empty() and bolts.is_empty())
	assert(harbor_bg != null and ship_sheet != null and tower_sheet != null)
	print('PASS: harbor assets, delayed impact, pause, sinking event and restart cancellation')
	get_tree().quit()

func audio_test():
	set_process(false)
	harbor_audio.update_state(.1,0,true)
	assert(not harbor_audio.water.playing)
	harbor_audio.update_state(.5,3,true)
	assert(harbor_audio.water.playing and harbor_audio.water.pitch_scale == 1.0)
	harbor_audio.weapon(1)
	harbor_audio.weapon(4)
	harbor_audio.weapon(7)
	assert(harbor_audio.voices[0].playing and harbor_audio.voices[1].playing and harbor_audio.voices[2].playing)
	harbor_audio.impact(1,true)
	harbor_audio.impact(4,false)
	assert(harbor_audio.events.arrow_hit == 1 and harbor_audio.events.stone_hit == 1)
	assert(harbor_audio.events.water_hit == 1)
	for i in 20: harbor_audio.update_state(.05,0,true)
	assert(not harbor_audio.water.playing)
	harbor_audio.update_state(.5,5,true)
	harbor_audio.update_state(.01,5,false)
	assert(not harbor_audio.water.playing)
	for voice in harbor_audio.voices: assert(not voice.playing)
	harbor_audio.update_state(.5,2,true)
	start_game()
	assert(not harbor_audio.water.playing)
	print('PASS: audio clips, sailing lifecycle, concurrent weapon impacts, lethal-hit layering and restart cleanup')
	harbor_audio.queue_free()
	harbor_audio = null
	await get_tree().create_timer(.3).timeout
	get_tree().quit()

func audio_preview():
	var record = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0,record)
	record.set_recording_active(true)
	start_game()
	slots = [1,4,7,2,5,1,1,0,0,0,0,0,0,0,0]
	wave = 4
	call_wave()
	for i in 10: spawn_enemy(0,Vector2(160+i*64,230+(i%5)*110))
	await get_tree().create_timer(8.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png('res://captures/audio-gameplay.png')
	paused = true
	await get_tree().create_timer(.5).timeout
	record.set_recording_active(false)
	var recording = record.get_recording()
	recording.save_to_wav('res://captures/harbor-audio-preview.wav')
	print('AUDIO PREVIEW: ',harbor_audio.events)
	assert(harbor_audio.events.ballista > 0 and harbor_audio.events.catapult > 0 and harbor_audio.events.firepot > 0)
	assert(harbor_audio.events.hull_hit > 0)
	assert(harbor_audio.events.arrow_hit > 0 and harbor_audio.events.stone_hit > 0)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	get_tree().quit()

func resolve_projectile(h: Dictionary):
	super.hit_enemy(h.enemy,h.damage)

func direct_damage(e: Dictionary, damage: float):
	if e.hp > 0: super.hit_enemy(e,damage)

# Ships anchor offshore. Firing and projectile impact are separate events.
func port_anchor(e: Dictionary) -> float:
	return 835.0 if e.get('boss',false) else 925.0 if e.kind == 'runner' else 905.0

func port_fire_time(e: Dictionary) -> float:
	return 0.64 if e.get('boss',false) else 0.48

func port_cycle_time(e: Dictionary) -> float:
	return 1.65 if e.get('boss',false) else 1.3

func advance_enemy(e: Dictionary, dt: float):
	var anchor = port_anchor(e)
	if not e.has('dock'):
		e.dock = clampi(roundi((e.p.y-35-175.5)/141.0),0,4)
	if e.p.x < anchor:
		e.p.x = minf(anchor,e.p.x+e.speed*dt*e.get('slow_factor',1.0))
		if e.p.x > 700:
			e.p.y = move_toward(e.p.y,slot_rect(e.dock).get_center().y+35,dt*45)
		return
	var target_y = slot_rect(e.dock).get_center().y+35
	e.p.y = move_toward(e.p.y,target_y,dt*45)
	if absf(e.p.y-target_y) > 1: return
	# Dropping anchor takes the travel time removed by stopping offshore.
	# Keep the first harbor hit comparable to the previous close approach.
	if not e.has('anchor_timer'):
		var former_anchor = 931.0 if e.boss else 996.0 if e.kind == 'runner' else 982.0
		e.anchor_timer = (former_anchor-anchor)/maxf(1,e.speed*e.get('slow_factor',1.0))
	if e.anchor_timer > 0:
		e.anchor_timer = maxf(0,e.anchor_timer-dt)
		return
	e.shot_age = e.get('shot_age',10.0)+dt
	var before = e.get('cannon_time',0.0)
	e.cannon_time = before+dt
	for gun in (3 if e.boss else 1):
		var fire_at = port_fire_time(e)+gun*0.18
		if before < fire_at and e.cannon_time >= fire_at: fire_ship_cannon(e,gun)
	if e.cannon_time >= port_cycle_time(e): e.cannon_time -= port_cycle_time(e)

func port_attack_pose(e: Dictionary) -> Vector2:
	var age: float = e.get('shot_age',10.0)
	var strength = 1.35 if e.get('boss',false) else 1.0
	if age >= 0.4: return Vector2.ZERO
	var recovery = 1.0-smoothstep(0.0,0.4,age)
	return Vector2(-10*strength*recovery,-0.045*recovery)

func cannon_local(e: Dictionary, gun: int) -> Vector2:
	var scale_ = 1.7 if e.get('boss',false) else 0.82 if e.kind == 'runner' else 1.0
	return Vector2(155*scale_*0.14,-7+(gun-1)*15 if e.get('boss',false) else -4)

func fire_ship_cannon(e: Dictionary, gun: int):
	var pose = port_attack_pose(e)
	var tilt = sin(sea_time*1.6+e.phase)*0.025+pose.y
	var origin: Vector2 = e.p+Vector2(pose.x,-45+sin(sea_time*2.3+e.phase)*2.2)+(cannon_local(e,gun)+Vector2(31,0)).rotated(tilt)
	var target = Vector2(slot_rect(e.dock).position.x+5,slot_rect(e.dock).get_center().y+(gun-1)*12 if e.boss else slot_rect(e.dock).get_center().y)
	enemy_cannonballs.append({'a':origin,'b':target,'t':0.0,'duration':0.5 if e.boss else 0.42,'damage':10 if e.boss else 5,'dock':e.dock,'boss':e.boss})
	cannon_flashes.append({'p':origin,'t':0.0,'boss':e.boss})
	e.shot_age = 0.0
	if not testing and harbor_audio: harbor_audio.play('ship_cannon',-15 if e.boss else -18)

func update_enemy_cannonballs(dt: float):
	for flash in cannon_flashes: flash.t += dt
	cannon_flashes = cannon_flashes.filter(func(f): return f.t < 0.7)
	for ball in enemy_cannonballs:
		ball.t += dt
		if ball.t >= ball.duration:
			health = maxf(0,health-ball.damage)
			dock_hit[ball.dock] = 1.0
			port_impacts.append({'p':ball.b,'t':0.0,'damage':ball.damage,'boss':ball.boss})
			if not testing and harbor_audio:
				harbor_audio.play('stone_hit',-16)
				harbor_audio.play('hull_hit',-16)
	enemy_cannonballs = enemy_cannonballs.filter(func(ball): return ball.t < ball.duration)

func draw_ship_cannons(e: Dictionary, _size: Vector2):
	for gun in (3 if e.get('boss',false) else 1):
		var p = cannon_local(e,gun)
		# Rounded dark barrel and brass collar, mounted on a little timber carriage.
		draw_line(p+Vector2(-6,6),p+Vector2(18,6),Color('#81543b'),9,true)
		draw_circle(p+Vector2(0,9),4,Color('#543b30'))
		draw_circle(p+Vector2(15,9),4,Color('#543b30'))
		draw_line(p,p+Vector2(27,0),Color('#364c50'),12,true)
		draw_line(p+Vector2(2,-3),p+Vector2(24,-3),Color('#78928c'),3,true)
		draw_line(p+Vector2(20,-6),p+Vector2(20,6),Color('#d5ac66'),4,true)
		draw_circle(p+Vector2(29,0),7,Color('#596c66'))
		draw_circle(p+Vector2(31,0),4,Color('#233b40'))
		var until = port_fire_time(e)+gun*0.18-e.get('cannon_time',-10.0)
		if until > 0 and until < 0.22:
			draw_circle(p+Vector2(-5,-7),2.5,Color('#ffcc74'))

func draw_enemy_cannonballs():
	for flash in cannon_flashes:
		var t: float = flash.t
		var p: Vector2 = flash.p
		if t < 0.1:
			var f = 1.0-t/0.1
			ellipse(p+Vector2(11,0),Vector2(24,13)*f,Color('#f0a25e'))
			ellipse(p+Vector2(7,0),Vector2(17,8)*f,Color('#fff2ba'))
		for n in 4:
			var q = p+Vector2(10+n*7,-n*4)+Vector2(20,-27)*t
			var alpha = maxf(0,0.55-t*0.75)
			draw_circle(q,5+n*1.5+t*12,Color(0.85,0.85,0.77,alpha))
	for ball in enemy_cannonballs:
		var f: float = clampf(ball.t/ball.duration,0,1)
		var p: Vector2 = ball.a.lerp(ball.b,f)-Vector2(0,sin(f*PI)*22)
		var direction: Vector2 = (ball.b-ball.a).normalized()
		draw_line(p-direction*16,p,Color(0.95,0.82,0.59,0.5),3,true)
		draw_circle(p+Vector2(1,2),6,Color(0.16,0.26,0.26,0.3))
		draw_circle(p,5,Color('#35484c'))
		draw_circle(p+Vector2(-1.5,-1.5),1.6,Color('#91a8a2'))

func draw_port_impacts():
	for effect in port_impacts:
		var t: float = effect.t
		var p: Vector2 = effect.p
		var power = 1.5 if effect.boss else 1.0
		# Short wood slivers fly back from the dock face, then fall into the sea.
		for n in 9:
			var velocity = Vector2(-55-n*12,(n%3-1)*85-40)*power
			var q = p+velocity*t+Vector2(0,175*t*t)
			var direction = Vector2.from_angle(n*1.7+t*7)
			draw_line(q-direction*4,q+direction*5,Color(0.65,0.38,0.17,maxf(0,1-t/0.65)),3)
		# Water stays close to the hull; no large circular explosion.
		for n in 7:
			var q = p+Vector2(-15-n*9,14)+Vector2(-35-n*10,-65-(n%3)*18)*t+Vector2(0,165*t*t)
			ellipse(q,Vector2(4,2),Color(0.87,1,0.94,maxf(0,1-t/0.5)))
		text_at('-'+str(effect.damage),p+Vector2(20,-22-t*40),23,Color(0.75,0.25,0.15,1-t/0.9),true)

func draw_tower_projectile(b: Dictionary):
	var p: Vector2 = b.a.lerp(b.b,b.t)
	p.y -= sin(b.t*PI)*(60 if b.lv < 4 else 145)
	if b.lv < 4:
		var direction: Vector2 = (b.b-b.a).normalized()
		draw_line(p-direction*15,p,Color('#fff0bc'),3)
	else: draw_circle(p,6,Color('#7d857a'))

func draw_enemy_health(e: Dictionary, p: Vector2, _size: Vector2):
	if e.hp < e.max:
		draw_rect(Rect2(p+Vector2(-28,-86),Vector2(56,6)),Color('#416660'))
		draw_rect(Rect2(p+Vector2(-27,-85),Vector2(54*maxf(0,e.hp/e.max),4)),Color('#f1cb78'))

func draw_combat_ground():
	pass

func draw_pause_button():
	button(Rect2(1538,8,44,43),'')
	for x in [1555,1565]: draw_line(Vector2(x,20),Vector2(x,38),Color('#6f795e'),3,true)

func draw_sound_button():
	button(Rect2(1449,834,55,52),'')
	var p = Vector2(1475,860)
	var ink = Color('#6f795e')
	draw_rect(Rect2(p+Vector2(-12,-5),Vector2(7,10)),ink)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-6,-5),p+Vector2(2,-12),p+Vector2(2,12),p+Vector2(-6,5)]),ink)
	if muted:
		draw_line(p+Vector2(7,-5),p+Vector2(16,5),ink,2.5,true)
		draw_line(p+Vector2(7,5),p+Vector2(16,-5),ink,2.5,true)
	else:
		for radius in [9,15]: draw_arc(p+Vector2(2,0),radius,-0.8,0.8,12,ink,2,true)
