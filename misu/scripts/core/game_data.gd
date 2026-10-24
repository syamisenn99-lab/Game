extends Node
## JSON データの読み込みと、文言の差し込み。自動読み込み（GameData）。
## 陳情・女房・作法・文言・しきい値は、すべて res://data/ の JSON にある。

const DATA_DIR := "res://data/"

var config: Dictionary = {}
var court: Dictionary = {}
var text: Dictionary = {}
var nyobo: Dictionary = {}  # id → 女房
var cases: Array = []
var errors: Array[String] = []


func _init() -> void:
	load_all()


func load_all() -> void:
	errors.clear()
	config = _load("config.json")
	court = _load("court.json")
	text = _load("text.json")
	nyobo.clear()
	for n in _load("nyobo.json").get("nyobo", []):
		nyobo[String(n.get("id", ""))] = n
	cases = _load("cases.json").get("cases", [])
	errors.append_array(validate())
	for e in errors:
		push_error("データの誤り: " + e)


func _load(file: String) -> Dictionary:
	var path := DATA_DIR + file
	if not FileAccess.file_exists(path):
		errors.append("%s が見つからない" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("%s を JSON として読めない" % path)
		return {}
	return parsed


## データの食い違いを探す（足りない沙汰、知らない女房など）
func validate() -> Array[String]:
	var out: Array[String] = []
	var verdicts: Dictionary = court.get("verdicts", {})
	var gestures: Dictionary = court.get("gestures", {})
	for g in gestures:
		if not verdicts.has(gestures[g].get("standard_verdict", "")):
			out.append("作法 %s の standard_verdict が沙汰にない" % g)
	for id in nyobo:
		for r in nyobo[id].get("rules", []):
			if not verdicts.has(r.get("verdict", "")):
				out.append("女房 %s の規則の verdict「%s」が沙汰にない" % [id, r.get("verdict", "")])
			var g: Variant = r.get("when", {}).get("gesture", null)
			if g is String and not gestures.has(g):
				out.append("女房 %s の規則の gesture「%s」が作法にない" % [id, g])
	for c in cases:
		var cid := String(c.get("id", "?"))
		if not nyobo.has(c.get("nyobo", "")):
			out.append("陳情 %s の女房「%s」がいない" % [cid, c.get("nyobo", "")])
		if not verdicts.has(c.get("correct", "")):
			out.append("陳情 %s の correct が沙汰にない" % cid)
		if not court.get("ranks", {}).has(c.get("rank", "")):
			out.append("陳情 %s の rank「%s」が身分にない" % [cid, c.get("rank", "")])
		var outcomes: Dictionary = c.get("outcomes", {})
		for v in verdicts:
			if not outcomes.has(v):
				out.append("陳情 %s に沙汰 %s の outcomes がない" % [cid, v])
	return out


func cfg(key: String, default: Variant = null) -> Variant:
	return config.get(key, default)


## 文言を取り出し、{name} を args の値に置き換える
func t(key: String, args: Dictionary = {}) -> String:
	var v: Variant = text.get(key, key)
	return fmt(str(v), args)


func fmt(template: String, args: Dictionary = {}) -> String:
	var s := template
	for k in args:
		s = s.replace("{%s}" % k, str(args[k]))
	return s


func verdict_name(id: String) -> String:
	return String(court.get("verdicts", {}).get(id, {}).get("name", id))


func gesture_name(id: String) -> String:
	return String(court.get("gestures", {}).get(id, {}).get("name", id))


func rank_name(id: String) -> String:
	return String(court.get("ranks", {}).get(id, id))


func standard_verdict(gesture: String) -> String:
	return String(court.get("gestures", {}).get(gesture, {}).get("standard_verdict", ""))


## 作法の一覧（「・開いたまま：聞き届ける」…）
func etiquette_text() -> String:
	var lines: PackedStringArray = []
	for g in court.get("gesture_order", []):
		lines.append(t("etiquette_line", {"gesture": gesture_name(g), "verdict": verdict_name(standard_verdict(g))}))
	return "\n".join(lines)


## 御方の扇の説明（「0.8秒で開き、そのまま5.2秒」）
func describe_gesture(f: Dictionary) -> String:
	var g := String(f.get("gesture", ""))
	var desc := String(court.get("gestures", {}).get(g, {}).get("desc", g))
	var s := fmt(desc, {
		"first": "%.1f" % float(f.get("first_move_sec", 0.0)),
		"hold": "%.1f" % float(f.get("final_open_sec", 0.0)),
		"snap": "%.1f" % float(f.get("snap_open_sec", 0.0)),
		"toggles": int(f.get("toggles", 0)),
	})
	if f.get("hesitated", false):
		s += t("hesitated_suffix")
	return s
