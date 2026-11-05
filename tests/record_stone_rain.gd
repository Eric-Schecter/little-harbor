extends SceneTree
func _initialize(): record.call_deferred()
func record():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g)
	g.start_game(); g.slots.fill(0); g.wave = 8; g.active = true; g.remaining = 1; g.spawn_time = 100
	for p in [Vector2(680,430),Vector2(750,490),Vector2(620,535)]: g.spawn_enemy(0,p)
	await frames(30)
	g.input_click(Vector2(584,858))
	await frames(30)
	g.input_click(Vector2(790,440))
	await frames(90)
	g.queue_free(); await process_frame; quit()
func frames(n):
	for i in n: await RenderingServer.frame_post_draw
