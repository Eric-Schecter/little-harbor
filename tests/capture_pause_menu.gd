extends SceneTree
func _initialize(): capture.call_deferred()
func capture():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g)
	for i in 10: await RenderingServer.frame_post_draw
	g.input_click(Vector2(1560,30))
	assert(g.paused)
	g.queue_redraw()
	for i in 3: await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png('res://captures/pause-menu.png')
	g.input_click(Vector2(800,547))
