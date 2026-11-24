class_name Board
extends Control
## 背包棋盘：6×5 格子，负责鼠标拖拽、合成、交换、移动，以及道具效果。
## 格子即"背包隔层"，物品不能重叠，每格最多一件。

signal merged(result_id: String)
signal board_changed
signal notice(text: String)
signal acted(kind: String)   ## merge / move / swap / tool —— 用于连击判定
signal recipe_found(key: String)   ## 玩家第一次摸到某条配方（用于图鉴解锁）

const COLS := 6
const ROWS := 5

var items := {}     ## Vector2i -> Item
var cells := {}     ## Vector2i -> Panel

var _layer_cells: Control
var _layer_items: Control
var _hint: Label

var dragging: Item = null
var locked := false
var _drag_from := Vector2i.ZERO
var _grab_offset := Vector2.ZERO

var _style_normal: StyleBoxFlat
var _style_hot: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.16, 0.18, 0.24, 0.85)
	_style_normal.set_corner_radius_all(10)
	_style_normal.border_color = Color(1, 1, 1, 0.05)
	_style_normal.set_border_width_all(1)
	_style_hot = StyleBoxFlat.new()
	_style_hot.bg_color = Color(0.24, 0.34, 0.28, 0.95)
	_style_hot.set_corner_radius_all(10)
	_style_hot.border_color = Color(0.55, 0.9, 0.6, 0.85)
	_style_hot.set_border_width_all(2)


## 重建棋盘（换关时调用）
func build() -> void:
	for n in get_children():
		remove_child(n)
		n.queue_free()
	items.clear()
	cells.clear()

	_layer_cells = Control.new()
	_layer_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer_cells)

	_layer_items = Control.new()
	_layer_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer_items)

	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.z_index = 200
	_hint.visible = false
	_hint.add_theme_font_size_override("font_size", 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.13, 0.94)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(7)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	_hint.add_theme_stylebox_override("normal", sb)
	_layer_items.add_child(_hint)

	for y in ROWS:
		for x in COLS:
			var p := Panel.new()
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.size = Vector2(GameData.SLOT, GameData.SLOT)
			p.position = _slot_pos(x, y)
			p.add_theme_stylebox_override("panel", _style_normal)
			_layer_cells.add_child(p)
			cells[Vector2i(x, y)] = p


# ---------- 放置 ----------

func _slot_pos(x: int, y: int) -> Vector2:
	return Vector2(x * GameData.PITCH, y * GameData.PITCH)


func _item_pos(cell: Vector2i) -> Vector2:
	return _slot_pos(cell.x, cell.y) + Vector2((GameData.SLOT - GameData.ITEM) * 0.5, (GameData.SLOT - GameData.ITEM) * 0.5)


func _cell_at(local_pos: Vector2) -> Vector2i:
	var x := int(floor(local_pos.x / GameData.PITCH))
	var y := int(floor(local_pos.y / GameData.PITCH))
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func spawn(id: String, cell: Vector2i) -> Item:
	var it := Item.new()
	_layer_items.add_child(it)
	it.setup(id)
	it.cell = cell
	it.position = _item_pos(cell)
	it.size = Vector2(GameData.ITEM, GameData.ITEM)
	items[cell] = it
	return it


## 随机找一个空格子放进去；背包满了返回 false
func spawn_random(id: String) -> bool:
	var free_cells: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			if not items.has(c):
				free_cells.append(c)
	if free_cells.is_empty():
		return false
	var pick: Vector2i = free_cells[randi() % free_cells.size()]
	spawn(id, pick)
	board_changed.emit()
	return true


func has_item(id: String) -> bool:
	return count_item(id) > 0


## 场上有几件指定物品（道具不计入）
func count_item(id: String) -> int:
	var n := 0
	for c in items:
		if (items[c] as Item).item_id == id:
			n += 1
	return n


## 普通物品数量（道具不计入）
func item_count() -> int:
	var n := 0
	for c in items:
		if not GameData.is_tool_item((items[c] as Item).item_id):
			n += 1
	return n


func free_cell_count() -> int:
	return COLS * ROWS - items.size()


func _first_free_cell(exclude: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			if c != exclude and not items.has(c):
				return c
	return Vector2i(-1, -1)


# ---------- 鼠标拖拽 ----------

func _input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				begin_drag_at(get_local_mouse_position())
			elif dragging != null:
				end_drag_at(get_local_mouse_position())
	elif event is InputEventMouseMotion and dragging != null:
		drag_to(get_local_mouse_position())


## 按下：在该点抓起一个物品
func begin_drag_at(lp: Vector2) -> void:
	var picked: Item = null
	for c in items:
		var it: Item = items[c]
		if it.get_rect().has_point(lp):
			picked = it
	if picked == null:
		return
	dragging = picked
	_drag_from = picked.cell
	_grab_offset = lp - picked.position
	picked.z_index = 50
	picked.scale = Vector2(1.08, 1.08)
	update_hover(lp)


## 拖动中
func drag_to(lp: Vector2) -> void:
	dragging.position = lp - _grab_offset
	update_hover(lp)


## 松手：判定移动 / 合成 / 交换 / 道具
func end_drag_at(lp: Vector2) -> void:
	var item := dragging
	dragging = null
	_hint.visible = false
	item.z_index = 0
	item.scale = Vector2.ONE

	var target := _cell_at(lp)
	if target.x < 0 or target.y < 0 or target == _drag_from:
		_place(item, _drag_from)
		return

	if not items.has(target):
		_place(item, target)
		acted.emit("move")
		board_changed.emit()
		return

	var other: Item = items[target]
	if other.item_id == item.item_id:
		var res := GameData.merge_result(item.item_id, other.item_id)
		if res == "":
			_place(item, _drag_from)
			notice.emit("%s 和 %s 合不起来" % [GameData.item_name(item.item_id), GameData.item_name(other.item_id)])
			return
		var key := item.item_id + "+" + other.item_id
		_erase(item)
		_erase(other)
		var made := spawn(res, target)
		made.pop()
		_flash_cell(target)
		recipe_found.emit(key)
		acted.emit("merge")
		merged.emit(res)
		board_changed.emit()
	elif GameData.is_tool_item(item.item_id):
		_apply_tool(item, other, target)
	else:
		_place(item, target)
		_place(other, _drag_from)
		acted.emit("swap")
		board_changed.emit()


## 道具生效：斧头劈开 / 药水升级 / 布袋复制
func _apply_tool(tool: Item, target_item: Item, target_cell: Vector2i) -> void:
	var effect := GameData.tool_effect(tool.item_id)
	var tid := target_item.item_id
	var result_id := ""
	var need_cells := 1
	var recipe_key := ""

	match effect:
		"boost":
			result_id = GameData.upgrade_of(tid)
			if result_id == "":
				notice.emit("%s 已经没法再升级了" % GameData.item_name(tid))
				_place(tool, _drag_from)
				return
			recipe_key = tid + "+" + tid
		"split":
			result_id = GameData.downgrade_of(tid)
			if result_id == "":
				notice.emit("%s 是最基础的，没法再劈开" % GameData.item_name(tid))
				_place(tool, _drag_from)
				return
			need_cells = 2
			recipe_key = result_id + "+" + result_id
		"copy":
			result_id = tid
			need_cells = 2
		_:
			_place(tool, _drag_from)
			return

	# 空间够不够
	var spots: Array[Vector2i] = [target_cell]
	if need_cells == 2:
		var second := _first_free_cell(target_cell)
		if second.x < 0:
			notice.emit("背包满了，先腾出两个格子")
			_place(tool, _drag_from)
			return
		spots.append(second)

	# 消耗道具与目标
	_erase(tool)
	_erase(target_item)
	for i in spots.size():
		var made := spawn(result_id, spots[i])
		made.pop()
	_flash_cell(target_cell)

	notice.emit("%s：%s → %d 个%s" % [GameData.item_name(tool.item_id),
			GameData.tool_desc(tool.item_id), spots.size(), GameData.item_name(result_id)])
	if recipe_key != "":
		recipe_found.emit(recipe_key)
	acted.emit("tool")
	board_changed.emit()


## 合成 / 道具生效时，让目标格子闪一下，给玩家一个视觉落点
func _flash_cell(cell: Vector2i) -> void:
	var p: Panel = cells.get(cell)
	if p == null:
		return
	p.modulate = Color(1.7, 1.7, 1.7, 1.0)
	# 用格子自己的 tween：换关时格子被释放，动画跟着一起消失，不会报错
	var tw := p.create_tween()
	tw.tween_property(p, "modulate", Color(1, 1, 1, 1), 0.28)


func _place(item: Item, cell: Vector2i) -> void:
	if items.get(item.cell) == item:
		items.erase(item.cell)
	item.cell = cell
	item.position = _item_pos(cell)
	items[cell] = item


func _erase(item: Item) -> void:
	if items.get(item.cell) == item:
		items.erase(item.cell)
	item.queue_free()


## 格子中心点（拖拽命中判定 / 自动化测试用）
func cell_center(cell: Vector2i) -> Vector2:
	return _slot_pos(cell.x, cell.y) + Vector2(GameData.SLOT, GameData.SLOT) * 0.5


## 拖拽过程中高亮可合成的格子，并给出提示文案
func update_hover(lp: Vector2) -> void:
	var target := _cell_at(lp)
	for c in cells:
		(cells[c] as Panel).add_theme_stylebox_override("panel", _style_normal)

	var txt := ""
	if target.x >= 0 and target.y >= 0 and items.has(target):
		var other: Item = items[target]
		if other != dragging:
			if other.item_id == dragging.item_id:
				var res := GameData.merge_result(dragging.item_id, other.item_id)
				if res != "":
					txt = "%s + %s = %s" % [GameData.item_name(dragging.item_id),
							GameData.item_name(other.item_id), GameData.item_name(res)]
					(cells[target] as Panel).add_theme_stylebox_override("panel", _style_hot)
				else:
					txt = "%s 和 %s 合不起来" % [GameData.item_name(dragging.item_id),
							GameData.item_name(other.item_id)]
			elif GameData.is_tool_item(dragging.item_id):
				txt = "%s：%s" % [GameData.item_name(dragging.item_id),
						GameData.tool_desc(dragging.item_id)]
				(cells[target] as Panel).add_theme_stylebox_override("panel", _style_hot)
			else:
				txt = "交换位置"
	elif target.x >= 0 and target.y >= 0:
		txt = "移动到这里"

	if txt == "":
		_hint.visible = false
	else:
		_hint.text = txt
		var w := 150.0
		var f := _hint.get_theme_default_font()
		if f != null:
			w = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 26.0
		_hint.size = Vector2(w, 32.0)
		_hint.visible = true
		_hint.position = Vector2(clampf(lp.x + 16.0, 0.0, COLS * GameData.PITCH - w),
				clampf(lp.y - 36.0, 0.0, ROWS * GameData.PITCH - 32.0))
