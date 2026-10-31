extends Control

const GOLD := Color("d6b477")
const PAPER := Color("f3e9d8")
const MUTED := Color("aaa99d")
const CHARACTERS := [
	{"name": "강서윤", "role": "딸 · 재단 실무 책임자", "quote": "아버지의 이야기는, 오늘 끝나야 해요.", "bio": "언니를 잃은 뒤 아버지의 곁을 지켜 온 딸.\n오늘은 유족 대표로 카메라 앞에 선다."},
	{"name": "윤해진", "role": "저택 관리인", "quote": "저는 그저, 진실을 듣고 싶었어요.", "bio": "저택의 모든 방과 습관을 아는 관리인.\n오랜 시간 이 집에서 누군가를 기다렸다."},
	{"name": "백도현", "role": "다큐멘터리 조감독", "quote": "이번에는 제대로 기록하겠습니다.", "bio": "명작의 그늘에 가려진 옛 제자.\n끊어진 관계를 뒤로하고 저택을 찾았다."},
	{"name": "문수경", "role": "생존자 · 피해자 지원 재단 대표", "quote": "살아남았다는 게, 용서는 아니잖아요.", "bio": "사건 이후 희망의 얼굴이 된 생존자.\n오늘 밤 재단의 새로운 출발을 발표한다."}
]
var screen := "menu"
var page: VBoxContainer
var notice := ""
var name_input: LineEdit
var ip_input: LineEdit
var port_input: SpinBox
var status_label: Label
var host_button: Button
var join_button: Button
var config := ConfigFile.new()
var atlas: Texture2D = preload("res://assets/suspects.png")
var click_player: AudioStreamPlayer

func _ready() -> void:
	config.load("user://settings.cfg")
	apply_settings()
	var ui_theme := Theme.new()
	ui_theme.default_font = preload("res://assets/Korean.otf")
	ui_theme.default_font_size = 18
	theme = ui_theme
	click_player = AudioStreamPlayer.new()
	click_player.stream = preload("res://assets/click.wav")
	add_child(click_player)
	Lobby.changed.connect(_network_changed)
	Lobby.failed.connect(func(message: String): notice = message)
	render()

func apply_settings() -> void:
	var volume := float(config.get_value("audio", "volume", 0.65))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if config.get_value("display", "fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED)

func save_settings() -> void:
	config.save("user://settings.cfg")
	apply_settings()

func _network_changed() -> void:
	if Lobby.active:
		screen = Lobby.phase
	elif not Lobby.connecting:
		screen = "connect" if not notice.is_empty() else "menu"
	render()

func panel_style(bg: Color, border := Color("65563e"), width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(8)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s

func label_text(value: String, size := 18, color := PAPER) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func wrap_label(value: String, size := 18, color := MUTED) -> Label:
	var l := label_text(value, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func button(value: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 52
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_color_override("font_color", Color("19251f") if primary else PAPER)
	b.add_theme_color_override("font_hover_color", Color("18231e"))
	b.add_theme_color_override("font_disabled_color", Color("777b71"))
	b.add_theme_stylebox_override("normal", panel_style(GOLD if primary else Color("1c2b25")))
	b.add_theme_stylebox_override("hover", panel_style(Color("e8ca90"), GOLD))
	b.add_theme_stylebox_override("pressed", panel_style(Color("bba16e"), GOLD))
	b.add_theme_stylebox_override("disabled", panel_style(Color("1e2521"), Color("343c34")))
	b.pressed.connect(func(): click_player.play(); action.call())
	return b

func row(spacing := 18) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", spacing)
	return r

func column(spacing := 12) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", spacing)
	return c

func spacer(parent: Control) -> void:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(s)

func render() -> void:
	for child in get_children():
		if child != click_player:
			remove_child(child)
			child.queue_free()
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/study.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.05, 0.04, 0.48 if screen == "menu" else 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 62)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	page = column(16)
	margin.add_child(page)
	match screen:
		"menu": menu_screen()
		"settings": settings_screen()
		"connect": connect_screen()
		"lobby": lobby_screen()
		"selection": selection_screen()
		"intro": intro_screen()

func header(step: String, title: String, subtitle: String) -> void:
	page.add_child(label_text("A MURDER MYSTERY  /  " + step, 14, GOLD))
	page.add_child(label_text(title, 36))
	page.add_child(wrap_label(subtitle))
	page.add_child(HSeparator.new())

func menu_screen() -> void:
	page.add_child(label_text("FOUR GUESTS. ONE UNFINISHED STORY.", 14, GOLD))
	spacer(page)
	page.add_child(label_text("당신을 두 번\n살렸습니다", 66))
	page.add_child(label_text("그날 밤, 진실보다 먼저 죽은 것이 있었다.", 20, GOLD))
	page.add_child(label_text("4인 온라인 머더 미스터리", 17, MUTED))
	var actions := column(12)
	actions.custom_minimum_size.x = 310
	actions.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(actions)
	actions.add_child(button("플레이   →", func(): screen = "connect"; notice = ""; render(), true))
	actions.add_child(button("설정", func(): screen = "settings"; render()))
	actions.add_child(button("게임 종료", func(): get_tree().quit()))
	spacer(page)
	page.add_child(label_text("CHAPTER 00  ·  초대받은 사람들", 14, GOLD))
	page.add_child(label_text("프로토타입 0.1   /   대기방 · 캐릭터 선택", 13, MUTED))

func settings_screen() -> void:
	header("SETTINGS", "설정", "설정은 이 컴퓨터에 자동 저장됩니다.")
	page.add_child(label_text("전체 음량 · 버튼 효과음", 22))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = config.get_value("audio", "volume", 0.65)
	slider.custom_minimum_size = Vector2(450, 45)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slider.value_changed.connect(func(value: float): config.set_value("audio", "volume", value); save_settings())
	page.add_child(slider)
	var fullscreen := CheckButton.new()
	fullscreen.text = "전체 화면"
	fullscreen.button_pressed = config.get_value("display", "fullscreen", false)
	fullscreen.toggled.connect(func(value: bool): config.set_value("display", "fullscreen", value); save_settings())
	page.add_child(fullscreen)
	page.add_child(wrap_label("이번 버전에는 음성채팅과 배경 음악이 포함되어 있지 않습니다."))
	spacer(page)
	page.add_child(button("← 메인 화면", func(): screen = "menu"; render()))

func connect_screen() -> void:
	header("01 / CONNECT", "저택으로의 초대", "방 한 개에 네 명이 모입니다. 한 명은 방을 만들고, 나머지는 방장의 주소로 참가하세요.")
	page.add_child(label_text("플레이어 이름", 20))
	name_input = LineEdit.new()
	name_input.text = config.get_value("player", "name", "")
	name_input.placeholder_text = "이름을 입력하세요 (최대 16자)"
	name_input.max_length = 16
	name_input.custom_minimum_size.y = 48
	page.add_child(name_input)
	page.add_child(label_text("방장 IP 주소 · 참가할 때만 필요", 20))
	ip_input = LineEdit.new()
	ip_input.text = config.get_value("network", "address", "127.0.0.1")
	ip_input.custom_minimum_size.y = 48
	page.add_child(ip_input)
	var p := row()
	p.add_child(label_text("UDP 포트", 20))
	port_input = SpinBox.new()
	port_input.min_value = 1024
	port_input.max_value = 65535
	port_input.value = config.get_value("network", "port", Lobby.DEFAULT_PORT)
	p.add_child(port_input)
	page.add_child(p)
	page.add_child(wrap_label("같은 PC에서 테스트: 127.0.0.1  ·  같은 공유기: 방장의 사설 IP\n서로 다른 인터넷: 방장 측 UDP 포트 포워딩 또는 VPN 연결이 필요합니다. 자동 방 검색은 지원하지 않습니다.", 16))
	var actions := row()
	host_button = button("방 만들기", func(): connect_room(true), true)
	join_button = button("주소로 참가", func(): connect_room(false))
	host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(host_button)
	actions.add_child(join_button)
	page.add_child(actions)
	status_label = wrap_label(notice, 18, GOLD)
	page.add_child(status_label)
	spacer(page)
	page.add_child(button("← 연결 취소 / 메인 화면", func(): Lobby.leave(); screen = "menu"; render()))

func connect_room(hosting: bool) -> void:
	if name_input.text.strip_edges().is_empty():
		status_label.text = "플레이어 이름을 입력해 주세요."
		return
	if not hosting and ip_input.text.strip_edges().is_empty():
		status_label.text = "방장 주소를 입력해 주세요."
		return
	var player_name := name_input.text
	var host_address := ip_input.text
	var room_port := int(port_input.value)
	config.set_value("player", "name", player_name)
	config.set_value("network", "address", host_address)
	config.set_value("network", "port", room_port)
	config.save("user://settings.cfg")
	if hosting:
		var result := Lobby.host_room(player_name, room_port)
		if result != OK:
			status_label.text = "방을 열지 못했습니다. 다른 포트를 선택해 주세요. (오류 %d)" % result
	else:
		var result := Lobby.join_room(player_name, host_address, room_port)
		if result != OK:
			status_label.text = "연결을 시작하지 못했습니다. (오류 %d)" % result
		else:
			status_label.text = "방장에게 연결 중… (최대 10초)"
			host_button.disabled = true
			join_button.disabled = true

func exit_button() -> Button:
	return button("← 방 나가기", func(): Lobby.leave(); screen = "menu"; render())

func lobby_screen() -> void:
	header("02 / LOBBY", "손님을 기다리는 중", "모든 손님이 도착하면 방장이 캐릭터 선택을 시작할 수 있습니다.")
	var top := row()
	top.add_child(label_text("참가자  %d / 4" % Lobby.players.size(), 26, GOLD))
	top.add_child(label_text("   UDP %d  ·  %s" % [Lobby.port, "내가 방장" if Lobby.is_host() else "접속: " + Lobby.address], 17, MUTED))
	page.add_child(top)
	var slots := row()
	slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(slots)
	var ids := Lobby.players.keys()
	ids.sort()
	for index in range(4):
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", panel_style(Color("182620")))
		slots.add_child(box)
		var c := column(15)
		box.add_child(c)
		c.add_child(label_text("GUEST  0%d" % (index + 1), 15, GOLD))
		spacer(c)
		c.add_child(label_text("초대장" if index < ids.size() else "빈 자리", 28))
		if index < ids.size():
			var id: int = ids[index]
			c.add_child(wrap_label(str(Lobby.players[id].name), 24, PAPER))
			c.add_child(label_text("방장" if id == 1 else "접속 완료", 16, GOLD))
			if id == multiplayer.get_unique_id():
				c.add_child(label_text("나", 16, MUTED))
		else:
			c.add_child(wrap_label("다른 플레이어를\n기다리고 있습니다.", 17))
		spacer(c)
	var start := button("게임 시작  →  캐릭터 선택" if Lobby.is_host() else "방장이 시작하기를 기다리는 중", func(): Lobby.start_selection(), true)
	start.disabled = not Lobby.is_host() or Lobby.players.size() != 4
	page.add_child(start)
	page.add_child(exit_button())

func portrait(index: int) -> TextureRect:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(index * atlas.get_width() / 4.0, 0, atlas.get_width() / 4.0, atlas.get_height())
	var view := TextureRect.new()
	view.texture = texture
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.custom_minimum_size.y = 245
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return view

func selection_screen() -> void:
	header("03 / CAST", "당신은 누구입니까?", "인물을 선택한 뒤 확정하세요. 먼저 선택한 사람에게 배정되며, 같은 인물을 두 명이 선택할 수 없습니다.")
	var cards := row(16)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(cards)
	var me: int = multiplayer.get_unique_id()
	var own: Dictionary = Lobby.players.get(me, {})
	for index in range(4):
		var data: Dictionary = CHARACTERS[index]
		var owner_id := 0
		for id in Lobby.players:
			if Lobby.players[id].character == index:
				owner_id = id
		var mine := owner_id == me
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", panel_style(Color("1d3028") if mine else Color("14221c"), GOLD if mine else Color("4d4d3a"), 2 if mine else 1))
		cards.add_child(box)
		var c := column(8)
		box.add_child(c)
		c.add_child(portrait(index))
		c.add_child(label_text(data.name, 28, GOLD if mine else PAPER))
		c.add_child(wrap_label(data.role, 15, GOLD))
		c.add_child(wrap_label(data.bio, 16))
		var owner_text := "선택 가능"
		if owner_id != 0:
			owner_text = str(Lobby.players[owner_id].name) + (" · 확정" if Lobby.players[owner_id].ready else " · 선택 중")
		c.add_child(wrap_label(owner_text, 16, GOLD if mine else MUTED))
		var choice := index
		var b := button("선택됨" if mine else ("다른 사람이 선택" if owner_id != 0 else "이 인물 선택"), func(): Lobby.choose(choice), mine)
		b.disabled = owner_id != 0 or own.get("ready", false)
		c.add_child(b)
	var ready_count := 0
	for p in Lobby.players.values():
		if p.ready:
			ready_count += 1
	page.add_child(label_text("선택 확정  %d / 4   ·   모두 확정하면 배역 소개로 이동합니다." % ready_count, 17, GOLD))
	var footer := row()
	var confirm := button("확정 취소" if own.get("ready", false) else "내 캐릭터 확정", func(): Lobby.confirm_choice(), true)
	confirm.disabled = own.get("character", -1) < 0
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(confirm)
	footer.add_child(exit_button())
	page.add_child(footer)

func intro_screen() -> void:
	var me: int = multiplayer.get_unique_id()
	var index: int = Lobby.players[me].character
	var data: Dictionary = CHARACTERS[index]
	header("04 / PROLOGUE", "네 명의 손님이 도착했습니다", "배역 선택 완료 · 당신의 이야기가 시작될 자리입니다.")
	var content := row(36)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(content)
	var image := portrait(index)
	image.custom_minimum_size.x = 330
	content.add_child(image)
	var details := column(20)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(details)
	details.add_child(label_text("당신의 배역", 16, GOLD))
	details.add_child(label_text(data.name, 44))
	details.add_child(label_text(data.role, 21, GOLD))
	details.add_child(wrap_label("“" + str(data.quote) + "”", 25, PAPER))
	details.add_child(wrap_label("밤 10시, 한 편의 다큐멘터리가 다시 상영될 예정이었다.\n그러나 서재에서 발견된 것은, 감독 강태오의 시신이었다.\n\n이 저택의 네 사람은 모두 그가 죽기를 바랐다.", 21, PAPER))
	details.add_child(wrap_label("현재 버전은 온라인 대기방과 배역 선택까지 플레이할 수 있습니다.\n비공개 역할지 · 맵 조사 · 음성채팅 · 투표는 다음 개발 범위입니다.", 17, GOLD))
	spacer(details)
	var names := "참여 배역  ·  "
	for p in Lobby.players.values():
		names += str(CHARACTERS[p.character].name) + "  "
	page.add_child(wrap_label(names, 17))
	if Lobby.is_host():
		page.add_child(button("대기방으로 돌아가기 · 배역 초기화", func(): Lobby.reopen_lobby()))
	page.add_child(exit_button())
