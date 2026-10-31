extends Node

var role := 0
var started := 0
var selection_at := 0
var collision_sent := false
var saw_intro := false
var saw_four := false
var invalid_tested := false
var lock_tested := false
var cancel_tested := false
var completion_at := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		get_tree().quit(1)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = int(args[0])
	started = Time.get_ticks_msec()
	Lobby.failed.connect(func(message: String): push_error(message); get_tree().quit(1))
	var result: Error
	if role == 0:
		result = Lobby.host_room("Host", 25489)
		Lobby.start_selection()
		check(Lobby.phase == "lobby", "must not start with fewer than four")
	else:
		result = Lobby.join_room("Guest%d" % role, "127.0.0.1", 25489)
	check(result == OK, "could not create network peer")

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - started > 18000:
		push_error("TEST TIMEOUT role %d phase %s players %d" % [role, Lobby.phase, Lobby.players.size()])
		get_tree().quit(1)
		return
	if not Lobby.active:
		return
	if role == 0 and Lobby.phase == "lobby" and Lobby.players.size() == 4 and not saw_four:
		saw_four = true
		Lobby.start_selection()
	if Lobby.phase == "selection":
		if selection_at == 0:
			selection_at = Time.get_ticks_msec()
		if not collision_sent:
			collision_sent = true
			Lobby.choose(0)
			if role != 0:
				# Non-authority cannot change phase by invoking the host-only API.
				Lobby.start_selection()
			return
		var elapsed := Time.get_ticks_msec() - selection_at
		if elapsed < 1200:
			if role == 0 and elapsed > 700:
				var owners := 0
				for data in Lobby.players.values():
					if data.character == 0:
						owners += 1
				check(owners == 1, "simultaneous duplicate choices accepted")
			return
		var me: int = multiplayer.get_unique_id()
		var own: Dictionary = Lobby.players[me]
		if not invalid_tested:
			invalid_tested = true
			Lobby.choose(-1)
			Lobby.choose(4)
		if own.character != role:
			Lobby.choose(role)
		elif not cancel_tested:
			# Confirm and cancel before all peers finish choosing.
			cancel_tested = true
			Lobby.confirm_choice()
			Lobby.confirm_choice()
		elif elapsed > 2200 and not own.ready:
			Lobby.confirm_choice()
		elif own.ready and not lock_tested:
			lock_tested = true
			Lobby.choose((role + 1) % 4)
	if Lobby.phase == "intro":
		if not saw_intro:
			saw_intro = true
			completion_at = Time.get_ticks_msec()
			check(Lobby.players[multiplayer.get_unique_id()].character == role, "confirmed choice changed unexpectedly")
			var assigned: Array = []
			for data in Lobby.players.values():
				check(data.ready, "unconfirmed player in intro")
				check(not assigned.has(data.character), "duplicate character in final roster")
				assigned.append(data.character)
			print("PASS role %d: synchronized four unique confirmed characters" % role)
		if role == 3 and Time.get_ticks_msec() - completion_at > 500:
			Lobby.leave()
			get_tree().quit(0)
	if saw_intro and Lobby.phase == "lobby" and Lobby.players.size() == 3:
		for data in Lobby.players.values():
			check(data.character == -1 and not data.ready, "disconnect must release all selections")
		print("PASS role %d: disconnect returns remaining peers to lobby" % role)
		get_tree().quit(0)
