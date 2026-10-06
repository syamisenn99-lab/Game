class_name GameSession
extends RefCounted
## シーンをまたいで持ち越す状態と、その保存。
##  - 誰をガイドするか
##  - ノートの育ち（埋めた虫食い・訂正した記述）
##  - 資金、日数、買った道具
## 保存ファイルは1つ（user://notebook.json）。古い保存ファイル（ノートだけ）も読める。

static var adventurer_id: StringName = &"childhood"
## 埋まった穴／訂正した箇所の id -> true（MatchingState と同じ辞書を共有する）
static var filled_blanks: Dictionary = {}
static var funds: int = Rules.START_FUNDS
static var day: int = 1
## 買った道具の id -> true
static var owned_items: Dictionary = {}
## 見た場面の id -> true（プロローグ、冒険者の紹介、姉の手がかり）
static var seen_scenes: Dictionary = {}
## 冒険者id -> その冒険者と探索を終えた回数
static var runs: Dictionary = {}
## 再生する場面と、終わったあとに進むシーン
static var story_scene: StringName = &""
static var story_next := "res://scenes/prep_screen.tscn"
## false にすると、場面を出さない・シーンを切り替えない（テスト用）
static var story_enabled := true
static var navigate := true
## navigate が false のとき、行き先だけを記録する（テスト用）
static var last_destination := ""
## false にすると、ファイルの読み書きをしない（テスト用）
static var persist := true
static var save_path := "user://notebook.json"
static var _loaded := false


static func load_notebook() -> void:
	if _loaded:
		return
	_loaded = true
	if not persist or not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	if data.get("filled") is Array:
		for id in data["filled"]:
			filled_blanks[StringName(str(id))] = true
	funds = int(data.get("funds", Rules.START_FUNDS))
	day = maxi(1, int(data.get("day", 1)))
	if data.get("items") is Array:
		for id in data["items"]:
			owned_items[StringName(str(id))] = true
	if data.get("seen") is Array:
		for id in data["seen"]:
			seen_scenes[StringName(str(id))] = true
	if data.get("runs") is Dictionary:
		for id in data["runs"]:
			runs[StringName(str(id))] = int(data["runs"][id])


static func save_notebook() -> void:
	if not persist:
		return
	var filled: Array[String] = []
	for id in filled_blanks:
		filled.append(String(id))
	var items: Array[String] = []
	for id in owned_items:
		items.append(String(id))
	var seen: Array[String] = []
	for id in seen_scenes:
		seen.append(String(id))
	var run_counts: Dictionary = {}
	for id in runs:
		run_counts[String(id)] = runs[id]
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"filled": filled, "funds": funds, "day": day, "items": items, "seen": seen, "runs": run_counts}))


## ノートだけを最初の状態に戻す
static func reset_notebook() -> void:
	filled_blanks.clear()
	if persist:
		save_notebook()


## ノート・資金・日数・道具のすべてを最初に戻す
static func reset_all() -> void:
	filled_blanks.clear()
	owned_items.clear()
	seen_scenes.clear()
	runs.clear()
	funds = Rules.START_FUNDS
	day = 1
	if persist:
		save_notebook()


static func has_seen(scene_id: StringName) -> bool:
	return seen_scenes.has(scene_id)


static func mark_seen(scene_id: StringName) -> void:
	seen_scenes[scene_id] = true
	save_notebook()


## その冒険者と探索を終えた回数
static func runs_of(adventurer_id: StringName) -> int:
	return int(runs.get(adventurer_id, 0))


## シーンを切り替える。navigate が false なら、行き先を記録するだけ（テスト用）
static func go_to(tree: SceneTree, path: String) -> void:
	last_destination = path
	if navigate:
		tree.change_scene_to_file(path)


static func has_item(id: StringName) -> bool:
	return owned_items.has(id)


## すでに買っているか（情報は、その箇所がもう埋まっていれば買い済みとみなす）
static func is_owned(item: ShopItem) -> bool:
	if item.kind == &"info":
		return filled_blanks.has(item.target)
	return owned_items.has(item.id)


static func can_buy(item: ShopItem) -> bool:
	return not is_owned(item) and funds >= item.price


## 買う。買えたら true
static func buy(item: ShopItem) -> bool:
	if not can_buy(item):
		return false
	funds -= item.price
	if item.kind == &"info":
		filled_blanks[item.target] = true
	else:
		owned_items[item.id] = true
	save_notebook()
	return true


## 探索の精算: 報酬を受け取り、生活費を払って、日が進む。
## 資金が足りなければ bankrupt = true（資金は0にする）
static func settle(reward: int) -> Dictionary:
	var funds_before := funds
	funds += reward
	funds -= Rules.LIVING_COST
	var bankrupt := funds < 0
	if bankrupt:
		funds = 0
	var result := {
		"reward": reward,
		"living": Rules.LIVING_COST,
		"funds_before": funds_before,
		"funds_after": funds,
		"day": day,
		"bankrupt": bankrupt,
	}
	day += 1
	runs[adventurer_id] = runs_of(adventurer_id) + 1
	save_notebook()
	return result
