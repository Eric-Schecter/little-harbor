extends "res://scripts/harbor.gd"

const MAX_TIER = 8
const TIER_DAMAGE = [17.0,28.0,48.0,82.0,140.0,250.0,450.0,820.0]
const FAMILY_NAMES = ['BALLISTA','CATAPULT','OIL POTS']
const ROUTES = [['RAPID CROSSBOW','HEAVY CROSSBOW'],['SCATTERSHOT','SIEGE BOULDER'],['FLAME JET','OIL SLICK']]
const MASTERY = [['Lv6: 5 bolts / Lv7: 6 bolts','Lv6: +35% vs armor and bosses'],['Lv6: wider fragment spread','Lv6: 3-second slow'],['Lv6: burns for 5 seconds','Lv6: oil lasts 6 seconds']]
const DESCRIPTIONS = [['Fast volleys • up to four bolts','Piercing bolts • breaks armor'],['Hits nearby ships with stone fragments','Wide impact • slows enemy ships'],['Stacking fire • ignites oil slicks','Lingering oil • slows ships for flames']]
var families = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
var branches = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
var tower_costs = [12,12,0,0,0,12,12,0,0,0,0,0,0,0,0]
var launch_effects: Array = []
var health_layout: Array[Rect2] = []
var damage_labels: Array = []
var area_pulses: Array = []
var stone_rains: Array = []
var build_family = 0
var specializing = -1
var growth: Dictionary = {}
var atlases: Array = []
var slicks: Array = []
var weapon_impacts: Array = []
var tower_cycles: Dictionary = {}
var mechanism_meshes: Dictionary = {}

func _ready():
	super._ready()
	for name_ in ['bow','stone','oil']:
		atlases.append(load('res://assets/harbor/upgrades-'+name_+'-v2.png'))
	if menu: start_game()
	if '--demo' in OS.get_cmdline_user_args():
		families = [0,0,1,1,2,0,0,1,1,2,2,2,2,2,2]
		branches = [1,2,1,2,1,0,0,0,0,0,0,2,0,0,0]
		slots = [3,4,4,5,5,1,2,1,2,2,0,4,0,0,0]
	if '--upgrade-test' in OS.get_cmdline_user_args(): upgrade_test.call_deferred()
	if '--branch-preview' in OS.get_cmdline_user_args():
		start_game(); families[5] = 0; slots[5] = 3; specializing = 5

func start_game():
	super.start_game()
	families.fill(0); branches.fill(0)
	tower_costs.fill(0)
	for i in 15:
		if slots[i] > 0: tower_costs[i] = 12
	launch_effects.clear(); damage_labels.clear(); area_pulses.clear(); stone_rains.clear()
	build_family = 0; specializing = -1
	growth.clear(); slicks.clear(); weapon_impacts.clear(); tower_cycles.clear()

func build_tower():
	var price = 12+upgrades[2]*8
	if coins < price: toast_msg('NOT ENOUGH GOLD'); return
	for i in range(5,15):
		if slots[i] == 0:
			slots[i] = mini(2,1+upgrades[2]); families[i] = build_family; branches[i] = 0
			tower_costs[i] = price
			coins -= price; growth[i] = 0.7; sfx('ui_buy'); return
	toast_msg('SHIPWRIGHT FULL — MERGE MATCHING TOWERS')

func move_tower(a: int, b: int):
	if a == b or a < 0 or b < 0 or slots[a] == 0: return
	if slots[a] == slots[b] and families[a] == families[b] and branches[a] == branches[b] and slots[a] < MAX_TIER:
		tower_costs[b] += tower_costs[a]; tower_costs[a] = 0
		slots[b] += 1; slots[a] = 0; families[a] = 0; branches[a] = 0
		growth[b] = 0.8; burst(slot_rect(b).get_center(),GOLD,28); sfx('ui_merge')
		toast_msg('UPGRADED!  LEVEL '+str(slots[b]))
		if slots[b] == 3 and branches[b] == 0: specializing = b
	else:
		for arr in [slots,families,branches,tower_costs]:
			var tmp = arr[b]; arr[b] = arr[a]; arr[a] = tmp
	selected = -1; drag = -1

func choose_branch(branch: int):
	if specializing < 0: return
	branches[specializing] = branch
	growth[specializing] = 0.9
	toast_msg(ROUTES[families[specializing]][branch-1]+' READY')
	specializing = -1; sfx('ui_upgrade')

func fire_tower(i: int, target: Dictionary):
	if testing:
		release_tower(i,target)
		return
	if tower_cycles.has(i): return
	var interval = [0.9,1.6,1.35][families[i]]
	if families[i] == 0 and branches[i] == 1: interval = 0.7
	interval /= 3 if over_time > 0 else 1
	cooldown[i] = interval
	tower_cycles[i] = {'t':0.0,'windup':minf([0.24,0.42,0.32][families[i]],interval*0.55),'f':families[i],'b':branches[i],'lv':slots[i],'target':target,'released':false,'duration':minf(interval*0.95,minf([0.24,0.42,0.32][families[i]],interval*0.55)+0.35)}

func release_tower(i: int, target: Dictionary):
	var lv = mini(slots[i],MAX_TIER)
	var family = families[i]
	var branch = branches[i]
	var damage = TIER_DAMAGE[lv-1]*(1+upgrades[0]*0.18)
	var interval = [0.9,1.6,1.35][family]
	if family == 0 and branch == 1: interval = 0.7
	if testing: cooldown[i] = interval/(3 if over_time > 0 else 1)
	launch_effects.append({'p':slot_rect(i).get_center()+Vector2(-43,-8),'family':family,'tier':lv,'t':0.0})
	var count = mini(6,maxi(2,lv-1)) if family == 0 and branch == 1 else 1
	for n in count:
		var from = slot_rect(i).get_center()+Vector2(-50,n*5-5)
		var end = target.p+Vector2(6,-50)
		var audio_level = [1,4,7][family]
		shots.append({'a':from,'b':end,'life':0.12+n*0.075,'delay':n*0.075,'level':audio_level,'family':family,'branch':branch,'tier':lv,'index':n})
		pending_hits.append({'enemy':target,'damage':damage*(0.48 if count > 1 else 1.0),'time':0.36+n*0.075,'level':audio_level,'family':family,'branch':branch,'tier':lv,'position':target.p,'secondary':false})
	burst(slot_rect(i).get_center()+Vector2(-50,0),GOLD,3)

func resolve_projectile(h: Dictionary):
	if not h.has('family'): super.resolve_projectile(h); return
	var e = h.enemy
	weapon_impacts.append({'p':e.p+Vector2(6,-50),'family':h.family,'branch':h.branch,'tier':h.tier,'t':0.0})
	mark_impact(e,h.family,h.tier)
	var damage = h.damage*(1.25 if e.get('armor_time',0.0) > 0 else 1.0)
	if h.family == 0:
		if h.branch == 2:
			e.armor_time = 4.0
			damage *= 1.8
			if h.tier >= 6 and (e.kind == 'armored' or e.get('boss',false)): damage *= 1.35
			for other in enemies:
				if other != e and other.hp > 0 and absf(other.p.y-e.p.y) < 36 and other.p.x < e.p.x and e.p.x-other.p.x < 250:
					other.armor_time = 4.0; mark_impact(other,h.family,h.tier); deal_damage(other,damage*0.6,'PIERCE')
		deal_damage(e,damage,'MULTI' if h.branch == 1 else 'PIERCE' if h.branch == 2 else 'HIT')
	elif h.family == 1:
		var radius = (110.0 if h.branch == 2 else 85.0 if h.branch == 1 else 48.0)+(15 if h.tier >= 6 and h.branch == 1 else 0)
		var count = 0
		for other in enemies:
			if other.hp > 0 and other.p.distance_to(e.p) < radius:
				count += 1
				mark_impact(other,h.family,h.tier)
				var distance: float = other.p.distance_to(e.p)
				var falloff = lerpf(1.0,0.35,clampf(distance/radius,0,1))
				var armor = 0.55 if other.kind == 'armored' or other.get('boss',false) else 1.0
				deal_damage(other,damage*(0.95 if h.branch == 2 else 0.8)*falloff*armor,'SPLASH')
				if h.branch == 2: other.slow_time = 3.0 if h.tier >= 6 else 1.2
		area_pulses.append({'p':e.p+Vector2(0,-40),'radius':radius,'count':count,'t':0.0})
		burst(e.p+Vector2(0,-40),GOLD,18)
	else:
		deal_damage(e,damage*0.7,'FIRE' if h.branch == 1 else 'OIL')
		if h.branch == 1:
			e.burn_time = 5.0 if h.tier >= 6 else 3.5
			e.burn_stacks = mini(3,e.get('burn_stacks',0)+1)
			e.burn_dps = minf(e.get('burn_dps',0.0)+damage*0.22,damage*0.66)
			for oil in slicks:
				if oil.p.distance_to(e.p) < oil.radius: oil.burning = true
		elif h.branch == 2:
			slicks.append({'p':e.p,'time':6.0 if h.tier >= 6 else 4.0,'radius':85.0+mini(h.tier,6)*5,'burning':false,'damage':damage*0.35})

func _process(delta):
	if specializing >= 0:
		music.stream_paused = true
		pointer = get_global_mouse_position()
		if harbor_audio: harbor_audio.update_state(delta,0,false)
		queue_redraw(); return
	if not (paused or workshop or menu) and health > 0:
		var dt = minf(delta,0.05)*speed
		update_stone_rain(dt)
		for label in damage_labels: label.t += dt
		damage_labels = damage_labels.filter(func(label): return label.t < 0.95)
		for pulse in area_pulses: pulse.t += dt
		area_pulses = area_pulses.filter(func(pulse): return pulse.t < 0.65)
		for i in tower_cycles.keys():
			var cycle = tower_cycles[i]
			if slots[i] != cycle.lv or families[i] != cycle.f or branches[i] != cycle.b or (not cycle.released and cycle.target.hp <= 0):
				tower_cycles.erase(i); cooldown[i] = 0; continue
			cycle.t += dt
			if not cycle.released and cycle.t >= cycle.windup:
				cycle.released = true
				release_tower(i,cycle.target)
			if cycle.t >= cycle.duration: tower_cycles.erase(i)
		for effect in launch_effects: effect.t += dt
		launch_effects = launch_effects.filter(func(effect): return effect.t < 0.25)
		for effect in weapon_impacts: effect.t += dt
		weapon_impacts = weapon_impacts.filter(func(effect): return effect.t < 0.85)
		for key in growth.keys():
			growth[key] -= dt
			if growth[key] <= 0: growth.erase(key)
		for oil in slicks: oil.time -= dt
		slicks = slicks.filter(func(o): return o.time > 0)
		for e in enemies:
			e.hp_visible = maxf(0,e.get('hp_visible',0.0)-dt)
			e.echo_hold = maxf(0,e.get('echo_hold',0.0)-dt)
			if e.echo_hold <= 0: e.hp_echo = move_toward(e.get('hp_echo',e.hp),maxf(0,e.hp),e.max*dt*1.5)
			e.combo_time = maxf(0,e.get('combo_time',0.0)-dt)
			if e.combo_time <= 0: e.combo_hits = 0
			e.oiled = false
			e.impact_time = maxf(0,e.get('impact_time',0.0)-dt)
			e.slow_time = maxf(0,e.get('slow_time',0.0)-dt)
			e.armor_time = maxf(0,e.get('armor_time',0.0)-dt)
			e.burn_time = maxf(0,e.get('burn_time',0.0)-dt)
			e.slow_factor = 0.55 if e.slow_time > 0 else 1.0
			for oil in slicks:
				if e.p.distance_to(oil.p) < oil.radius:
					e.slow_factor = 0.45
					e.oiled = true
					if oil.burning: e.dot_pending = e.get('dot_pending',0.0)+oil.damage*dt
			if e.burn_time > 0: e.dot_pending = e.get('dot_pending',0.0)+e.burn_dps*dt
			else: e.burn_dps = 0.0; e.burn_stacks = 0
			e.dot_clock = e.get('dot_clock',0.0)+dt
			if e.dot_clock >= 0.4:
				if e.get('dot_pending',0.0) > 0: deal_damage(e,e.dot_pending,'DOT')
				e.dot_clock = 0.0; e.dot_pending = 0.0
	super._process(delta)

func sprite(family: int, branch: int, level: int, center: Vector2, scale_: float = 1.0, angle: float = PI):
	if atlases.size() < 3: super.tower(family*3+level,center,angle,scale_); return
	var sheet: Texture2D = atlases[family]
	var cell = sheet.get_size()/3.0
	var column = clampi(level-1 if branch == 0 else level-3,0,2)
	var extent = Vector2(119,119)*scale_
	draw_set_transform(center,clampf(wrapf(angle-PI,-PI,PI),-0.15,0.15))
	draw_texture_rect_region(sheet,Rect2(-extent*0.5,extent),Rect2((Vector2(column,branch)+Vector2(0.13,0.13))*cell,cell*0.74))
	draw_set_transform(Vector2.ZERO)

func tower(lv: int, center: Vector2, angle = PI, size_ = 1.0):
	var idx = drag if drag >= 0 and center.distance_to(pointer) < 1 else slot_at(center)
	if menu or idx < 0: sprite(mini(2,(lv-1)/3),0,1,center,size_,angle); return
	var pop = sin(growth.get(idx,0.0)*PI)*0.12
	if idx < 5 and tower_cycles.has(idx):
		draw_working_tower(idx,center,angle,size_+pop)
	else: sprite(families[idx],branches[idx],lv,center,size_+pop,angle)
	if lv >= 6:
		for n in lv-5:
			var q = center+Vector2(-18+n*17,-48)
			draw_colored_polygon(PackedVector2Array([q+Vector2(0,-8),q+Vector2(6,0),q+Vector2(0,8),q+Vector2(-6,0)]),Color('#f3c96d'))
		draw_arc(center+Vector2(0,32),40,0.2,PI-0.2,24,Color('#e8ba59'),3,true)
	var color = [Color('#57a6a1'),Color('#da8b63')][maxi(0,branches[idx]-1)]
	if branches[idx] > 0:
		draw_circle(center+Vector2(-43,42),9,color)
		text_at('R' if families[idx] == 0 and branches[idx] == 1 else 'H' if families[idx] == 0 else 'S' if families[idx] == 1 and branches[idx] == 1 else 'B' if families[idx] == 1 else 'F' if branches[idx] == 1 else 'O',center+Vector2(-47,47),13,WHITE,true)

func draw_hud():
	super.draw_hud()
	panel(Rect2(-5,820,1610,85))
	for family in 3:
		var r = Rect2(18+family*178,832,170,58)
		panel(r)
		if r.has_point(pointer): draw_style_box(button_style(Color('#ffe1a9')),r.grow(-4))
		sprite(family,0,mini(2,1+upgrades[2]),r.position+Vector2(27,28),0.43)
		text_at(FAMILY_NAMES[family],r.position+Vector2(52,24),19,Color('#3d4c47'),true)
		text_at(str(12+upgrades[2]*8)+' GOLD',r.position+Vector2(52,46),17,Color('#8c6a3f'))
		text_at(['Q','W','E'][family],r.position+Vector2(151,15),12,Color('#947049'))
	draw_utility_icon(Rect2(558,834,52,52),0,grenade_cd,'G')
	draw_utility_icon(Rect2(622,834,52,52),1,over_cd,'O')
	draw_utility_icon(Rect2(1378,834,52,52),2,0,'U')
	if not active: button(Rect2(706,834,202,52),'NEXT FLEET  ›',str(maxi(0,int(ceil(next_time))))+'s • SPACE',true)
	else: text_at('Q / W / E  Build',Vector2(716,866),18,Color('#75816a'))
	draw_sound_button()
	button(Rect2(1520,834,62,52),str(int(speed))+'×')
	if selected >= 0 and slots[selected] > 0:
		button(Rect2(1090,834,258,52),'SELL  +'+str(sell_value(selected))+' GOLD','50% build value',false,'X')
	draw_utility_tooltip()
	if selected >= 0 and slots[selected] > 0:
		text_at((ROUTES[families[selected]][branches[selected]-1] if branches[selected] > 0 else FAMILY_NAMES[families[selected]])+'  '+str(slots[selected])+'/8',Vector2(520,36),20,Color('#44766b'))

func buy_family(family: int):
	aim_grenade = false
	build_family = family
	build_tower()

func draw_workshop():
	super.draw_workshop()
	if upgrades[2] >= 1: button(Rect2(449,511,700,73),'BUILD TIER 2 — MAX','New towers start reinforced')

func _draw():
	super._draw()
	if menu: return
	draw_weapon_impacts()
	draw_launch_effects()
	draw_rally_buff()
	draw_stone_rain()
	for oil in slicks:
		ellipse(oil.p+Vector2(0,-18),Vector2(oil.radius,22),Color(0.9,0.38,0.12,0.35) if oil.burning else Color(0.28,0.42,0.25,0.3))
		if oil.burning:
			for n in 7: flame_shape(oil.p+Vector2((n-3)*oil.radius/4,-16),24+sin(sea_time*8+n)*6,n,0.8)
	for e in enemies: draw_ship_conditions(e)
	draw_damage_readouts()
	if paused:
		draw_pause_menu()
		return
	if specializing < 0: return
	draw_rect(Rect2(0,0,1600,900),Color(0.12,0.3,0.3,0.75))
	panel(Rect2(260,165,1080,570))
	text_at('CHOOSE YOUR SPECIALTY',Vector2(510,225),36,Color('#44766b'),true)
	text_at('Level 3 reached • Your fleet waits while you choose',Vector2(538,262),23,Color('#897958'))
	var family = families[specializing]
	for branch in [1,2]:
		var x = 300+(branch-1)*510
		panel(Rect2(x,295,490,385))
		text_at(ROUTES[family][branch-1],Vector2(x+25,338),28,Color('#44766b'),true)
		for stage in 3:
			sprite(family,branch,stage+3,Vector2(x+85+stage*155,442),1.12)
			text_at('LV '+str(stage+3),Vector2(x+64+stage*155,524),18,Color('#897958'))
		text_at(DESCRIPTIONS[family][branch-1],Vector2(x+22,568),21,Color('#667c64'))
		text_at(MASTERY[family][branch-1],Vector2(x+25,582),18,Color('#6e8273'))
		button(Rect2(x+25,600,440,56),'CHOOSE  '+str(branch),'Matching towers merge up to level 8',true)

func _unhandled_input(event):
	if paused:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ESCAPE,KEY_P]: paused = false
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Rect2(580,341,440,68).has_point(event.position) or Rect2(1538,8,44,43).has_point(event.position): paused = false
			elif Rect2(580,427,440,68).has_point(event.position): start_game()
			elif not OS.has_feature('web') and Rect2(580,513,440,68).has_point(event.position): exit_game()
		return
	if specializing >= 0:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_1: choose_branch(1)
			elif event.keycode == KEY_2: choose_branch(2)
		if event is InputEventMouseButton and event.pressed:
			for b in [1,2]:
				if Rect2(300+(b-1)*510,295,490,385).has_point(event.position): choose_branch(b)
		return
	if not menu and not paused and not workshop and health > 0:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_X: sell_selected(); return
			if event.keycode in [KEY_Q,KEY_W,KEY_E,KEY_B]:
				buy_family(0 if event.keycode in [KEY_Q,KEY_B] else 1 if event.keycode == KEY_W else 2)
				return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.position.y >= 820:
			if not event.pressed:
				drag = -1
				return
			var p: Vector2 = event.position
			if selected >= 0 and Rect2(1090,834,258,52).has_point(p): sell_selected(); return
			for family in 3:
				if Rect2(18+family*178,832,170,58).has_point(p): buy_family(family); return
			if Rect2(558,834,52,52).has_point(p): aim_grenade = grenade_cd <= 0
			elif Rect2(622,834,52,52).has_point(p): overdrive()
			elif Rect2(1378,834,52,52).has_point(p): workshop = true
			elif Rect2(706,834,202,52).has_point(p) and not active: call_wave()
			elif Rect2(1449,834,55,52).has_point(p): muted = not muted
			elif Rect2(1520,834,62,52).has_point(p): speed = 2 if speed == 1 else 1
			return
	if workshop and upgrades[2] >= 1 and event is InputEventMouseButton and event.pressed and Rect2(449,511,700,73).has_point(event.position): return
	super._unhandled_input(event)

func upgrade_test():
	testing = true
	start_game(); muted = true; slots.fill(0)
	slots[5] = 2; slots[6] = 2
	move_tower(5,6); assert(slots[6] == 3 and specializing == 6)
	choose_branch(2); assert(branches[6] == 2)
	slots[5] = 3; branches[5] = 1
	move_tower(5,6); assert(slots[5] == 3 and slots[6] == 3 and branches[6] == 1)
	branches[5] = 1; move_tower(5,6); assert(slots[6] == 4)
	families[5] = 1; slots[5] = 4; branches[5] = 1
	move_tower(5,6); assert(slots[5] == 4 and families[5] == 0 and families[6] == 1)
	for family in 3:
		for branch in [1,2]:
			enemies.clear(); pending_hits.clear(); slicks.clear()
			spawn_enemy(0,Vector2(700,300)); spawn_enemy(0,Vector2(650,300))
			for e in enemies: e.hp = 10000; e.max = 10000
			families[0] = family; branches[0] = branch; slots[0] = 3
			fire_tower(0,enemies[0]); assert(not pending_hits.is_empty())
			for hit in pending_hits: resolve_projectile(hit)
			assert(enemies[0].hp < 10000)
			if family == 0 and branch == 2: assert(enemies[1].hp < 10000 and enemies[0].armor_time > 0)
			if family == 1: assert(enemies[1].hp < 10000)
			if family == 1 and branch == 2: assert(enemies[1].slow_time > 0)
			if family == 2 and branch == 1: assert(enemies[0].burn_time > 0)
			if family == 2 and branch == 2: assert(slicks.size() == 1)
	# Oil/fire synergy, pause, and real delayed impacts.
	enemies.clear(); pending_hits.clear(); slicks.clear(); slots.fill(0)
	spawn_enemy(0,Vector2(700,300)); enemies[0].hp = 10000; enemies[0].max = 10000
	var foe = enemies[0]
	var oil_hit = {'enemy':foe,'damage':40.0,'family':2,'branch':2,'tier':3}
	resolve_projectile(oil_hit)
	resolve_projectile({'enemy':foe,'damage':40.0,'family':2,'branch':1,'tier':3})
	assert(slicks[0].burning)
	paused = true; var old_time = slicks[0].time; _process(0.05); assert(slicks[0].time == old_time)
	paused = false; _process(0.05); assert(foe.slow_factor == 0.45)
	families[0] = 0; branches[0] = 0; slots[0] = 1
	var old_hp = foe.hp; fire_tower(0,foe); assert(foe.hp == old_hp)
	slots[0] = 0
	for step in 9: _process(0.05)
	assert(foe.hp < old_hp)
	start_game(); assert(slicks.is_empty() and pending_hits.is_empty() and branches.count(0) == 15)
	print('UPGRADE TEST PASS: typed merges, specialization, six attacks, reset')
	get_tree().quit()

func setup_campaign_test():
	slots = [8,8,8,8,8,0,0,0,0,0,0,0,0,0,0]
	families = [0,0,1,2,2,0,0,0,0,0,0,0,0,0,0]
	branches = [1,2,2,1,2,0,0,0,0,0,0,0,0,0,0]
	upgrades[0] = 5
	upgrades[1] = 5

func campaign_test_actions():
	if enemies.size() > 4:
		if over_cd <= 0: overdrive()
		if grenade_cd <= 0:
			for e in enemies:
				if e.p.x > 500:
					throw_grenade(e.p+Vector2(0,-40)); break

func draw_tower_projectile(b: Dictionary):
	if not b.has('family'): super.draw_tower_projectile(b); return
	var family: int = b.family
	var branch: int = b.branch
	var tier: int = b.tier
	if family == 2 and branch == 1:
		draw_flame_jet(b)
		return
	var arc = 12.0 if family == 0 else 145.0 if family == 1 else 100.0
	var p: Vector2 = b.a.lerp(b.b,b.t)-Vector2(0,sin(b.t*PI)*arc)
	var tangent: Vector2 = b.b-b.a-Vector2(0,cos(b.t*PI)*PI*arc)
	var growth_ = 1.0+(mini(tier,6)-1)*0.13
	if family == 0:
		var heavy = branch == 2
		var length_ = (31.0 if heavy else 18.0 if branch == 1 else 24.0)*growth_
		var width = 4.0 if heavy else 2.0
		var feather = Color('#e4a156') if heavy else Color('#70d9cb') if branch == 1 else Color('#f5ebbf')
		draw_set_transform(p,tangent.angle())
		if heavy: draw_line(Vector2(-length_-17,0),Vector2(-length_,0),Color(1,0.80,0.40,0.32),5,true)
		draw_line(Vector2(-length_,0),Vector2(-5,0),Color('#805632'),width+1,true)
		draw_line(Vector2(-length_,-1),Vector2(-5,-1),Color('#e7bf7c'),width,true)
		draw_colored_polygon(PackedVector2Array([Vector2(5,0),Vector2(-8,-(6 if heavy else 3)),Vector2(-5,0),Vector2(-8,6 if heavy else 3)]),Color('#b4d0cc'))
		for side in [-1,1]:
			draw_colored_polygon(PackedVector2Array([Vector2(-length_+8,0),Vector2(-length_+2,side*5),Vector2(-length_-4,side*5),Vector2(-length_,0)]),feather)
		if heavy: draw_line(Vector2(-12,-3),Vector2(-12,3),Color('#f0c46b'),3)
		draw_set_transform(Vector2.ZERO)
	elif family == 1:
		var count = 4 if branch == 1 else 1
		for n in count:
			var spread = Vector2((n%2)*13-6,(n/2)*12-6)*sin(b.t*PI) if count > 1 else Vector2.ZERO
			var radius = (5.0 if count > 1 else 13.0 if branch == 2 else 8.0)*growth_
			var q = p+spread
			draw_set_transform(q,b.t*5+n)
			var points = PackedVector2Array()
			for v in 7: points.append(Vector2.from_angle(v*TAU/7)*radius*(0.85 if v%2 == 0 else 1.0))
			draw_colored_polygon(points,Color('#737d83') if branch != 2 else Color('#656477'))
			draw_colored_polygon(PackedVector2Array([points[3],points[4],points[5],Vector2.ZERO]),Color('#b6b9af'))
			if branch == 2:
				draw_polyline(PackedVector2Array([Vector2(-5,-9),Vector2(2,-2),Vector2(-1,5),Vector2(7,9)]),Color('#434758'),2,true)
			draw_set_transform(Vector2.ZERO)
	else:
		var flaming = branch == 1
		var oil = branch == 2
		if flaming:
			for n in 4:
				var tail = p-tangent.normalized()*(n*8+7)+Vector2(0,-sin(sea_time*20+n)*3)
				draw_circle(tail,5-n,Color(1,0.5+n*0.08,0.13,0.65-n*0.13))
		elif oil:
			for n in 3: draw_circle(p-tangent.normalized()*(n*8+9)+Vector2(0,n*3),2.8-n*0.5,Color('#8baf69'))
		draw_set_transform(p,b.t*3,Vector2.ONE*growth_)
		var color = Color('#86a15b') if oil else Color('#d67a43') if flaming else Color('#bc8657')
		draw_circle(Vector2.ZERO,8,Color('#79553e'))
		draw_circle(Vector2(0,-1),7,color)
		draw_rect(Rect2(-4,-11,8,5),Color('#e7c18b'))
		draw_line(Vector2(-6,2),Vector2(6,2),Color('#edce8f'),2)
		if tier >= 4: draw_line(Vector2(-6,-2),Vector2(6,-2),Color('#edce8f'),2)
		draw_circle(Vector2(-2,-4),2,Color(1,0.94,0.72,0.6))
		if flaming:
			draw_colored_polygon(PackedVector2Array([Vector2(-4,-10),Vector2(0,-23),Vector2(2,-16),Vector2(6,-20),Vector2(4,-10)]),Color('#ffbc4e'))
			draw_circle(Vector2(0,-12),3,Color('#fff3b8'))
		draw_set_transform(Vector2.ZERO)

func draw_weapon_impacts():
	for effect in weapon_impacts:
		var t: float = effect.t
		var p: Vector2 = effect.p
		var power = 0.7+effect.tier*0.28
		var fade = maxf(0,1-t/0.85)
		var flash = maxf(0,1-t/0.16)
		if effect.family == 0:
			var heavy: bool = effect.branch == 2
			var tint = Color('#ffe1a0') if heavy else Color('#a8f2df')
			tint.a = flash
			for n in 6:
				var axis = Vector2.from_angle(n*TAU/6+0.3)
				draw_line(p+axis*4,p+axis*(12+t*130)*power,tint,3*flash+1,true)
			for n in (14 if heavy else 7):
				var q = p+Vector2(-45-n*14,(n%5-2)*65-25)*t*power+Vector2(0,200*t*t)
				var dir = Vector2.from_angle(n+t*9)
				draw_line(q-dir*3,q+dir*(4+effect.tier),Color(0.76,0.46,0.20,fade),2.5,true)
			if heavy and t < 0.2:
				draw_line(p+Vector2(28,0),p-Vector2(150*power,0),Color(1,0.85,0.45,(1-t/0.2)*0.65),7*flash+1,true)
		elif effect.family == 1:
			var heavy: bool = effect.branch == 2
			if t < 0.3:
				for n in 6:
					var q = p+Vector2(cos(n*1.5)*28,sin(n*1.5)*12)*power
					draw_circle(q,(10+t*50)*power,Color(0.87,0.80,0.60,(0.3-t)*1.5))
			if flash > 0:
				var star = PackedVector2Array()
				for n in 16: star.append(p+Vector2.from_angle(n*TAU/16)*(26 if n%2 == 0 else 11)*power*(1+t*3))
				draw_colored_polygon(star,Color(1,0.94,0.72,flash*0.85))
			for n in (20 if heavy else 26):
				var direction = Vector2.from_angle(n*2.4)
				var q = p+Vector2(direction.x*160,direction.y*100-70)*t*power+Vector2(0,230*t*t)
				var radius = (5.5 if heavy else 3.3)*power*fade
				if radius < 0.6: continue
				draw_colored_polygon(PackedVector2Array([q+Vector2(-radius,0),q+Vector2(-radius*0.3,-radius),q+Vector2(radius,-radius*0.2),q+Vector2(radius*0.5,radius)]),Color(0.53,0.58,0.60,fade))
		else:
			var flame: bool = effect.branch == 1
			for n in (14 if flame else 12):
				var q = p+Vector2.from_angle(n*2.4)*t*105*power+Vector2(0,(80 if not flame else -80)*t*t)
				if flame:
					var radius = (8+n%3*3)*power*fade
					draw_circle(q,radius,Color(1,0.31,0.09,fade*0.65))
					draw_circle(q+Vector2(0,-radius*0.3),radius*0.64,Color(1,0.73,0.22,fade*0.9))
					if t < 0.2: draw_circle(q,radius*0.34,Color(1,0.96,0.72,flash))
				else:
					ellipse(q,Vector2(7,4)*power*fade,Color(0.39,0.57,0.19,fade))
					draw_circle(q+Vector2(-2,-2),2*fade,Color(0.85,0.93,0.57,fade))
			for n in (0 if flame else 7):
				var q = p+Vector2.from_angle(n*2.9)*t*130*power+Vector2(0,t*t*180)
				draw_line(q,q+Vector2(5,3),Color(0.72,0.35,0.15,fade),3,true)

func workshop_button_position() -> Vector2:
	return Vector2(1404,858)

func draw_working_tower(i: int, center: Vector2, angle: float, scale_: float):
	var cycle = tower_cycles[i]
	var family: int = families[i]
	var loading: float = clampf(cycle.t/cycle.windup,0,1) if not cycle.released else 0.0
	var kick: float = maxf(0,1-(cycle.t-cycle.windup)/0.28) if cycle.released else 0.0
	var sheet: Texture2D = atlases[family]
	var column = clampi(slots[i]-1 if branches[i] == 0 else slots[i]-3,0,2)
	var uv_origin = (Vector2(column,branches[i])+Vector2(0.13,0.13))/3.0
	var uv_extent = Vector2.ONE*0.74/3.0
	var extent = 119.0
	var rotation_ = clampf(wrapf(angle-PI,-PI,PI),-0.15,0.15)
	draw_set_transform(center,rotation_,Vector2.ONE*scale_)
	var vertices = PackedVector3Array()
	var texture_uvs = PackedVector2Array()
	# Deform the upper mechanism, keeping the masonry base fixed.
	for row in 12:
		for col in 8:
			var points = PackedVector2Array()
			var uvs = PackedVector2Array()
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var uv = Vector2((col+corner.x)/8.0,(row+corner.y)/12.0)
				var p = (uv-Vector2(0.5,0.5))*extent
				var weight = 1.0-smoothstep(-20.0,28.0,p.y)
				if family == 0:
					p.x += (loading*9-kick*5)*weight
					p.y *= 1.0-loading*0.035*weight
				else:
					var pivot = Vector2(-3,7)
					var turn = (loading*0.20-kick*0.45)*(0.7 if family == 2 else 1.0)
					p = p.lerp(pivot+(p-pivot).rotated(turn),weight)
				points.append(p); uvs.append(uv_origin+uv*uv_extent)
			for tri in [[0,1,2],[0,2,3]]:
				if absf((points[tri[1]]-points[tri[0]]).cross(points[tri[2]]-points[tri[0]])) < 0.01: continue
				for vertex in tri:
					vertices.append(Vector3(points[vertex].x,points[vertex].y,0))
					texture_uvs.append(uvs[vertex])
	if not mechanism_meshes.has(i): mechanism_meshes[i] = ArrayMesh.new()
	var mesh: ArrayMesh = mechanism_meshes[i]
	mesh.clear_surfaces()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = texture_uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	draw_mesh(mesh,sheet)
	# Animate the painted mechanism itself; extra ropes duplicate the atlas artwork.
	draw_set_transform(Vector2.ZERO)

func draw_utility_icon(r: Rect2, kind: int, cooldown_: float, key: String):
	panel(r)
	var p = r.get_center()+Vector2(-2,-2)
	var tint = Color('#6e8273') if cooldown_ > 0 else Color('#987344')
	if kind == 0:
		for n in 3:
			var q = p+Vector2(n*9-9,abs(n-1)*7-5)
			draw_line(q+Vector2(5,-8),q+Vector2(9,-15),Color('#b4aa87'),2,true)
			draw_circle(q,5,tint)
			draw_circle(q+Vector2(-1,-2),2,Color('#c8c8ae'))
	elif kind == 1:
		draw_colored_polygon(PackedVector2Array([p+Vector2(-13,-4),p+Vector2(8,-8),p+Vector2(15,-15),p+Vector2(15,12),p+Vector2(7,5),p+Vector2(-13,2)]),tint)
		draw_line(p+Vector2(14,-15),p+Vector2(14,12),Color('#e8b86a'),4,true)
		draw_arc(p+Vector2(-4,5),6,0,PI,12,tint,3,true)
	else:
		draw_line(p+Vector2(-7,12),p+Vector2(7,-8),Color('#a5794d'),5,true)
		draw_line(p+Vector2(-1,-13),p+Vector2(15,-3),Color('#6f8982'),9,true)
	text_at(key,r.position+Vector2(37,14),12,Color('#99754d'))
	if cooldown_ > 0:
		draw_rect(Rect2(r.position+Vector2(4,37),Vector2(44,11)),Color('#f1e6cc'))
		text_at(str(int(ceil(cooldown_)))+'s',r.position+Vector2(17,48),13,Color('#735944'))
	if kind == 1 and over_time > 0: draw_arc(p,21,0,TAU*over_time/7,30,Color('#e4a54b'),3,true)

func draw_utility_tooltip():
	var index = -1
	for n in 3:
		if [Rect2(558,834,52,52),Rect2(622,834,52,52),Rect2(1378,834,52,52)][n].has_point(pointer): index = n
	if index < 0: return
	var x = clampf(pointer.x-145,12,1250)
	panel(Rect2(x,733,334,78))
	text_at(['STONE RAIN  [G]','RALLY HORN  [O]','SHIPWRIGHT  [U]'][index],Vector2(x+16,759),20,Color('#416b60'),true)
	text_at(['Aim an area • '+str(maxi(8,20-upgrades[1]*3))+'s cooldown','3x fire rate for 7s • 32s cooldown','Spend gold on upgrades for this run'][index],Vector2(x+16,788),19,Color('#85714e'))

func sell_value(i: int) -> int:
	return int(tower_costs[i]/2) if i >= 0 and slots[i] > 0 else 0

func sell_selected():
	if selected < 0 or slots[selected] == 0 or specializing >= 0: return
	var i = selected
	var refund = sell_value(i)
	coins += refund
	slots[i] = 0; families[i] = 0; branches[i] = 0; tower_costs[i] = 0
	tower_cycles.erase(i); growth.erase(i)
	if i < 5: cooldown[i] = 0
	selected = -1; drag = -1
	sfx('ui_buy')
	toast_msg('SOLD  +'+str(refund)+' GOLD')

func mark_impact(e: Dictionary, family: int, tier: int):
	e.impact_time = 0.24
	e.impact_family = family
	e.impact_strength = 2.0+tier*1.4

func draw_launch_effects():
	for effect in launch_effects:
		if effect.tier < 3: continue
		var fade = 1-effect.t/0.25
		var p: Vector2 = effect.p
		var color = Color('#a6efe0') if effect.family == 0 else Color('#e8cf9a') if effect.family == 1 else Color('#ffc56c')
		color.a = fade*0.6
		for n in 5:
			var q = p+Vector2(-60-n*15,(n-2)*22)*effect.t
			draw_line(q,q+Vector2(-9,0),color,2.0+effect.tier*0.2,true)

func deal_damage(e: Dictionary, damage: float, kind: String):
	e.damage_kind = kind
	direct_damage(e,damage)
	e.damage_kind = 'HIT'

func damage_feedback(e: Dictionary, damage: float, before: float):
	if damage <= 0: return
	e.hp_visible = 3.5
	e.hp_echo = maxf(e.get('hp_echo',before),before)
	e.echo_hold = 0.24
	var kind: String = e.get('damage_kind','HIT')
	if kind == 'MULTI':
		e.combo_hits = e.get('combo_hits',0)+1 if e.get('combo_time',0.0) > 0 else 1
		e.combo_time = 0.5
	e.label_sequence = e.get('label_sequence',0)+1
	var offset = (int(e.label_sequence)%3-1)*72
	var pos: Vector2 = e.p+Vector2(offset,-115 if e.get('boss',false) else -75)
	damage_labels.append({'p':pos,'amount':ceili(damage),'kind':kind,'t':0.0,'lane':offset})
	if damage_labels.size() > 120: damage_labels.pop_front()

func damage_color(kind: String) -> Color:
	return {'MULTI':Color('#a8ffeb'),'PIERCE':Color('#ffe58b'),'SPLASH':Color('#c9e9ff'),'FIRE':Color('#ffbd68'),'DOT':Color('#ff9a52'),'OIL':Color('#c7e88b')}.get(kind,Color('#fff4d2'))

func draw_enemy_health(e: Dictionary, p: Vector2, size_: Vector2):
	if e.hp <= 0: return
	var affected = e.get('burn_time',0.0) > 0 or e.get('slow_time',0.0) > 0 or e.get('armor_time',0.0) > 0 or e.get('oiled',false)
	if e.get('hp_visible',0.0) <= 0 and not affected: return
	var width = 154.0 if e.get('boss',false) else 90.0
	var point = Vector2(p.x-width/2,maxf(78,p.y-size_.y*0.7-22))
	var anchor = point
	var occupied = Rect2(point-Vector2(5,3),Vector2(width+10,24))
	for attempt in 8:
		if not health_layout.any(func(previous): return previous.intersects(occupied)): break
		point.y -= 57
		if point.y < 80: point.y = anchor.y; point.x -= occupied.size.x+8
		occupied.position = point-Vector2(5,3)
	health_layout.append(occupied)
	if point.distance_to(anchor) > 10: draw_line(point+Vector2(width/2,18),anchor+Vector2(width/2,18),Color(0.22,0.4,0.35,0.5),1,true)
	var rect = Rect2(point,Vector2(width,16))
	draw_style_box(button_style(Color('#375854')),rect.grow(2))
	draw_rect(rect,Color('#466863'))
	draw_rect(Rect2(point,Vector2(width*clampf(e.get('hp_echo',e.hp)/e.max,0,1),16)),Color('#eeb775'))
	draw_rect(Rect2(point,Vector2(width*clampf(e.hp/e.max,0,1),16)),Color('#85c889') if e.hp/e.max > 0.3 else Color('#e77756'))
	var label = str(ceili(maxf(0,e.hp)))+' / '+str(ceili(e.max))
	var tw = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	draw_string_outline(font,point+Vector2((width-tw)/2,13),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color('#365b51'))
	text_at(label,point+Vector2((width-tw)/2,13),14,Color('#fff9df'))
	if e.get('combo_hits',0) > 1 and e.get('combo_time',0) > 0:
		text_at('x'+str(e.combo_hits)+' HITS',point+Vector2(width+8,13),16,Color('#d9fff0'),true)

func draw_damage_readouts():
	for label in damage_labels:
		var alpha = minf(1,(0.95-label.t)*4)
		var color = damage_color(label.kind)
		color.a = alpha
		var size_ = int(clampf(18+log(float(label.amount)+1)/log(2.0)*1.4,19,34))
		if label.kind == 'DOT': size_ = 19
		var p: Vector2 = label.p+Vector2(label.lane*label.t*0.4,-label.t*48)
		p.y = clampf(p.y,85,790)
		var value = '-'+str(label.amount)
		draw_string_outline(bold,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,5,Color(0.16,0.28,0.26,alpha))
		text_at(value,p,size_,color,true)

func draw_combat_ground():
	health_layout.clear()
	for pulse in area_pulses:
		var fade = 1-pulse.t/0.65
		draw_circle(pulse.p,pulse.radius,Color(1,0.88,0.57,fade*0.07))
		for n in 12:
			draw_arc(pulse.p,pulse.radius,n*TAU/12,n*TAU/12+0.35,8,Color(1,0.88,0.57,fade*0.7),2,true)
		text_at('SPLASH x'+str(pulse.count),pulse.p+Vector2(-42,pulse.radius+18),16,Color(1,0.94,0.73,fade),true)

func flame_shape(p: Vector2, height: float, phase: float, alpha: float = 1.0):
	# Curved, independently curling tongues; warm translucent edges around a bright root.
	for layer in 3:
		var h = height*[1.0,0.74,0.40][layer]
		var points = PackedVector2Array()
		for side in [1,-1]:
			for n in (range(9) if side == 1 else range(1,8)):
				var t = float(n if side == 1 else 8-n)/8.0
				var curl = (sin(sea_time*5.1+phase+t*3.7)*0.17+sin(sea_time*8.3+phase*2.1+t*5)*0.06)*h*t
				var width = pow(maxf(0,sin(PI*pow(t,0.72))),0.8)*h*0.24*(1-t*0.5)
				points.append(p+Vector2(curl+side*width,-t*h))
		var color = [Color(1,0.24,0.035,alpha*0.72),Color(1,0.59,0.075,alpha*0.88),Color(1,0.91,0.43,alpha*0.95)][layer]
		# Render short convex sections: tiny curling tongues can defeat polygon triangulation.
		for n in range(8):
			var left0 = points[n]
			var left1 = points[n+1]
			var right0 = points[16-n] if n > 0 else points[0]
			var right1 = points[16-(n+1)] if n < 7 else points[8]
			if n == 0: draw_primitive(PackedVector2Array([left0,left1,right1]),PackedColorArray([color]),PackedVector2Array())
			elif n == 7: draw_primitive(PackedVector2Array([left0,left1,right0]),PackedColorArray([color]),PackedVector2Array())
			else: draw_primitive(PackedVector2Array([left0,left1,right1,right0]),PackedColorArray([color]),PackedVector2Array())

func draw_flame_jet(b: Dictionary):
	var direction: Vector2 = (b.b-b.a).normalized()
	var normal = direction.orthogonal()
	var front = minf(1,b.t*1.15)
	# A rolling plume travels outward, rather than a solid luminous beam.
	for n in 24:
		var t = float(n)/23.0*front
		var age = fmod(sea_time*2.7+n*0.618,1.0)
		var q = b.a.lerp(b.b,t)+normal*sin(n*2.1+sea_time*13)*(3+t*9)
		var radius = (5+t*(13+b.tier))*sin(PI*clampf(b.t,0.08,0.96))*(0.75+age*0.4)
		for layer in 3:
			draw_circle(q,radius*(1-layer*0.24),[Color(1,0.27,0.04,0.25),Color(1,0.48,0.055,0.52),Color(1,0.79,0.23,0.70)][layer])
		if n%3 == 0: flame_shape(q,radius*(1.7+age),n*2.7,0.72)

func draw_ship_conditions(e: Dictionary):
	if e.hp <= 0: return
	var p: Vector2 = e.p
	var scale_ = 1.35 if e.get('boss',false) else 1.0
	if e.get('oiled',false) or e.get('slow_time',0.0) > 0:
		var oil: bool = e.get('oiled',false)
		for n in 3:
			var phase = fmod(sea_time*0.65+n/3.0,1.0)
			var tint = Color(0.50,0.62,0.25,(1-phase)*0.8) if oil else Color(0.65,0.93,1.0,(1-phase)*0.85)
			draw_set_transform(p+Vector2(0,-15),0,Vector2(1,0.32))
			draw_arc(Vector2.ZERO,(35+phase*40)*scale_,0,TAU,48,tint,4,true)
			draw_set_transform(Vector2.ZERO)
		for n in 3:
			var q = p+Vector2((n-1)*28,-55+sin(sea_time*3+n)*4)*scale_
			draw_polyline(PackedVector2Array([q+Vector2(-6,-7),q,q+Vector2(6,-7)]),Color('#b5e9f3') if not oil else Color('#b3cb6a'),3,true)
	if e.get('burn_time',0.0) > 0:
		var seed_: float = e.phase
		var intensity = 0.85+e.get('burn_stacks',1)*0.1
		# Wisps drift above localized deck fires, fading before they hide the sails.
		for n in 9:
			var age = fmod(sea_time*(0.34+(n%3)*0.06)+n*0.618+seed_*0.1,1.0)
			var smoke = p+Vector2(sin(n*4.7)*24+age*24,-53-age*88)*scale_
			var radius = (5+age*12)*scale_
			var opacity = sin(age*PI)*0.12
			draw_circle(smoke,radius,Color(0.35,0.33,0.30,opacity))
			draw_circle(smoke+Vector2(-4,-3),radius*0.75,Color(0.55,0.49,0.39,opacity*0.6))
		for n in 9:
			var phase = n*2.399+seed_
			var age = fmod(sea_time*(0.8+(n%3)*0.17)+n*0.618,1.0)
			var life = sin(PI*age)
			var q = p+Vector2(sin(phase)*30,-38+cos(phase*1.7)*7-age*12)*scale_
			var height = (16+life*(16+(n%3)*5))*scale_*intensity
			flame_shape(q,height,phase,0.45+life*0.5)
		for n in 9:
			var rise = fmod(sea_time*(0.65+n*0.025)+n*0.618,1.0)
			var q = p+Vector2(sin(n*4.7)*25+sin(rise*5+n)*rise*13,-45-rise*88)*scale_
			draw_line(q,q+Vector2(1,3+rise*2),Color(1,0.68+0.2*(n%2),0.21,sin(rise*PI)*0.8),1.5,true)
	if e.get('armor_time',0.0) > 0:
		var center = p+Vector2(0,-80)*scale_
		var pulse = sin(sea_time*3)*2
		for side in [-1,1]:
			var q = center+Vector2(side*(7+pulse),0)
			var shard = PackedVector2Array([q+Vector2(side*3,-14),q+Vector2(side*14,-10),q+Vector2(side*12,3),q+Vector2(side*3,13),q+Vector2(side*6,2),q+Vector2(-side*1,-3)])
			draw_colored_polygon(shard,Color('#b1c7c9'))
			draw_polyline(shard,Color('#6a858b'),2,true)
			draw_line(q+Vector2(side*17,-1),q+Vector2(side*22,4),Color('#f4cb82'),2,true)

func spawn_enemy(offset = 0.0, pos = Vector2(-70,0), boss = false):
	super.spawn_enemy(offset,pos,boss)
	var e = enemies.back()
	if not boss and wave >= 3 and wave <= 10:
		var roll = randi_range(0,9)
		var kind = 'armored' if roll < (3 if wave >= 6 else 2) else 'runner' if roll < 5 else 'walker'
		e.kind = kind
		e.hp = (42.0+wave*14+wave*wave*3.0)*({'armored':2.1,'runner':0.65,'walker':1.0}[kind])
		e.max = e.hp
		e.speed = randf_range(51,63)*(1.6 if kind == 'runner' else 1.0)*(1+minf(wave,30)*0.012)
	e.speed *= 1.12 if wave <= 2 else 1.20
	if wave >= 3:
		e.hp *= 1.0+minf(wave-2,8)*0.035
		e.max = e.hp
		e.speed *= 1.08

func acquire_target(i: int):
	if not focused.is_empty() and can_target(focused,i): return focused
	if families[i] == 0 and branches[i] == 2:
		var target = null
		var score = -INF
		for e in enemies:
			if not can_target(e,i): continue
			var priority = e.p.x+(700 if e.get('boss',false) else 350 if e.kind == 'armored' else 0)
			if priority > score: score = priority; target = e
		return target
	return super.acquire_target(i)

func can_target(e: Dictionary, i: int) -> bool:
	if e.get('hp',0) <= 0 or e.p.x < 48 or e.p.x > 1060: return false
	var muzzle = slot_rect(i).get_center()+Vector2(-50,0)
	var reach = [475.0,510.0,430.0][families[i]]+mini(7,slots[i]-1)*5.0+maxi(0,slots[i]-5)*40.0
	return muzzle.distance_to(e.p+Vector2(6,-50)) <= reach

func fleet_spawn_interval() -> float:
	var interval = maxf(0.30,0.98-wave*0.022)
	return interval if wave <= 2 else interval*0.78

func throw_grenade(p: Vector2):
	if grenade_cd > 0: return
	grenade_cd = maxf(8,20-upgrades[1]*3)
	aim_grenade = false
	stone_rains.append({'p':p,'t':0.0,'landed':false,'damage':170+wave*12})
	if harbor_audio: harbor_audio.specialty_weapon(1,2,4)

func update_stone_rain(dt: float):
	for rain in stone_rains:
		rain.t += dt
		if rain.t >= 0.62 and not rain.landed:
			rain.landed = true
			shake = 12
			for e in enemies:
				if e.hp > 0 and e.p.distance_to(rain.p+Vector2(0,30)) < 190:
					mark_impact(e,1,5)
					deal_damage(e,rain.damage,'SPLASH')
			burst(rain.p,Color('#c1e9e5'),38)
			if harbor_audio: harbor_audio.specialty_impact(1,2,false,5)
	stone_rains = stone_rains.filter(func(rain): return rain.t < 1.6)

func draw_stone_rain():
	for rain in stone_rains:
		var p: Vector2 = rain.p
		var age: float = rain.t
		if age < 0.62:
			var progress = age/0.62
			draw_circle(p,190,Color(1,0.83,0.44,0.08))
			for n in 16: draw_arc(p,190,n*TAU/16,n*TAU/16+0.25,6,Color(1,0.89,0.60,0.65),3,true)
			for n in 7:
				var landing = p+Vector2.from_angle(n*2.399)*sqrt(float(n)/7.0)*145
				ellipse(landing,Vector2(22,9)*(0.5+progress*0.5),Color(0.16,0.32,0.34,progress*0.35))
				var q = landing+Vector2(55,-500)*(1-progress*progress)
				draw_line(q+Vector2(12,-88),q,Color(0.91,0.94,0.86,progress*0.6),5,true)
				draw_set_transform(q,age*4+n)
				var rock = PackedVector2Array([Vector2(-20,-9),Vector2(-7,-22),Vector2(15,-17),Vector2(22,2),Vector2(8,19),Vector2(-15,16)])
				draw_colored_polygon(rock,Color('#737d83'))
				draw_colored_polygon(PackedVector2Array([rock[0],rock[1],rock[2],Vector2(0,0)]),Color('#b8bbaa'))
				draw_set_transform(Vector2.ZERO)
		else:
			var t = age-0.62
			var fade = maxf(0,1-t/0.98)
			for n in 7:
				var landing = p+Vector2.from_angle(n*2.399)*sqrt(float(n)/7.0)*145
				ellipse(landing,Vector2(22+t*85,8+t*30),Color(0.79,0.97,0.96,fade*0.25))
				for j in 6:
					var angle_ = j*TAU/6+n
					var q = landing+Vector2(cos(angle_)*t*100,sin(angle_)*t*40-t*160+t*t*210)
					draw_circle(q,(4+j%3)*fade,Color(0.80,0.96,0.95,fade))
					var shard = landing+Vector2(cos(angle_)*t*75,sin(angle_)*t*55-t*95+t*t*145)
					draw_line(shard,shard+Vector2(5,-3)*fade,Color(0.48,0.53,0.54,fade),4*fade,true)
			if t < 0.18: draw_circle(p,30+t*500,Color(1,0.93,0.69,(1-t/0.18)*0.24))

func draw_rally_buff():
	if over_time <= 0: return
	var elapsed = 7.0-over_time
	var fade = minf(1.0,over_time/0.45)
	for i in 5:
		if slots[i] <= 0: continue
		var center = slot_rect(i).get_center()
		var pulse = 0.85+sin(elapsed*9)*0.15
		# Keep the tower sprite unobscured: use only line effects and the haste badge.
		draw_set_transform(center+Vector2(0,34),0,Vector2(1,0.32))
		draw_arc(Vector2.ZERO,51,0,TAU,56,Color(0.32,0.24,0.10,fade),10,true)
		draw_arc(Vector2.ZERO,51,0,TAU,56,Color(1,0.78,0.19,fade),6,true)
		draw_arc(Vector2.ZERO,48,0,TAU,56,Color(1,0.97,0.69,fade*pulse),2,true)
		draw_set_transform(Vector2.ZERO)
		if elapsed < 0.65:
			draw_arc(center,28+elapsed*100,0,TAU,48,Color(1,0.86,0.32,(1-elapsed/0.65)*0.9),5,true)
		for n in 3:
			var phase = fmod(elapsed*1.5+n/3.0,1.0)
			var points = PackedVector2Array()
			for j in 19:
				var angle_ = elapsed*7+n*TAU/3+j*0.085
				points.append(center+Vector2(cos(angle_)*51,29-phase*69+sin(angle_)*14))
			var opacity = (0.4+sin(phase*PI)*0.6)*fade
			draw_polyline(points,Color(0.42,0.27,0.08,opacity*0.7),7,true)
			draw_polyline(points,Color(1,0.78,0.20,opacity),4.5,true)
			draw_polyline(points,Color(1,0.97,0.72,opacity),1.5,true)
		# Fixed badge remains visible even between firing animations.
		var badge = center+Vector2(-43,-40)
		draw_circle(badge,19,Color(0.19,0.34,0.29,fade))
		draw_arc(badge,19,0,TAU,32,Color(1,0.81,0.25,fade),3,true)
		for n in 3:
			var q = badge+Vector2(0,9-n*8)
			var alpha = (0.65+0.35*sin(elapsed*10-n))*fade
			draw_polyline(PackedVector2Array([q+Vector2(-9,3),q+Vector2(0,-3),q+Vector2(9,3)]),Color(1,0.91,0.43,alpha),3.5,true)

func draw_overlay(title: String, sub: String):
	# Draw the pause panel last, above combat effects and projectiles.
	if title != 'PAUSED': super.draw_overlay(title,sub)

func draw_pause_menu():
	draw_rect(Rect2(0,0,1600,900),Color(0.1,0.3,0.31,0.72))
	panel(Rect2(520,230,560,324 if OS.has_feature('web') else 410))
	text_at('PAUSED',Vector2(716,295),38,Color('#477970'),true)
	button(Rect2(580,341,440,68),'RESUME','Return to the harbor',true,'ESC')
	button(Rect2(580,427,440,68),'RESTART','Start a new run from wave 1')
	if not OS.has_feature('web'):
		button(Rect2(580,513,440,68),'QUIT GAME','Close the game')

func exit_game():
	if OS.has_feature('web'):
		JavaScriptBridge.eval('window.harborExit()',true)
	else:
		get_tree().quit()
