extends Node
class_name ClientApp
## 客户端：连服务器、画界面、发指令。一个窗口 = 一只独立的蛙。

const URL := "ws://127.0.0.1:9876"
const VISITOR_ICON := {
	"hudie": "🦋", "mifeng": "🐝", "piaochong": "🐞",
	"songshu": "🐿️", "wugui": "🐢",
}

var ws := WebSocketPeer.new()
var account := ""
var connected := false
var got_welcome := false
var retry_t := 0.0
var state := {}
var last_seq := 0
var log_lines: Array = []
var visitor_sig := ""

# UI
var layer: Control
var clover_lbl: Label
var four_lbl: Label
var mail_btn: Button
var conn_lbl: Label
var status_lbl: Label
var house: Views.HouseView
var frog: Views.FrogSprite
var garden: Views.GardenView
var harvest_btn: Button
var visitor_box: VBoxContainer
var log_rtl: RichTextLabel
var panels := {}          # key -> {"panel": BasePanel, "sig": String}
var open_key := ""
var ui_theme: Theme
var margin_ctn: MarginContainer
var root_box: VBoxContainer
var main_row: HBoxContainer
var dbg_t := 0.0
var dbg_done := false

func _ready() -> void:
	randomize()
	_cascade_window()
	account = "%08x%08x%08x%08x" % [randi(), randi(), randi(), randi()]
	_connect_ws()
	_build_ui()
	# 调试：--open=shop / luggage / mail / gallery 启动2秒后自动打开对应面板
	# 调试：--shot=路径.png 4秒后截取自身画面并退出
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--open="):
			var which := a.get_slice("=", 1)
			get_tree().create_timer(2.0).timeout.connect(func(): toggle_panel(which))
		elif a.begins_with("--shot="):
			var path := a.get_slice("=", 1)
			get_tree().create_timer(4.0).timeout.connect(func(): _do_shot(path))

func _do_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT saved: ", path, " size=", img.get_size())
	get_tree().quit()

func _exit_tree() -> void:
	_drop_win_file()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_drop_win_file()
		get_tree().quit()

# ---------------------------------------------------------------- 网络

func _connect_ws() -> void:
	ws = WebSocketPeer.new()
	ws.connect_to_url(URL)
	ws.set_no_delay(true)
	retry_t = 3.0

func send_msg(t: String, extra: Dictionary = {}) -> void:
	if not connected:
		return
	var msg := {"t": t}
	msg.merge(extra)
	ws.send_text(JSON.stringify(msg))

func _process(delta: float) -> void:
	if not dbg_done:
		dbg_t += delta
		if dbg_t > 2.5 and log_rtl != null:
			dbg_done = true
			print("DEBUG win=", get_window().size, " layer=", layer.size, " margin=", margin_ctn.size,
				" root=", root_box.size, " main=", main_row.size, " log=", log_rtl.size)
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			send_msg("hello", {"account": account})
			conn_lbl.text = "已连接服务器 ✓"
			conn_lbl.add_theme_color_override("font_color", Color(0x2f8f4eff))
		while ws.get_available_packet_count():
			var pkt := ws.get_packet()
			if not ws.was_string_packet():
				continue
			var msg = JSON.parse_string(pkt.get_string_from_utf8())
			if msg is Dictionary:
				_on_msg(msg)
	elif st == WebSocketPeer.STATE_CLOSED:
		# 连接失败/断开：等 retry_t 归零后重连（_connect_ws 会重置计时）
		retry_t -= delta
		if retry_t <= 0.0:
			connected = false
			got_welcome = false
			conn_lbl.text = "连接断开，重连中…"
			conn_lbl.add_theme_color_override("font_color", Color(0xc0503fff))
			_connect_ws()
	else:
		retry_t -= delta

func _on_msg(msg: Dictionary) -> void:
	match str(msg.get("t", "")):
		"welcome":
			got_welcome = true
			get_window().title = "旅行青蛙·网络版 - %s" % msg.get("name", "")
		"state":
			_apply_state(msg.get("s", {}))
		"glog":
			_push_log(str(msg.get("text", "")), Color(0x2f6fb0ff))

func _push_log(text: String, color: Color) -> void:
	log_lines.append({"text": text, "color": color.to_html(false)})
	while log_lines.size() > 40:
		log_lines.pop_front()
	_render_log()

func _render_log() -> void:
	var out := ""
	for l in log_lines:
		out += "[color=#%s]%s[/color]\n" % [l["color"], str(l["text"]).replace("[", "[lb]")]
	log_rtl.text = out

# ---------------------------------------------------------------- 状态刷新

func _apply_state(s: Dictionary) -> void:
	if s.is_empty():
		return
	state = s
	# 日志（按 seq 增量）
	for entry in s.get("logs", []):
		var seq := int(entry[0])
		if seq > last_seq:
			last_seq = seq
			_push_log(str(entry[1]), Color(0x5b4632ff))
	# 顶栏
	clover_lbl.text = "☘ 三叶草 %d" % int(s["clover"])
	four_lbl.text = "🍀 %d" % int(s["four"])
	var unread := 0
	for c in s["mail"]:
		if not bool(c["read"]):
			unread += 1
	mail_btn.text = "📮 邮箱%s" % ("(%d)" % unread if unread > 0 else "")
	# 蛙状态
	var frog_s: Dictionary = s["frog"]
	var mode := str(frog_s["mode"])
	frog.mode = mode
	frog.visible = mode != "travel"
	if mode == "travel":
		var left := int(ceilf(float(frog_s["left"])))
		status_lbl.text = "🌍 %s 出门旅行中【%s】，还有 %02d:%02d 回家" % [
			s["name"], frog_s["dest"], left / 60, left % 60]
	else:
		var tip := ""
		if s["pack"].get("food") == null:
			tip = "　💡 背包里没放便当，它暂时不想出门"
		elif float(frog_s["cd"]) > 0.0:
			tip = "　⏳ 约 %d 秒后再次出发" % int(ceilf(float(frog_s["cd"])))
		status_lbl.text = "🐸 %s 正在%s%s" % [s["name"], frog_s["act_text"], tip]
	# 花园
	garden.progress = float(s["garden"])
	var ready := float(s["garden"]) >= 1.0
	harvest_btn.visible = ready
	# 访客按钮
	var vsig := JSON.stringify(s["yard"])
	if vsig != visitor_sig:
		visitor_sig = vsig
		_rebuild_visitors()
	# 打开中的面板
	if not open_key.is_empty():
		var entry: Dictionary = panels[open_key]
		var panel = entry["panel"]
		var sig: String = panel.state_sig(s)
		if sig != entry["sig"]:
			entry["sig"] = sig
			panel.refresh(s)

func _rebuild_visitors() -> void:
	for c in visitor_box.get_children():
		c.queue_free()
	for v in state.get("yard", []):
		var info: Dictionary = GameData.VISITORS[v["type"]]
		var b := Button.new()
		b.text = "%s %s 来串门 —— 请它吃点东西" % [VISITOR_ICON.get(v["type"], "🐸"), info["name"]]
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func(): _open_feed(str(v["uid"])))
		visitor_box.add_child(b)

# ---------------------------------------------------------------- 面板

func toggle_panel(key: String) -> void:
	if open_key == key:
		close_panel()
		return
	close_panel()
	if not panels.has(key):
		var p = null
		match key:
			"shop": p = Panels.ShopPanel.new()
			"luggage": p = Panels.LuggagePanel.new()
			"mail": p = Panels.MailPanel.new()
			"gallery": p = Panels.GalleryPanel.new()
		p.setup(self)
		p.hide()
		layer.add_child(p)
		panels[key] = {"panel": p, "sig": ""}
	var entry: Dictionary = panels[key]
	open_key = key
	var panel = entry["panel"]
	panel.show()
	if panel is PanelContainer:
		panel.size = panel.custom_minimum_size
	panel.position = Vector2((layer.size - panel.size) * 0.5)
	if state.is_empty():
		return
	var sig: String = panel.state_sig(state)
	entry["sig"] = sig
	panel.refresh(state)
	# 打开邮箱即视为已读
	if key == "mail" and _unread_count() > 0:
		send_msg("readmail")

func _open_feed(uid: String) -> void:
	close_panel()
	var key := "feed"
	if not panels.has(key):
		var p = Panels.FeedPanel.new()
		p.setup(self)
		p.hide()
		layer.add_child(p)
		panels[key] = {"panel": p, "sig": ""}
	var entry: Dictionary = panels[key]
	var p = entry["panel"]
	p.visitor_uid = uid
	open_key = key
	p.show()
	p.size = p.custom_minimum_size
	p.position = Vector2((layer.size - p.size) * 0.5)
	var sig: String = p.state_sig(state)
	entry["sig"] = sig
	p.refresh(state)

func close_panel() -> void:
	if open_key.is_empty():
		return
	var entry: Dictionary = panels.get(open_key)
	if entry != null:
		entry["panel"].hide()
	open_key = ""

func _unread_count() -> int:
	var n := 0
	for c in state.get("mail", []):
		if not bool(c["read"]):
			n += 1
	return n

# ---------------------------------------------------------------- 界面搭建

func _build_ui() -> void:
	ui_theme = _make_theme()

	# 米色底（Godot 默认深灰底配深色字看不清）
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0xfaf4e8ff)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	layer = Control.new()
	layer.name = "Layer"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.theme = ui_theme
	# 注意：layer 要等主界面加完后再 add_child，保证弹窗画在主界面之上

	margin_ctn = MarginContainer.new()
	margin_ctn.name = "Margin"
	margin_ctn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_ctn.add_theme_constant_override("margin_left", 10)
	margin_ctn.add_theme_constant_override("margin_right", 10)
	margin_ctn.add_theme_constant_override("margin_top", 8)
	margin_ctn.add_theme_constant_override("margin_bottom", 8)
	add_child(margin_ctn)

	root_box = VBoxContainer.new()
	root_box.name = "Root"
	root_box.theme = ui_theme
	root_box.add_theme_constant_override("separation", 8)
	margin_ctn.add_child(root_box)
	add_child(layer)          # 主界面之后加入 → 弹窗层在最上面
	var root: VBoxContainer = root_box

	# ---- 顶栏 ----
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	var title := Label.new()
	title.text = "🐸 旅行青蛙·网络版"
	title.add_theme_font_size_override("font_size", 19)
	header.add_child(title)
	clover_lbl = Label.new()
	clover_lbl.add_theme_color_override("font_color", Color(0x2f8f4eff))
	header.add_child(clover_lbl)
	four_lbl = Label.new()
	four_lbl.add_theme_color_override("font_color", Color(0x3f9d4fff))
	header.add_child(four_lbl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	for bt in [["🏪 商店", "shop"], ["🎒 行李", "luggage"], ["📮 邮箱", "mail"], ["📖 图鉴", "gallery"]]:
		var b := Button.new()
		b.text = bt[0]
		var key: String = bt[1]
		b.pressed.connect(func(): toggle_panel(key))
		header.add_child(b)
		if key == "mail":
			mail_btn = b
	conn_lbl = Label.new()
	conn_lbl.text = "连接中…"
	conn_lbl.add_theme_font_size_override("font_size", 12)
	header.add_child(conn_lbl)

	# ---- 主区域 ----
	main_row = HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.size_flags_stretch_ratio = 2.0
	main_row.add_theme_constant_override("separation", 10)
	root.add_child(main_row)
	var main: HBoxContainer = main_row

	# 房间
	var house_wrap := Control.new()
	house_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	house_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	house_wrap.custom_minimum_size = Vector2(500, 380)
	main.add_child(house_wrap)
	house = Views.HouseView.new()
	house.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	house.mouse_filter = Control.MOUSE_FILTER_IGNORE
	house_wrap.add_child(house)
	frog = Views.FrogSprite.new()
	frog.position = Vector2(330, 260)
	house_wrap.add_child(frog)
	status_lbl = Label.new()
	status_lbl.add_theme_font_size_override("font_size", 16)
	status_lbl.add_theme_color_override("font_color", Color(0x4a3b2aff))
	house_wrap.add_child(status_lbl)
	house_wrap.resized.connect(func():
		status_lbl.position = Vector2(house_wrap.size.x * 0.5 - status_lbl.size.x * 0.5, house_wrap.size.y - 52)
		frog.position = Vector2(house_wrap.size.x * 0.52, house_wrap.size.y * 0.70))

	# 花园
	var garden_wrap := Control.new()
	garden_wrap.custom_minimum_size = Vector2(430, 380)
	garden_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(garden_wrap)
	garden = Views.GardenView.new()
	garden.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	garden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	garden_wrap.add_child(garden)
	harvest_btn = Button.new()
	harvest_btn.text = "✂️ 收割三叶草"
	harvest_btn.visible = false
	harvest_btn.pressed.connect(func(): send_msg("harvest"))
	garden_wrap.add_child(harvest_btn)
	visitor_box = VBoxContainer.new()
	visitor_box.add_theme_constant_override("separation", 6)
	garden_wrap.add_child(visitor_box)
	var gl := Label.new()
	gl.text = "🌿 院子"
	gl.add_theme_font_size_override("font_size", 15)
	gl.add_theme_color_override("font_color", Color(0x4a6b3aff))
	garden_wrap.add_child(gl)
	garden_wrap.resized.connect(func():
		gl.position = Vector2(12, 6)
		harvest_btn.position = Vector2(garden_wrap.size.x - harvest_btn.size.x - 12, 8)
		visitor_box.position = Vector2(14, garden_wrap.size.y - visitor_box.size.y - 14)
		visitor_box.size.x = garden_wrap.size.x - 28)
	# 访客条位置需要在刷新后重新贴底
	visitor_box.child_entered_tree.connect(func(_c): visitor_box.position.y = garden_wrap.size.y - visitor_box.size.y - 14)

	# ---- 日志 ----
	log_rtl = RichTextLabel.new()
	log_rtl.bbcode_enabled = true
	log_rtl.scroll_following = true
	log_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_rtl.custom_minimum_size = Vector2(0, 110)
	log_rtl.add_theme_font_size_override("normal_font_size", 13)
	log_rtl.add_theme_color_override("default_color", Color(0x5b4632ff))
	root.add_child(log_rtl)

# ---------------------------------------------------------------- 窗口

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 15
	th.set_color("font_color", "Label", Color(0x4a3b2aff))
	th.set_stylebox("normal", "Button", _sb(Color(0xffffffff), Color(0xd8c8adff), 6, 6))
	th.set_stylebox("hover", "Button", _sb(Color(0xfff2d5ff), Color(0xc8b28cff), 6, 6))
	th.set_stylebox("pressed", "Button", _sb(Color(0xefe0c4ff), Color(0xb5a07eff), 6, 6))
	th.set_stylebox("disabled", "Button", _sb(Color(0xeae5ddff), Color(0xd2cabdff), 6, 6))
	th.set_color("font_color", "Button", Color(0x4a3b2aff))
	th.set_color("font_hover_color", "Button", Color(0x2f6fb0ff))
	th.set_color("font_pressed_color", "Button", Color(0x7a5c3aff))
	th.set_color("font_disabled_color", "Button", Color(0x9d9589ff))
	th.set_stylebox("panel", "PanelContainer", _sb(Color(0xfffdf6ff), Color(0xd8c8adff), 10, 12))
	th.set_stylebox("normal", "RichTextLabel", _sb(Color(0xffffffff), Color(0xd8c8adff), 6, 10))
	return th

func _sb(bg: Color, border: Color, radius: int, pad: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.7
	sb.content_margin_bottom = pad * 0.7
	return sb

func _cascade_window() -> void:
	var dir := "user://wins"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var d := DirAccess.open(dir)
	var n := 0
	if d:
		for f in d.get_files():
			var path := dir + "/" + f
			var mtime := FileAccess.get_modified_time(path)
			if Time.get_unix_time_from_system() - float(mtime) > 600.0:
				d.remove(f)          # 清掉残留的死进程文件
				continue
			n += 1
		var pf := FileAccess.open(dir + "/" + str(OS.get_process_id()) + ".pid", FileAccess.WRITE)
		if pf:
			pf.store_string("1")
	var win := get_window()
	win.position = Vector2(70 + (n % 6) * 56, 50 + (n % 6) * 48)

func _drop_win_file() -> void:
	var path := "user://wins/" + str(OS.get_process_id()) + ".pid"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
