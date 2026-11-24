class_name MainGame
extends Control
## 主流程：关卡流程 + HUD + 目标判定 + 胜负结算 + 存档 / 图鉴 / 关卡选择。

const GEN_BUTTONS := {"leaf": "GenLeaf", "wheat": "GenWheat", "dew": "GenDew"}

@onready var board: Board = $Board
@onready var title_label: Label = $Header/Title
@onready var subtitle_label: Label = $Header/Subtitle
@onready var hint_label: Label = $Header/HintLabel
@onready var target_label: Label = $Header/TargetBox/TargetLabel
@onready var moves_label: Label = $Header/TargetBox/MovesLabel
@onready var score_label: Label = $Header/TargetBox/ScoreLabel
@onready var combo_label: Label = $Header/TargetBox/ComboLabel
@onready var gen_label: Label = $Header/TargetBox/GenLabel
@onready var recipe_title: Label = $Side/RecipeTitle
@onready var recipe_list: VBoxContainer = $Side/RecipeScroll/RecipeList
@onready var tool_title: Label = $Side/ToolTitle
@onready var tool_help: VBoxContainer = $Side/ToolHelp
@onready var gen_title: Label = $Side/GenTitle
@onready var restart_button: Button = $Side/RestartButton
@onready var overlay: Control = $Overlay
@onready var overlay_title: Label = $Overlay/Center/Panel/VBox/Title
@onready var overlay_text: Label = $Overlay/Center/Panel/VBox/Text
@onready var primary_button: Button = $Overlay/Center/Panel/VBox/Buttons/Primary
@onready var secondary_button: Button = $Overlay/Center/Panel/VBox/Buttons/Secondary

var level_index := 0
var objective: Dictionary = {}
var moves_left := 0
var move_total := 0
var gen_used := 0
var gen_limit := 0
var score := 0
var combo := 0
var level_over := false
var save_data: Dictionary = {}

var _primary_action := "next"
var _toast: Label
var _building := false          ## 正在摆开局物品：这期间不判定目标
var _discovered := {}            ## 已发现的配方 key -> true
var level_overlay: Control
var level_buttons: Array[Button] = []
var level_stars: Array[Label] = []


func _ready() -> void:
	randomize()

	save_data = SaveData.load_data()
	for k in save_data.get("recipes", []):
		_discovered[str(k)] = true

	board.merged.connect(_on_merged)
	board.board_changed.connect(_on_board_changed)
	board.notice.connect(_toast_show)
	board.acted.connect(_on_acted)
	board.recipe_found.connect(_on_recipe_found)

	for id in GameData.BASE_ITEMS:
		var node_name := str(GEN_BUTTONS.get(id, ""))
		if node_name == "":
			continue
		var b: Button = $Side/GenRow.get_node(node_name)
		b.text = GameData.item_name(id)
		b.pressed.connect(_on_generate.bind(id))

	restart_button.pressed.connect(_on_restart)
	primary_button.pressed.connect(_on_primary)
	secondary_button.pressed.connect(_on_restart)

	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.size = Vector2(300.0, 40.0)
	_toast.position = Vector2(178.0, 330.0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 17)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.13, 0.92)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	sb.border_color = Color(1.0, 0.85, 0.45, 0.45)
	sb.set_border_width_all(1)
	_toast.add_theme_stylebox_override("normal", sb)
	_toast.modulate.a = 0.0
	add_child(_toast)

	var level_btn := Button.new()
	level_btn.text = "关卡选择"
	level_btn.add_theme_font_size_override("font_size", 17)
	level_btn.pressed.connect(show_level_select)
	$Side.add_child(level_btn)

	_build_recipe_list()
	_build_tool_help()
	_build_level_select()

	# 从上次解锁的地方继续；第一次玩就是第一关
	start_level(_unlocked())
	show_level_select()


# ---------- 关卡流程 ----------

func start_level(index: int) -> void:
	level_index = clampi(index, 0, GameData.LEVELS.size() - 1)
	var lv: Dictionary = GameData.LEVELS[level_index]
	objective = lv.get("objective", {"type": "make", "items": ["berry"]})
	move_total = int(lv["moves"])
	moves_left = move_total
	gen_limit = int(lv.get("gen_limit", 3))
	gen_used = 0
	score = 0
	combo = 0
	level_over = false

	overlay.visible = false
	if level_overlay != null:
		level_overlay.visible = false
	board.locked = false
	board.build()
	_building = true
	for id in lv["start"]:
		board.spawn_random(str(id))
	for t in lv.get("tools", []):
		board.spawn_random(str(t))
	_building = false

	title_label.text = "合成小院"
	subtitle_label.text = "%s · %s" % [str(lv["name"]), GameData.objective_plan(objective, lv)]
	hint_label.text = str(lv.get("hint", ""))
	hint_label.visible = hint_label.text != ""
	_build_tool_help()
	_update_hud()


func _on_acted(kind: String) -> void:
	if kind == "merge":
		combo += 1
		score += 10 * combo
		if combo >= 3:
			_toast_show("连击 ×%d ！" % combo)
	else:
		combo = 0


func _on_merged(_result_id: String) -> void:
	if level_over:
		return
	moves_left -= 1


## 玩家第一次摸到某条配方 → 图鉴解锁
func _on_recipe_found(key: String) -> void:
	if _discovered.has(key):
		return
	_discovered[key] = true
	save_data["recipes"] = _discovered.keys()
	SaveData.write_data(save_data)
	_build_recipe_list()


func _on_board_changed() -> void:
	if level_over or _building:
		return
	_update_hud()
	if _objective_done():
		_win()
		return
	if moves_left <= 0:
		_lose()


## 当前目标是否达成
func _objective_done() -> bool:
	match str(objective.get("type", "make")):
		"count":
			return board.count_item(str(objective["items"][0])) >= int(objective.get("n", 1))
		"purge":
			return board.item_count() <= int(objective.get("left", 1))
		_:
			for it in objective.get("items", []):
				if not board.has_item(str(it)):
					return false
			return true


func _win() -> void:
	level_over = true
	board.locked = true
	var stars := _stars()
	overlay_title.text = "过关！ " + "★".repeat(stars) + "☆".repeat(3 - stars)
	var extra := ""
	if str(objective.get("type", "")) == "purge":
		extra = " · 背包剩 %d 件" % board.item_count()
	overlay_text.text = "%s · 剩余 %d 步 · 得分 %d%s" % [
		GameData.objective_text(objective), moves_left, score, extra]
	_record_progress(stars)
	_primary_action = "next"
	primary_button.text = "下一关" if level_index + 1 < GameData.LEVELS.size() else "再来一轮"
	secondary_button.visible = true
	overlay.visible = true


## 星级按「这一关最少需要几步」校准：刚好用最优步数 = 三星，多用两步 = 二星
func _stars() -> int:
	var used := move_total - moves_left
	var best := _best_steps()
	if used <= best:
		return 3
	if used <= best + 2:
		return 2
	return 1


func _best_steps() -> int:
	var lv: Dictionary = GameData.LEVELS[level_index]
	return int(lv.get("best", 0))


func _lose() -> void:
	level_over = true
	board.locked = true
	overlay_title.text = "步数用完了"
	overlay_text.text = "没能达成「%s」。重玩一次，试试先造哪一件。" % GameData.objective_text(objective)
	_primary_action = "retry"
	primary_button.text = "重玩本关"
	secondary_button.visible = false
	overlay.visible = true


func _on_primary() -> void:
	if _primary_action == "next":
		if level_index + 1 < GameData.LEVELS.size():
			start_level(level_index + 1)
		else:
			start_level(0)
	else:
		start_level(level_index)


func _on_restart() -> void:
	start_level(level_index)


func _on_generate(id: String) -> void:
	if level_over:
		return
	if gen_used >= gen_limit:
		_toast_show("本关生成次数用完了")
		return
	if moves_left <= 0:
		_toast_show("步数已经用完了")
		return
	if board.spawn_random(id):
		gen_used += 1
		_update_hud()
	else:
		_toast_show("背包满了，先合成掉几件吧")


# ---------- 存档 ----------

func _unlocked() -> int:
	return clampi(int(save_data.get("unlocked", 0)), 0, GameData.LEVELS.size() - 1)


func _saved_stars(idx: int) -> int:
	var stars_map: Dictionary = save_data.get("stars", {})
	return int(stars_map.get(str(idx), 0))


func _record_progress(stars: int) -> void:
	var stars_map: Dictionary = save_data.get("stars", {})
	if int(stars_map.get(str(level_index), 0)) < stars:
		stars_map[str(level_index)] = stars
	save_data["stars"] = stars_map
	if level_index + 1 < GameData.LEVELS.size() and level_index + 1 > _unlocked():
		save_data["unlocked"] = level_index + 1
	SaveData.write_data(save_data)
	_refresh_level_select()


# ---------- 关卡选择面板 ----------

func _build_level_select() -> void:
	level_overlay = Control.new()
	level_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	level_overlay.visible = false
	add_child(level_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	level_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.098, 0.110, 0.149, 0.98)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "合成小院"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.847, 0.443))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "选一关开始 · 通关解锁下一关 · 三星 = 用最少步数通关"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.70, 0.76, 0.86))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(grid)

	for i in GameData.LEVELS.size():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		grid.add_child(cell)
		var b := Button.new()
		b.text = "第 %d 关" % (i + 1)
		b.custom_minimum_size = Vector2(140, 42)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_on_level_picked.bind(i))
		cell.add_child(b)
		level_buttons.append(b)
		var s := Label.new()
		s.add_theme_font_size_override("font_size", 14)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(s)
		level_stars.append(s)

	var close := Button.new()
	close.text = "继续当前关卡"
	close.custom_minimum_size = Vector2(0, 42)
	close.add_theme_font_size_override("font_size", 17)
	close.pressed.connect(hide_level_select)
	vb.add_child(close)

	_refresh_level_select()


func _refresh_level_select() -> void:
	var unlocked := _unlocked()
	for i in level_buttons.size():
		var b: Button = level_buttons[i]
		var s: Label = level_stars[i]
		if i > unlocked:
			b.disabled = true
			s.text = "未解锁"
			s.add_theme_color_override("font_color", Color(0.48, 0.52, 0.60))
		else:
			b.disabled = false
			var st := _saved_stars(i)
			if st > 0:
				s.text = "★".repeat(st) + "☆".repeat(3 - st)
				s.add_theme_color_override("font_color", Color(1.0, 0.843, 0.443))
			else:
				s.text = "未通关"
				s.add_theme_color_override("font_color", Color(0.70, 0.76, 0.86))


func show_level_select() -> void:
	if level_overlay == null:
		return
	_refresh_level_select()
	level_overlay.visible = true


func hide_level_select() -> void:
	if level_overlay != null:
		level_overlay.visible = false


func _on_level_picked(idx: int) -> void:
	if idx > _unlocked():
		return
	hide_level_select()
	start_level(idx)


# ---------- HUD ----------

func _update_hud() -> void:
	target_label.text = "目标：" + GameData.objective_text(objective)
	moves_label.text = "步数 %d / %d" % [moves_left, move_total]
	if moves_left <= 2:
		moves_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	else:
		moves_label.add_theme_color_override("font_color", Color(0.72, 0.92, 0.78))
	score_label.text = "得分 %d" % score
	combo_label.text = "连击 ×%d" % combo
	gen_label.text = "生成 %d / %d" % [gen_used, gen_limit]

	var can_gen := gen_used < gen_limit and not level_over
	for id in GameData.BASE_ITEMS:
		var node_name := str(GEN_BUTTONS.get(id, ""))
		if node_name == "":
			continue
		($Side/GenRow.get_node(node_name) as Button).disabled = not can_gen


## 合成图鉴：没合成过的配方先不显示，靠玩家自己试出来
func _build_recipe_list() -> void:
	for c in recipe_list.get_children():
		recipe_list.remove_child(c)
		c.queue_free()
	var found := 0
	for key in GameData.RECIPES:
		if not _discovered.has(key):
			continue
		found += 1
		var parts := str(key).split("+")
		var res := str(GameData.RECIPES[key])
		var l := Label.new()
		l.text = "%s + %s = %s" % [GameData.item_name(parts[0]), GameData.item_name(parts[1]),
				GameData.item_name(res)]
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Color(0.82, 0.87, 0.95))
		recipe_list.add_child(l)
	var total := GameData.RECIPES.size()
	recipe_title.text = "合成图鉴 (%d / %d)" % [found, total]
	if found < total:
		var l2 := Label.new()
		l2.text = "还有 %d 条配方没发现" % (total - found)
		l2.add_theme_font_size_override("font_size", 15)
		l2.add_theme_color_override("font_color", Color(0.50, 0.56, 0.66))
		recipe_list.add_child(l2)


## 道具说明：只列玩家已经遇到过的（解锁到的关卡 + 当前关卡）
func _known_tools() -> Array:
	var out: Array = []
	var upto := maxi(level_index, _unlocked())
	for i in range(0, upto + 1):
		for t in GameData.LEVELS[i].get("tools", []):
			if not out.has(str(t)):
				out.append(str(t))
	return out


func _build_tool_help() -> void:
	for c in tool_help.get_children():
		tool_help.remove_child(c)
		c.queue_free()
	var known := _known_tools()
	if known.is_empty():
		tool_title.text = "道具（还没遇到）"
		var l := Label.new()
		l.text = "后面的关卡会出现道具"
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.58, 0.63, 0.73))
		tool_help.add_child(l)
		return
	tool_title.text = "道具（拖到物品上生效）"
	for id in GameData.TOOLS:
		if not known.has(str(id)):
			continue
		var l := Label.new()
		l.text = "%s：%s" % [GameData.item_name(str(id)), GameData.tool_desc(str(id))]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.95, 0.78, 0.55))
		tool_help.add_child(l)


func _toast_show(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
