extends Node
## 入口：根据命令行参数决定是跑服务器（--server）还是跑客户端。

func _ready() -> void:
	randomize()
	_load_font()
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		var server := ServerLogic.new()
		server.name = "Server"
		add_child(server)
	else:
		var client := ClientApp.new()
		client.name = "Client"
		add_child(client)

func _load_font() -> void:
	var candidates := [
		"res://fonts/NotoSansSC-Regular.otf",
		"C:/Windows/Fonts/msyh.ttc",
		"C:/Windows/Fonts/msyhbd.ttc",
		"C:/Windows/Fonts/simhei.ttf",
	]
	for p in candidates:
		if not FileAccess.file_exists(p):
			continue
		var f := FontFile.new()
		if f.load_dynamic_font(p) == OK:
			ThemeDB.fallback_font = f
			ThemeDB.fallback_font_size = 15
			return
	push_warning("没有找到中文字体，界面可能出现方框")
