class_name Views
## 客户端自绘部件：青蛙、房间、花园、明信片小图。

# ================================================================= 青蛙

class FrogSprite extends Node2D:
	var mode := "idle"
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var bob := sin(t * 3.0) * 2.0 if mode != "idle" else sin(t * 1.5) * 1.5
		var c := Vector2(0, bob)
		# 影子
		draw_circle(c + Vector2(0, 30), 26, Color(0, 0, 0, 0.12))
		# 后腿
		draw_circle(c + Vector2(-20, 22), 9, Color(0x6fbf5eff))
		draw_circle(c + Vector2(20, 22), 9, Color(0x6fbf5eff))
		# 身体
		draw_circle(c, 30, Color(0x8fd47aff))
		# 肚皮
		draw_circle(c + Vector2(0, 9), 19, Color(0xe3f5cfff))
		# 眼睛
		for sx in [-1.0, 1.0]:
			draw_circle(c + Vector2(11 * sx, -8), 6, Color(0x2f3b2fff))
			draw_circle(c + Vector2(11 * sx - 2, -10), 2, Color(1, 1, 1, 0.9))
		# 腮红
		for sx in [-1.0, 1.0]:
			draw_circle(c + Vector2(21 * sx, 3), 4, Color(1, 0.65, 0.65, 0.55))
		# 嘴
		draw_arc(c + Vector2(0, 2), 7, PI * 0.15, PI * 0.85, 12, Color(0x2f3b2fff), 2.0)
		# 手里/面前的道具
		match mode:
			"read":
				draw_rect(Rect2(c + Vector2(-15, 8), Vector2(30, 13)), Color(0xf7f1e1ff))
				draw_line(c + Vector2(0, 8), c + Vector2(0, 21), Color(0xb9a888ff), 1.5)
				draw_rect(Rect2(c + Vector2(-15, 8), Vector2(30, 13)), Color(0x8a7a5cff), false, 1.5)
			"eat":
				draw_circle(c + Vector2(0, 15), 9, Color(0xd9884aff))
				draw_line(c + Vector2(-6, 4), c + Vector2(6, -6), Color(0x8a5a30ff), 2.0)
				draw_line(c + Vector2(-4, 3), c + Vector2(8, -7), Color(0x8a5a30ff), 2.0)
			"write":
				draw_rect(Rect2(c + Vector2(-22, 14), Vector2(44, 12)), Color(0xb98a5aff))
				draw_rect(Rect2(c + Vector2(-8, 12), Vector2(16, 10)), Color(0xfffdf5ff))
			"craft":
				draw_rect(Rect2(c + Vector2(-12, 12), Vector2(24, 9)), Color(0xc99a63ff))
				draw_line(c + Vector2(-4, 4), c + Vector2(10, 10), Color(0xddddddff), 3.0)
			"idle":
				pass

# ================================================================= 房间

class HouseView extends Control:
	func _draw() -> void:
		var s := size
		# 墙
		draw_rect(Rect2(Vector2.ZERO, s), Color(0xf7e9d2ff))
		# 墙裙
		draw_rect(Rect2(0, s.y * 0.55, s.x, s.y * 0.45), Color(0xefdcc0ff))
		# 地板
		draw_rect(Rect2(0, s.y * 0.72, s.x, s.y * 0.28), Color(0xd9b283ff))
		for i in range(8):
			var y := s.y * 0.72 + i * (s.y * 0.28 / 8.0)
			draw_line(Vector2(0, y), Vector2(s.x, y), Color(0xc79d70ff), 1.0)
		# 窗户
		var win := Rect2(s.x * 0.08, s.y * 0.10, s.x * 0.24, s.y * 0.30)
		draw_rect(win, Color(0xbfe6ffff))
		draw_circle(win.position + Vector2(win.size.x * 0.75, win.size.y * 0.3), 12, Color(0xfff3b0ff))
		draw_rect(win, Color(0xa97c50ff), false, 5.0)
		draw_line(win.position + Vector2(win.size.x / 2, 0), win.position + Vector2(win.size.x / 2, win.size.y), Color(0xa97c50ff), 3.0)
		# 窗帘
		draw_rect(Rect2(win.position + Vector2(-14, -8), Vector2(14, win.size.y + 16)), Color(0xf3a6a6ff))
		draw_rect(Rect2(win.position + Vector2(win.size.x, -8), Vector2(14, win.size.y + 16)), Color(0xf3a6a6ff))
		# 架子与照片
		draw_rect(Rect2(s.x * 0.72, s.y * 0.18, s.x * 0.2, 6), Color(0xb08a5eff))
		draw_rect(Rect2(s.x * 0.75, s.y * 0.08, 30, 34), Color(0xfff8eaff), false, 3.0)
		# 地毯
		draw_circle(Vector2(s.x * 0.5, s.y * 0.86), s.x * 0.16, Color(0xe8b7b7ff))
		draw_circle(Vector2(s.x * 0.5, s.y * 0.86), s.x * 0.11, Color(0xf3d3d3ff))

# ================================================================= 花园

class GardenView extends Control:
	var progress := 0.0
	var spots: Array = []
	var t := 0.0

	func _ready() -> void:
		resized.connect(func(): queue_redraw())

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		# 草地
		draw_rect(Rect2(Vector2.ZERO, s), Color(0xa9d97eff))
		draw_rect(Rect2(0, s.y * 0.6, s.x, s.y * 0.4), Color(0x9ccd70ff))
		# 栅栏
		var fence_y := s.y * 0.16
		for i in range(11):
			var x := i * (s.x / 10.0)
			draw_rect(Rect2(x - 4, fence_y - 26, 8, 34), Color(0xf0e3cbff))
		draw_rect(Rect2(0, fence_y - 16, s.x, 6), Color(0xe6d5b6ff))
		# 泥土花坛
		var bed := Rect2(s.x * 0.06, s.y * 0.24, s.x * 0.88, s.y * 0.46)
		draw_rect(bed, Color(0x8f6f4fff))
		draw_rect(bed, Color(0x7a5e41ff), false, 3.0)
		# 三叶草：按生长进度逐株出现
		var n := 12
		var grown := progress * n
		for i in range(n):
			var col := i % 4
			var row := i / 4
			var pos := Vector2(
				bed.position.x + bed.size.x * (0.16 + col * 0.22) + (20 if row == 1 else 0),
				bed.position.y + bed.size.y * (0.30 + row * 0.26)
			)
			var g := clampf(grown - i, 0.0, 1.0)
			if g <= 0.0:
				continue
			var scale := 0.35 + 0.65 * g
			var ready := progress >= 1.0
			var leaf := Color(0x3f9d4fff) if not ready else Color(0x2fb84aff)
			var stem_h := 16.0 * scale
			draw_line(pos, pos + Vector2(0, -stem_h), leaf.darkened(0.2), 2.0)
			for ang in [-0.7, 0.0, 0.7]:
				var lp := pos + Vector2(0, -stem_h) + Vector2(sin(ang) * 8 * scale, -cos(ang) * 8 * scale)
				draw_circle(lp, 5.5 * scale, leaf)
		# 长满时的提示
		if progress >= 1.0:
			var pulse := 0.5 + 0.5 * sin(t * 5.0)
			draw_rect(bed.grow(4.0), Color(1, 1, 0.6, 0.18 + 0.2 * pulse), false, 4.0)
		# 小路
		draw_rect(Rect2(s.x * 0.42, s.y * 0.72, s.x * 0.16, s.y * 0.28), Color(0xe4d3aeff))

# ================================================================= 明信片小图

class PostcardArt extends Control:
	var dest := "山"
	var art := 0
	var mono := false

	func _ready() -> void:
		resized.connect(func(): queue_redraw())
		custom_minimum_size = Vector2(214, 140)

	func _hx(v: int) -> Color:
		return Color.from_rgba8((v >> 16) & 255, (v >> 8) & 255, v & 255)

	func _draw() -> void:
		var s := size
		var d: Dictionary = GameData.DESTS.get(dest, GameData.DESTS["山"])
		var top := _hx(int(d["sky_top"]))
		var bottom := _hx(int(d["sky_bottom"]))
		var ground := _hx(int(d["ground"]))
		# 渐变天空
		for i in range(16):
			var f := i / 15.0
			var c := top.lerp(bottom, f)
			draw_rect(Rect2(0, s.y * 0.62 * f, s.x, s.y * 0.62 / 15.0 + 1), c)
		# 地面
		draw_rect(Rect2(0, s.y * 0.62, s.x, s.y * 0.38), ground)
		# 太阳/月亮
		var sun_x := s.x * (0.72 + (0.1 if art % 3 == 1 else 0.0))
		var sun_c := Color(0xfff0a8ff) if dest != "洞窟" else Color(0xe8f0ffff)
		draw_circle(Vector2(sun_x, s.y * 0.18), 13, sun_c)
		# 各地景观
		match str(d["shape"]):
			"mountain":
				draw_colored_polygon(PackedVector2Array([
					Vector2(s.x * 0.05, s.y * 0.64), Vector2(s.x * 0.38, s.y * 0.20),
					Vector2(s.x * 0.68, s.y * 0.64)]), Color(0x6f96b8ff))
				draw_colored_polygon(PackedVector2Array([
					Vector2(s.x * 0.45, s.y * 0.64), Vector2(s.x * 0.75, s.y * 0.30),
					Vector2(s.x * 1.0, s.y * 0.64)]), Color(0x5d84a8ff))
				draw_colored_polygon(PackedVector2Array([
					Vector2(s.x * 0.30, s.y * 0.32), Vector2(s.x * 0.38, s.y * 0.20),
					Vector2(s.x * 0.46, s.y * 0.32)]), Color(0xffffffff))
			"sea":
				draw_rect(Rect2(0, s.y * 0.52, s.x, s.y * 0.48), Color(0x4f9fd6ff))
				for i in range(4):
					var y := s.y * (0.58 + i * 0.10)
					for j in range(3):
						draw_arc(Vector2(s.x * (0.18 + j * 0.34), y), s.x * 0.10, PI, TAU, 10, Color(1, 1, 1, 0.7), 2.0)
			"onsen":
				draw_rect(Rect2(s.x * 0.1, s.y * 0.55, s.x * 0.8, s.y * 0.35), Color(0x7fb6c9ff))
				for i in range(3):
					draw_circle(Vector2(s.x * (0.3 + i * 0.2), s.y * (0.4 - 0.05 * i)), 10 + i * 3, Color(1, 1, 1, 0.4))
			"city":
				for i in range(6):
					var h := s.y * (0.18 + 0.06 * ((i + art) % 4))
					draw_rect(Rect2(s.x * (0.05 + i * 0.16), s.y * 0.62 - h, s.x * 0.12, h), Color(0x7d8aa0ff))
					for w in range(3):
						draw_rect(Rect2(s.x * (0.07 + i * 0.16) + w * 7, s.y * 0.62 - h + 6, 4, 5), Color(0xffe9a0ff))
			"forest":
				for i in range(5):
					var x := s.x * (0.10 + i * 0.2)
					draw_colored_polygon(PackedVector2Array([
						Vector2(x - 16, s.y * 0.64), Vector2(x, s.y * (0.26 + 0.05 * (i % 2))),
						Vector2(x + 16, s.y * 0.64)]), Color(0x3f7f52ff))
					draw_rect(Rect2(x - 3, s.y * 0.62, 6, 12), Color(0x6b4f33ff))
			"field":
				for i in range(14):
					var x := s.x * (0.03 + i * 0.07)
					var h := 12.0 + (i * 7 % 9)
					draw_line(Vector2(x, s.y * 0.72), Vector2(x + 3, s.y * 0.72 - h), Color(0x6fae4fff), 2.0)
				draw_circle(Vector2(s.x * 0.2, s.y * 0.78), 5, Color(0xfff2b0ff))
			"torii":
				var base := Color(0xd95b4aff)
				draw_rect(Rect2(s.x * 0.28, s.y * 0.28, 8, s.y * 0.36), base)
				draw_rect(Rect2(s.x * 0.64, s.y * 0.28, 8, s.y * 0.36), base)
				draw_rect(Rect2(s.x * 0.20, s.y * 0.26, s.x * 0.56, 9), base)
				draw_rect(Rect2(s.x * 0.24, s.y * 0.38, s.x * 0.48, 7), base)
			"cave":
				draw_colored_polygon(PackedVector2Array([
					Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.30),
					Vector2(s.x * 0.6, s.y * 0.55), Vector2(s.x * 0.35, s.y * 0.30),
					Vector2(0, s.y * 0.5)]), Color(0x2b3244ff))
				draw_circle(Vector2(s.x * 0.5, s.y * 0.66), 14, Color(0xffe9a0, 0.5))
		# 小青蛙
		var fx := s.x * (0.16 + 0.1 * (art % 3))
		var fy := s.y * 0.84
		draw_circle(Vector2(fx, fy), 7, Color(0x4f9e4aff))
		draw_circle(Vector2(fx - 2.5, fy - 3), 1.6, Color(0x22301fff))
		draw_circle(Vector2(fx + 2.5, fy - 3), 1.6, Color(0x22301fff))
		# 白框
		draw_rect(Rect2(Vector2.ZERO, s), Color(0xffffffff), false, 4.0)
		if mono:
			draw_rect(Rect2(Vector2.ZERO, s), Color(0.45, 0.45, 0.45, 0.72))
