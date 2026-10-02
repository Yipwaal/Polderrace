extends Node
## Screenshots of the online screen (NetUi): start a host and a player, each in its own window, at the same size:
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1280x720 res://tools/shot_net.tscn -- out=/abs/dir role=host
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1280x720 res://tools/shot_net.tscn -- out=/abs/dir role=guest
## host: net_host.png (its game with the player in it), then it closes the game. guest: net_lobby.png (the list),
## net_guest.png (in the game), net_closed.png (the host closed the game: message and the list again).
## Each plays on its own save file, never the player's.

var out := "/tmp"

func _ready() -> void:
	get_tree().create_timer(300, true, false, true).timeout.connect(func(): get_tree().quit(1))
	var a := {"out": "/tmp", "role": "guest"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	out = a.out
	DirAccess.make_dir_recursive_absolute(out)
	G.use_store("user://shot-net-%s.json" % a.role, {})
	G.prefs.nick = "Yip" if a.role == "host" else "Fenna"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null:
		await get_tree().process_frame
	Menu.homePanel("play")
	if a.role == "host":
		Menu.netOpen()
		Net.netCreate()
		while Net.net.remotes.is_empty():
			await get_tree().process_frame
		await get_tree().create_timer(1.0).timeout
		await _shot("net_host")
		await get_tree().create_timer(3.0).timeout
		Net.netLeave()
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()
		return
	Menu.netOpen()
	var t0 := Time.get_ticks_msec()
	while Net.lobbies().is_empty() and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _shot("net_lobby")
	Net.netJoin(Net.lobbies()[0].ip)
	while Net.net != null and not Net.net.game.is_connected_room():
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	await _shot("net_guest")
	while Net.net != null:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _shot("net_closed")
	get_tree().quit()

func _shot(n: String) -> void:
	for _i in 3: await RenderingServer.frame_post_draw
	var p := out + "/" + n + ".png"
	get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)
