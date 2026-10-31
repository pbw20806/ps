extends Node

func _ready() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	for target in ["menu", "settings", "connect", "lobby", "selection", "intro"]:
		Lobby.active = target in ["lobby", "selection", "intro"]
		Lobby.players = {
			1: {"name": "테스트 방장", "character": 0, "ready": false},
			2: {"name": "손님 둘", "character": 1, "ready": true},
			3: {"name": "손님 셋", "character": 2, "ready": false},
			4: {"name": "손님 넷", "character": 3, "ready": true}}
		ui.screen = target
		ui.render()
		for frame in range(4):
			await get_tree().process_frame
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/mystery-" + target + ".png")
		var limit := get_viewport().get_visible_rect().size
		var valid := check_bounds(ui, limit)
		print("UI %s viewport %s layout %s" % [target, limit, "PASS" if valid else "FAIL"])
		if not valid:
			get_tree().quit(1)
			return
	Lobby.active = false
	print("PASS six UI screens constructed within viewport")
	get_tree().quit(0)

func check_bounds(node: Node, limit: Vector2) -> bool:
	var valid := true
	if node is Button or node is Label or node is LineEdit:
		var rect: Rect2 = node.get_global_rect()
		if rect.end.y > limit.y + 1 or rect.end.x > limit.x + 1:
			print("OVERFLOW: %s at %s" % [node.text, rect])
			valid = false
	for child in node.get_children():
		valid = check_bounds(child, limit) and valid
	return valid
