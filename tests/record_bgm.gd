extends SceneTree
func _initialize(): record.call_deferred()
func record():
	var g = load('res://main.tscn').instantiate()
	root.add_child(g)
	await frames(180)
	assert(g.music.playing and not g.music.stream_paused)
	assert(g.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	g.slots[2] = 3; g.families[2] = 0; g.branches[2] = 1
	g.wave = 4; g.call_wave()
	g.spawn_enemy(0,Vector2(760,490),true)
	await frames(180)
	g.paused = true
	await frames(30)
	assert(g.music.stream_paused)
	g.paused = false
	await frames(30)
	assert(not g.music.stream_paused)
	g.muted = true
	await frames(30)
	assert(g.music.stream_paused)
	g.muted = false
	await frames(30)
	assert(not g.music.stream_paused)
	g.music.seek(g.music.stream.get_length()-0.12)
	await frames(30)
	assert(g.music.get_playback_position() < 2.0)
	print('PASS: BGM playing, pause/resume, mute/unmute, real loop boundary')
	g.queue_free(); await process_frame; quit()
func frames(n):
	for i in n: await RenderingServer.frame_post_draw
