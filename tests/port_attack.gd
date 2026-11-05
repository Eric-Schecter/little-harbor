extends SceneTree

func _initialize():
	check.call_deferred()

func check():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.testing = true
	game.muted = true
	assert(not game.menu, 'Boot goes directly to preparation')
	assert(not game.menu and game.coins == 100)
	game.slots.fill(0)
	game.active = true
	game.remaining = 1
	game.spawn_time = 100
	game.spawn_enemy(0,Vector2(982,351.5))
	var ship = game.enemies[0]
	ship.kind = 'walker'
	ship.anchor_timer = 0.0
	ship.dock = 1
	ship.p = Vector2(game.port_anchor(ship),game.slot_rect(1).get_center().y+35)
	var hp = game.health
	for i in 10: game._process(0.05)
	assert(game.health == hp and game.enemy_cannonballs.size() == 1, 'Firing must not damage the harbor')
	assert(game.port_attack_pose(ship).x < 0, 'Firing recoils away from shore')
	game.paused = true
	var phase = ship.cannon_time
	var flight = game.enemy_cannonballs[0].t
	game._process(0.05)
	assert(ship.cannon_time == phase and game.enemy_cannonballs[0].t == flight)
	game.paused = false
	for i in 8: game._process(0.05)
	assert(game.health == hp, 'Airborne cannonball must not damage harbor')
	game._process(0.05)
	assert(game.health == hp-5 and game.port_impacts.size() == 1)
	for i in 4: game._process(0.05)
	assert(game.health == hp-5, 'A projectile can hit only once')
	game.start_game()
	assert(game.enemy_cannonballs.is_empty() and game.cannon_flashes.is_empty() and game.port_impacts.is_empty())
	game.slots.fill(0)
	game.active = true; game.remaining = 1; game.spawn_time = 100
	game.spawn_enemy(0,Vector2(835,492.5),true)
	ship = game.enemies[0]
	ship.anchor_timer = 0.0
	ship.dock = 2
	ship.p = Vector2(game.port_anchor(ship),game.slot_rect(2).get_center().y+35)
	for i in 21: game._process(0.05)
	assert(game.health == game.max_health and game.enemy_cannonballs.size() == 3, 'Flagship launches three separate balls')
	for i in 11: game._process(0.05)
	assert(game.health == game.max_health-30, 'Flagship volley totals 30 damage on impact')
	ship.cannon_time = 0.5; ship.hp = 0
	hp = game.health
	for i in 12: game._process(0.05)
	assert(game.health == hp and game.enemy_cannonballs.is_empty(), 'Sunk ship cannot launch')
	game.start_game(); game.wave = 30; game.next_time = 0.01
	game._process(0.05)
	assert(game.wave == 31 and game.active)
	print('PASS: endless entry, single cannon, recoil, flight-only delay, pause, one impact, triple flagship volley, sinking, reset, wave 31')
	game.queue_free()
	await create_timer(0.3).timeout
	quit()
