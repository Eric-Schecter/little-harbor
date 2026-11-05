extends SceneTree
func _initialize(): record.call_deferred()
func record():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g)
	seed(4126)
	g.start_game(); g.slots.fill(0)
	for i in 5:
		g.slots[i] = 4; g.families[i] = [0,0,1,2,2][i]; g.branches[i] = [1,2,2,1,2][i]
	g.wave = 4; g.call_wave()
	for i in 750: await RenderingServer.frame_post_draw
	g.queue_free(); await process_frame
	quit()
