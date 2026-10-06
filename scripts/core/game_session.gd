class_name GameSession
extends RefCounted
## シーンをまたいで持ち越す状態。
##  - 誰をガイドするか
##  - ノートの育ち（埋めた虫食い・訂正した記述）。探索をまたいで引き継ぎ、ファイルにも保存する

static var adventurer_id: StringName = &"childhood"
## 埋まった穴／訂正した箇所の id -> true（MatchingState と同じ辞書を共有する）
static var filled_blanks: Dictionary = {}
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
	if data is Dictionary and data.get("filled") is Array:
		for id in data["filled"]:
			filled_blanks[StringName(str(id))] = true


static func save_notebook() -> void:
	if not persist:
		return
	var ids: Array[String] = []
	for id in filled_blanks:
		ids.append(String(id))
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"filled": ids}))


## ノートを最初の状態に戻す
static func reset_notebook() -> void:
	filled_blanks.clear()
	if persist:
		save_notebook()
