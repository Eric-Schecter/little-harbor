extends SceneTree
func _initialize(): record.call_deferred()
func record():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g)
	await frames(30)
	for phase in 3:
		g.start_game(); g.slots.fill(0); g.wave = 20
		g.active = true; g.remaining = 1; g.spawn_time = 100
		g.spawn_enemy(0,Vector2(720,490),true)
		g.enemies[0].speed = 8
		if phase == 0:
			g.slots[2] = 5; g.families[2] = 0; g.branches[2] = 1
			g.toast_msg('RAPID BOW  /  MULTI-HIT')
		elif phase == 1:
			g.slots[2] = 4; g.families[2] = 1; g.branches[2] = 2
			for offset in [Vector2(-50,-65),Vector2(-75,75),Vector2(-80,220)]:
				g.spawn_enemy(0,Vector2(720,490)+offset)
				g.enemies[-1].speed = 8
			g.toast_msg('SIEGE STONE  /  AREA + SLOW')
		else:
			for i in [1,2,3]: g.slots[i] = 4
			g.families[1] = 2; g.branches[1] = 1
			g.families[2] = 2; g.branches[2] = 2
			g.families[3] = 0; g.branches[3] = 2
			g.toast_msg('FLAME + OIL + ARMOR BREAK')
		g.toast_time = 6
		await frames(210)
	g.paused = true
	await frames(15)
	quit()
func frames(count: int):
	for i in count: await RenderingServer.frame_post_draw
