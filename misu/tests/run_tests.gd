extends SceneTree
## ヘッドレスで実行するテスト。
##   godot --headless --path . --import                       # 初回のみ
##   godot --headless --path . --script tests/run_tests.gd

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, message: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var gd: Node = root.get_node("GameData")
	_check(gd.errors.is_empty(), "データに誤りがない: %s" % [gd.errors])
	_test_gesture(gd.config)
	_test_matches()
	_test_every_case_is_solvable(gd)
	_test_designed_traps(gd)
	await _test_flow(gd)
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_gesture(cfg: Dictionary) -> void:
	var w := 6.0
	_check(Gesture.read([], w, cfg)["gesture"] == "still", "動かさなければ still")
	var hold := Gesture.read([0.5], w, cfg)
	_check(hold["gesture"] == "open_hold" and hold["long_hold"], "早く開いたままなら long_hold")
	var late := Gesture.read([3.0], w, cfg)
	_check(late["gesture"] == "open_hold" and not late["long_hold"] and late["hesitated"], "遅く開くと long_hold ではなく、ためらい")
	var quick := Gesture.read([0.4, 0.7], w, cfg)
	_check(quick["gesture"] == "snap" and quick["quick"] and not quick["hesitated"], "素早く開閉すると quick な snap")
	var slow := Gesture.read([0.4, 1.6], w, cfg)
	_check(slow["gesture"] == "snap" and not slow["quick"], "ゆっくり開閉すると quick ではない")
	_check(Gesture.read([0.2, 0.4, 0.6], w, cfg)["gesture"] == "open_hold", "3回（開いて終わる）は open_hold")
	_check(Gesture.read([0.2, 0.4, 0.6, 0.8], w, cfg)["gesture"] == "flutter", "4回で flutter")


func _test_matches() -> void:
	var ctx := {"gesture": "snap", "toggles": 2, "rank": "low", "quick": true}
	_check(Interpreter.matches({"gesture": "snap", "quick": true}, ctx), "条件がすべて合う")
	_check(not Interpreter.matches({"gesture": "snap", "quick": false}, ctx), "1つでも違えば合わない")
	_check(Interpreter.matches({"rank": ["high", "low"]}, ctx), "配列はどれか")
	_check(Interpreter.matches({"toggles_min": 2.0, "toggles_max": 3}, ctx), "_min / _max")
	_check(not Interpreter.matches({"toggles_min": 3}, ctx), "_min を下回る")
	_check(not Interpreter.matches({"missing": true}, ctx), "ない値は合わない")
	_check(Interpreter.assess("defer", "grant", "defer") == "lost", "作法なら正しかった → lost")
	_check(Interpreter.assess("punish", "punish", "punish") == "conveyed", "そのまま → conveyed")
	_check(Interpreter.assess("dismiss", "punish", "punish") == "read_quirk", "作法と違う扇で正解 → read_quirk")
	_check(Interpreter.assess("grant", "grant", "dismiss") == "misjudged", "作法どおりに誤り → misjudged")


## 代表的な扇の動かし方
func _samples(cfg: Dictionary) -> Dictionary:
	var w := 6.0
	return {
		"何もしない": Gesture.read([], w, cfg),
		"すぐ開いたまま": Gesture.read([0.5], w, cfg),
		"遅れて開いたまま": Gesture.read([3.0], w, cfg),
		"素早く開閉": Gesture.read([0.5, 0.8], w, cfg),
		"ゆっくり開閉": Gesture.read([0.5, 1.8], w, cfg),
		"ためらって開閉": Gesture.read([2.5, 3.5], w, cfg),
		"幾度も": Gesture.read([0.3, 0.6, 0.9, 1.2], w, cfg),
	}


func _declare(gd: Node, c: Dictionary, f: Dictionary) -> String:
	var ctx := f.duplicate()
	ctx["rank"] = c["rank"]
	ctx.merge(c.get("attributes", {}), true)
	return Interpreter.interpret(gd.nyobo[c["nyobo"]], ctx, gd.standard_verdict(f["gesture"]))["verdict"]


## どの陳情も、女房のクセを読めば、ふさわしい沙汰にたどり着ける
func _test_every_case_is_solvable(gd: Node) -> void:
	var samples := _samples(gd.config)
	for c in gd.cases:
		var ok := false
		for k in samples:
			if _declare(gd, c, samples[k]) == c["correct"]:
				ok = true
		_check(ok, "陳情 %s は、どれかの扇でふさわしい沙汰になる" % c["id"])


## 設計どおりの「ずれ」が起きる
func _test_designed_traps(gd: Node) -> void:
	var s := _samples(gd.config)
	var by_id := {}
	for c in gd.cases:
		by_id[c["id"]] = c
	_check(_declare(gd, by_id["mizu"], s["すぐ開いたまま"]) == "grant", "小萩: 開いたまま → 聞き届ける")
	_check(_declare(gd, by_id["tachi"], s["素早く開閉"]) == "grant", "小萩: すぐ開閉 → 聞き届ける（早合点）")
	_check(_declare(gd, by_id["tachi"], s["ためらって開閉"]) == "defer", "小萩: ためらって開閉 → 差し戻す")
	_check(_declare(gd, by_id["ume"], s["何もしない"]) == "defer", "常盤: 高貴の方を退けられない")
	_check(_declare(gd, by_id["ume"], s["素早く開閉"]) == "dismiss", "常盤: ぴしゃりなら退ける")
	_check(_declare(gd, by_id["karaginu"], s["遅れて開いたまま"]) == "defer", "常盤: 下々には遅い情けは差し戻し")
	_check(_declare(gd, by_id["karaginu"], s["すぐ開いたまま"]) == "grant", "常盤: 早く長く開けば聞き届ける")
	_check(_declare(gd, by_id["hi"], s["幾度も"]) == "grant", "夕霧: 幾度もはお慈悲")
	_check(_declare(gd, by_id["hi"], s["素早く開閉"]) == "punish", "夕霧: ぴしゃりは厳罰")


## 画面の流れ: 扇を押し続けるだけで、最後の陳情まで進んでまとめが出る
func _test_flow(gd: Node) -> void:
	var saved: Dictionary = gd.config.duplicate()
	gd.config["judgment_window_sec"] = 0.25
	gd.config["judgment_grace_sec"] = 0.0
	gd.config["after_window_lock_sec"] = 0.0
	gd.config["feeling_window_sec"] = 0.1
	gd.config["text_chars_per_sec"] = 0
	gd.config["save_playtest_log"] = false
	var fan: Node = root.get_node("Fan")
	fan.set_state(false)
	# 自動読み込み（Fan など）が登録されてから読み込む
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.autostart = false
	root.add_child(main)
	await process_frame
	_check(main.split.vertical == (main.size.y >= main.size.x), "縦横で並びが変わる")

	main.play_session()
	var deadline := Time.get_ticks_msec() + 20000
	while main.results.size() < gd.cases.size() and Time.get_ticks_msec() < deadline:
		fan.press(true)
		await create_timer(0.03).timeout
	_check(main.results.size() == gd.cases.size(), "全陳情を終えた（%d / %d）" % [main.results.size(), gd.cases.size()])
	for r in main.results:
		_check(r["category"] in ["conveyed", "read_quirk", "lost", "misjudged", "astray"], "分類がある")
	_check(not main.notebook.is_empty(), "女房帖に所見がたまる")

	# 狙いどおりの扇: 小萩の陳情（太刀）で、ためらってから開閉すると差し戻しになる
	main.results.clear()
	gd.config["judgment_window_sec"] = 1.2
	gd.config["hesitate_sec"] = 0.5
	gd.config["ask_feeling"] = false
	var tachi: Dictionary = gd.cases[1]
	main.play_case(tachi, 2)
	deadline = Time.get_ticks_msec() + 10000
	while not main._judging and Time.get_ticks_msec() < deadline:
		fan.press(true)
		await create_timer(0.03).timeout
	if fan.is_open:  # 構えるために閉じる
		fan.press(true)
	await create_timer(0.6).timeout
	fan.press(true)
	await create_timer(0.3).timeout
	fan.press(true)
	while main.results.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
		if not main._judging:
			fan.press(true)
	_check(main.results.size() == 1 and main.results[0]["declared"] == "defer", "ためらって開閉 → 小萩は差し戻す: %s" % [main.results])
	if main.results.size() == 1:
		_check(main.results[0]["category"] == "conveyed", "作法どおりで、そのまま伝わった")

	main.queue_free()
	gd.config = saved
