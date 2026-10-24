class_name Interpreter
extends RefCounted
## 女房の解釈。女房の rules を上から調べ、when がすべて合った最初の規則で沙汰が決まる。
## どれにも合わなければ、作法どおりの沙汰になる。UI に依存しない。


## when の各キーを ctx と照らし合わせる。
##   "rank": "low"         … 等しい
##   "rank": ["low", "x"]  … どれかに等しい
##   "toggles_min": 3      … ctx["toggles"] >= 3（_max は <=）
static func matches(when: Dictionary, ctx: Dictionary) -> bool:
	for key in when:
		var want: Variant = when[key]
		var k := String(key)
		if k.ends_with("_min") and not ctx.has(k):
			var base := k.trim_suffix("_min")
			if not ctx.has(base) or float(ctx[base]) < float(want):
				return false
		elif k.ends_with("_max") and not ctx.has(k):
			var base := k.trim_suffix("_max")
			if not ctx.has(base) or float(ctx[base]) > float(want):
				return false
		elif want is Array:
			if not ctx.has(k) or not _in_array(ctx[k], want):
				return false
		elif not ctx.has(k) or not _same(ctx[k], want):
			return false
	return true


static func interpret(nyobo: Dictionary, ctx: Dictionary, standard_verdict: String) -> Dictionary:
	var rules: Array = nyobo.get("rules", [])
	for i in rules.size():
		var rule: Dictionary = rules[i]
		if matches(rule.get("when", {}), ctx):
			var r := rule.duplicate()
			r["index"] = i
			return r
	return {"verdict": standard_verdict, "reading": "", "note": "", "index": -1}


## 結果の分類。作法どおりの読み（standard）を、御方の意図とみなす。
static func assess(standard: String, declared: String, correct: String) -> String:
	if declared == correct:
		return "conveyed" if standard == correct else "read_quirk"
	if standard == correct:
		return "lost"
	if declared == standard:
		return "misjudged"
	return "astray"


static func _same(a: Variant, b: Variant) -> bool:
	# JSON の数値は float になるので、数どうしは値で比べる
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if typeof(a) != typeof(b):
		return false
	return a == b


static func _in_array(a: Variant, arr: Array) -> bool:
	for v in arr:
		if _same(a, v):
			return true
	return false
