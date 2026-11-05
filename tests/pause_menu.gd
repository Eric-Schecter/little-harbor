extends SceneTree
func _initialize(): check.call_deferred()
func check():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g); await process_frame
	g.set_process(false); g.testing = true; g.muted = true
	g.input_click(Vector2(1560,30)); assert(g.paused)
	g.input_click(Vector2(100,400)); assert(g.paused)
	var event = InputEventKey.new(); event.keycode = KEY_Q; event.pressed = true
	var coins = g.coins; g._unhandled_input(event); assert(g.coins == coins)
	g.input_click(Vector2(800,375)); assert(not g.paused)
	g.wave = 8; g.coins = 1; g.health = 10; g.over_time = 4
	g.input_click(Vector2(1560,30)); g.input_click(Vector2(800,460))
	assert(not g.paused and g.wave == 0 and g.coins == 100 and g.health == 420 and g.over_time == 0)
	g.input_click(Vector2(1560,30))
	print('PASS: pause entry, outside/input blocking, resume, full restart; clicking quit now')
	g.input_click(Vector2(800,547))
