extends SceneTree

func _initialize():
	record.call_deferred()

func record():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await create_timer(2.0).timeout
	game.input_click(Vector2(700,450))
	# A reproducible close-approach setup in the actual default game scene.
	# Combat stats, attack timings, health, visuals and sound remain unmodified.
	seed(4821)
	game.wave = 9
	game.call_wave()
	game.enemies.clear()
	game.remaining = 0
	game.toast_time = 0
	game.spawn_enemy(0,Vector2(830,350))
	game.enemies.back().kind = 'walker'
	game.spawn_enemy(0,Vector2(750,650))
	game.enemies.back().kind = 'runner'
	game.spawn_enemy(0,Vector2(650,490),true)
	await create_timer(18.0).timeout
	print('RECORDING: health=',game.health,' cannon shots=',game.harbor_audio.events.ship_cannon,' impacts=',game.harbor_audio.events.hull_hit)
	game.paused = true
	await create_timer(0.5).timeout
	quit()
