extends Node
class_name ServerLogic
## 服务器：WebSocket 监听 + 权威游戏状态 + 存档。
## 所有蛙的作息、花园生长、旅行计时都在这里跑，客户端只收状态、发指令。

const PORT := 9876
const SAVE_PATH := "user://players.json"
const G := preload("res://scripts/game_data.gd")

var tcp := TCPServer.new()
var clients: Dictionary = {}     # peer_id -> {"ws": WebSocketPeer, "account": String}
var next_id := 2
var players: Dictionary = {}     # account -> 玩家状态字典
var tick_acc := 0.0
var save_acc := 0.0
var hb_acc := 0.0

func _ready() -> void:
	var err := tcp.listen(PORT, "*")
	if err != OK:
		print("[server] 端口 %d 监听失败: %d" % [PORT, err])
		get_tree().quit(1)
		return
	_load_save()
	print("[server] 旅行青蛙服务器已启动，端口 %d" % PORT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_save_save()

func _process(delta: float) -> void:
	# 1) 接受新连接
	while tcp.is_connection_available():
		var stream := tcp.take_connection()
		var ws := WebSocketPeer.new()
		ws.accept_stream(stream)
		ws.set_no_delay(true)
		clients[next_id] = {"ws": ws, "account": ""}
		print("[server] 新连接 peer=%d" % next_id)
		next_id += 1
	# 2) 收包 / 断线
	for id in clients.keys().duplicate():
		var c: Dictionary = clients[id]
		var ws: WebSocketPeer = c["ws"]
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count():
				var pkt := ws.get_packet()
				var raw := ""
				if ws.was_string_packet():
					raw = pkt.get_string_from_utf8()
				if raw.is_empty():
					continue
				var msg = JSON.parse_string(raw)
				if msg is Dictionary:
					_handle(id, msg)
		elif st == WebSocketPeer.STATE_CLOSED:
			print("[server] 断开 peer=%d code=%d" % [id, ws.get_close_code()])
			clients.erase(id)
	# 3) 世界节拍
	tick_acc += delta
	if tick_acc >= G.TICK:
		_world_update(tick_acc)
		tick_acc = 0.0
	save_acc += delta
	if save_acc > 15.0:
		save_acc = 0.0
		_save_save()
	hb_acc += delta
	if hb_acc > 5.0:
		hb_acc = 0.0
		var hb := FileAccess.open("user://heartbeat.txt", FileAccess.WRITE)
		if hb:
			hb.store_string("%f players=%d conns=%d" % [Time.get_unix_time_from_system(), players.size(), clients.size()])

# ---------------------------------------------------------------- 消息处理

func _handle(id: int, msg: Dictionary) -> void:
	var t := str(msg.get("t", ""))
	var acc := str(clients[id].get("account", ""))
	if t == "hello":
		acc = str(msg.get("account", ""))
		if acc.is_empty():
			return
		if not players.has(acc):
			players[acc] = _new_player()
			print("[server] 新玩家 %s（%d 只蛙在线）" % [players[acc]["name"], players.size()])
		clients[id]["account"] = acc
		_send(id, {"t": "welcome", "name": players[acc]["name"]})
		_log_to(players[acc], "呱领养成功！先去商店买个便当吧")
		_send_state(acc)
		return
	if acc.is_empty() or not players.has(acc):
		return
	var p: Dictionary = players[acc]
	match t:
		"harvest": _do_harvest(p)
		"buy": _do_buy(p, str(msg.get("id", "")))
		"pack": _do_pack(p, str(msg.get("slot", "")), msg.get("id"))
		"feed": _do_feed(p, str(msg.get("uid", "")), str(msg.get("id", "")))
		"readmail":
			for card in p["mail"]:
				card["read"] = true
		_:
			return
	_send_state(acc)

# ---------------------------------------------------------------- 玩家

func _new_player() -> Dictionary:
	var name: String = G.FROG_NAMES[randi() % G.FROG_NAMES.size()] + "#%04d" % randi_range(0, 9999)
	return {
		"name": name,
		"clover": 30, "four": 0,
		"garden": 0.0,
		"inv": {"food": {"cong_bing": 1}, "item": {}, "charm": {}},
		"pack": {"food": "cong_bing", "charm": null, "item": null},
		"frog": {
			"mode": "idle", "act_left": 8.0,
			"trip_cooldown": G.TRIP_CD_FIRST, "left": 0.0, "total": 1.0,
			"dest": "", "cards_sent": 0, "had_charm": false, "trips": 0,
		},
		"mail": [], "yard": [],
		"gallery": {"cards": [], "gifts": [], "guests": []},
		"stats": {"trips": 0, "cards": 0, "new_cards": 0, "feedings": 0},
		"logs": [], "seq": 0, "no_food_logged": false,
	}

func _log_to(p: Dictionary, text: String) -> void:
	p["seq"] = int(p["seq"]) + 1
	var logs: Array = p["logs"]
	logs.append([p["seq"], text])
	while logs.size() > 12:
		logs.pop_front()

func _broadcast(text: String) -> void:
	for id in clients:
		var c: Dictionary = clients[id]
		if str(c["account"]).is_empty():
			continue
		_send(id, {"t": "glog", "text": text})

func _send(id: int, obj: Dictionary) -> void:
	var c = clients.get(id)
	if c == null:
		return
	var ws: WebSocketPeer = c["ws"]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(obj))

func _send_state(acc: String) -> void:
	var p = players.get(acc)
	if p == null:
		return
	var msg := {"t": "state", "s": _state_of(p)}
	for id in clients:
		var c: Dictionary = clients[id]
		if str(c["account"]) == acc:
			_send(id, msg)

func _state_of(p: Dictionary) -> Dictionary:
	var frog: Dictionary = p["frog"]
	var s := {
		"name": p["name"], "clover": p["clover"], "four": p["four"],
		"garden": p["garden"], "inv": p["inv"], "pack": p["pack"],
		"mail": p["mail"], "yard": p["yard"], "gallery": p["gallery"],
		"stats": p["stats"], "logs": p["logs"],
		"frog": {
			"mode": frog["mode"], "dest": frog["dest"],
			"left": frog["left"], "total": frog["total"],
			"trips": frog["trips"], "cd": maxf(0.0, frog["trip_cooldown"]),
			"act_text": G.ACTS.get(frog["mode"], "在发呆"),
		},
	}
	return s

# ---------------------------------------------------------------- 世界模拟

func _world_update(dt: float) -> void:
	for acc in players.keys().duplicate():
		var p: Dictionary = players[acc]
		_update_player(p, dt)
		_send_state(acc)

func _update_player(p: Dictionary, dt: float) -> void:
	# 花园生长
	if float(p["garden"]) < 1.0:
		p["garden"] = minf(1.0, float(p["garden"]) + dt / G.GROW_TIME)
	var frog: Dictionary = p["frog"]
	if frog["mode"] == "travel":
		_update_trip(p, dt)
	else:
		# 在家小动作
		frog["act_left"] = float(frog["act_left"]) - dt
		if float(frog["act_left"]) <= 0.0:
			_reroll_activity(p)
		# 出发倒计时
		frog["trip_cooldown"] = float(frog["trip_cooldown"]) - dt
		if float(frog["trip_cooldown"]) <= 0.0:
			_try_depart(p)
	# 访客
	var visit_cd: float = float(p.get("visit_cd", _rand_visit_cd())) - dt
	if visit_cd <= 0.0:
		if (p["yard"] as Array).size() < G.MAX_VISITORS:
			_spawn_visitor(p)
		visit_cd = _rand_visit_cd()
	p["visit_cd"] = visit_cd
	for v in (p["yard"] as Array).duplicate():
		v["life"] = float(v["life"]) - dt
		if float(v["life"]) <= 0.0:
			(p["yard"] as Array).erase(v)
			_log_to(p, "%s等不到人，悄悄离开了院子" % G.VISITORS[v["type"]]["name"])

func _rand_visit_cd() -> float:
	return randf_range(G.VISIT_CD_MIN, G.VISIT_CD_MAX)

func _reroll_activity(p: Dictionary) -> void:
	var frog: Dictionary = p["frog"]
	var pool := ["idle", "read", "write", "craft"]
	if _total_food(p) > 0:
		pool.append("eat")
	frog["mode"] = pool[randi() % pool.size()]
	frog["act_left"] = randf_range(G.ACT_MIN, G.ACT_MAX)

func _total_food(p: Dictionary) -> int:
	var n := 0
	for k in (p["inv"]["food"] as Dictionary):
		n += int(p["inv"]["food"][k])
	return n

# ---------------------------------------------------------------- 旅行

func _try_depart(p: Dictionary) -> void:
	var frog: Dictionary = p["frog"]
	var pack: Dictionary = p["pack"]
	var food_id = pack.get("food")
	var ok := food_id != null and int(p["inv"]["food"].get(food_id, 0)) > 0
	if not ok:
		pack["food"] = null
		frog["trip_cooldown"] = G.NO_FOOD_CD
		if not bool(p.get("no_food_logged", false)):
			p["no_food_logged"] = true
			_log_to(p, "蛙盯着空背包发呆——先准备一份便当它才肯出门")
		return
	p["no_food_logged"] = false
	# 消耗便当与护身符
	p["inv"]["food"][food_id] = int(p["inv"]["food"][food_id]) - 1
	if int(p["inv"]["food"][food_id]) <= 0:
		p["inv"]["food"].erase(food_id)
	pack["food"] = null
	var charm = pack.get("charm")
	var had_charm := charm != null
	if charm != null:
		if charm == G.FOUR:
			p["four"] = int(p["four"]) - 1
		else:
			p["inv"]["charm"][charm] = int(p["inv"]["charm"].get(charm, 0)) - 1
			if int(p["inv"]["charm"][charm]) <= 0:
				p["inv"]["charm"].erase(charm)
		pack["charm"] = null
	# 选择目的地
	var dest := _pick_dest(p)
	var dur := randf_range(G.TRIP_MIN, G.TRIP_MAX)
	frog["mode"] = "travel"
	frog["dest"] = dest
	frog["left"] = dur
	frog["total"] = dur
	frog["cards_sent"] = 0
	frog["had_charm"] = had_charm
	frog["trips"] = int(frog["trips"]) + 1
	frog["act_left"] = 1.0
	p["stats"]["trips"] = int(p["stats"]["trips"]) + 1
	_log_to(p, "呱背着包出门了，目的地【%s】，约 %d 秒后回家" % [dest, int(dur)])
	_broadcast("【全服】%s 的呱出发去【%s】了" % [p["name"], dest])

func _pick_dest(p: Dictionary) -> String:
	var weight := {}
	for d in G.DESTS:
		weight[d] = 1.0
	var pack: Dictionary = p["pack"]
	var food = pack.get("food")
	if food != null:
		for d in G.FOODS[food]["bias"]:
			weight[d] = float(weight[d]) + 2.5
	var item = pack.get("item")
	if item != null:
		for d in G.ITEMS[item]["bias"]:
			weight[d] = float(weight[d]) + 2.5
	var total := 0.0
	for d in weight:
		total += float(weight[d])
	var r := randf() * total
	for d in weight:
		r -= float(weight[d])
		if r <= 0.0:
			return d
	return "山"

func _update_trip(p: Dictionary, dt: float) -> void:
	var frog: Dictionary = p["frog"]
	frog["left"] = float(frog["left"]) - dt
	var frac := float(frog["left"]) / maxf(0.001, float(frog["total"]))
	var sent := int(frog["cards_sent"])
	if sent == 0 and frac <= 0.65:
		_send_card(p)
		frog["cards_sent"] = 1
	elif sent == 1 and frac <= 0.30:
		_send_card(p)
		frog["cards_sent"] = 2
	if float(frog["left"]) <= 0.0:
		_return_home(p)

func _send_card(p: Dictionary) -> void:
	var frog: Dictionary = p["frog"]
	var dest := str(frog["dest"])
	var pool := []
	for i in range(G.CARD_VARIANTS):
		pool.append(i)
	# 带了护身符的话，优先挑还没收集到的那张
	if bool(frog["had_charm"]):
		var have: Array = p["gallery"]["cards"]
		var unseen := []
		for i in pool:
			if not have.has(G.card_id(dest, i)):
				unseen.append(i)
		if not unseen.is_empty():
			pool = unseen
	var art: int = pool[randi() % pool.size()]
	var texts: Array = G.DESTS[dest]["texts"]
	var cid := G.card_id(dest, art)
	var card := {
		"cid": cid, "dest": dest, "art": art,
		"text": texts[randi() % texts.size()],
		"read": false, "t": int(Time.get_unix_time_from_system()),
	}
	(p["mail"] as Array).append(card)
	while (p["mail"] as Array).size() > 30:
		(p["mail"] as Array).pop_front()
	var is_new: bool = not (p["gallery"]["cards"] as Array).has(cid)
	if is_new:
		(p["gallery"]["cards"] as Array).append(cid)
		p["stats"]["new_cards"] = int(p["stats"]["new_cards"]) + 1
	p["stats"]["cards"] = int(p["stats"]["cards"]) + 1
	_log_to(p, "📮 收到【%s】寄来的明信片%s" % [dest, "（新收集！）" if is_new else ""])

func _return_home(p: Dictionary) -> void:
	var frog: Dictionary = p["frog"]
	var dest := str(frog["dest"])
	var had_charm := bool(frog["had_charm"])
	# 特产
	if had_charm or randf() < 0.65:
		var gifts: Array = G.DESTS[dest]["gifts"]
		var unseen := []
		for gname in gifts:
			if not (p["gallery"]["gifts"] as Array).has(gname):
				unseen.append(gname)
		var src: Array = unseen if not unseen.is_empty() else gifts
		var gift: String = src[randi() % src.size()]
		if not (p["gallery"]["gifts"] as Array).has(gift):
			(p["gallery"]["gifts"] as Array).append(gift)
		_log_to(p, "呱回家了，带回了特产【%s】" % gift)
	else:
		_log_to(p, "呱回家了，这次没带土特产")
	# 三叶草礼物
	var bonus := randi_range(0, 12) + (5 if had_charm else 0)
	if bonus > 0:
		p["clover"] = int(p["clover"]) + bonus
		_log_to(p, "呱把路上捡的 %d 株三叶草放进了院子" % bonus)
	if randf() < 0.06:
		p["four"] = int(p["four"]) + 1
		_log_to(p, "🍀 咦！门口长出了一株四叶草")
	frog["mode"] = "idle"
	frog["dest"] = ""
	frog["left"] = 0.0
	frog["trip_cooldown"] = randf_range(G.TRIP_CD_MIN, G.TRIP_CD_MAX)
	frog["act_left"] = randf_range(2.0, 6.0)
	_broadcast("【全服】%s 的呱从【%s】回来了" % [p["name"], dest])

# ---------------------------------------------------------------- 玩家操作

func _do_harvest(p: Dictionary) -> void:
	if float(p["garden"]) < 1.0:
		return
	var n := randi_range(4, 8)
	p["clover"] = int(p["clover"]) + n
	p["garden"] = 0.0
	var msg := "割下 %d 株三叶草" % n
	if randf() < 0.12:
		p["four"] = int(p["four"]) + 1
		msg += "，还发现一株四叶草！"
	_log_to(p, msg)

func _do_buy(p: Dictionary, id: String) -> void:
	var cat := ""
	var info = null
	if G.FOODS.has(id): cat = "food"; info = G.FOODS[id]
	elif G.ITEMS.has(id): cat = "item"; info = G.ITEMS[id]
	elif G.CHARMS.has(id): cat = "charm"; info = G.CHARMS[id]
	else: return
	var price := int(info["price"])
	if int(p["clover"]) < price:
		_log_to(p, "三叶草不够，买不起【%s】" % info["name"])
		return
	p["clover"] = int(p["clover"]) - price
	var inv: Dictionary = p["inv"]
	inv[cat][id] = int(inv[cat].get(id, 0)) + 1
	_log_to(p, "买下了【%s】（-%d☘）" % [info["name"], price])

func _do_pack(p: Dictionary, slot: String, id) -> void:
	var pack: Dictionary = p["pack"]
	var new_id = id if (id is String and not str(id).is_empty()) else null
	match slot:
		"food":
			if new_id == null:
				pack["food"] = null
			elif int(p["inv"]["food"].get(new_id, 0)) > 0:
				pack["food"] = new_id
		"charm":
			if new_id == null:
				pack["charm"] = null
			elif new_id == G.FOUR and int(p["four"]) > 0:
				pack["charm"] = new_id
			elif new_id == "yumite" and int(p["inv"]["charm"].get("yumite", 0)) > 0:
				pack["charm"] = new_id
		"item":
			if new_id == null:
				pack["item"] = null
			elif int(p["inv"]["item"].get(new_id, 0)) > 0:
				pack["item"] = new_id

func _spawn_visitor(p: Dictionary) -> void:
	var keys := G.VISITORS.keys()
	var type: String = keys[randi() % keys.size()]
	(p["yard"] as Array).append({
		"uid": "%d%d" % [Time.get_ticks_msec(), randi() % 100000],
		"type": type, "life": G.VISIT_LIFE,
	})
	_log_to(p, "院子里来了%s" % G.VISITORS[type]["name"])

func _do_feed(p: Dictionary, uid: String, food_id: String) -> void:
	var yard: Array = p["yard"]
	var visitor = null
	for v in yard:
		if v["uid"] == uid:
			visitor = v
	if visitor == null:
		return
	if int(p["inv"]["food"].get(food_id, 0)) <= 0:
		return
	p["inv"]["food"][food_id] = int(p["inv"]["food"][food_id]) - 1
	if int(p["inv"]["food"][food_id]) <= 0:
		p["inv"]["food"].erase(food_id)
	yard.erase(visitor)
	var info: Dictionary = G.VISITORS[visitor["type"]]
	var fav: bool = info["fav"] == food_id
	var reward := randi_range(15, 20) if fav else randi_range(6, 10)
	p["clover"] = int(p["clover"]) + reward
	if not (p["gallery"]["guests"] as Array).has(visitor["type"]):
		(p["gallery"]["guests"] as Array).append(visitor["type"])
	if fav and randf() < 0.18:
		var keys := G.ITEMS.keys()
		var gift: String = keys[randi() % keys.size()]
		p["inv"]["item"][gift] = int(p["inv"]["item"].get(gift, 0)) + 1
		_log_to(p, "%s吃饱了，留下【%s】和 %d☘ 才走" % [info["name"], G.ITEMS[gift]["name"], reward])
	else:
		_log_to(p, "%s吃了%s，留下 %d☘ 飞走了" % [info["name"], G.food_name(food_id), reward])
	p["stats"]["feedings"] = int(p["stats"]["feedings"]) + 1

# ---------------------------------------------------------------- 存档

func _save_save() -> void:
	if players.is_empty():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(players, "  "))

func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		players = data
		print("[server] 读档成功，共 %d 只蛙" % players.size())
