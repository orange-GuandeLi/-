class_name SheetCanvas
extends Control
## 索引图画布：把一堆 16×16 精灵按网格排开，每格下面标注原始编号。

var cells: Array = []   ## [{tex: Texture2D, label: String}]
var cols := 26
var cell_w := 40.0
var cell_h := 48.0
var sprite_scale := 2.0


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var bg := Color(0.09, 0.10, 0.14, 1.0)
	var fg := Color(0.72, 0.78, 0.90, 1.0)
	for i in cells.size():
		var c: Dictionary = cells[i]
		var cx: float = float(i % cols) * cell_w
		var cy: float = floor(float(i) / float(cols)) * cell_h
		draw_rect(Rect2(cx + 0.5, cy + 0.5, cell_w - 1.0, cell_h - 1.0), bg)
		draw_rect(Rect2(cx + 0.5, cy + 0.5, cell_w - 1.0, cell_h - 1.0), Color(1, 1, 1, 0.07), false, 1.0)
		var tex: Texture2D = c["tex"]
		var sz := 16.0 * sprite_scale
		draw_texture_rect(tex, Rect2(cx + (cell_w - sz) * 0.5, cy + 2.0, sz, sz), false)
		if font != null:
			draw_string(font, Vector2(cx + 2.0, cy + cell_h - 4.0), str(c["label"]),
					HORIZONTAL_ALIGNMENT_LEFT, cell_w - 4.0, 11, fg)
