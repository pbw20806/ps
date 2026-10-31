extends Node

signal changed
signal failed(message: String)

const DEFAULT_PORT := 24567
const CAPACITY := 4
var players: Dictionary = {}
var phase := "lobby"
var active := false
var connecting := false
var nickname := ""
var address := ""
var port := DEFAULT_PORT
var connection_deadline := 0

func _ready() -> void:
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): _fail("접속하지 못했습니다. IP, UDP 포트와 방장 실행 여부를 확인해 주세요."))
	multiplayer.server_disconnected.connect(func(): _fail("방장과 연결이 끊어졌습니다. 메인 화면으로 돌아갑니다."))
	multiplayer.peer_disconnected.connect(_disconnected)

func _process(_delta: float) -> void:
	if connecting and Time.get_ticks_msec() > connection_deadline:
		_fail("연결 시간이 초과되었습니다. 주소와 방화벽 설정을 확인해 주세요.")

func host_room(player_name: String, room_port: int) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(room_port, CAPACITY - 1)
	if result != OK:
		return result
	multiplayer.multiplayer_peer = peer
	active = true
	port = room_port
	nickname = clean_name(player_name)
	players = {1: {"name": nickname, "character": -1, "ready": false}}
	phase = "lobby"
	changed.emit()
	return OK

func join_room(player_name: String, host_address: String, room_port: int) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(host_address.strip_edges(), room_port)
	if result != OK:
		return result
	nickname = clean_name(player_name)
	address = host_address.strip_edges()
	port = room_port
	connecting = true
	connection_deadline = Time.get_ticks_msec() + 10000
	multiplayer.multiplayer_peer = peer
	return OK

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	phase = "lobby"
	active = false
	connecting = false

func clean_name(value: String) -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").left(16)
	return clean if not clean.is_empty() else "손님"

func is_host() -> bool:
	return active and multiplayer.is_server()

func _connected() -> void:
	_request_join.rpc_id(1, nickname)

@rpc("any_peer", "call_remote", "reliable")
func _request_join(player_name: String) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if players.has(sender):
		return
	if phase != "lobby" or players.size() >= CAPACITY:
		_rejected.rpc_id(sender, "이미 시작했거나 가득 찬 방입니다.")
		return
	players[sender] = {"name": clean_name(player_name), "character": -1, "ready": false}
	publish()

@rpc("authority", "call_remote", "reliable")
func _rejected(message: String) -> void:
	_fail(message)

func _fail(message: String) -> void:
	leave()
	failed.emit(message)
	changed.emit()

func _disconnected(peer_id: int) -> void:
	if not is_host() or not players.has(peer_id):
		return
	players.erase(peer_id)
	# A missing player invalidates selection; return everyone to an open lobby.
	phase = "lobby"
	for data in players.values():
		data.character = -1
		data.ready = false
	publish()

func start_selection() -> void:
	if is_host() and phase == "lobby" and players.size() == CAPACITY:
		phase = "selection"
		publish()

func choose(character_id: int) -> void:
	if is_host():
		_apply_choice(1, character_id)
	elif active:
		_request_choice.rpc_id(1, character_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_choice(character_id: int) -> void:
	if is_host():
		_apply_choice(multiplayer.get_remote_sender_id(), character_id)

func _apply_choice(peer_id: int, character_id: int) -> void:
	if phase != "selection" or not players.has(peer_id) or character_id < 0 or character_id > 3:
		return
	if players[peer_id].ready:
		return
	for other in players:
		if other != peer_id and players[other].character == character_id:
			return
	players[peer_id].character = character_id
	publish()

func confirm_choice() -> void:
	if is_host():
		_apply_confirm(1)
	elif active:
		_request_confirm.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _request_confirm() -> void:
	if is_host():
		_apply_confirm(multiplayer.get_remote_sender_id())

func _apply_confirm(peer_id: int) -> void:
	if phase != "selection" or not players.has(peer_id) or players[peer_id].character < 0:
		return
	players[peer_id].ready = not players[peer_id].ready
	var all_ready := players.size() == CAPACITY
	for data in players.values():
		all_ready = all_ready and data.ready
	if all_ready:
		phase = "intro"
	publish()

func reopen_lobby() -> void:
	if not is_host():
		return
	phase = "lobby"
	for data in players.values():
		data.character = -1
		data.ready = false
	publish()

func publish() -> void:
	_sync.rpc(players, phase)
	changed.emit()

@rpc("authority", "call_remote", "reliable")
func _sync(roster: Dictionary, next_phase: String) -> void:
	players = roster
	phase = next_phase
	active = true
	connecting = false
	changed.emit()
