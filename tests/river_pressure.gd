extends SceneTree
func _initialize(): check.call_deferred()
func check():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g)
	await process_frame
	g.set_process(false); g.testing = true; g.muted = true
	for scenario in [[1,2],[3,3],[5,4],[10,6]]:
		seed(4126)
		g.start_game(); g.slots.fill(0)
		for i in 5:
			g.slots[i] = scenario[1]; g.families[i] = [0,0,1,2,2][i]
			g.branches[i] = [1,2,2,1,2][i] if scenario[1] >= 3 else 0
		g.wave = scenario[0]-1; g.call_wave()
		var total_x = 0.0; var deaths = 0; var furthest = 0.0; var ticks = 0
		while g.active and g.health > 0 and ticks < 4000:
			var before = g.enemies.duplicate()
			g._process(0.05); ticks += 1
			for e in before:
				furthest = maxf(furthest,e.p.x)
				if e.hp <= 0: total_x += e.p.x; deaths += 1
		print('wave=',scenario[0],' tier=',scenario[1],' first=',snappedf(g.first_kill_x,1),' mean=',snappedf(total_x/maxi(1,deaths),1),' furthest=',snappedf(furthest,1),' portHP=',g.health,' killed=',deaths)
		assert(g.offscreen_kills == 0)
		assert(g.first_kill_x > 650 and total_x/maxi(1,deaths) > 740)
		assert(not g.active and g.health > 0)
		if scenario[0] == 10: assert(g.health < g.max_health)
	g.queue_free(); await process_frame
	quit()
