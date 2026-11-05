extends SceneTree
func _initialize():
	record.call_deferred()
func record():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await frames(30)
	game.input_click(game.slot_rect(5).get_center())
	await frames(24)
	game.input_click(Vector2(1200,855))
	await frames(18)
	game.input_click(Vector2(80,855))
	game.input_click(Vector2(258,855))
	game.input_click(Vector2(436,855))
	await frames(60)
	for family in 3:
		for branch in [1,2]:
			game.start_game(); game.slots.fill(0)
			game.wave = 10; game.active = true; game.remaining = 0
			game.slots[2] = 5; game.families[2] = family; game.branches[2] = branch
			game.spawn_enemy(0,Vector2(700,490),true)
			game.toast_msg(game.ROUTES[family][branch-1])
			game.toast_time = 3.6
			await frames(108)
			print(game.ROUTES[family][branch-1],': audio=',game.harbor_audio.events[game.harbor_audio.specialty_name(family,branch)+'_release'])
	game.paused = true
	await frames(9)
	quit()

func frames(count: int):
	for i in count: await RenderingServer.frame_post_draw
