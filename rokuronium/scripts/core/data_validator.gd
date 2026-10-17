class_name DataValidator
extends RefCounted
## 全 JSON を検証する。存在しない next の参照・未定義のID・条件式の構文エラー・行き止まりなどを一覧にする。
## 戻り値: { "errors": Array[String], "warnings": Array[String], "info": Array[String] }

const MAX_CHOICES := 5
const MAX_PARAGRAPH_CHARS := 260
const CHOICE_NEXT_KEYS := ["next", "next_success", "next_failure", "next_critical"]
const CONDITION_NAMESPACES := ["flag", "affinity", "item", "hp", "mp", "level"]
const CONDITION_PLAIN := ["money", "day", "slot", "location", "exp"]


static func validate(db: GameDB) -> Dictionary:
	var r := {"errors": [], "warnings": [], "info": []}
	for e in db.load_errors:
		r["errors"].append(e)
	_check_config(db, r)
	_check_characters(db, r)
	_check_items(db, r)
	for id in db.scenes:
		_check_scene(db, id, db.scenes[id], r)
	_check_reachability(db, r)
	var drafts := 0
	for id in db.scenes:
		if db.scenes[id].get("draft", false):
			drafts += 1
	r["info"].append("シーン %d 件（うち draft %d 件）、キャラ %d 件、アイテム %d 件" % [
		db.scenes.size(), drafts, db.characters.size(), db.items.size()])
	return r


static func _err(r: Dictionary, where: String, msg: String) -> void:
	r["errors"].append("%s: %s" % [where, msg])


static func _warn(r: Dictionary, where: String, msg: String) -> void:
	r["warnings"].append("%s: %s" % [where, msg])


# ---------------------------------------------------------------- config / characters / items

static func _check_config(db: GameDB, r: Dictionary) -> void:
	var c := db.config
	var start := str(c.get("start_scene", ""))
	if start.is_empty():
		_err(r, "config", "start_scene がありません")
	elif not db.scenes.has(start):
		_err(r, "config", "start_scene '%s' というシーンがありません" % start)
	if not Money.is_valid(c.get("start_money", 0)):
		_err(r, "config", "start_money が金額として読めません")
	for id in c.get("party", []):
		if not db.characters.has(id):
			_err(r, "config", "party に未定義のキャラ '%s'" % id)
	for id in c.get("start_items", {}):
		if not db.items.has(id):
			_err(r, "config", "start_items に未定義のアイテム '%s'" % id)


static func _check_characters(db: GameDB, r: Dictionary) -> void:
	for id in db.characters:
		var c: Dictionary = db.characters[id]
		if not c.has("name"):
			_err(r, "characters.%s" % id, "name がありません")
		if not str(c.get("color", "")).is_valid_html_color():
			_err(r, "characters.%s" % id, "color が色コードではありません")
		if c.get("party", false) or c.has("stats"):
			for k in ["hp", "mp"]:
				if not c.has(k):
					_err(r, "characters.%s" % id, "%s がありません" % k)
			for s in c.get("stats", {}):
				if not (s in GameState.STAT_NAMES):
					_err(r, "characters.%s" % id, "未知のステータス '%s'" % s)


static func _check_items(db: GameDB, r: Dictionary) -> void:
	for id in db.items:
		if not (db.items[id] as Dictionary).has("name"):
			_err(r, "items.%s" % id, "name がありません")


# ---------------------------------------------------------------- scenes

static func _check_scene(db: GameDB, id: String, sc: Dictionary, r: Dictionary) -> void:
	var where := "scene '%s' (%s)" % [id, db.scene_files.get(id, "?")]
	if typeof(sc.get("text")) != TYPE_ARRAY or (sc["text"] as Array).is_empty():
		_err(r, where, "text（本文の配列）がありません")
	else:
		for line in sc["text"]:
			var body := str(line.get("text", "")) if typeof(line) == TYPE_DICTIONARY else str(line)
			if body.length() > MAX_PARAGRAPH_CHARS:
				_warn(r, where, "1段落が %d 字あります（%d 字まで。本文ボックスに収まらない恐れ）" % [body.length(), MAX_PARAGRAPH_CHARS])
			if typeof(line) == TYPE_DICTIONARY:
				if not line.has("text"):
					_err(r, where, "本文行に text がありません")
				if line.has("if"):
					_check_cond(db, str(line["if"]), where + " 本文行の if", r)
			elif typeof(line) != TYPE_STRING:
				_err(r, where, "本文行は文字列か {text, if} にしてください")
	for p in sc.get("portraits", []):
		var cid := str(p).split("_")[0]
		if not db.characters.has(cid):
			_err(r, where, "portraits '%s' のキャラ '%s' が characters.json にありません" % [p, cid])
	var t: Variant = sc.get("time")
	if t != null:
		if typeof(t) != TYPE_DICTIONARY:
			_err(r, where, "time は {day, slot} にしてください")
		elif t.has("slot") and not (t["slot"] in GameState.SLOTS):
			_err(r, where, "time.slot '%s' は朝/昼/夕方/夜/深夜のいずれかです" % t["slot"])
	_check_effects(db, sc.get("on_enter", []), where + " on_enter", r)

	var choices := StoryEngine.raw_choices(sc)
	if choices.is_empty():
		if not sc.get("end", false):
			_err(r, where, "行き止まりです（choices / auto / next / end のどれもありません）")
		return
	if sc.get("end", false):
		_warn(r, where, "end:true のシーンに選択肢があります")
	if choices.size() > MAX_CHOICES:
		_err(r, where, "選択肢が %d 個あります（最大 %d）" % [choices.size(), MAX_CHOICES])
	var free_count := 0
	for ch in choices:
		if not ch.get("fixed", false):
			free_count += 1
	if free_count == 2:
		_warn(r, where, "選択肢が2個だけです（3〜5個が基本）")
	for i in choices.size():
		_check_choice(db, where + " 選択肢%d" % (i + 1), choices[i], r)


static func _check_choice(db: GameDB, where: String, ch: Dictionary, r: Dictionary) -> void:
	if str(ch.get("text", "")).is_empty():
		_err(r, where, "text がありません")
	if ch.has("condition"):
		_check_cond(db, str(ch["condition"]), where + " condition", r)
	_check_effects(db, ch.get("effects", []), where + " effects", r)
	if ch.has("check"):
		_check_check(db, where, ch, r)
		for k in ["next_success", "next_failure"]:
			if not ch.has(k):
				_err(r, where, "check があるのに %s がありません" % k)
		if ch.has("next"):
			_warn(r, where, "check があるので next は使われません")
		for k in ["effects_success", "effects_failure", "effects_critical"]:
			_check_effects(db, ch.get(k, []), where + " " + k, r)
	else:
		if not ch.has("next"):
			_err(r, where, "next がありません")
		for k in ["next_success", "next_failure", "next_critical", "effects_success", "effects_failure", "effects_critical"]:
			if ch.has(k):
				_warn(r, where, "check が無いのに %s があります" % k)
	for k in CHOICE_NEXT_KEYS:
		if ch.has(k) and not db.scenes.has(str(ch[k])):
			_err(r, where, "%s '%s' というシーンがありません" % [k, ch[k]])


static func _check_check(db: GameDB, where: String, ch: Dictionary, r: Dictionary) -> void:
	var chk: Dictionary = ch["check"]
	var who := str(chk.get("who", StoryEngine.DEFAULT_WHO))
	if not db.characters.has(who):
		_err(r, where, "check.who '%s' が未定義" % who)
	if not (str(chk.get("stat", "")) in GameState.STAT_NAMES):
		_err(r, where, "check.stat '%s' は力/体力/敏捷/知力/魔力/器用/運のいずれかです" % str(chk.get("stat", "")))
	if typeof(chk.get("difficulty")) != TYPE_INT:
		_err(r, where, "check.difficulty は整数にしてください")
	if chk.has("skill") and db.characters.has(who):
		var skills: Dictionary = (db.characters[who] as Dictionary).get("skills", {})
		if not skills.has(chk["skill"]):
			_warn(r, where, "check.skill '%s' を %s は初期状態で持っていません（Lv0扱い）" % [chk["skill"], who])
	for m in chk.get("mods", []):
		_check_cond(db, str(m.get("if", "")), where + " check.mods", r)


static func _check_cond(db: GameDB, expr: String, where: String, r: Dictionary) -> void:
	var p := Cond.parse(expr)
	if not p["ok"]:
		_err(r, where, "条件式 '%s' の構文エラー: %s" % [expr, p["error"]])
		return
	for ident in p["idents"]:
		var s: String = ident
		if s in CONDITION_PLAIN:
			continue
		var dot := s.find(".")
		var ns := s.substr(0, dot) if dot >= 0 else s
		var key := s.substr(dot + 1) if dot >= 0 else ""
		if dot < 0 or not (ns in CONDITION_NAMESPACES) or key.is_empty():
			_err(r, where, "条件式 '%s' の '%s' は参照できない名前です" % [expr, s])
			continue
		match ns:
			"item":
				if not db.items.has(key):
					_err(r, where, "条件式 '%s' に未定義のアイテム '%s'" % [expr, key])
			"affinity", "hp", "mp", "level":
				if not db.characters.has(key):
					_err(r, where, "条件式 '%s' に未定義のキャラ '%s'" % [expr, key])


static func _check_effects(db: GameDB, effects: Variant, where: String, r: Dictionary) -> void:
	if typeof(effects) != TYPE_ARRAY:
		_err(r, where, "effects は配列にしてください")
		return
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			_err(r, where, "effects の要素は {op: ...} にしてください")
			continue
		var op := str(e.get("op", ""))
		if op in Fx.RESERVED_OPS:
			_warn(r, where, "op '%s' はまだ実装されていません" % op)
			continue
		if not Fx.OP_SPECS.has(op):
			_err(r, where, "未知の op '%s'" % op)
			continue
		for k in Fx.OP_SPECS[op]:
			if not e.has(k):
				_err(r, where, "op '%s' に '%s' がありません" % [op, k])
		if e.has("if"):
			_check_cond(db, str(e["if"]), where + " if", r)
		if e.has("id") and not db.items.has(str(e["id"])):
			_err(r, where, "未定義のアイテムID '%s'" % e["id"])
		if e.has("who") and not db.characters.has(str(e["who"])):
			_err(r, where, "未定義のキャラ '%s'" % e["who"])
		if op == "add_money" and e.has("value") and not Money.is_valid(e["value"]):
			_err(r, where, "add_money の value '%s' が金額として読めません" % str(e["value"]))
		if op == "advance_time" and e.has("slot") and not (e["slot"] in GameState.SLOTS):
			_err(r, where, "advance_time.slot '%s' は朝/昼/夕方/夜/深夜のいずれかです" % e["slot"])


# ---------------------------------------------------------------- 到達性

static func _check_reachability(db: GameDB, r: Dictionary) -> void:
	var start := str(db.config.get("start_scene", ""))
	if not db.scenes.has(start):
		return
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var id: String = queue.pop_back()
		for ch in StoryEngine.raw_choices(db.scenes[id]):
			for k in CHOICE_NEXT_KEYS:
				var nxt := str(ch.get(k, ""))
				if not nxt.is_empty() and db.scenes.has(nxt) and not seen.has(nxt):
					seen[nxt] = true
					queue.append(nxt)
	for id in db.scenes:
		if not seen.has(id):
			_warn(r, "scene '%s'" % id, "開始シーンから到達できません")
	# 終端(end:true)に到達できるか
	var reaches_end := false
	for id in seen:
		if db.scenes[id].get("end", false):
			reaches_end = true
	if not reaches_end:
		_warn(r, "config", "end:true のシーンに到達できません")
