extends SceneTree
## 自动化测试：直接驱动 Board 的拖拽接口，验证核心玩法链路。
## 用法：
##   Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/test_game.gd
## 全部通过会输出 "ALL TESTS PASSED"。

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK]   ", msg)
	else:
		failures += 1
		print("  [FAIL] ", msg)


func cells_with(board: Board, id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in board.items:
		if (board.items[c] as Item).item_id == id:
			out.append(c)
	return out


## 从 from 拖到 to
func drag(board: Board, from: Vector2i, to: Vector2i) -> void:
	board.begin_drag_at(board.cell_center(from))
	board.drag_to(board.cell_center(to))
	board.end_drag_at(board.cell_center(to))


## 拖一件同类物品到另一件同类物品上，触发合成
func merge_pair(board: Board, id: String) -> Vector2i:
	var cs := cells_with(board, id)
	if cs.size() < 2:
		return Vector2i(-1, -1)
	var from: Vector2i = cs[0]
	var to: Vector2i = cs[1]
	drag(board, from, to)
	return to


## 连续合成 n 次，返回实际合成的次数
func merge_n(board: Board, id: String, n: int) -> int:
	var done := 0
	for i in n:
		if cells_with(board, id).size() < 2:
			break
		merge_pair(board, id)
		done += 1
	return done


func first_free(board: Board) -> Vector2i:
	for y in Board.ROWS:
		for x in Board.COLS:
			if not board.items.has(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## 切到某一关，并确认这一关没有"一开局就判定过关"
## （摆开局物品时棋盘是空的，清理背包类目标会被误判 —— 这里专门盯住这个坑）
func begin_level(main: MainGame, idx: int) -> void:
	main.start_level(idx)
	check(not main.level_over, "第 %d 关开局不应直接过关" % (idx + 1))
	check(not (main.get_node("Overlay") as Control).visible, "第 %d 关结算面板开局应隐藏" % (idx + 1))


func _initialize() -> void:
	# 存档改用临时路径，别污染玩家真实存档
	SaveData.save_path = "user://test_save.json"
	SaveData.clear()

	# ---------- 0. 配方表自检 ----------
	print("\n[0] 配方表")
	var bad := 0
	for key in GameData.RECIPES:
		var parts := str(key).split("+")
		if parts[0] != parts[1]:
			bad += 1
			print("  [FAIL] 配方不是「相同物品 + 相同物品」: ", key)
	check(bad == 0, "所有配方都是「相同物品 + 相同物品」")

	var reachable := 0
	for id in GameData.ITEMS:
		if not GameData.plans_for(id).is_empty():
			reachable += 1
	check(reachable == GameData.ITEMS.size(), "每件物品都能被合成出来")
	check(GameData.plan_text("sacred_fruit").contains("8 片叶子"), "圣果路线：8 片叶子")
	check(GameData.plan_text("sacred_fruit").contains("8 束麦穗"), "圣果路线：8 束麦穗")
	check(GameData.plan_text("sacred_fruit").contains("8 滴露珠"), "圣果路线：8 滴露珠")
	check(GameData.plan_text("berry").contains("4 片叶子"), "浆果需要 4 片叶子")
	check(GameData.plan_text("tree").contains("4 束麦穗"), "小树需要 4 束麦穗")
	check(GameData.plan_text("gem").contains("4 滴露珠"), "紫晶需要 4 滴露珠")

	# ---------- 0.2 升级 / 降级映射 ----------
	print("\n[0.2] 升级与降级")
	var map_bad := 0
	for key in GameData.RECIPES:
		var parts := str(key).split("+")
		var a := parts[0]
		var b := str(GameData.RECIPES[key])
		if GameData.upgrade_of(a) != b:
			map_bad += 1
			print("  [FAIL] upgrade_of(%s) 应为 %s，实际 %s" % [a, b, GameData.upgrade_of(a)])
		var down := GameData.downgrade_of(b)
		if down == "" or GameData.merge_result(down, down) != b:
			map_bad += 1
			print("  [FAIL] downgrade_of(%s) 不可逆" % b)
	check(map_bad == 0, "升级/降级映射与配方表互相一致")
	check(GameData.upgrade_of("sacred_fruit") == "", "圣果没有更高一级")
	check(GameData.downgrade_of("leaf") == "", "叶子是最基础的材料，拆不开")

	# ---------- 0.3 关卡表自检 ----------
	print("\n[0.3] 关卡表")
	var lv_bad := 0
	for i in GameData.LEVELS.size():
		var lv: Dictionary = GameData.LEVELS[i]
		var tag := "第 %d 关" % (i + 1)
		var obj: Dictionary = lv.get("objective", {})
		var ot := str(obj.get("type", ""))
		if ot != "make" and ot != "count" and ot != "purge":
			lv_bad += 1
			print("  [FAIL] ", tag, " 目标类型非法: ", ot)
		if ot == "make":
			for it in obj.get("items", []):
				if not GameData.ITEMS.has(str(it)):
					lv_bad += 1
					print("  [FAIL] ", tag, " 目标物品不存在: ", it)
		if ot == "count":
			if not GameData.ITEMS.has(str(obj["items"][0])):
				lv_bad += 1
				print("  [FAIL] ", tag, " 计数物品不存在")
			if int(obj.get("n", 1)) < 1:
				lv_bad += 1
				print("  [FAIL] ", tag, " count 目标数量非法")
		if ot == "purge" and int(obj.get("left", 1)) < 1:
			lv_bad += 1
			print("  [FAIL] ", tag, " purge 目标件数非法")
		if int(lv["moves"]) < 1:
			lv_bad += 1
			print("  [FAIL] ", tag, " 步数非法")
		if int(lv.get("gen_limit", 0)) < 0:
			lv_bad += 1
			print("  [FAIL] ", tag, " 生成次数非法")
		var start: Array = lv["start"]
		if start.is_empty():
			lv_bad += 1
			print("  [FAIL] ", tag, " 开局没有物品")
		var tools: Array = lv.get("tools", [])
		if start.size() + tools.size() > Board.COLS * Board.ROWS:
			lv_bad += 1
			print("  [FAIL] ", tag, " 开局物品放不下")
		for s in start:
			if not GameData.ITEMS.has(str(s)):
				lv_bad += 1
				print("  [FAIL] ", tag, " 开局物品非法: ", s)
		for t in tools:
			if not GameData.is_tool_item(str(t)):
				lv_bad += 1
				print("  [FAIL] ", tag, " 道具非法: ", t)
	check(lv_bad == 0, "%d 关的关卡表字段全部合法" % GameData.LEVELS.size())

	# ---------- 0.5 贴图资源 ----------
	print("\n[0.5] 贴图资源")
	var missing := 0
	for id in GameData.ITEMS:
		var p := "res://assets/items/%s.png" % str(id)
		if not ResourceLoader.exists(p):
			missing += 1
			print("  [FAIL] 缺少贴图: %s" % str(id))
			continue
		var t := load(p) as Texture2D
		if t == null or t.get_size() != Vector2(16, 16):
			missing += 1
			print("  [FAIL] 贴图尺寸不对: %s" % str(id))
	check(missing == 0, "10 件物品的 16×16 贴图齐全")
	var tmissing := 0
	for id in GameData.TOOLS:
		var p := "res://assets/items/%s.png" % str(id)
		if not ResourceLoader.exists(p):
			tmissing += 1
			print("  [FAIL] 缺少道具贴图: %s" % str(id))
			continue
		var t := load(p) as Texture2D
		if t == null or t.get_size() != Vector2(16, 16):
			tmissing += 1
			print("  [FAIL] 道具贴图尺寸不对: %s" % str(id))
	check(tmissing == 0, "3 件道具的 16×16 贴图齐全")

	var scene: PackedScene = load("res://scenes/Main.tscn")
	check(scene != null, "Main.tscn 能正常解析加载")
	if scene == null:
		print("FAILED: 场景加载失败，后续测试无法进行")
		quit(1)
		return
	var main: MainGame = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	check(main.get_node("Board") != null, "主场景节点结构正确")
	check(main.get_node("Header/HintLabel") != null, "提示文字节点存在")

	var board: Board = main.get_node("Board")

	# ---------- 1. 合成 ----------
	print("\n[1] 合成：两片叶子")
	begin_level(main, 0)
	await process_frame
	var leaves := cells_with(board, "leaf")
	check(leaves.size() == 4, "第一关开局 4 片叶子（实际 %d）" % leaves.size())
	var la: Vector2i = leaves[0]
	var lb: Vector2i = leaves[1]
	var size_before: int = board.items.size()
	drag(board, la, lb)
	check(board.items.size() == size_before - 1, "合成后背包少 1 件")
	check(board.items.has(lb), "结果落在目标格")
	check(board.items.has(lb) and (board.items[lb] as Item).item_id == "flower", "叶子 + 叶子 = 花")
	check(not board.items.has(la), "原格已清空")
	check(main.moves_left == main.move_total - 1, "步数扣 1（剩余 %d）" % main.moves_left)
	check(main.score == 10, "第一次合成得 10 分（实际 %d）" % main.score)
	check(main.combo == 1, "连击数 = 1")
	var leaf_item: Item = board.items[lb]
	check(leaf_item.tex != null, "叶片用的是真实贴图，不是代码占位图形")

	# ---------- 2. 拖到空格子 = 移动 ----------
	print("\n[2] 移动：拖到空格")
	var flower_cell: Vector2i = lb
	var empty_cell := first_free(board)
	check(empty_cell.x >= 0, "背包还有空格子")
	var moves_before: int = main.moves_left
	drag(board, flower_cell, empty_cell)
	check(board.items.has(empty_cell), "物品移动到空格")
	check((board.items[empty_cell] as Item).item_id == "flower", "移动后还是花")
	check(main.moves_left == moves_before, "移动不扣步数")
	check(main.combo == 0, "移动后连击清零")

	# ---------- 3. 拖到不同物品上 = 交换位置 ----------
	print("\n[3] 交换：拖到不同种类的物品上")
	var other_cells := cells_with(board, "wheat")
	if other_cells.is_empty():
		other_cells = cells_with(board, "dew")
	# 前面那两片叶子已经被合成掉了，这里要重新取当前的叶子位置
	var leaf_cells := cells_with(board, "leaf")
	check(not leaf_cells.is_empty(), "场上还有叶子可以交换")
	var la2: Vector2i = leaf_cells[0]
	var lo2: Vector2i = other_cells[0]
	var leaf_id := (board.items[la2] as Item).item_id
	var other_id := (board.items[lo2] as Item).item_id
	drag(board, la2, lo2)
	check((board.items[la2] as Item).item_id == other_id, "两个物品交换了位置")
	check((board.items[lo2] as Item).item_id == leaf_id, "两个物品交换了位置")
	check(main.moves_left == moves_before, "交换不扣步数")

	# ---------- 4. 连击与评分 ----------
	print("\n[4] 连击与评分")
	begin_level(main, 4)
	await process_frame
	merge_n(board, "leaf", 2)
	merge_pair(board, "flower")
	check(main.combo == 3, "连续 3 次合成 → 连击 ×3（实际 %d）" % main.combo)
	check(main.score == 60, "连击得分 10×1 + 10×2 + 10×3 = 60（实际 %d）" % main.score)
	check(not main.level_over, "还没达成两个目标，不算过关")
	var w1: Vector2i = cells_with(board, "wheat")[0]
	var d1: Vector2i = cells_with(board, "dew")[0]
	drag(board, w1, d1)
	check(main.combo == 0, "交换打断连击")

	# ---------- 5. 生成器限次 ----------
	print("\n[5] 生成器限次")
	begin_level(main, 0)
	await process_frame
	var gen_btn: Button = main.get_node("Side/GenRow/GenLeaf")
	var n_before: int = board.items.size()
	var mv_before: int = main.moves_left
	gen_btn.pressed.emit()
	gen_btn.pressed.emit()
	check(main.gen_used == 2, "生成器用了 2 次（第一关上限 2）")
	check(board.items.size() == n_before + 2, "背包多了 2 件")
	check(main.moves_left == mv_before, "生成不扣步数")
	gen_btn.pressed.emit()
	check(main.gen_used == 2, "超过上限后不再生成")
	check(board.items.size() == n_before + 2, "超限那次没有加物品")
	check(gen_btn.disabled, "次数用完后生成按钮变灰")
	check((main.get_node("Header/TargetBox/GenLabel") as Label).text.contains("2 / 2"), "HUD 显示生成次数")

	# ---------- 6. 道具 ----------
	print("\n[6] 道具")

	# 6a 药水：直接升一级
	begin_level(main, 6)
	await process_frame
	check(cells_with(board, "tool_potion").size() == 1, "第七关开局有 1 个药水")
	var potion_cell: Vector2i = cells_with(board, "tool_potion")[0]
	var leaf_target: Vector2i = cells_with(board, "leaf")[0]
	var leaf_n: int = board.count_item("leaf")
	var mv2: int = main.moves_left
	drag(board, potion_cell, leaf_target)
	check(board.count_item("leaf") == leaf_n - 1, "药水吃掉 1 片叶子")
	check(board.count_item("flower") == 1, "药水把叶子直接变成花")
	check(cells_with(board, "tool_potion").is_empty(), "药水被消耗")
	check(main.moves_left == mv2, "道具不消耗步数")

	# 6b 布袋：复制成两个
	begin_level(main, 6)
	await process_frame
	var pouch_cell: Vector2i = cells_with(board, "tool_pouch")[0]
	var leaf_target2: Vector2i = cells_with(board, "leaf")[0]
	var leaf_n2: int = board.count_item("leaf")
	drag(board, pouch_cell, leaf_target2)
	check(board.count_item("leaf") == leaf_n2 + 1, "布袋复制出 1 片额外的叶子")
	check(cells_with(board, "tool_pouch").is_empty(), "布袋被消耗")

	# 6c 斧头：劈开成两个低一级；劈最基础的材料应该失败
	begin_level(main, 7)
	await process_frame
	check(cells_with(board, "tool_axe").size() == 1, "第八关开局有 1 把斧头")
	var axe_cell: Vector2i = cells_with(board, "tool_axe")[0]
	var base_target: Vector2i = cells_with(board, "leaf")[0]
	var leaf_n3: int = board.count_item("leaf")
	var flower_n3: int = board.count_item("flower")
	drag(board, axe_cell, base_target)
	check(board.count_item("leaf") == leaf_n3, "斧头劈不开最基础的叶子")
	check(board.count_item("flower") == flower_n3, "目标物品没变")
	check(cells_with(board, "tool_axe").size() == 1, "失败的斧头留在原地")
	var flower_target: Vector2i = cells_with(board, "flower")[0]
	drag(board, axe_cell, flower_target)
	check(board.count_item("flower") == flower_n3 - 1, "斧头劈掉了 1 朵花")
	check(board.count_item("leaf") == leaf_n3 + 2, "斧头把花劈成 2 片叶子")
	check(cells_with(board, "tool_axe").is_empty(), "斧头被消耗")

	# ---------- 7. count 目标 ----------
	print("\n[7] count 目标：同时拥有 3 朵花")
	begin_level(main, 5)
	await process_frame
	check(str(main.objective.get("type", "")) == "count", "第六关是计数目标")
	merge_n(board, "leaf", 2)
	check(board.count_item("flower") == 2, "现在有 2 朵花，还不算达成")
	check(not main.level_over, "只有 2 朵花不触发过关")
	(main.get_node("Side/GenRow/GenLeaf") as Button).pressed.emit()
	merge_n(board, "leaf", 1)
	check(board.count_item("flower") == 3, "第 3 朵花到位")
	check(main.level_over, "计数目标达成 → 过关")
	check((main.get_node("Overlay") as Control).visible, "结算面板已弹出")
	check((main.get_node("Overlay/Center/Panel/VBox/Title") as Label).text.contains("过关"), "结算面板标题正确")

	# ---------- 8. purge 目标 ----------
	print("\n[8] purge 目标：背包只剩 2 件")
	begin_level(main, 8)
	await process_frame
	check(str(main.objective.get("type", "")) == "purge", "第九关是清理目标")
	var mv8: int = main.moves_left
	merge_n(board, "leaf", 2)
	merge_n(board, "flower", 1)
	merge_n(board, "wheat", 2)
	merge_n(board, "sprout", 1)
	check(main.moves_left == mv8 - 6, "6 次合成扣 6 步（剩余 %d）" % main.moves_left)
	check(board.item_count() == 2, "背包剩 2 件")
	check(board.has_item("berry") and board.has_item("tree"), "剩下一颗浆果和一棵小树")
	check(main.level_over, "清理目标达成 → 过关")
	check((main.get_node("Overlay/Center/Panel/VBox/Text") as Label).text.contains("剩 2 件"), "结算面板显示剩余件数")

	print("\n[8.1] purge 目标：背包只剩 1 件")
	begin_level(main, 9)
	await process_frame
	merge_n(board, "leaf", 4)
	merge_n(board, "flower", 2)
	merge_n(board, "berry", 1)
	check(board.item_count() == 1, "8 片叶子合成到只剩 1 颗圣果")
	check(board.has_item("sacred_fruit"), "最后那件是圣果")
	check(main.level_over, "过关")

	# ---------- 9. 关卡可解性（完整解法） ----------
	print("\n[9] 关卡可解性")

	# 第七关：布袋 + 生成器 + 药水，缺一不可
	begin_level(main, 6)
	await process_frame
	drag(board, cells_with(board, "tool_pouch")[0], cells_with(board, "leaf")[0])
	for i in 3:
		(main.get_node("Side/GenRow/GenLeaf") as Button).pressed.emit()
	drag(board, cells_with(board, "tool_potion")[0], cells_with(board, "leaf")[0])
	merge_n(board, "leaf", 3)
	merge_n(board, "flower", 2)
	merge_n(board, "berry", 1)
	check(board.has_item("sacred_fruit"), "第七关：布袋 + 3 次生成 + 药水 → 圣果")
	check(main.level_over, "第七关可以通关")
	check(main.moves_left >= 0, "第七关步数够用（剩余 %d）" % main.moves_left)

	# 第八关：不劈开就拿不到 5 片叶子
	begin_level(main, 7)
	await process_frame
	check(board.count_item("leaf") == 3, "第八关开局只有 3 片叶子")
	check(board.count_item("flower") == 2, "第八关开局有 2 朵花")
	drag(board, cells_with(board, "tool_axe")[0], cells_with(board, "flower")[0])
	check(board.count_item("leaf") == 5, "劈开 1 朵花 → 5 片叶子")
	check(main.level_over, "第八关可以通关")

	# 第十一关：满院堆料 —— 用现成的高阶材料走叶子路线
	begin_level(main, 10)
	await process_frame
	check(board.items.size() == 18, "第十一关开局 18 件（实际 %d）" % board.items.size())
	merge_n(board, "leaf", 2)
	merge_n(board, "flower", 2)
	merge_n(board, "berry", 1)
	check(board.has_item("sacred_fruit"), "第十一关：满院堆料 → 圣果")
	check(main.level_over, "第十一关可以通关")
	check(main.moves_left == 2, "第十一关用 5 步（剩 %d）" % main.moves_left)

	# 第十二关：16 件东西收拾到只剩 3 件
	begin_level(main, 11)
	await process_frame
	check(board.items.size() == 16, "第十二关开局 16 件（实际 %d）" % board.items.size())
	merge_n(board, "leaf", 4)
	merge_n(board, "flower", 2)
	merge_n(board, "berry", 1)
	merge_n(board, "wheat", 2)
	merge_n(board, "sprout", 1)
	merge_n(board, "dew", 2)
	merge_n(board, "crystal", 1)
	check(board.item_count() == 3, "第十二关：16 件收拾到只剩 3 件（实际 %d）" % board.item_count())
	check(main.level_over, "第十二关可以通关")
	check(main.moves_left == 1, "第十二关用 13 步（剩 %d）" % main.moves_left)

	# ---------- 10. 换关与 HUD ----------
	print("\n[10] 换关与 HUD")
	begin_level(main, 1)
	await process_frame
	check(main.objective.get("items", []).has("sacred_fruit"), "第二关目标是圣果")
	check(main.move_total == 13, "第二关步数 13")
	check(board.items.size() == 9, "第二关开局 9 件物品（实际 %d）" % board.items.size())
	check((main.get_node("Header/Subtitle") as Label).text.contains("8 片叶子"), "副标题显示所需材料数量")
	check((main.get_node("Header/HintLabel") as Label).text != "", "关卡提示文字已显示")

	# ---------- 11. 星级 ----------
	print("\n[11] 星级")
	begin_level(main, 0)
	await process_frame
	merge_n(board, "leaf", 2)
	merge_n(board, "flower", 1)
	check(main.level_over, "第一关通关")
	check((main.get_node("Overlay/Center/Panel/VBox/Title") as Label).text.contains("★★★"),
			"用最优步数通关 = 三星")

	# ---------- 12. 存档 ----------
	print("\n[12] 存档")
	var save := SaveData.load_data()
	check(int(save.get("stars", {}).get("0", 0)) == 3, "第一关三星写进存档")
	check(int(save.get("unlocked", 0)) >= 1, "通关后解锁下一关")
	check(save.has("recipes"), "存档里记了图鉴进度")

	# ---------- 13. 关卡选择 ----------
	print("\n[13] 关卡选择")
	main.show_level_select()
	await process_frame
	check(main.level_overlay.visible, "关卡选择面板能打开")
	var btns: Array = main.level_buttons
	var unlocked := main._unlocked()
	check(not (btns[unlocked] as Button).disabled, "解锁到的最后一关可点")
	if unlocked + 1 < btns.size():
		check((btns[unlocked + 1] as Button).disabled, "再往后的关卡是锁的")
	check((main.level_stars[0] as Label).text.contains("★"), "关卡格子显示星级")
	main._on_level_picked(1)
	await process_frame
	check(main.level_index == 1, "点了第二关就切过去了")
	check(not main.level_overlay.visible, "切关后面板自动关掉")

	# ---------- 14. 配方发现 ----------
	print("\n[14] 配方发现")
	check(main._discovered.has("leaf+leaf"), "合成过叶子 → 图鉴解锁「叶子 + 叶子」")
	check(main._discovered.has("flower+flower"), "合成过花 → 图鉴解锁「花 + 花」")
	check(not main._discovered.has("tree+tree"), "没碰过的「小树 + 小树」还锁着")
	check(not main._discovered.has("gem+gem"), "没碰过的「紫晶 + 紫晶」还锁着")
	var codex_title := (main.get_node("Side/RecipeTitle") as Label).text
	check(codex_title.contains("/ 9"), "图鉴标题显示已发现数量（%s）" % codex_title)

	# ---------- 15. 第一次启动的体验 ----------
	print("\n[15] 第一次启动")
	SaveData.clear()
	var fresh: MainGame = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(fresh)
	await process_frame
	await process_frame
	check(fresh.level_overlay.visible, "启动时先看到关卡选择面板")
	var fbtns: Array = fresh.level_buttons
	check(not (fbtns[0] as Button).disabled, "新档第一关可点")
	check((fbtns[1] as Button).disabled, "新档后面的关卡全锁着")
	check((fresh.get_node("Side/ToolTitle") as Label).text.contains("还没遇到"), "新档不剧透道具")
	check((fresh.get_node("Side/RecipeTitle") as Label).text.contains("(0 / 9)"), "新档图鉴是空的")
	fresh.queue_free()
	await process_frame

	SaveData.clear()
	print("\n==============================")
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILED: %d 项未通过" % failures)
	print("==============================")
	quit(0 if failures == 0 else 1)
