extends SceneTree
func _initialize():
	check.call_deferred()
func check():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false); game.muted = true
	game.start_game(); game.slots.fill(0)
	game.active = true; game.remaining = 1; game.spawn_time = 100
	game.slots[2] = 3; game.families[2] = 1; game.branches[2] = 2
	game.spawn_enemy(0,Vector2(700,490),true)
	var target = game.enemies[0]
	game.fire_tower(2,target)
	assert(game.pending_hits.is_empty() and game.tower_cycles.has(2))
	for n in 7: game._process(0.05)
	assert(game.pending_hits.is_empty(), 'No projectile before the arm releases')
	game.paused = true
	var time = game.tower_cycles[2].t
	game._process(0.05)
	assert(game.tower_cycles[2].t == time)
	game.paused = false
	for n in 2: game._process(0.05)
	assert(game.tower_cycles[2].released and game.pending_hits.size() == 1)
	game.start_game(); game.slots.fill(0)
	game.slots[2] = 3; game.families[2] = 1; game.branches[2] = 2
	game.active = true; game.remaining = 1; game.spawn_time = 100
	game.spawn_enemy(0,Vector2(700,490),true)
	game.fire_tower(2,game.enemies[0])
	game.move_tower(2,8)
	game._process(0.05)
	assert(game.tower_cycles.is_empty() and game.pending_hits.is_empty(), 'Moving during loading cancels that launch')
	game.start_game()
	assert(game.tower_cycles.is_empty())
	print('PASS: load before release, synchronized projectile, pause, move cancellation, reset')
	game.queue_free()
	await create_timer(0.3).timeout
	quit()
