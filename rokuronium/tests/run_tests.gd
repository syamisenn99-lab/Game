extends SceneTree
## 使い方:  godot --headless --path rokuronium --script tests/run_tests.gd
## ロジック（金額・条件式・判定・効果・進行）と、シナリオ全体のランダムプレイ／網羅テスト。

var _fails := 0
var _checks := 0


func _initialize() -> void:
	test_money()
	test_cond()
	test_rules()
	test_fx()
	test_state()
	test_canon_route()
	test_menu_text()
	test_validator_detects_errors()
	test_random_playthrough()
	print("\nテスト完了: %d 件中 %d 件失敗" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  [失敗] ", msg)


func eq(a: Variant, b: Variant, msg: String) -> void:
	_checks += 1
	if a != b:
		_fails += 1
		print("  [失敗] %s（期待: %s／実際: %s）" % [msg, str(b), str(a)])


func _make() -> Array:
	var db := GameDB.new()
	db.load_all()
	var st := GameState.new()
	st.rng.seed = 12345
	st.new_game(db)
	return [db, st]


# ---------------------------------------------------------------- 個別テスト

func test_money() -> void:
	print("# 金額")
	eq(Money.format(0), "0銅", "0銅")
	eq(Money.format(200), "2金", "2金")
	eq(Money.format(142), "1金4銀2銅", "1金4銀2銅")
	eq(Money.format(30), "3銀", "3銀")
	eq(Money.format(-4), "-4銅", "負の金額")
	eq(Money.parse("3銀"), 30, "parse 3銀")
	eq(Money.parse("1金4銀2銅"), 142, "parse 複合")
	eq(Money.parse("-1銀"), -10, "parse 負")
	eq(Money.parse(25), 25, "parse 整数")
	ok(Money.is_valid("2金3銀") and not Money.is_valid("abc"), "is_valid")


func test_cond() -> void:
	print("# 条件式")
	var m := _make()
	var st: GameState = m[1]
	st.flags["ruu_released"] = true
	eq(Cond.test("flag.ruu_released == true", st), true, "flag == true")
	eq(Cond.test("flag.nothing", st), false, "未設定フラグは false")
	eq(Cond.test("!flag.nothing", st), true, "! 未設定")
	eq(Cond.test("money >= 30", st), true, "money >= 30")
	eq(Cond.test("money >= 30 && affinity.ayaka >= 60", st), false, "&& 偽")
	eq(Cond.test("money < 10 || affinity.ayaka >= 40", st), true, "|| 真")
	eq(Cond.test("(money > 1000 || flag.ruu_released) && !flag.x", st), true, "括弧")
	eq(Cond.test("item.herb == 5", st), true, "item.herb == 5")
	eq(Cond.test("slot == '朝'", st), true, "文字列比較")
	st.flags["how"] = "magic"
	eq(Cond.test("flag.how == 'magic'", st), true, "文字列フラグ")
	eq(Cond.test("flag.how != 'magic'", st), false, "文字列フラグ !=")
	eq(Cond.test("flag.zzz == 0", st), true, "未設定 == 0")
	ok(not Cond.parse("money >=")["ok"], "構文エラー: 右辺なし")
	ok(not Cond.parse("(money > 1")["ok"], "構文エラー: 括弧")
	ok(not Cond.parse("money > 1 )")["ok"], "構文エラー: 余分な )")
	ok(not Cond.parse("money # 1")["ok"], "構文エラー: 不正な文字")
	ok(not Cond.parse("")["ok"], "構文エラー: 空")


func test_rules() -> void:
	print("# 判定")
	# 2d6 + ステータス + スキルLv×2 + 補正 >= 難易度
	eq(Rules.evaluate(7, 5, 1, 0, 14)["outcome"], Rules.OUTCOME_SUCCESS, "ちょうど難易度で成功")
	eq(Rules.evaluate(6, 5, 1, 0, 14)["outcome"], Rules.OUTCOME_FAILURE, "1足りず失敗")
	eq(Rules.evaluate(6, 5, 1, 1, 14)["outcome"], Rules.OUTCOME_SUCCESS, "補正で成功")
	eq(Rules.evaluate(12, 0, 0, -99, 99)["outcome"], Rules.OUTCOME_CRITICAL, "出目12は大成功")
	eq(Rules.evaluate(2, 99, 9, 99, 1)["outcome"], Rules.OUTCOME_FAILURE, "出目2は失敗")
	eq(Rules.evaluate(7, 5, 1, 0, 14)["total"], 14, "合計値")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var lo := 99
	var hi := 0
	for i in 500:
		var r := Rules.roll_dice(rng)
		lo = mini(lo, r)
		hi = maxi(hi, r)
	ok(lo >= 2 and hi <= 12, "2d6 の範囲 (%d..%d)" % [lo, hi])


func test_fx() -> void:
	print("# 効果")
	var m := _make()
	var db: GameDB = m[0]
	var st: GameState = m[1]
	var notes: Array = []
	Fx.apply([{"op": "add_money", "value": "3銀"}], st, db, notes)
	eq(st.money, 230, "add_money 3銀")
	Fx.apply([{"op": "add_money", "value": -9999}], st, db, notes)
	eq(st.money, 0, "所持金は0未満にならない")
	Fx.apply([{"op": "add_item", "id": "empty_bottle", "count": 5}, {"op": "remove_item", "id": "herb", "count": 2}], st, db, notes)
	eq(st.item_count("empty_bottle"), 5, "add_item")
	eq(st.item_count("herb"), 3, "remove_item")
	Fx.apply([{"op": "remove_item", "id": "herb", "count": 3}], st, db, notes)
	ok(not st.inventory.has("herb"), "0個になったら消える")
	Fx.apply([{"op": "add_mp", "who": "ayaka", "value": -3}], st, db, notes)
	eq(st.party["ayaka"]["mp"], 17, "ayaka MP 20→17")
	Fx.apply([{"op": "add_hp", "who": "kazuki", "value": -999}], st, db, notes)
	eq(st.party["kazuki"]["hp"], 1, "非戦闘ではHPが0にならない")
	Fx.apply([{"op": "add_hp", "who": "kazuki", "value": 999}], st, db, notes)
	eq(st.party["kazuki"]["hp"], 30, "HPは最大値まで")
	Fx.apply([{"op": "add_affinity", "who": "ayaka", "value": 1}], st, db, notes)
	eq(st.affinity["ayaka"], 46, "親密度 +1")
	ok(not st.affinity.has("ruu"), "出会う前のヒロインは親密度に載らない")
	Fx.apply([{"op": "meet", "who": "ruu", "value": 3}], st, db, notes)
	eq(st.affinity["ruu"], 3, "meet")
	Fx.apply([{"op": "set_flag", "key": "a", "value": true, "if": "money > 99999"}], st, db, notes)
	ok(not st.flags.has("a"), "if が偽なら実行しない")
	Fx.apply([{"op": "add_flag", "key": "n", "value": 2}, {"op": "add_flag", "key": "n", "value": 3}], st, db, notes)
	eq(st.flags["n"], 5, "add_flag")
	st.day = 1
	st.slot = "夕方"
	Fx.apply([{"op": "advance_time", "slot": "昼"}], st, db, notes)
	eq([st.day, st.slot], [2, "昼"], "過去の時間帯を指定すると翌日")
	Fx.apply([{"op": "advance_time", "steps": 4}], st, db, notes)
	eq([st.day, st.slot], [3, "朝"], "steps で進める（昼+4 → 翌日の朝）")


func test_state() -> void:
	print("# 状態")
	var m := _make()
	var db: GameDB = m[0]
	var st: GameState = m[1]
	eq(st.money, 200, "初期所持金 2金")
	eq(st.party["kazuki"]["hp"], 30, "カズキ HP30")
	eq(st.stat_of("ayaka", "知力"), 8, "アヤカ 知力8")
	eq(st.skill_of("ayaka", "風魔法"), 1, "アヤカ 風魔法Lv1")
	eq(st.affinity.get("ayaka"), 45, "アヤカ親密度45")
	eq(GameState.hearts(45), 3, "45 → ♡3")
	eq(GameState.hearts(19), 1, "19 → ♡1")
	eq(GameState.hearts(20), 2, "20 → ♡2")
	eq(GameState.hearts(80), 5, "80 → ♡5")
	eq(GameState.hearts(100), 5, "100 → ♡5")
	st.location = "乗合馬車"
	eq(st.status_line(), "【冒険1日目・朝】【乗合馬車】【所持金 2金】【HP カズキ 30/30・アヤカ 20/20】", "状況欄")
	var d := st.to_dict()
	var st2 := GameState.new()
	st2.from_dict(JSON.parse_string(JSON.stringify(d)))
	eq(st2.money, st.money, "セーブ往復: 所持金")
	eq(st2.party["ayaka"]["mp"], 20, "セーブ往復: MP")
	eq(st2.inventory.get("herb"), 5, "セーブ往復: 所持品")
	ok(db.items.has("herb"), "items 読込")


## 本編ルートを出目固定で通し、終了時の状態を確かめる。
func test_canon_route() -> void:
	print("# 本編ルート")
	var m := _make()
	var db: GameDB = m[0]
	var st: GameState = m[1]
	var eng := StoryEngine.new(db, st)
	eng.start_new_game()
	var route := [
		"ドワーフの商人に、言いかけた話の続き",
		"続ける",                        # ゴルムの話が終わって城門前へ
		"ゴルムの木箱を一緒に運ぶ",
		"木箱を運び続ける",            # 力判定: 成功
		"とっさに、子どもの袖へ",      # 器用判定: 失敗（出目固定で失敗させる）
		"アヤカに、風魔法で",           # 成功
		"子どもを逃がす",
		"続ける",                        # ルゥが去って、衛兵バルドの場面へ
		"事情を正直に説明し",           # 運判定: 成功
		"続ける",                        # バルドとの話が終わって昼のゴルム店へ
		"どちらにするか、アヤカに意見",
		"続ける",                        # アヤカの答えのあと、ふたたび手間賃の選択へ
		"手間賃として、空の硝子瓶5本",
		"続ける",                        # ゴルム店を出て ch1_end へ
	]
	var rolls := {"木箱を運び続ける": 9, "とっさに、子どもの袖へ": 3, "アヤカに、風魔法で": 8, "事情を正直に説明し": 9}
	for prefix in route:
		var idx := -1
		for i in eng.shown_choices.size():
			if str(eng.shown_choices[i]["text"]).begins_with(prefix):
				idx = i
		ok(idx >= 0, "選択肢が見つかる: " + prefix + "（シーン %s）" % st.current_scene)
		if idx < 0:
			return
		eng.forced_roll = rolls.get(prefix, -1)
		eng.choose(idx)
	eng.forced_roll = -1
	eq(st.current_scene, "ch1_end", "硝子瓶店の選択のあと ch1_end に着く")
	ok(eng.is_end(), "終端シーン")
	eq(st.money, 200, "所持金は変わらない")
	eq(st.item_count("empty_bottle"), 5, "空の硝子瓶5本")
	eq(st.party["ayaka"]["mp"], 17, "アヤカ MP 20→17")
	eq(st.affinity["ayaka"], 46, "アヤカ親密度 +1")
	eq(st.affinity["ruu"], 3, "ルゥと出会っている")
	eq(st.flags.get("ruu_released"), true, "ruu_released")
	eq([st.day, st.slot], [1, "昼"], "1日目・昼")
	eq(st.flags.get("ruu_sleeve"), false, "器用判定は失敗")


func test_menu_text() -> void:
	print("# メニュー表示")
	var m := _make()
	var db: GameDB = m[0]
	var st: GameState = m[1]
	ok(MenuText.status(st).contains("カズキ"), "ステータスにカズキ")
	ok(MenuText.items(st, db).contains("所持金：2金"), "持ち物に所持金")
	ok(MenuText.items(st, db).contains("干し肉 ×3"), "持ち物に干し肉")
	var a := MenuText.affinity(st, db)
	ok(a.contains("アヤカ") and a.contains("♡3"), "親密度にアヤカ♡3")
	ok(not a.contains("ルゥ"), "出会っていないヒロインは出さない")


## わざと壊したデータを検証にかけて、問題を拾えるか確かめる。
func test_validator_detects_errors() -> void:
	print("# 検証スクリプトの検出力")
	var db := GameDB.new()
	db.config = {"start_scene": "a", "start_money": "2金", "party": ["kazuki"], "start_items": {}}
	db.characters = {"kazuki": {"name": "カズキ", "color": "#ffffff", "hp": 30, "mp": 5, "stats": {"力": 6}}}
	db.items = {"herb": {"name": "薬草"}}
	db.scenes = {
		"a": {"id": "a", "text": ["本文"], "choices": [
			{"text": "存在しない遷移", "next": "zzz"},
			{"text": "未定義アイテム", "next": "b", "effects": [{"op": "add_item", "id": "ghost"}]},
			{"text": "条件式が壊れている", "next": "b", "condition": "money >= "},
			{"text": "判定に失敗側がない", "check": {"stat": "運", "difficulty": 9}, "next_success": "b"},
			{"text": "未知のop", "next": "b", "effects": [{"op": "explode"}]},
		]},
		"b": {"id": "b", "text": ["行き止まり"]},
		"orphan": {"id": "orphan", "text": ["どこからも来ない"], "end": true},
	}
	for f in db.scenes:
		db.scene_files[f] = "test.json"
	var r := DataValidator.validate(db)
	var all_errors := "\n".join(r["errors"])
	ok(all_errors.contains("'zzz'"), "存在しない next を検出")
	ok(all_errors.contains("ghost"), "未定義アイテムIDを検出")
	ok(all_errors.contains("構文エラー"), "条件式の構文エラーを検出")
	ok(all_errors.contains("next_failure"), "判定の失敗側の欠落を検出")
	ok(all_errors.contains("explode"), "未知の op を検出")
	ok(all_errors.contains("行き止まり"), "行き止まりを検出")
	ok("\n".join(r["warnings"]).contains("orphan"), "到達できないシーンを警告")
	var good := GameDB.new()
	good.load_all()
	eq(DataValidator.validate(good)["errors"].size(), 0, "実データはエラー0件")


## ランダムに選び続けて、行き止まり・エラーなく終端へ着くか。選択肢×結果の網羅率も出す。
func test_random_playthrough() -> void:
	print("# ランダムプレイ")
	var db := GameDB.new()
	db.load_all()
	var covered := {}      # "scene#idx#outcome" -> true
	var scenes_seen := {}
	var ended := 0
	var runs := 3000
	var max_steps := 0
	for run in runs:
		var st := GameState.new()
		st.rng.seed = 1000 + run
		var eng := StoryEngine.new(db, st)
		eng.start_new_game()
		var steps := 0
		while not eng.is_end() and steps < 300:
			scenes_seen[st.current_scene] = true
			var n := eng.shown_choices.size()
			if n == 0:
				ok(false, "行き止まり: " + st.current_scene)
				break
			var pick := st.rng.randi_range(0, n - 1)
			var ch: Dictionary = eng.shown_choices[pick]
			var raw := StoryEngine.raw_choices(eng.scene).find(ch)
			var before := st.current_scene
			eng.choose(pick)
			var outcome := "-"
			if ch.has("check"):
				outcome = "failure" if eng.last_check["outcome"] == "failure" else "success"
			covered["%s#%d#%s" % [before, raw, outcome]] = true
			steps += 1
		max_steps = maxi(max_steps, steps)
		if eng.is_end():
			scenes_seen[st.current_scene] = true
			ended += 1
	eq(ended, runs, "ランダムプレイ %d 回すべてが終端へ到達（最大 %d 手）" % [runs, max_steps])
	eq(scenes_seen.size(), db.scenes.size(), "全シーンを通った（%d/%d）" % [scenes_seen.size(), db.scenes.size()])
	# 選択肢×判定結果（成功側／失敗側）をすべて一度は通ったか
	var missing: Array[String] = []
	for id in db.scenes:
		var cs := StoryEngine.raw_choices(db.scenes[id])
		for i in cs.size():
			var outcomes: Array = ["success", "failure"] if cs[i].has("check") else ["-"]
			for o in outcomes:
				if not covered.has("%s#%d#%s" % [id, i, o]):
					missing.append("%s 選択肢%d %s" % [id, i + 1, o])
	eq(missing, [], "すべての選択肢・判定結果を一度は通った")
