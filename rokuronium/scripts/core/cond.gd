class_name Cond
extends RefCounted
## 条件式（選択肢の表示条件・本文行の条件・効果の条件）の小さなパーサと評価器。
##
## 例:  flag.ruu_released == true  /  money >= 30  /  affinity.ayaka >= 60 && !flag.met_gorm
## 使える要素: 数値 / true / false / '文字列' / 識別子(flag.x, item.x, affinity.x, hp.x, mp.x, level.x, money, day, slot)
## 演算子: == != >= <= > < && || ! ( )

static var _cache: Dictionary = {}


## 構文を解析する。{"ok": bool, "ast": Dictionary, "error": String, "idents": Array[String]}
static func parse(expr: String) -> Dictionary:
	if _cache.has(expr):
		return _cache[expr]
	var res := _parse_uncached(expr)
	_cache[expr] = res
	return res


static func test(expr: String, state: GameState) -> bool:
	if expr.strip_edges().is_empty():
		return true
	var p := parse(expr)
	if not p["ok"]:
		push_error("条件式の構文エラー: '%s' (%s)" % [expr, p["error"]])
		return false
	return to_bool(evaluate(p["ast"], state))


static func to_bool(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING:
			return not (v as String).is_empty()
	return true


static func evaluate(ast: Dictionary, state: GameState) -> Variant:
	match ast["t"]:
		"lit":
			return ast["v"]
		"id":
			return state.resolve(ast["name"])
		"not":
			return not to_bool(evaluate(ast["e"], state))
		"bin":
			var op: String = ast["op"]
			if op == "&&":
				return to_bool(evaluate(ast["l"], state)) and to_bool(evaluate(ast["r"], state))
			if op == "||":
				return to_bool(evaluate(ast["l"], state)) or to_bool(evaluate(ast["r"], state))
			return _compare(op, evaluate(ast["l"], state), evaluate(ast["r"], state))
	return null


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _compare(op: String, a: Variant, b: Variant) -> bool:
	# 未設定(null)は false 扱い。真偽値と数値の比較は 0/1 として扱う。
	if a == null:
		a = false
	if b == null:
		b = false
	if typeof(a) == TYPE_BOOL and _is_num(b):
		a = 1 if a else 0
	if typeof(b) == TYPE_BOOL and _is_num(a):
		b = 1 if b else 0
	var comparable := (_is_num(a) and _is_num(b)) or typeof(a) == typeof(b)
	match op:
		"==":
			return comparable and a == b
		"!=":
			return not (comparable and a == b)
	if not (_is_num(a) and _is_num(b)):
		return false
	match op:
		">=":
			return a >= b
		"<=":
			return a <= b
		">":
			return a > b
		"<":
			return a < b
	return false


static func collect_idents(ast: Dictionary, out: Array) -> void:
	match ast["t"]:
		"id":
			out.append(ast["name"])
		"not":
			collect_idents(ast["e"], out)
		"bin":
			collect_idents(ast["l"], out)
			collect_idents(ast["r"], out)


# ---------------------------------------------------------------- 構文解析

static func _parse_uncached(expr: String) -> Dictionary:
	var tk := _tokenize(expr)
	if tk["error"] != "":
		return {"ok": false, "error": tk["error"], "ast": {}, "idents": []}
	if (tk["tokens"] as Array).is_empty():
		return {"ok": false, "error": "式が空です", "ast": {}, "idents": []}
	var p := _Parser.new()
	p.toks = tk["tokens"]
	var ast := p.parse_or()
	if p.error == "" and p.pos < p.toks.size():
		p.error = "余分な記号 '%s' があります" % str(p.toks[p.pos]["v"])
	if p.error != "":
		return {"ok": false, "error": p.error, "ast": {}, "idents": []}
	var idents: Array = []
	collect_idents(ast, idents)
	return {"ok": true, "error": "", "ast": ast, "idents": idents}


static func _is_ident_start(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _tokenize(s: String) -> Dictionary:
	var tokens: Array = []
	var i := 0
	var n := s.length()
	while i < n:
		var c := s[i]
		if c == " " or c == "\t":
			i += 1
			continue
		if _is_digit(c):
			var j := i
			while j < n and _is_digit(s[j]):
				j += 1
			tokens.append({"k": "num", "v": int(s.substr(i, j - i))})
			i = j
			continue
		if _is_ident_start(c):
			var j := i
			while j < n and (_is_ident_start(s[j]) or _is_digit(s[j]) or s[j] == "."):
				j += 1
			var word := s.substr(i, j - i)
			if word == "true" or word == "false":
				tokens.append({"k": "bool", "v": word == "true"})
			else:
				tokens.append({"k": "id", "v": word})
			i = j
			continue
		if c == "'" or c == "\"":
			var j := s.find(c, i + 1)
			if j < 0:
				return {"tokens": [], "error": "文字列が閉じていません"}
			tokens.append({"k": "str", "v": s.substr(i + 1, j - i - 1)})
			i = j + 1
			continue
		var two := s.substr(i, 2)
		if two in ["==", "!=", ">=", "<=", "&&", "||"]:
			tokens.append({"k": "op", "v": two})
			i += 2
			continue
		if c in [">", "<", "!", "(", ")"]:
			tokens.append({"k": "op", "v": c})
			i += 1
			continue
		return {"tokens": [], "error": "使えない文字 '%s' があります" % c}
	return {"tokens": tokens, "error": ""}


class _Parser:
	var toks: Array = []
	var pos := 0
	var error := ""

	func _peek() -> Dictionary:
		if pos < toks.size():
			return toks[pos]
		return {"k": "eof", "v": ""}

	func _is_op(v: String) -> bool:
		var t := _peek()
		return t["k"] == "op" and t["v"] == v

	func parse_or() -> Dictionary:
		var l := parse_and()
		while error == "" and _is_op("||"):
			pos += 1
			var r := parse_and()
			l = {"t": "bin", "op": "||", "l": l, "r": r}
		return l

	func parse_and() -> Dictionary:
		var l := parse_not()
		while error == "" and _is_op("&&"):
			pos += 1
			var r := parse_not()
			l = {"t": "bin", "op": "&&", "l": l, "r": r}
		return l

	func parse_not() -> Dictionary:
		if _is_op("!"):
			pos += 1
			return {"t": "not", "e": parse_not()}
		return parse_cmp()

	func parse_cmp() -> Dictionary:
		var l := parse_primary()
		if error == "":
			var t := _peek()
			if t["k"] == "op" and t["v"] in ["==", "!=", ">=", "<=", ">", "<"]:
				pos += 1
				var r := parse_primary()
				return {"t": "bin", "op": t["v"], "l": l, "r": r}
		return l

	func parse_primary() -> Dictionary:
		var t := _peek()
		match t["k"]:
			"num", "bool", "str":
				pos += 1
				return {"t": "lit", "v": t["v"]}
			"id":
				pos += 1
				return {"t": "id", "name": t["v"]}
		if _is_op("("):
			pos += 1
			var e := parse_or()
			if error == "":
				if _is_op(")"):
					pos += 1
				else:
					error = "')' が足りません"
			return e
		if error == "":
			error = "式が途中で終わっています" if t["k"] == "eof" else "ここに '%s' は置けません" % str(t["v"])
		return {"t": "lit", "v": null}
