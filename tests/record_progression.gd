extends SceneTree
func _initialize(): record.call_deferred()
func record():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g)
	g.start_game(); g.slots.fill(0); g.wave = 16
	g.active = true; g.remaining = 1; g.spawn_time = 100
	for i in 5:
		g.slots[i] = [6,7,8,6,7][i]
		g.families[i] = [0,0,1,2,2][i]
		g.branches[i] = [1,2,2,1,2][i]
	for i in 5: g.spawn_enemy(0,Vector2(680,180+i*128),true)
	g.toast_msg('LEVEL 6 / 7 / 8  -  ADVANCED DEFENSE')
	g.toast_time = 5
	for i in 210: await RenderingServer.frame_post_draw
	g.queue_free()
	await process_frame
	quit()
