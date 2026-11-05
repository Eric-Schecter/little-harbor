extends SceneTree
func _initialize(): check.call_deferred()
func check():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g)
	await process_frame
	g.set_process(false); g.testing = true; g.muted = true
	g.start_game()
	for tier in range(5,8):
		g.slots[5] = tier; g.slots[6] = tier
		g.families[5] = 1; g.families[6] = 1; g.branches[5] = 2; g.branches[6] = 2
		g.move_tower(5,6)
		assert(g.slots[6] == tier+1 and g.slots[5] == 0)
	g.slots[5] = 8; g.move_tower(5,6)
	assert(g.slots[5] == 8 and g.slots[6] == 8)
	g.start_game(); g.slots.fill(0); g.wave = 6
	for p in [Vector2(700,400),Vector2(700,480),Vector2(700,510)]: g.spawn_enemy(0,p)
	for e in g.enemies: e.hp = 1000; e.max = 1000; e.kind = 'walker'
	g.resolve_projectile({'enemy':g.enemies[0],'family':1,'branch':2,'tier':4,'damage':100})
	assert(is_equal_approx(g.enemies[0].hp,905))
	assert(g.enemies[1].hp > g.enemies[0].hp and g.enemies[2].hp == 1000)
	g.enemies[0].kind = 'armored'; g.enemies[0].hp = 1000
	g.resolve_projectile({'enemy':g.enemies[0],'family':1,'branch':2,'tier':4,'damage':100})
	assert(g.enemies[0].hp > 945)
	for family in [1,0,-1]:
		seed(70421)
		g.start_game(); g.slots.fill(0)
		for i in 5:
			g.slots[i] = 3; g.families[i] = family if family >= 0 else [0,0,1,2,2][i]; g.branches[i] = 2 if family >= 0 else [1,2,2,1,2][i]
		var reached = 0
		for wave in range(1,11):
			g.call_wave()
			var ticks = 0
			while g.active and g.health > 0 and ticks < 5000:
				g._process(0.05); ticks += 1
			reached = wave
			if g.health <= 0: break
		print('FIXED LV3 family=',family,' reached=',reached,' health=',g.health)
	print('PASS: levels 5-8, max cap, splash falloff, armored resistance')
	quit()
