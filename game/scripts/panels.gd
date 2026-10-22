class_name Panels
## 各个弹窗面板：商店、行李、邮箱、图鉴、喂食。

# ================================================================= 基类

class BasePanel extends PanelContainer:
	var client = null            # ClientApp（弱类型，避免循环引用）
	var title_lbl: Label
	var content: VBoxContainer
	var sig := ""

	func _init() -> void:
		custom_minimum_size = Vector2(780, 540)

	func build(title: String) -> void:
		var outer := VBoxContainer.new()
		outer.add_theme_constant_override("separation", 8)
		add_child(outer)
		# 标题栏
		var head := HBoxContainer.new()
		outer.add_child(head)
		title_lbl = Label.new()
		title_lbl.text = title
		title_lbl.add_theme_font_size_override("font_size", 20)
		title_lbl.add_theme_color_override("font_color", Color(0x5b4632ff))
		head.add_child(title_lbl)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(sp)
		var close := Button.new()
		close.text = "✕ 关闭"
		close.pressed.connect(func(): hide())
		head.add_child(close)
		var line := HSeparator.new()
		outer.add_child(line)
		# 内容区（可滚动）
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outer.add_child(scroll)
		content = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 6)
		scroll.add_child(content)

	func _section(text: String) -> void:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Color(0x8a6b45ff))
		content.add_child(l)

	func _btn(text: String, cb: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.pressed.connect(cb)
		return b

	func _clear() -> void:
		for c in content.get_children():
			c.queue_free()

# ================================================================= 商店

class ShopPanel extends BasePanel:
	func setup(c) -> void:
		client = c
		build("🏪 商店 —— 用三叶草换东西")

	func state_sig(s: Dictionary) -> String:
		return JSON.stringify([s.get("clover"), s.get("inv")])

	func refresh(s: Dictionary) -> void:
		_clear()
		var sections := [
			["🥣 便当（蛙出门时吃掉，影响去哪儿）", GameData.FOODS, "food"],
			["🎒 道具（跟着蛙走，不消耗）", GameData.ITEMS, "item"],
			["🧧 护身符（出发时用掉，保佑带回特产）", GameData.CHARMS, "charm"],
	 ]
		for sec in sections:
			_section(sec[0])
			var table: Dictionary = sec[1]
			var cat: String = sec[2]
			for id in table:
				var info: Dictionary = table[id]
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 10)
				content.add_child(row)
				var vb := VBoxContainer.new()
				vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(vb)
				var name_l := Label.new()
				var owned := int(s["inv"][cat].get(id, 0))
				name_l.text = "%s%s" % [info["name"], ("　（已有 ×%d）" % owned) if owned > 0 else ""]
				name_l.add_theme_font_size_override("font_size", 16)
				vb.add_child(name_l)
				var desc_l := Label.new()
				desc_l.text = str(info["desc"])
				desc_l.add_theme_font_size_override("font_size", 12)
				desc_l.add_theme_color_override("font_color", Color(0x9b8b76ff))
				vb.add_child(desc_l)
				var price := Label.new()
				price.text = "%d ☘" % int(info["price"])
				price.add_theme_color_override("font_color", Color(0x2f8f4eff))
				row.add_child(price)
				var b := _btn("购买", func(): client.send_msg("buy", {"id": id}))
				if int(s["clover"]) < int(info["price"]):
					b.disabled = true
				row.add_child(b)
			content.add_child(HSeparator.new())

# ================================================================= 行李

class LuggagePanel extends BasePanel:
	func setup(c) -> void:
		client = c
		build("🎒 行李 —— 帮蛙收拾出门的东西")

	func state_sig(s: Dictionary) -> String:
		return JSON.stringify([s.get("pack"), s.get("inv"), s.get("four")])

	func refresh(s: Dictionary) -> void:
		_clear()
		var pack: Dictionary = s["pack"]
		_section("🍱 便当（没有便当，蛙不会出门）")
		_slot_row(s, "food", pack.get("food"), _food_options(s))
		content.add_child(HSeparator.new())
		_section("🍀 护身符（出发时消耗，保证带回特产）")
		var charm_opts := []
		if int(s["four"]) > 0:
			charm_opts.append(["four", "四叶草 ×%d" % int(s["four"])])
		if int(s["inv"]["charm"].get("yumite", 0)) > 0:
			charm_opts.append(["yumite", "开运御守 ×%d" % int(s["inv"]["charm"]["yumite"])])
		_slot_row(s, "charm", pack.get("charm"), charm_opts)
		content.add_child(HSeparator.new())
		_section("🎒 道具（不消耗，影响目的地）")
		var item_opts := []
		for id in s["inv"]["item"]:
			item_opts.append([id, "%s ×%d" % [GameData.ITEMS[id]["name"], int(s["inv"]["item"][id])]])
		_slot_row(s, "item", pack.get("item"), item_opts)

	func _food_options(s: Dictionary) -> Array:
		var opts := []
		for id in s["inv"]["food"]:
			opts.append([id, "%s ×%d" % [GameData.FOODS[id]["name"], int(s["inv"]["food"][id])]])
		return opts

	func _slot_row(s: Dictionary, slot: String, current, options: Array) -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		content.add_child(row)
		var cur := Label.new()
		cur.text = "当前：%s" % ("空" if current == null else GameData.food_name(str(current)))
		cur.add_theme_font_size_override("font_size", 15)
		cur.custom_minimum_size.x = 190
		row.add_child(cur)
		if options.is_empty():
			var none := Label.new()
			none.text = "（背包里没有可放的，先去商店买）"
			none.add_theme_color_override("font_color", Color(0xa89a86ff))
			row.add_child(none)
		for opt in options:
			var id: String = opt[0]
			var chosen: bool = str(current) == id
			var b := _btn(("✓ " if chosen else "") + str(opt[1]),
				func(): client.send_msg("pack", {"slot": slot, "id": null if chosen else id}))
			row.add_child(b)
		if current != null:
			row.add_child(_btn("卸下", func(): client.send_msg("pack", {"slot": slot, "id": null})))

# ================================================================= 邮箱

class MailPanel extends BasePanel:
	func setup(c) -> void:
		client = c
		build("📮 邮箱 —— 蛙寄回来的明信片")

	func state_sig(s: Dictionary) -> String:
		return JSON.stringify([s.get("mail")])

	func refresh(s: Dictionary) -> void:
		_clear()
		var mail: Array = s["mail"]
		if mail.is_empty():
			var l := Label.new()
			l.text = "信箱空空的。等蛙出门旅行后，会寄明信片回来～"
			l.add_theme_color_override("font_color", Color(0xa89a86ff))
			content.add_child(l)
			return
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		content.add_child(grid)
		for i in range(mail.size() - 1, -1, -1):
			var card: Dictionary = mail[i]
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 3)
			grid.add_child(cell)
			var art := Views.PostcardArt.new()
			art.dest = str(card["dest"])
			art.art = int(card["art"])
			cell.add_child(art)
			var t := Label.new()
			var new_mark := "" if bool(card["read"]) else " 📮新"
			t.text = "【%s】%s" % [card["dest"], new_mark]
			t.add_theme_font_size_override("font_size", 13)
			cell.add_child(t)
			var body := Label.new()
			body.text = str(card["text"])
			body.add_theme_font_size_override("font_size", 12)
			body.add_theme_color_override("font_color", Color(0x8d7f6aff))
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.custom_minimum_size = Vector2(214, 0)
			cell.add_child(body)

# ================================================================= 图鉴

class GalleryPanel extends BasePanel:
	func setup(c) -> void:
		client = c
		build("📖 图鉴 —— 收集的回忆")

	func state_sig(s: Dictionary) -> String:
		return JSON.stringify([s.get("gallery"), s.get("stats")])

	func refresh(s: Dictionary) -> void:
		_clear()
		var gal: Dictionary = s["gallery"]
		var tabs := TabContainer.new()
		tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(tabs)

		# 明信片
		var p1 := VBoxContainer.new()
		p1.name = "明信片 %d/%d" % [gal["cards"].size(), GameData.DESTS.size() * GameData.CARD_VARIANTS]
		tabs.add_child(p1)
		var g1 := GridContainer.new()
		g1.columns = 4
		g1.add_theme_constant_override("h_separation", 12)
		g1.add_theme_constant_override("v_separation", 12)
		p1.add_child(g1)
		for dest in GameData.DESTS:
			for art in range(GameData.CARD_VARIANTS):
				var cid := GameData.card_id(dest, art)
				var got: bool = (gal["cards"] as Array).has(cid)
				var cell := VBoxContainer.new()
				g1.add_child(cell)
				var art_c := Views.PostcardArt.new()
				art_c.dest = dest
				art_c.art = art
				art_c.mono = not got
				cell.add_child(art_c)
				var l := Label.new()
				l.text = dest if got else "？？？"
				l.add_theme_font_size_override("font_size", 12)
				cell.add_child(l)

		# 特产
		var p2 := VBoxContainer.new()
		p2.name = "特产 %d/%d" % [gal["gifts"].size(), _gift_total()]
		tabs.add_child(p2)
		var g2 := GridContainer.new()
		g2.columns = 4
		g2.add_theme_constant_override("h_separation", 16)
		g2.add_theme_constant_override("v_separation", 8)
		p2.add_child(g2)
		for dest in GameData.DESTS:
			for gname in GameData.DESTS[dest]["gifts"]:
				var got2: bool = (gal["gifts"] as Array).has(gname)
				var l2 := Label.new()
				l2.text = ("✓ " if got2 else "？ ") + (gname if got2 else "未收集")
				l2.add_theme_font_size_override("font_size", 14)
				l2.add_theme_color_override("font_color", Color(0x2f8f4eff) if got2 else Color(0xb3a894ff))
				g2.add_child(l2)

		# 访客
		var p3 := VBoxContainer.new()
		p3.name = "访客 %d/%d" % [gal["guests"].size(), GameData.VISITORS.size()]
		tabs.add_child(p3)
		for vid in GameData.VISITORS:
			var info: Dictionary = GameData.VISITORS[vid]
			var got3: bool = (gal["guests"] as Array).has(vid)
			var l3 := Label.new()
			l3.text = "%s %s　　最爱：%s" % [
				"✓" if got3 else "？",
				info["name"] if got3 else "？？？",
				GameData.food_name(info["fav"]) if got3 else "？",
			]
			l3.add_theme_font_size_override("font_size", 15)
			l3.add_theme_color_override("font_color", Color(0x2f8f4eff) if got3 else Color(0xb3a894ff))
			p3.add_child(l3)

		# 战绩
		var stats: Dictionary = s["stats"]
		var line := Label.new()
		line.text = "🌏 出门 %d 次　📮 收到 %d 张明信片（新 %d）　🍽 喂过访客 %d 次" % [
			stats["trips"], stats["cards"], stats["new_cards"], stats["feedings"]]
		line.add_theme_font_size_override("font_size", 13)
		line.add_theme_color_override("font_color", Color(0x8d7f6aff))
		content.add_child(line)

	func _gift_total() -> int:
		var n := 0
		for dest in GameData.DESTS:
			n += (GameData.DESTS[dest]["gifts"] as Array).size()
		return n

# ================================================================= 喂食

class FeedPanel extends BasePanel:
	var visitor_uid := ""

	func setup(c) -> void:
		client = c
		custom_minimum_size = Vector2(430, 260)
		build("🍽 请它吃点东西")

	func state_sig(s: Dictionary) -> String:
		return JSON.stringify([visitor_uid, s.get("inv")])

	func refresh(s: Dictionary) -> void:
		_clear()
		var visitor = null
		for v in s["yard"]:
			if v["uid"] == visitor_uid:
				visitor = v
		if visitor == null:
			hide()
			return
		var info: Dictionary = GameData.VISITORS[visitor["type"]]
		var hint := Label.new()
		hint.text = "%s眼巴巴地看着你……（它最爱吃%s）" % [info["name"], GameData.food_name(info["fav"])]
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(hint)
		var any := false
		for id in s["inv"]["food"]:
			any = true
			var b := _btn("%s ×%d" % [GameData.FOODS[id]["name"], int(s["inv"]["food"][id])],
				func():
					client.send_msg("feed", {"uid": visitor_uid, "id": id})
					hide())
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content.add_child(b)
		if not any:
			var l := Label.new()
			l.text = "背包里没有食物，去买点吧。"
			l.add_theme_color_override("font_color", Color(0xb3a894ff))
			content.add_child(l)
