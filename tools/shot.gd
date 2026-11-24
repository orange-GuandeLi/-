extends SceneTree
## 开发用截图工具：跑主场景并把画面存成 png。
## 用法（在项目根目录）：
##   Godot_v4.7.2-stable_win64.exe --path . --script res://tools/shot.gd -- [关卡序号]
## 关卡序号 0 起；传 -1 则展示全部物品；传 menu 则截关卡选择面板。
## 截图用独立的存档文件，不会动玩家的存档。

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var level := 0
	var mode := "level"
	if args.size() > 0:
		var a := str(args[0])
		if a == "menu":
			mode = "menu"
		else:
			level = int(a)

	# 截图专用存档：解锁到第 4 关，图鉴发现 4 条
	SaveData.save_path = "user://shot_save.json"
	SaveData.write_data({
		"stars": {"0": 3, "1": 2, "2": 3},
		"unlocked": 3,
		"recipes": ["leaf+leaf", "flower+flower", "wheat+wheat", "sprout+sprout"],
		"best_score": 0,
	})

	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame

	if mode == "level":
		if level < 0:
			_showcase(main)
		else:
			main.start_level(level)
	await process_frame

	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw

	DirAccess.make_dir_recursive_absolute("res://docs")
	var name := "showcase.png"
	if mode == "menu":
		name = "menu.png"
	elif level >= 0:
		name = "level%d.png" % (level + 1)
	var out := "res://docs/" + name
	var err := root.get_texture().get_image().save_png(out)
	print("SHOT_SAVE:", err, " -> ", ProjectSettings.globalize_path(out))
	quit()


## 把 10 件物品 + 3 件道具各摆一个到棋盘上，用于核对美术
func _showcase(main: Node) -> void:
	main.start_level(0)
	main.hide_level_select()
	var board: Board = main.get_node("Board")
	board.build()
	var ids: Array = []
	for id in GameData.ITEMS:
		ids.append(id)
	for id in GameData.TOOLS:
		ids.append(id)
	var i := 0
	for y in 3:
		for x in 6:
			if i >= ids.size():
				break
			board.spawn(str(ids[i]), Vector2i(x, y))
			i += 1
	main.set("level_over", true)
