class_name GameDB
extends RefCounted
## data/ 以下の JSON を読み込んで保持する。シナリオを足すときにコードを触らなくて済むようにするための入口。

const DATA_DIR := "res://data"

var config: Dictionary = {}
var characters: Dictionary = {}
var items: Dictionary = {}
var scenes: Dictionary = {}          # scene id -> scene Dictionary
var scene_files: Dictionary = {}     # scene id -> 定義されていたファイル名
var load_errors: Array[String] = []  # 読み込み時の問題（JSON構文エラー・ID重複など）


func load_all(base: String = DATA_DIR) -> void:
	load_errors.clear()
	config = _as_dict(_read_json(base + "/config.json"))
	characters = _as_dict(_as_dict(_read_json(base + "/characters.json")).get("characters", {}))
	items = _as_dict(_as_dict(_read_json(base + "/items.json")).get("items", {}))
	scenes.clear()
	scene_files.clear()
	var dir := DirAccess.open(base + "/scenes")
	if dir == null:
		load_errors.append("%s/scenes を開けません" % base)
		return
	var files: Array = Array(dir.get_files())
	files.sort()
	for f in files:
		if not (f as String).ends_with(".json"):
			continue
		var data := _as_dict(_read_json("%s/scenes/%s" % [base, f]))
		for sc in data.get("scenes", []):
			if typeof(sc) != TYPE_DICTIONARY or not sc.has("id"):
				load_errors.append("%s: id のないシーンがあります" % f)
				continue
			var id := str(sc["id"])
			if scenes.has(id):
				load_errors.append("%s: シーンID '%s' が重複しています（%s にも定義あり）" % [f, id, scene_files[id]])
				continue
			scenes[id] = sc
			scene_files[id] = f


func item_name(id: String) -> String:
	return str((items.get(id, {}) as Dictionary).get("name", id))


func char_name(id: String) -> String:
	return str((characters.get(id, {}) as Dictionary).get("name", id))


func _as_dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		load_errors.append("%s を開けません" % path)
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		load_errors.append("%s:%d: JSON構文エラー: %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return _intify(j.data)


## JSON の数値はすべて float で読まれるので、整数値のものは int に直す。
static func _intify(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			if v == floorf(v) and absf(v) < 1.0e15:
				return int(v)
		TYPE_ARRAY:
			var a: Array = []
			for x in v:
				a.append(_intify(x))
			return a
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k in v:
				d[k] = _intify(v[k])
			return d
	return v
