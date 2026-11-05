extends SceneTree
func _initialize(): check.call_deferred()
func check():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g)
	await process_frame
	g.set_process(false); g.testing = true; g.muted = true
	g.start_game(); g.slots.fill(0); g.wave = 20
	g.active = true; g.remaining = 1; g.spawn_time = 100
	g.spawn_enemy(0,Vector2(700,490),true)
	var e = g.enemies[0]
	g.slots[2] = 5; g.families[2] = 0; g.branches[2] = 1
	g.release_tower(2,e); g.slots[2] = 0
	assert(g.pending_hits.size() >= 3)
	assert(g.pending_hits[1].time > g.pending_hits[0].time)
	g.paused = true
	var life = g.shots[1].life
	g._process(0.05)
	assert(g.shots[1].life == life and g.bolts.is_empty())
	g.paused = false
	for n in 9: g._process(0.05)
	assert(g.damage_labels.size() >= 2 and e.combo_hits >= 2)
	assert(e.hp_echo > e.hp and e.hp_visible > 0)
	g.spawn_enemy(0,e.p+Vector2(0,65))
	g.spawn_enemy(0,e.p+Vector2(0,220))
	var outside_hp = g.enemies[2].hp
	g.resolve_projectile({'enemy':e,'family':1,'branch':2,'tier':3,'damage':100})
	assert(g.area_pulses[-1].count == 2 and g.enemies[2].hp == outside_hp)
	assert(is_equal_approx(g.enemies[1].slow_time,1.2))
	g.resolve_projectile({'enemy':e,'family':2,'branch':1,'tier':3,'damage':100})
	g.resolve_projectile({'enemy':e,'family':0,'branch':2,'tier':3,'damage':100})
	assert(e.burn_stacks == 1 and e.armor_time == 4)
	for n in 9: g._process(0.05)
	assert(g.damage_labels.any(func(label): return label.kind == 'DOT'))
	g.deal_damage(e,e.hp+500,'HIT')
	assert(g.damage_labels[-1].amount < e.max+500)
	g.start_game()
	assert(g.damage_labels.is_empty() and g.area_pulses.is_empty())
	print('PASS: staggered hits, pause, HP echo, area count, statuses, burn damage, reset')
	quit()
