extends SceneTree
func _initialize():
	record.call_deferred()
func record():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await frames(15)
	for stage in 3:
		game.start_game()
		game.slots.fill(0)
		game.active = true
		game.remaining = 1
		game.spawn_time = 1000
		game.wave = 5
		for family in 3:
			var slot = family * 2
			game.slots[slot] = 1 if stage == 0 else 5
			game.families[slot] = family
			game.branches[slot] = stage
			game.spawn_enemy(0,Vector2(860,game.slot_rect(slot).get_center().y),true)
			var enemy = game.enemies.back()
			enemy.hp = 100000
			enemy.max = 100000
			enemy.speed = 0
		game.toast_msg(['BASE TOWERS - CLEAN LAUNCH','UPGRADE ROUTE I - CLEAN LAUNCH','UPGRADE ROUTE II - CLEAN LAUNCH'][stage])
		game.toast_time = 6
		await frames(180)
	print('CAPTURE PASS: three families, base and both upgrade routes')
	quit()
func frames(count: int):
	for i in count: await RenderingServer.frame_post_draw
