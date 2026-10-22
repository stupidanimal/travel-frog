extends SceneTree

func _init() -> void:
	print("COLOR_INT=", Color(0xf7e9d2ff))
	print("COLOR_STR=", Color("f7e9d2"))
	var files := [
		"res://main.gd",
		"res://scripts/game_data.gd",
		"res://scripts/views.gd",
		"res://scripts/panels.gd",
		"res://scripts/client_app.gd",
		"res://scripts/server_logic.gd",
	]
	for p in files:
		var s = load(p)
		print(p, " -> ", "OK" if s != null else "FAIL")
	quit()
