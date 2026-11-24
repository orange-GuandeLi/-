class_name Item
extends Control
## 一个可拖动的物品。
## 优先使用 res://assets/items/<id>.png；没有贴图时用代码画一个占位图形。

const TEX_DIR := "res://assets/items/"
const ICON_BOX := Vector2(64.0, 64.0)  ## 贴图显示区域（16px 底图 ×4）

var item_id: String = ""
var info: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO
var tex: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 像素风：必须最近邻过滤，否则像素边缘会被插值糊掉
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(GameData.ITEM, GameData.ITEM)
	pivot_offset = size * 0.5


func setup(id: String) -> void:
	item_id = id
	info = GameData.item_info(id)
	var path := TEX_DIR + id + ".png"
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			tex = _prepare(res)
	queue_redraw()


## 贴图比显示框大时，用最近邻缩小一份，保证像素边缘不糊
func _prepare(src: Texture2D) -> Texture2D:
	var ts := src.get_size()
	if ts.x <= ICON_BOX.x and ts.y <= ICON_BOX.y:
		return src
	var s := minf(ICON_BOX.x / ts.x, ICON_BOX.y / ts.y)
	var img := src.get_image()
	if img == null:
		return src
	img.resize(maxi(1, int(floor(ts.x * s))), maxi(1, int(floor(ts.y * s))), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	var font := get_theme_default_font()
	var col: Color = Color(str(info.get("color", "#ffffff")))
	var shape := str(info.get("shape", "circle"))
	var tier := int(info.get("tier", 1))
	var icon_c := Vector2(size.x * 0.5, 30.0)
	var r := 26.0

	# 投影
	draw_circle(icon_c + Vector2(0.0, 3.0), r, Color(0.0, 0.0, 0.0, 0.22))

	if tex != null:
		draw_texture_rect(tex, _fit_tex(tex, Rect2(Vector2((size.x - ICON_BOX.x) * 0.5, 0.0), ICON_BOX)), false)
	else:
		_draw_shape(shape, icon_c, r, col)

	# 等级徽章（像素风：方块而非圆角）；道具没有等级，用实心色块区分
	var badge := Rect2(size.x - 24.0, 4.0, 20.0, 20.0)
	if tier <= 0:
		draw_rect(badge, col)
		draw_rect(badge, Color(0.07, 0.08, 0.11, 0.92), false, 2.0)
	else:
		draw_rect(badge, Color(0.07, 0.08, 0.11, 0.92))
		draw_rect(badge, col, false, 2.0)
		if font != null:
			draw_string(font, Vector2(badge.position.x, badge.position.y + 15.0), str(tier),
					HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 13, Color(1, 1, 1))

	# 名称
	if font != null:
		draw_string(font, Vector2(0.0, 80.0), str(info.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER,
				size.x, 15, Color(0.88, 0.92, 0.99))


## 合成 / 道具生效时的弹跳动画：让结果"冒"出来，而不是凭空出现
func pop() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.45, 0.45)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.10) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)


## 贴图按整数倍缩放并居中到指定区域内：整数倍才能保证像素大小一致、不出现半像素
func _fit_tex(tex: Texture2D, box: Rect2) -> Rect2:
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return box
	var f := maxi(1, int(floor(minf(box.size.x / ts.x, box.size.y / ts.y))))
	var sz := ts * float(f)
	return Rect2(box.position + (box.size - sz) * 0.5, sz)


# ---------- 占位图形 ----------

func _draw_shape(shape: String, c: Vector2, r: float, col: Color) -> void:
	var dark := col.darkened(0.3)
	var lite := col.lightened(0.25)
	match shape:
		"circle":
			draw_circle(c, r, col)
			draw_arc(c, r, 0.0, TAU, 30, dark, 2.0, true)
		"oval":
			_fill(_ellipse(c, r, r * 0.72, 30), col, dark)
		"square":
			_fill(PackedVector2Array([
				c + Vector2(-r * 0.82, -r * 0.82), c + Vector2(r * 0.82, -r * 0.82),
				c + Vector2(r * 0.82, r * 0.82), c + Vector2(-r * 0.82, r * 0.82)]), col, dark)
		"pill":
			draw_rect(Rect2(c.x - r * 0.5, c.y - r * 0.7, r, r * 1.4), col)
			draw_circle(c + Vector2(-r * 0.5, 0.0), r * 0.7, col)
			draw_circle(c + Vector2(r * 0.5, 0.0), r * 0.7, col)
			draw_arc(c + Vector2(-r * 0.5, 0.0), r * 0.7, 0.0, TAU, 22, dark, 2.0, true)
			draw_arc(c + Vector2(r * 0.5, 0.0), r * 0.7, 0.0, TAU, 22, dark, 2.0, true)
		"triangle":
			_fill(PackedVector2Array([
				c + Vector2(0.0, -r * 1.05), c + Vector2(r * 0.95, r * 0.7),
				c + Vector2(-r * 0.95, r * 0.7)]), col, dark)
		"diamond":
			_fill(PackedVector2Array([
				c + Vector2(0.0, -r * 1.05), c + Vector2(r * 0.85, 0.0),
				c + Vector2(0.0, r * 1.05), c + Vector2(-r * 0.85, 0.0)]), col, dark)
		"hexagon":
			_fill(_ngon(c, r, 6, PI / 6.0), col, dark)
		"star":
			_fill(_star(c, r, r * 0.46, 5, -PI / 2.0), col, dark)
		"drop":
			_fill(PackedVector2Array([
				c + Vector2(0.0, -r * 1.2), c + Vector2(r * 0.8, r * 0.2),
				c + Vector2(-r * 0.8, r * 0.2)]), col, dark)
			draw_circle(c + Vector2(0.0, r * 0.3), r * 0.8, col)
			draw_arc(c + Vector2(0.0, r * 0.3), r * 0.8, 0.0, TAU, 28, dark, 2.0, true)
		"blossom":
			for i in 5:
				var a := -PI / 2.0 + TAU * i / 5.0
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.52, r * 0.48, col)
			draw_circle(c, r * 0.42, lite)
			draw_arc(c, r * 0.42, 0.0, TAU, 24, dark, 1.6, true)
		_:
			draw_circle(c, r, col)


func _fill(pts: PackedVector2Array, col: Color, outline: Color) -> void:
	draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, outline, 2.0, true)


func _ellipse(c: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var t := TAU * i / steps
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	return pts


func _ngon(c: Vector2, r: float, sides: int, offset: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := offset + TAU * i / sides
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _star(c: Vector2, r_out: float, r_in: float, points: int, offset: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := offset + PI * i / points
		var rr := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts
