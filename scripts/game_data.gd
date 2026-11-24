class_name GameData
extends RefCounted
## 全局静态数据：物品表、道具表、合成配方、关卡表。
## 想加物品 / 加道具 / 加关卡 / 改数值，只改这一个文件。

# ---------- 布局尺寸（棋盘格子） ----------
# 素材是 16×16 像素图，这里按 4 倍整数放大显示：64px 图标 + 16px 名称条 = 84px 物品
const SLOT := 92.0   ## 单个格子的绘制尺寸
const PITCH := 100.0 ## 格子间距（SLOT + 8 的空隙）
const ITEM := 84.0   ## 物品本体尺寸
const ICON := 64.0   ## 贴图显示边长（16 × 4）

# ---------- 物品表 ----------
# 规则：只有【相同物品】才能合成，即 X + X = Y。
# 三条链（叶子链 / 麦穗链 / 露珠链）各自向上升级，最终汇合到「圣果」。
# shape/color: 没找到贴图时的代码占位图形
const ITEMS := {
	"leaf":         {"name": "叶子", "tier": 1, "unit": "片", "shape": "drop",     "color": "#6fcf5f"},
	"wheat":        {"name": "麦穗", "tier": 1, "unit": "束", "shape": "circle",   "color": "#d9a441"},
	"dew":          {"name": "露珠", "tier": 1, "unit": "滴", "shape": "oval",     "color": "#56ccf2"},
	"flower":       {"name": "花",   "tier": 2, "unit": "朵", "shape": "blossom",  "color": "#f299cd"},
	"sprout":       {"name": "嫩芽", "tier": 2, "unit": "棵", "shape": "triangle", "color": "#c2d96b"},
	"crystal":      {"name": "冰晶", "tier": 2, "unit": "块", "shape": "diamond",  "color": "#5b8def"},
	"berry":        {"name": "浆果", "tier": 3, "unit": "颗", "shape": "circle",   "color": "#eb5757"},
	"tree":         {"name": "小树", "tier": 3, "unit": "棵", "shape": "hexagon",  "color": "#2d9b5f"},
	"gem":          {"name": "紫晶", "tier": 3, "unit": "块", "shape": "pill",     "color": "#9b6bdf"},
	"sacred_fruit": {"name": "圣果", "tier": 4, "unit": "颗", "shape": "star",     "color": "#f2c94c"},
}

# ---------- 道具表（单次使用，拖到物品上生效） ----------
# effect: split=劈开成两个低一级 / boost=直接升一级 / copy=复制成两个一样的
const TOOLS := {
	"tool_axe":    {"name": "斧头", "effect": "split", "shape": "triangle", "color": "#e05c4a", "desc": "劈开成两个低一级"},
	"tool_potion": {"name": "药水", "effect": "boost", "shape": "circle",   "color": "#56ccf2", "desc": "直接升一级"},
	"tool_pouch":  {"name": "布袋", "effect": "copy",  "shape": "square",   "color": "#b8a07a", "desc": "复制成两个一样的"},
}

## 可被「生成」按钮造出来的基础物品
const BASE_ITEMS := ["leaf", "wheat", "dew"]

# ---------- 合成配方表 ----------
# 键 = "材料A+材料B"（两边必须相同），值 = 合成结果
const RECIPES := {
	"leaf+leaf": "flower",
	"flower+flower": "berry",
	"berry+berry": "sacred_fruit",
	"wheat+wheat": "sprout",
	"sprout+sprout": "tree",
	"tree+tree": "sacred_fruit",
	"dew+dew": "crystal",
	"crystal+crystal": "gem",
	"gem+gem": "sacred_fruit",
}

# ---------- 关卡表 ----------
# objective: {type: make|count|purge, items: [id], n: 同时拥有几个, left: 背包剩几件}
# moves = 允许的合成次数；gen_limit = 生成器可用次数；tools = 开局摆在棋盘上的道具
# best = 这一关「最少需要几次合成」（星级按它校准：刚好用 best 步 = 三星）
# hint = 给玩家的一句话提示（可留空）
const LEVELS := [
	{
		"name": "第一关 · 四片叶子",
		"objective": {"type": "make", "items": ["berry"]},
		"moves": 8, "gen_limit": 2, "best": 3,
		"start": ["leaf", "leaf", "leaf", "leaf", "wheat", "dew"],
		"tools": [],
		"hint": "把两片叶子叠在一起试试",
	},
	{
		"name": "第二关 · 圣果（叶子路线）",
		"objective": {"type": "make", "items": ["sacred_fruit"]},
		"moves": 13, "gen_limit": 3, "best": 7,
		"start": ["leaf", "leaf", "leaf", "leaf", "leaf", "wheat", "wheat", "dew", "dew"],
		"tools": [],
		"hint": "圣果要 8 片叶子 —— 3 条链都能到圣果，选一条就行",
	},
	{
		"name": "第三关 · 小树",
		"objective": {"type": "make", "items": ["tree"]},
		"moves": 8, "gen_limit": 3, "best": 3,
		"start": ["wheat", "wheat", "wheat", "wheat", "leaf", "leaf", "dew", "dew"],
		"tools": [],
		"hint": "麦穗 → 嫩芽 → 小树",
	},
	{
		"name": "第四关 · 紫晶",
		"objective": {"type": "make", "items": ["gem"]},
		"moves": 8, "gen_limit": 3, "best": 3,
		"start": ["dew", "dew", "dew", "dew", "leaf", "leaf", "wheat", "wheat"],
		"tools": [],
		"hint": "露珠 → 冰晶 → 紫晶",
	},
	{
		"name": "第五关 · 两样都要",
		"objective": {"type": "make", "items": ["berry", "tree"]},
		"moves": 15, "gen_limit": 4, "best": 6,
		"start": ["leaf", "leaf", "leaf", "leaf", "wheat", "wheat", "wheat", "wheat", "dew", "dew"],
		"tools": [],
		"hint": "两个目标都要同时在场，步数够，按顺序来",
	},
	{
		"name": "第六关 · 三朵花",
		"objective": {"type": "count", "items": ["flower"], "n": 3},
		"moves": 6, "gen_limit": 5, "best": 3,
		"start": ["leaf", "leaf", "leaf", "leaf", "leaf", "dew", "wheat"],
		"tools": [],
		"hint": "要同时有 3 朵花 —— 合得太快反而不够",
	},
	{
		"name": "第七关 · 工具箱",
		"objective": {"type": "make", "items": ["sacred_fruit"]},
		"moves": 14, "gen_limit": 3, "best": 6,
		"start": ["leaf", "leaf", "leaf", "wheat", "wheat", "dew"],
		"tools": ["tool_potion", "tool_pouch"],
		"hint": "药水直接升一级，布袋复制一个 —— 两个都得用上",
	},
	{
		"name": "第八关 · 拆开重来",
		"objective": {"type": "count", "items": ["leaf"], "n": 5},
		"moves": 6, "gen_limit": 0, "best": 0,
		"start": ["leaf", "leaf", "leaf", "flower", "flower"],
		"tools": ["tool_axe"],
		"hint": "斧头能把高级物品劈成两份基础材料 —— 这关没有生成器",
	},
	{
		"name": "第九关 · 整理背包",
		"objective": {"type": "purge", "left": 2},
		"moves": 9, "gen_limit": 2, "best": 6,
		"start": ["leaf", "leaf", "leaf", "leaf", "wheat", "wheat", "wheat", "wheat"],
		"tools": [],
		"hint": "两条链各收成一件，背包就只剩 2 件了",
	},
	{
		"name": "第十关 · 只剩一颗",
		"objective": {"type": "purge", "left": 1},
		"moves": 10, "gen_limit": 2, "best": 7,
		"start": ["leaf", "leaf", "leaf", "leaf", "leaf", "leaf", "leaf", "leaf"],
		"tools": [],
		"hint": "8 片叶子正好合成 1 颗圣果 —— 多生成一件就合不完了",
	},
	{
		"name": "第十一关 · 满院堆料",
		"objective": {"type": "make", "items": ["sacred_fruit"]},
		"moves": 7, "gen_limit": 0, "best": 5,
		"start": ["leaf", "leaf", "leaf", "leaf", "leaf",
				"wheat", "wheat", "wheat", "wheat", "wheat",
				"dew", "dew", "dew", "dew",
				"flower", "flower", "sprout", "sprout"],
		"tools": [],
		"hint": "院子里堆满了 —— 现成的高阶材料就是省步数的捷径",
	},
	{
		"name": "第十二关 · 腾空",
		"objective": {"type": "purge", "left": 3},
		"moves": 14, "gen_limit": 0, "best": 13,
		"start": ["leaf", "leaf", "leaf", "leaf", "leaf", "leaf", "leaf", "leaf",
				"wheat", "wheat", "wheat", "wheat",
				"dew", "dew", "dew", "dew"],
		"tools": [],
		"hint": "16 件东西只剩 3 件 —— 三条链各收成一件，别留零头",
	},
]


# ---------- 查询 ----------

## 物品信息（普通物品或道具）
static func item_info(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	if TOOLS.has(id):
		return TOOLS[id]
	return {}


static func item_name(id: String) -> String:
	return str(item_info(id).get("name", id))


static func item_unit(id: String) -> String:
	return str(item_info(id).get("unit", "个"))


static func item_color(id: String) -> Color:
	return Color(str(item_info(id).get("color", "#ffffff")))


static func item_tier(id: String) -> int:
	return int(item_info(id).get("tier", 1))


## 这件东西是不是道具
## 注意：不能叫 is_tool —— Script.is_tool() 是引擎内置方法（判断 @tool 脚本），会遮蔽掉同名静态函数
static func is_tool_item(id: String) -> bool:
	return TOOLS.has(id)


static func tool_effect(id: String) -> String:
	return str(TOOLS.get(id, {}).get("effect", ""))


static func tool_desc(id: String) -> String:
	return str(TOOLS.get(id, {}).get("desc", ""))


## 两种材料能否合成？能则返回结果 id，不能则返回空串
static func merge_result(a: String, b: String) -> String:
	var key := ""
	if a <= b:
		key = a + "+" + b
	else:
		key = b + "+" + a
	return str(RECIPES.get(key, ""))


## 这件东西能升级成什么（X + X = Y 里的 Y）；没有则返回空串
static func upgrade_of(id: String) -> String:
	for key in RECIPES:
		var parts := str(key).split("+")
		if parts[0] == id and parts[1] == id:
			return str(RECIPES[key])
	return ""


## 这件东西是被什么合成出来的（劈开后变成什么）；没有则返回空串
static func downgrade_of(id: String) -> String:
	for key in RECIPES:
		var parts := str(key).split("+")
		if parts[0] == parts[1] and str(RECIPES[key]) == id:
			return parts[0]
	return ""


## 合成目标所需的路线方案，每条是 {base: 基础物品id, count: 需要几个, merges: 需要几步}
static func plans_for(target: String) -> Array:
	var producers: Array[String] = []
	for key in RECIPES:
		var parts := str(key).split("+")
		if parts[0] == parts[1] and str(RECIPES[key]) == target:
			producers.append(parts[0])
	if producers.is_empty():
		return [{"base": target, "count": 1, "merges": 0}]
	var out: Array = []
	for p in producers:
		for sub in plans_for(p):
			out.append({
				"base": str(sub["base"]),
				"count": int(sub["count"]) * 2,
				"merges": int(sub["merges"]) * 2 + 1,
			})
	return out


## 某个物品的合成路线文案，例如「8 片叶子 / 8 束麦穗 / 8 滴露珠」
static func plan_text(target: String) -> String:
	var plans := plans_for(target)
	if plans.is_empty():
		return ""
	var parts: Array[String] = []
	for p in plans:
		parts.append("%d %s%s" % [int(p["count"]), item_unit(str(p["base"])),
				item_name(str(p["base"]))])
	return " / ".join(parts)


# ---------- 关卡目标文案 ----------

## 目标的一句话描述
static func objective_text(obj: Dictionary) -> String:
	match str(obj.get("type", "make")):
		"count":
			var it := str(obj["items"][0])
			return "%d %s%s" % [int(obj.get("n", 1)), item_unit(it), item_name(it)]
		"purge":
			return "背包只剩 %d 件" % int(obj.get("left", 1))
		_:
			var names: Array[String] = []
			for it in obj.get("items", []):
				names.append(item_name(str(it)))
			return " + ".join(names)


## 目标需要多少基础材料、多少步
## lv = 所在关卡（可选，用于"清理背包"这类需要知道开局数量的目标）
static func objective_plan(obj: Dictionary, lv: Dictionary = {}) -> String:
	match str(obj.get("type", "make")):
		"count":
			var it := str(obj["items"][0])
			var cplans := plans_for(it)
			if cplans.is_empty():
				return ""
			var cp: Dictionary = cplans[0]
			var n := int(obj.get("n", 1))
			if int(cp["merges"]) == 0:
				return "需要同时有 %d %s%s（不用合成）" % [n,
						item_unit(str(cp["base"])), item_name(str(cp["base"]))]
			return "需要 %d %s%s · 共 %d 步" % [int(cp["count"]) * n,
					item_unit(str(cp["base"])), item_name(str(cp["base"])),
					int(cp["merges"]) * n]
		"purge":
			# 每次合成让背包少 1 件，所以「开局件数 - 目标件数」就是需要的步数
			var left := int(obj.get("left", 1))
			var total := 0
			for s in lv.get("start", []):
				if not GameData.is_tool_item(str(s)):
					total += 1
			return "共 %d 步 · 最后只剩 %d 件" % [maxi(0, total - left), left]
		_:
			var parts: Array[String] = []
			var steps := 0
			for it in obj.get("items", []):
				var plans := plans_for(str(it))
				if plans.is_empty():
					continue
				steps += int(plans[0]["merges"])
				var subs: Array[String] = []
				for p in plans:
					subs.append("%d %s%s" % [int(p["count"]), item_unit(str(p["base"])),
							item_name(str(p["base"]))])
				parts.append(" / ".join(subs))
			if parts.is_empty():
				return ""
			return "需要 %s · 共 %d 步" % [" + ".join(parts), steps]
