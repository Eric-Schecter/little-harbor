extends SceneTree
func _initialize(): check.call_deferred()
func check():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g); await process_frame
	g.set_process(false); g.testing = true; g.muted = true
	g.start_game(); g.slots.fill(0); g.wave = 5
	g.spawn_enemy(0,Vector2(700,430),true)
	var e = g.enemies[0]; var hp = e.hp
	g.throw_grenade(Vector2(700,400))
	assert(g.stone_rains.size() == 1 and e.hp == hp)
	g.throw_grenade(Vector2(700,400)); assert(g.stone_rains.size() == 1)
	g.paused = true; g._process(0.05); assert(g.stone_rains[0].t == 0)
	g.paused = false
	g.update_stone_rain(0.61); assert(e.hp == hp)
	g.update_stone_rain(0.02); assert(e.hp == hp-230)
	g.update_stone_rain(0.1); assert(e.hp == hp-230)
	g.start_game(); assert(g.stone_rains.is_empty())
	print('PASS: falling before damage, one impact, cooldown, pause, reset')
	g.queue_free(); await process_frame; quit()
