extends SceneTree
func _initialize():
	check.call_deferred()
func check():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.testing = true
	game.start_game()
	for i in range(5,15): game.slots[i] = 0
	for family in 3:
		game.input_click(Vector2(80+family*178,855))
		assert(game.slots[5+family] == 1 and game.families[5+family] == family)
	assert(game.coins == 64 and not game.active)
	var key = InputEventKey.new(); key.pressed = true; key.keycode = KEY_W
	game._unhandled_input(key)
	assert(game.slots[8] == 1 and game.families[8] == 1 and game.coins == 52)
	game.input_click(game.workshop_button_position()); assert(game.workshop)
	game.workshop = false
	game.harbor_audio.update_state(0.1,0,true)
	for family in 3:
		for branch in [1,2]:
			var name_ = game.harbor_audio.specialty_name(family,branch)
			assert(game.harbor_audio.clips.has(name_+'_release') and game.harbor_audio.clips.has(name_+'_hit'))
			game.harbor_audio.specialty_weapon(family,branch,4)
			game.harbor_audio.specialty_impact(family,branch,false)
			assert(game.harbor_audio.events[name_+'_release'] == 1 and game.harbor_audio.events[name_+'_hit'] >= 1)
			game.enemies.clear(); game.pending_hits.clear(); game.shots.clear()
			game.spawn_enemy(0,Vector2(750,490),true)
			game.slots[2] = 4; game.families[2] = family; game.branches[2] = branch
			game.fire_tower(2,game.enemies[0])
			assert(game.shots[0].family == family and game.shots[0].branch == branch and game.shots[0].tier == 4)
	game.start_game()
	assert(game.weapon_impacts.is_empty())
	print('PASS: direct purchase buttons and hotkey, costs, workshop, six distinct release/impact clips, projectile identity, reset')
	game.queue_free()
	await create_timer(0.3).timeout
	quit()
