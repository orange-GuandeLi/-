extends SceneTree
## 把指定编号的精灵放大排成一张对照图，用来确认「哪个才是我要的」。
## 用法：
##   Godot_v4.7.2-stable_win64.exe --path . --script res://tools/zoom_candidates.gd

const SRC_DIR := "C:/Users/96103/Desktop/games/my-game/_source/extracted"
const OUT_DIR := "res://docs"

const CANDIDATES := [
	# 斧头 / 刀 / 锤
	651, 652, 653, 654, 655, 656, 758, 759, 760, 799, 800, 802,
	815, 816, 829, 830, 831, 832, 838, 839, 840, 841, 842, 843,
	894, 895, 897, 906, 907, 908, 909,
	# 药水 / 瓶
	949, 950, 797, 798, 805, 370, 371, 764, 765, 766, 769, 770,
	# 桶 / 篓 / 袋
	792, 810, 811, 807, 808, 812, 813, 793, 794,
]

const COLS := 12
const ROWS_PER_PAGE := 6
const SCALE := 5.0


func _initialize() -> void:
	var per_page := COLS * ROWS_PER_PAGE
	var page := 0
	var i := 0
	while i < CANDIDATES.size():
		var chunk: Array = CANDIDATES.slice(i, mini(i + per_page, CANDIDATES.size()))
		await _render_page(chunk, page)
		page += 1
		i += per_page
	print("完成，共 %d 页" % page)
	quit()


func _render_page(chunk: Array, page: int) -> void:
	var canvas := SheetCanvas.new()
	canvas.cols = COLS
	canvas.cell_w = 16.0 * SCALE + 10.0
	canvas.cell_h = 16.0 * SCALE + 16.0
	canvas.sprite_scale = SCALE
	for idx in chunk:
		var path := SRC_DIR + "/item%d.png" % int(idx)
		var img := Image.load_from_file(path)
		if img == null:
			print("缺失: item%d.png" % int(idx))
			continue
		canvas.cells.append({
			"tex": ImageTexture.create_from_image(img),
			"label": str(idx),
		})
	canvas.size = Vector2(COLS * canvas.cell_w, ROWS_PER_PAGE * canvas.cell_h)
	root.add_child(canvas)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var out := "%s/tools_%d.png" % [OUT_DIR, page]
	var err := root.get_texture().get_image().save_png(out)
	print("PAGE:", err, " -> ", ProjectSettings.globalize_path(out))
	root.remove_child(canvas)
	canvas.free()
