class_name Illustrations
extends RefCounted
## 絵の読み込み口。フォルダに絵があれば返し、無ければ null を返す（呼び出し側は何も出さない）。
##
##   res://assets/illustrations/sketches/<id>.png      … 冒険者のスケッチ（通信ログに添える）
##   res://assets/illustrations/sketches/<冒険者id>/<id>.png … その冒険者だけが描く版（あれば優先）
##   res://assets/illustrations/portraits/<冒険者id>.png … キャラの顔
##   res://assets/illustrations/backgrounds/<id>.png   … 背景
##
## 拡張子は png → webp → jpg → svg の順に探す。本物の絵（png）を置けば、仮の絵（svg）より優先される。

const ROOT := "res://assets/illustrations"
const EXTENSIONS: Array[String] = ["png", "webp", "jpg", "svg"]

static var _cache: Dictionary = {}


## 絵を探す。見つからなければ null。owner が空でなければ、その冒険者専用の絵を先に探す。
static func find(kind: String, id: StringName, owner: StringName = &"") -> Texture2D:
	if id == &"":
		return null
	var key := "%s/%s/%s" % [kind, owner, id]
	if _cache.has(key):
		return _cache[key]
	var texture: Texture2D = null
	for path in candidate_paths(kind, id, owner):
		if ResourceLoader.exists(path):
			texture = load(path) as Texture2D
			if texture != null:
				break
	_cache[key] = texture
	return texture


## 探す場所の候補（優先順）。専用の絵 → 共通の絵、拡張子は png → webp → jpg → svg
static func candidate_paths(kind: String, id: StringName, owner: StringName = &"") -> Array[String]:
	var paths: Array[String] = []
	var bases: Array[String] = []
	if owner != &"":
		bases.append("%s/%s/%s/%s" % [ROOT, kind, owner, id])
	bases.append("%s/%s/%s" % [ROOT, kind, id])
	for base in bases:
		for ext in EXTENSIONS:
			paths.append("%s.%s" % [base, ext])
	return paths


static func clear_cache() -> void:
	_cache.clear()
