extends SceneTree
func _initialize():
	check.call_deferred()
func check():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	assert(not game.menu and game.wave == 0 and not game.active, 'Direct boot to preparation')
	game.testing = true; game.muted = true
	for i in range(5,15): game.slots[i] = 0; game.tower_costs[i] = 0
	game.buy_family(0); game.buy_family(0)
	assert(game.coins == 76)
	game.move_tower(5,6)
	assert(game.sell_value(6) == 12 and game.tower_costs[6] == 24)
	game.move_tower(6,7)
	assert(game.sell_value(7) == 12 and game.tower_costs[6] == 0)
	game.selected = 7
	game.input_click(Vector2(1200,855))
	assert(game.coins == 88 and game.slots[7] == 0 and game.selected == -1)
	game.sell_selected(); assert(game.coins == 88)
	game.upgrades[2] = 1
	game.buy_family(1)
	assert(game.slots[5] == 2 and game.sell_value(5) == 10)
	game.selected = 5
	var key = InputEventKey.new(); key.pressed = true; key.keycode = KEY_X
	game._unhandled_input(key)
	assert(game.coins == 78 and game.slots[5] == 0)
	game.testing = false
	game.spawn_enemy(0,Vector2(700,300),true)
	game.fire_tower(0,game.enemies[0])
	assert(game.tower_cycles.has(0))
	game.selected = 0; game.sell_selected()
	assert(not game.tower_cycles.has(0) and game.slots[0] == 0)
	game.start_game()
	assert(game.tower_costs[0] == 12 and game.coins == 100)
	print('PASS: direct preparation, accumulated merge value, swap, click/shortcut sale, no duplicate refund, upgraded purchase cost, loading cancellation, reset')
	game.queue_free()
	await create_timer(0.3).timeout
	quit()
