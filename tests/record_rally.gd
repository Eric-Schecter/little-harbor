extends SceneTree
func _initialize(): record.call_deferred()
func record():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g)
	g.start_game(); g.slots.fill(0); g.wave = 8; g.active = true; g.remaining = 1; g.spawn_time = 100
	for i in 5:
		g.slots[i] = 0 if i == 2 else 3; g.families[i] = [0,0,1,2,2][i]; g.branches[i] = [1,2,2,1,2][i]
		g.spawn_enemy(0,Vector2(760,210+i*130),true)
	await frames(30)
	g.input_click(Vector2(648,858))
	assert(g.over_time > 0)
	await frames(60)
	g.paused = true
	var remaining = g.over_time
	await frames(15)
	assert(g.over_time == remaining)
	g.paused = false
	await frames(195)
	assert(g.over_time == 0)
	print('PASS: actual horn click, pause freeze, buff expires with visuals')
	g.queue_free(); await process_frame; quit()
func frames(n):
	for i in n: await RenderingServer.frame_post_draw
