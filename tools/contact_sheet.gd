extends SceneTree
## 把 _source/extracted 里全部精灵排成带编号的索引图，方便肉眼认领。
## 用法：
##   Godot_v4.7.2-stable_win64.exe --path . --script res://tools/contact_sheet.gd
## 产物：docs/sheet_0.png ... docs/sheet_N.png

const SRC_DIR := "C:/Users/96103/Desktop/games/my-game/_source/extracted"
const OUT_DIR := "res://docs"
const COLS := 26
const ROWS := 12
const PER_PAGE := COLS * ROWS


func _initialize() -> void:
	var names := _list_png(DirAccess.open(SRC_DIR))
	print("找到 %d 张精灵" % names.size())

	# 按编号排序（item1, item2, ... item10 排在 item9 前面，这里用数值排序）
	var entries: Array = []
	for n in names:
		entries.append({"name": n, "idx": int(n.get_basename().replace("item", ""))})
	entries.sort_custom(func(a, b): return int(a["idx"]) < int(b["idx"]))

	var page := 0
	var i := 0
	while i < entries.size():
		var chunk: Array = entries.slice(i, mini(i + PER_PAGE, entries.size()))
		await _render_page(chunk, page)
		page += 1
		i += PER_PAGE

	print("完成，共 %d 页" % page)
	quit()


func _render_page(chunk: Array, page: int) -> void:
	var canvas := SheetCanvas.new()
	canvas.cols = COLS
	for e in chunk:
		var img := Image.load_from_file(SRC_DIR + "/" + str(e["name"]))
		canvas.cells.append({
			"tex": ImageTexture.create_from_image(img),
			"label": str(e["idx"]),
		})
	canvas.size = Vector2(COLS * canvas.cell_w, ROWS * canvas.cell_h)
	root.add_child(canvas)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var out := "%s/sheet_%d.png" % [OUT_DIR, page]
	var err := root.get_texture().get_image().save_png(out)
	print("PAGE:", err, " -> ", ProjectSettings.globalize_path(out))
	root.remove_child(canvas)
	canvas.free()


func _list_png(dir: DirAccess) -> Array[String]:
	var out: Array[String] = []
	if dir == null:
		return out
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if not dir.current_is_dir() and n.to_lower().ends_with(".png"):
			out.append(n)
		n = dir.get_next()
	dir.list_dir_end()
	return out
