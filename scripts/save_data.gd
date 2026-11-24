class_name SaveData
extends RefCounted
## 本地存档：user://save.json
##
## 存的东西：
##   stars   —— {"关卡索引": 星级}，取最高
##   unlocked—— 已解锁到第几关（索引）
##   recipes —— 已发现的配方 key（如 "leaf+leaf"）
##   best_score —— 无尽模式最高分（以后做无尽模式时用）
##
## 以后做「世外桃源开店 / 菜谱研究」那套大改版时，这个文件也是地基：
## 星级、图鉴、解锁进度都从这里长出来，不用推倒重来。

const DEFAULT_PATH := "user://save.json"
static var save_path: String = DEFAULT_PATH   ## 自动化测试会改成临时路径，别污染玩家存档


static func blank() -> Dictionary:
	return {"stars": {}, "unlocked": 0, "recipes": [], "best_score": 0}


## 读存档；文件不存在或坏了就返回一份空的
static func load_data() -> Dictionary:
	var out := blank()
	if not FileAccess.file_exists(save_path):
		return out
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return out
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for k in out.keys():
		if parsed.has(k):
			out[k] = parsed[k]
	return out


static func write_data(d: Dictionary) -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	return true


## 清档（以后加设置界面时用）
static func clear() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
