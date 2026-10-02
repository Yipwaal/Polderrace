extends Node
## Screenshots of the online screen: the lobby list (start a host first in another process), and inside a game.
## godot --path godot --rendering-driver opengl3 res://tools/shot_net.tscn -- out=/abs/dir [host=1]

func _ready() -> void:
	get_tree().create_timer(300, true, false, true).timeout.connect(func(): get_tree().quit(1))
	var a := {"out": "/tmp", "host": "0"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null:
		await get_tree().process_frame
	if a.host == "1":
		G.prefs.nick = "Yip"
		Net.netCreate()
		while Net.net.remotes.is_empty():
			await get_tree().process_frame
		NetUi.open()
		await get_tree().create_timer(1.0).timeout
		await _shot(a.out + "/net_host.png")
		await get_tree().create_timer(8.0).timeout
		get_tree().quit()
		return
	G.prefs.nick = "Gast"
	NetUi.open()
	var t0 := Time.get_ticks_msec()
	while Net.lobbies().is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _shot(a.out + "/net_lobby.png")
	Net.netJoin(Net.lobbies()[0].ip)
	await get_tree().create_timer(2.0).timeout
	await _shot(a.out + "/net_guest.png")
	await get_tree().create_timer(4.0).timeout
	get_tree().quit()

func _shot(p: String) -> void:
	for _i in 3: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)
