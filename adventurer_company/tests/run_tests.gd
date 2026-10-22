extends SceneTree
## ヘッドレスで実行するテスト。
##   godot --headless --path . --import                         # 初回のみ（クラス名キャッシュの生成）
##   godot --headless --path . --script res://tests/run_tests.gd

var _checks := 0
var _failures := 0
var _current := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test("データの読み込み", _test_data_loads)
	_test("確率の合計が1になる", _test_probability_sums)
	_test("段階の境界値", _test_outcome_boundaries)
	_test("補正の計算（腕前・人数・職業一致・先読み）", _test_modifiers)
	_test("鉄壁：確率と実判定", _test_iron_wall)
	_test("強運：確率と実判定", _test_lucky)
	_test("研究熱心：確率と実判定", _test_research)
	_test("表示の確率と実判定が一致する", _test_preview_matches_actual)
	_test("派遣のエラー", _test_dispatch_errors)
	_test("給料日の支払い", _test_payday_paid)
	_test("給料日に払えなければ倒産", _test_payday_bankrupt)
	_test("12週でクリア・未完了は報酬なし", _test_clear_and_unfinished)
	_test("軽傷：休養と医療費", _test_light_injury)
	_test("大失敗：重傷と医療費", _test_heavy_injury)
	_test("掲示板：出現・評判不足・期限切れ", _test_board)
	_test("常設依頼：何度でも受けられる", _test_repeatable)
	_test("常設依頼：評判の上限", _test_reputation_cap)
	_test("契約：月の最初の週だけ見直せる", _test_contract_change)
	_test("契約：歩合の取り分と会社の手取り", _test_commission_split)
	_test("契約：歩合の不満と退職", _test_discontent)
	_test("週ごとの進行フック", _test_hook)
	_test("シードで再現できる", _test_reproducible)
	print("- UI：派遣から結果画面まで")
	_current = "UI"
	await _test_ui_flow()
	print("- UI：ポートレートのドラッグ＆ドロップ（実際のマウス操作）")
	_current = "UIドラッグ"
	await _test_ui_drag()
	print("")
	if _failures == 0:
		print("OK: %d checks passed" % _checks)
	else:
		printerr("NG: %d / %d checks failed" % [_failures, _checks])
	quit(1 if _failures > 0 else 0)


func _test(title: String, f: Callable) -> void:
	_current = title
	print("- ", title)
	f.call()


func _check(cond: bool, message: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("  FAIL [%s]: %s" % [_current, message])


func _eq(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s（期待: %s / 実際: %s）" % [message, expected, actual])


# ---- 補助 ----

func _data() -> GameData:
	var data := GameData.load_from("res://data")
	_check(data.is_valid(), "data/*.json の読み込み: %s" % [data.errors])
	return data


func _defs(data: GameData, ids: Array) -> Array[AdventurerDef]:
	var list: Array[AdventurerDef] = []
	for i: Variant in ids:
		list.append(data.adventurer_def(str(i)))
	return list


func _ids(ids: Array) -> Array[String]:
	var list: Array[String] = []
	for i: Variant in ids:
		list.append(str(i))
	return list


func _quest_def(data: GameData, quest_id: String) -> QuestDef:
	for q: QuestDef in data.quests:
		if q.id == quest_id:
			return q
	return null


## d20 を d1 にして、出目を常に 1 にする（結果を狙って出すため）
func _fixed_die_controller(seed_value: int = 1) -> GameController:
	var data := _data()
	data.config.dice_sides = 1
	return GameController.new(data, seed_value)


func _all_parties(data: GameData) -> Array:
	var parties := []
	var n := data.adventurers.size()
	for mask in range(1, 1 << n):
		var party: Array[AdventurerDef] = []
		for i in n:
			if mask & (1 << i):
				party.append(data.adventurers[i])
		if party.size() <= data.config.party_max:
			parties.append(party)
	return parties


# ---- テスト ----

func _test_data_loads() -> void:
	var data := _data()
	_eq(data.adventurers.size(), 5, "冒険者は5人")
	var normal := 0
	var standing := 0
	for q: QuestDef in data.quests:
		if q.repeatable:
			standing += 1
		else:
			normal += 1
	_eq(normal, 10, "通常の依頼は10件")
	_eq(standing, 1, "常設依頼は1件")
	_eq(data.config.jobs.size(), 3, "職業は3種")
	for a: AdventurerDef in data.adventurers:
		_eq(a.employment_type, "regular", "%s の雇用形態" % a.name)
	for q: QuestDef in data.quests:
		_check(q.description.split("\n").size() >= 2, "%s に依頼文が2行以上ある" % q.name)
	var c := GameController.new(data, 1)
	_eq(c.gold, 300, "初期所持金")
	_eq(c.reputation, 10, "初期評判")
	var salary_total := 0
	for a: AdventurerDef in data.adventurers:
		salary_total += a.salary
	_eq(c.payroll(), salary_total, "月給の合計")


func _test_probability_sums() -> void:
	var data := _data()
	var config := data.config
	var parties := _all_parties(data)
	_eq(parties.size(), 25, "1〜3人のパーティの数")
	var tables := 0
	for q: QuestDef in data.quests:
		for party: Array[AdventurerDef] in parties:
			for tier in config.supply_tier_count():
				var mods := CheckRules.build_modifiers(party, q, tier, config)
				var table := CheckRules.probabilities(mods, config)
				var expected_total := 1
				for i in mods.dice_count:
					expected_total *= config.dice_sides
				var sum_counts := 0
				var sum_rates := 0.0
				for o: OutcomeDef in config.outcomes:
					sum_counts += table.count(o.id)
					sum_rates += table.rate(o.id)
				_check(table.total == expected_total, "数え上げの総数 %d" % table.total)
				_check(sum_counts == table.total, "件数の合計が総数に一致")
				_check(absf(sum_rates - 1.0) < 1e-9, "確率の合計が1（%f）" % sum_rates)
				tables += 1
	_eq(tables, data.quests.size() * 25 * config.supply_tier_count(), "確かめた確率表の数")


func _test_outcome_boundaries() -> void:
	var data := _data()
	var config := data.config
	var cases := {
		100: "great_success", 8: "great_success", 7: "success", 3: "success",
		2: "narrow_success", 0: "narrow_success", -1: "failure", -5: "failure",
		-6: "great_failure", -100: "great_failure",
	}
	for diff: int in cases:
		_eq(config.outcome_for_diff(diff).id, cases[diff], "差 %+d の段階" % diff)
	# 実際の判定関数を通しても同じ境界になる（トム単独・補正0・難易度10）
	var q := QuestDef.new()
	q.difficulty = 10
	q.job = "mage"
	var mods := CheckRules.build_modifiers(_defs(data, ["tom"]), q, 0, config)
	_eq(mods.total_bonus(), 0, "トム単独・職業不一致の補正")
	var by_die := {18: "great_success", 17: "success", 13: "success", 12: "narrow_success",
		10: "narrow_success", 9: "failure", 5: "failure", 4: "great_failure", 1: "great_failure"}
	for die: int in by_die:
		var r := CheckRules.evaluate([die] as Array[int], mods, config)
		_eq(r.outcome.id, by_die[die], "出目 %d（差 %+d）" % [die, r.diff])
	var table := CheckRules.probabilities(mods, config)
	_eq(table.count("great_success"), 3, "大成功の目（18〜20）")
	_eq(table.count("success"), 5, "成功の目（13〜17）")
	_eq(table.count("narrow_success"), 3, "辛勝の目（10〜12）")
	_eq(table.count("failure"), 5, "失敗の目（5〜9）")
	_eq(table.count("great_failure"), 4, "大失敗の目（1〜4）")
	_eq(table.success_count(), 11, "成功率の目（10〜20）")


func _test_modifiers() -> void:
	var data := _data()
	var config := data.config
	var q01 := _quest_def(data, "q01")  # 戦士・難易度10
	var mods := CheckRules.build_modifiers(_defs(data, ["gald", "tom", "lina"]), q01, 0, config)
	# 腕前2（ガルド） + 追加2人×2 + 職業一致3 + 先読み2
	_eq(mods.total_bonus(), 11, "ガルド・トム・リーナで戦士クエスト")
	var mods2 := CheckRules.build_modifiers(_defs(data, ["gald", "tom"]), q01, 0, config)
	_eq(mods2.total_bonus(), 2 + 2 + 3, "戦士2人でも職業一致は1回だけ")
	var mods3 := CheckRules.build_modifiers(_defs(data, ["lina"]), q01, 2, config)
	# 腕前1 + 支度金60G で +2 + 先読み2
	_eq(mods3.total_bonus(), 5, "リーナ単独・支度金60G")
	_eq(mods3.outcome_floor, "", "鉄壁なし")
	_eq(mods3.dice_count, 1, "強運なし")


func _test_iron_wall() -> void:
	var data := _data()
	var config := data.config
	var hard := QuestDef.new()
	hard.difficulty = 40
	hard.job = "mage"
	var with_gald := CheckRules.build_modifiers(_defs(data, ["gald", "tom"]), hard, 0, config)
	var without := CheckRules.build_modifiers(_defs(data, ["tom"]), hard, 0, config)
	_eq(with_gald.outcome_floor, "failure", "鉄壁で下限が失敗になる")
	var t1 := CheckRules.probabilities(with_gald, config)
	var t2 := CheckRules.probabilities(without, config)
	_eq(t1.count("great_failure"), 0, "鉄壁ありなら大失敗の確率は0")
	_eq(t1.count("failure"), 20, "鉄壁ありなら全部失敗止まり")
	_eq(t2.count("great_failure"), 20, "鉄壁なしなら全部大失敗")
	var r := CheckRules.evaluate([1] as Array[int], with_gald, config)
	_eq(r.raw_outcome.id, "great_failure", "差だけなら大失敗")
	_eq(r.outcome.id, "failure", "鉄壁で失敗止まり")
	_check(r.floored, "鉄壁が効いた印")

	# 実際のゲーム進行でも大失敗にならず、重傷も出ない
	for seed_value in range(1, 21):
		var c := GameController.new(_data(), seed_value)
		c.quest("q01").def.difficulty = 40
		_eq(c.dispatch(c.quest("q01"), _ids(["gald"]), 0), "", "ガルドを派遣")
		var report := c.end_week()
		_eq(report.entries[0].check.outcome.id, "failure", "鉄壁の実判定（seed %d）" % seed_value)
		_eq(report.injuries.size(), 0, "鉄壁なら重傷なし")
	var c2 := GameController.new(_data(), 1)
	c2.quest("q01").def.difficulty = 40
	c2.dispatch(c2.quest("q01"), _ids(["tom"]), 0)
	var report2 := c2.end_week()
	_eq(report2.entries[0].check.outcome.id, "great_failure", "鉄壁なしの実判定は大失敗")
	_eq(report2.injuries.size(), 1, "大失敗で重傷1人")


func _test_lucky() -> void:
	var data := _data()
	var config := data.config
	var q02 := _quest_def(data, "q02")  # 斥候・難易度8
	var q := QuestDef.new()
	q.difficulty = 10
	q.job = "scout"
	var mods := CheckRules.build_modifiers(_defs(data, ["mira"]), q, 0, config)
	_eq(mods.dice_count, 2, "強運で2回振る")
	_eq(mods.total_bonus(), 4, "腕前1 + 職業一致3")
	var table := CheckRules.probabilities(mods, config)
	_eq(table.total, 400, "強運は400通り")
	# 成功 = 判定値10以上 = 高い方の目が6以上 → 1 − (5/20)^2 = 375/400
	_eq(table.success_count(), 375, "強運ありの成功の件数")
	# 高い方の目の分布 (2k−1)/400 から各段階を数えて照合
	var expected := {}
	for o: OutcomeDef in config.outcomes:
		expected[o.id] = 0
	for k in range(1, 21):
		expected[config.outcome_for_diff(k + 4 - 10).id] += 2 * k - 1
	for o: OutcomeDef in config.outcomes:
		_eq(table.count(o.id), expected[o.id], "強運の %s の件数" % o.name)
	var no_luck := CheckRules.probabilities(CheckRules.build_modifiers(_defs(data, ["lina"]), q, 0, config), config)
	_check(table.success_rate() > no_luck.success_rate() - 0.1, "強運で成功率が大きく下がらない")
	var r := CheckRules.evaluate([3, 17] as Array[int], mods, config)
	_eq(r.used_die, 17, "高い方の目を使う")
	_eq(r.total, 21, "17 + 4")

	# 実判定：同じシードの乱数で2回振った目の高い方が使われる
	for seed_value in range(1, 21):
		var c := GameController.new(_data(), seed_value)
		c.dispatch(c.quest("q02"), _ids(["mira"]), 0)
		var report := c.end_week()
		var check := report.entries[0].check
		var rng := GameRng.new(seed_value)
		var d1 := rng.roll(20)
		var d2 := rng.roll(20)
		_eq(check.dice, [d1, d2] as Array[int], "実判定で2回振る（seed %d）" % seed_value)
		_eq(check.used_die, maxi(d1, d2), "実判定で高い方を使う")
		_eq(check.outcome.id, config.outcome_for_diff(maxi(d1, d2) + 4 - q02.difficulty).id, "実判定の段階")


func _test_research() -> void:
	var data := _data()
	var config := data.config
	var q03 := _quest_def(data, "q03")  # 魔術師
	var tier0 := CheckRules.build_modifiers(_defs(data, ["oswald"]), q03, 0, config)
	var tier1 := CheckRules.build_modifiers(_defs(data, ["oswald"]), q03, 1, config)
	var tier3 := CheckRules.build_modifiers(_defs(data, ["oswald"]), q03, 3, config)
	var tom1 := CheckRules.build_modifiers(_defs(data, ["tom"]), q03, 1, config)
	_eq(tier0.total_bonus(), 3 + 3, "支度金0Gなら研究熱心は効かない")
	_eq(tier1.total_bonus(), 3 + 3 + 1 + 1, "支度金30Gで +1、研究熱心で +1")
	_eq(tier3.total_bonus(), 3 + 3 + 3 + 1, "支度金100Gで +3、研究熱心で +1")
	_eq(tom1.total_bonus(), 0 + 1, "研究熱心なしなら支度金の分だけ")
	var p0 := CheckRules.probabilities(tier0, config)
	var p1 := CheckRules.probabilities(tier1, config)
	# 差 ≥ 0 ⇔ 出目 ≥ 難易度 − 補正
	_eq(p0.success_count(), 20 - (q03.difficulty - 6) + 1, "研究熱心なしの成功の件数")
	_eq(p1.success_count(), 20 - (q03.difficulty - 8) + 1, "研究熱心ありの成功の件数")

	# 実判定の補正にも入る
	var c := GameController.new(_data(), 3)
	_eq(c.dispatch(c.quest("q03"), _ids(["oswald"]), 1), "", "オズワルドを支度金30Gで派遣")
	_eq(c.gold, 270, "支度金を払う")
	var report := c.end_week()
	var check := report.entries[0].check
	_eq(check.bonus, 8, "実判定の補正に研究熱心が入る")
	_eq(check.total, check.used_die + 8, "判定値 = 出目 + 補正")


func _test_preview_matches_actual() -> void:
	# 派遣画面と同じ preview_modifiers の補正が、実判定でもそのまま使われる
	for seed_value in range(1, 41):
		var c := GameController.new(_data(), seed_value)
		var party := _ids(["gald", "lina", "mira"]) if seed_value % 2 == 0 else _ids(["oswald", "tom"])
		var tier := seed_value % 4
		var q := c.quest("q01")
		var preview := c.preview_modifiers(q, party, tier)
		c.dispatch(q, party, tier)
		var check := c.end_week().entries[0].check
		_eq(check.modifiers.key(), preview.key(), "表示と実判定の補正が同じ（seed %d）" % seed_value)
		_eq(check.modifiers.items, preview.items, "補正の内訳が同じ")
		var again := CheckRules.evaluate(check.dice, preview, c.config)
		_eq(again.outcome.id, check.outcome.id, "同じ目なら表示側の補正でも同じ結果")

	# 大量に振った頻度が厳密な確率に近い（強運・鉄壁入り）
	var data := _data()
	var q := QuestDef.new()
	q.difficulty = 16
	q.job = "warrior"
	var mods := CheckRules.build_modifiers(_defs(data, ["gald", "mira"]), q, 1, data.config)
	var table := CheckRules.probabilities(mods, data.config)
	var rng := GameRng.new(12345)
	var freq := {}
	var n := 40000
	for i in n:
		var id := CheckRules.resolve(mods, data.config, rng).outcome.id
		freq[id] = int(freq.get(id, 0)) + 1
	for o: OutcomeDef in data.config.outcomes:
		var observed := float(freq.get(o.id, 0)) / n
		_check(absf(observed - table.rate(o.id)) < 0.01, "%s の頻度 %.4f と確率 %.4f" % [o.name, observed, table.rate(o.id)])


func _test_dispatch_errors() -> void:
	var c := GameController.new(_data(), 1)
	var q01 := c.quest("q01")
	_check(c.dispatch_error(q01, _ids([]), 0) != "", "0人は派遣できない")
	_check(c.dispatch_error(q01, _ids(["gald", "tom", "lina", "mira"]), 0) != "", "4人は派遣できない")
	_check(c.dispatch_error(q01, _ids(["gald", "gald"]), 0) != "", "同じ人を2回は選べない")
	_check(c.dispatch_error(c.quest("q04"), _ids(["gald"]), 0) != "", "まだ掲示されていないクエスト")
	c.gold = 50
	_check(c.dispatch_error(q01, _ids(["gald"]), 2) != "", "支度金が所持金を超える")
	_eq(c.dispatch(q01, _ids(["gald"]), 1), "", "所持金内の支度金なら派遣できる")
	_eq(c.gold, 20, "支度金を引く")
	_check(c.dispatch_error(c.quest("q02"), _ids(["gald"]), 0) != "", "派遣中の冒険者は選べない")
	_check(c.dispatch_error(q01, _ids(["tom"]), 0) != "", "受注済みのクエストには派遣できない")
	_eq(c.adventurer("gald").status(), AdventurerState.Status.ON_MISSION, "派遣中")


func _advance_weeks(c: GameController, weeks: int) -> void:
	for i in weeks:
		c.end_week()
		for case: InjuryCase in c.pending_injuries():
			c.decide_injury(case, false)
		c.finish_week()


func _test_payday_paid() -> void:
	var c := GameController.new(_data(), 1)
	_eq(c.weeks_until_payday(), 3, "第1週は給料日まであと3週")
	_advance_weeks(c, 3)
	_eq(c.week, 4, "第4週")
	_eq(c.weeks_until_payday(), 0, "第4週は今週末が給料日")
	_eq(c.month(), 1, "第4週は1月目")
	c.gold = c.payroll()
	c.end_week()
	var report := c.finish_week()
	_check(report.payday, "給料日")
	_check(report.paid, "払えた")
	_eq(report.payroll, c.payroll(), "支払額")
	_eq(c.gold, 0, "ちょうど払い切って0G")
	_eq(c.phase, GameController.Phase.PLANNING, "続行")
	_eq(c.week, 5, "第5週へ")
	_eq(c.month(), 2, "第5週は2月目")


func _test_payday_bankrupt() -> void:
	var c := GameController.new(_data(), 1)
	_advance_weeks(c, 3)
	c.gold = c.payroll() - 1
	c.end_week()
	var report := c.finish_week()
	_check(report.payday and not report.paid, "払えない")
	_eq(c.phase, GameController.Phase.GAME_OVER, "倒産")
	_eq(c.bankrupt_week, 4, "倒産した週")
	_eq(c.gold, c.payroll() - 1, "払えないときは引かない")
	_check(c.is_over(), "ゲーム終了")

	# 給料日でない週は所持金が少なくても倒産しない
	var c2 := GameController.new(_data(), 1)
	c2.gold = 0
	c2.end_week()
	c2.finish_week()
	_eq(c2.phase, GameController.Phase.PLANNING, "給料日以外は倒産しない")


func _test_clear_and_unfinished() -> void:
	var c := GameController.new(_data(), 1)
	c.gold = 10000
	_advance_weeks(c, 11)
	_eq(c.week, 12, "第12週")
	# 第12週に2週かかるクエストを受けても終わらない
	var q := c.quest("q10")
	c.reputation = 50
	q.status = QuestState.Status.POSTED
	_eq(c.dispatch(q, _ids(["gald"]), 0), "", "第12週に派遣")
	var gold_before := c.gold
	var report := c.end_week()
	_eq(report.entries.size(), 0, "完了なし")
	c.finish_week()
	_eq(c.phase, GameController.Phase.CLEARED, "12週目の給料日を払えばクリア")
	_eq(report.unfinished_quests, ["ワイバーンの巣の排除"] as Array[String], "未完了のクエスト")
	_eq(q.status, QuestState.Status.UNFINISHED, "未完了扱い")
	_eq(c.gold, gold_before - c.payroll(), "未完了は報酬なし（給料だけ引かれる）")
	_eq(c.adventurer("gald").status(), AdventurerState.Status.IDLE, "未完了でも冒険者は戻る")


func _test_light_injury() -> void:
	# 出目は常に1。トム単独で q01（戦士）：判定値 1 + 3 = 4。難易度を4にして差0 → 辛勝
	for pay in [false, true]:
		var c := _fixed_die_controller()
		c.quest("q01").def.difficulty = 4
		c.dispatch(c.quest("q01"), _ids(["tom"]), 0)
		var report := c.end_week()
		_eq(report.entries[0].check.outcome.id, "narrow_success", "辛勝")
		_eq(report.entries[0].reward, 64, "報酬80Gの80%")
		_eq(report.entries[0].reputation_delta, 1, "評判 +1")
		_eq(report.injuries.size(), 1, "軽傷1人")
		var case := report.injuries[0]
		_eq(case.injury, "light", "軽傷")
		_eq(case.adventurer_id, "tom", "負傷者はパーティの中から")
		_eq(c.adventurer("tom").rest_weeks, 1, "休養1週")
		_eq(c.pending_injuries().size(), 1, "医療費の選択待ち")
		_eq(c.decide_injury(case, pay), "", "医療費の選択")
		c.finish_week()
		_eq(c.week, 2, "第2週")
		if pay:
			_eq(c.gold, 300 + 64 - 30, "医療費30Gを払う")
			_eq(c.reputation, 10 + 1 + 2, "医療費で評判 +2")
			_eq(c.adventurer("tom").status(), AdventurerState.Status.IDLE, "医療費を払えば次の週から派遣できる")
		else:
			_eq(c.gold, 300 + 64, "医療費なし")
			_eq(c.reputation, 10 + 1, "評判は辛勝の +1 だけ")
			_eq(c.adventurer("tom").status(), AdventurerState.Status.RESTING, "次の週は休養中")
			_check(c.dispatch_error(c.quest("q02"), _ids(["tom"]), 0) != "", "休養中は派遣できない")
			_advance_weeks(c, 1)
			_eq(c.adventurer("tom").status(), AdventurerState.Status.IDLE, "その次の週から派遣できる")

	# 所持金が医療費に足りなければ払えない
	var c2 := _fixed_die_controller()
	c2.quest("q01").def.difficulty = 4
	c2.dispatch(c2.quest("q01"), _ids(["tom"]), 0)
	c2.end_week()
	c2.gold = 29
	_check(not c2.can_pay_medical(), "29Gでは医療費を払えない")
	_check(c2.decide_injury(c2.report.injuries[0], true) != "", "払えないとエラー")
	_eq(c2.gold, 29, "所持金は変わらない")


func _test_heavy_injury() -> void:
	# 出目1、トム単独で q02（斥候・難易度8）：判定値1、差 −7 → 大失敗
	var c := _fixed_die_controller()
	c.dispatch(c.quest("q02"), _ids(["tom"]), 0)
	var report := c.end_week()
	_eq(report.entries[0].check.outcome.id, "great_failure", "大失敗")
	_eq(report.entries[0].reward, 0, "報酬なし")
	_eq(report.entries[0].reputation_delta, -3, "評判 −3")
	_eq(report.injuries[0].injury, "heavy", "重傷")
	_eq(c.adventurer("tom").rest_weeks, 2, "休養2週")
	c.decide_injury(report.injuries[0], true)
	_eq(c.adventurer("tom").rest_weeks, 1, "医療費で休養 −1週")
	_eq(c.reputation, 10 - 3 + 2, "評判 −3 + 2")
	c.finish_week()
	_eq(c.adventurer("tom").status(), AdventurerState.Status.RESTING, "第2週は休養中")
	_advance_weeks(c, 1)
	_eq(c.adventurer("tom").status(), AdventurerState.Status.IDLE, "第3週から派遣できる")

	# 評判は0未満にならない
	var c2 := _fixed_die_controller()
	c2.reputation = 1
	c2.dispatch(c2.quest("q02"), _ids(["tom"]), 0)
	var r2 := c2.end_week()
	_eq(c2.reputation, 0, "評判の下限0")
	_eq(r2.entries[0].reputation_delta, -1, "実際に変わった分だけ記録する")


func _test_board() -> void:
	var c := GameController.new(_data(), 1)
	var names := []
	for q: QuestState in c.board_quests():
		names.append(q.def.id)
	_eq(names, ["q01", "q02", "q03", "s01"], "第1週の掲示板（常設依頼を含む）")
	c.dispatch(c.quest("q01"), _ids(["gald"]), 0)
	_check(c.board_quests().has(c.quest("q01")), "受注中の紙も掲示板に残る")
	_advance_weeks(c, 1)
	_check(c.quest("q04").status == QuestState.Status.POSTED, "第2週に q04 が出る")
	_check(c.report.new_quests.has("峠越えの商隊護衛"), "新しい依頼の通知")
	_advance_weeks(c, 1)
	var q05 := c.quest("q05")
	_eq(q05.status, QuestState.Status.POSTED, "第3週に q05 が出る")
	c.reputation = 14
	_check(not c.is_unlocked(q05), "評判14では q05（必要15）を受けられない")
	_check(c.dispatch_error(q05, _ids(["lina"]), 0).contains("評判15"), "評判不足の理由")
	c.reputation = 15
	_check(c.is_unlocked(q05), "評判15で受けられる")
	_eq(c.quest("q02").status, QuestState.Status.POSTED, "第3週まで q02 は残る")
	_advance_weeks(c, 1)
	_eq(c.quest("q02").status, QuestState.Status.EXPIRED, "第4週に q02 は消える")
	_check(c.report.expired_quests.has("薬草採取の護衛"), "期限切れの通知")
	_eq(c.quest("q01").status, QuestState.Status.COMPLETED, "受けたクエストは完了")


func _test_repeatable() -> void:
	var c := GameController.new(_data(), 1)
	var s01 := c.quest("s01")
	_check(s01.def.repeatable, "s01 は常設依頼")
	_eq(s01.status, QuestState.Status.POSTED, "第1週から掲示")
	for week in range(1, 4):
		_eq(c.dispatch(s01, _ids(["gald"]), 0), "", "第%d週に受注できる" % week)
		_check(c.dispatch_error(s01, _ids(["tom"]), 0) != "", "受注中はもう1組は受けられない")
		var report := c.end_week()
		_eq(report.entries.size(), 1, "1週で完了")
		_eq(s01.status, QuestState.Status.POSTED, "完了すると掲示板に戻る")
		_eq(s01.times_completed, week, "完了回数")
		_eq(s01.party_ids.size(), 0, "パーティは解散")
		for case: InjuryCase in c.pending_injuries():
			c.decide_injury(case, true)
		c.finish_week()
		c.gold = 10000
		if c.adventurer("gald").rest_weeks > 0:
			c.adventurer("gald").rest_weeks = 0
	_advance_weeks(c, 8)
	_eq(c.week, 12, "第12週")
	_eq(s01.status, QuestState.Status.POSTED, "常設依頼は期限切れにならない")
	_eq(c.last_listed_week(s01), 12, "掲示は最終週まで")


func _test_reputation_cap() -> void:
	# 出目は常に1。ガルド単独で s01（戦士）：判定値 1 + 2 + 3 = 6。難易度を変えて結果を選ぶ
	var cases := [
		# [評判, 難易度, 期待する変化, 上限で削られたか]
		[10, 3, 2, false],   # 差 +3 成功 +2（上限15に届かない）
		[14, 3, 1, true],    # 成功 +2 だが 15 で止まる
		[15, 3, 0, true],    # 上限ちょうどなら上がらない
		[20, -2, 0, true],   # 上限より上でも下がりはしない（大成功 +3 → 0）
		[20, 7, -1, false],  # 失敗の −1 は上限に関係なく下がる
	]
	for row: Array in cases:
		var c := _fixed_die_controller()
		c.reputation = row[0]
		var s01 := c.quest("s01")
		s01.def.difficulty = row[1]
		c.dispatch(s01, _ids(["gald"]), 0)
		var entry := c.end_week().entries[0]
		_eq(entry.reputation_delta, row[2], "評判%d・%s の評判変化" % [row[0], entry.check.outcome.name])
		_eq(entry.reputation_capped, row[3], "評判%d・%s の上限の印" % [row[0], entry.check.outcome.name])
		_eq(c.reputation, row[0] + row[2], "評判%d・%s の評判" % [row[0], entry.check.outcome.name])
	# 上限のない通常の依頼は、評判が高くても上がる
	var c2 := _fixed_die_controller()
	c2.reputation = 40
	c2.quest("q01").def.difficulty = 3
	c2.dispatch(c2.quest("q01"), _ids(["gald"]), 0)
	_eq(c2.end_week().entries[0].reputation_delta, 2, "通常の依頼は上限なし")


func _test_contract_change() -> void:
	var c := GameController.new(_data(), 1)
	for a: AdventurerState in c.adventurers:
		_eq(a.employment_type, "regular", "%sは最初は専属" % a.def.name)
	var full := c.payroll()
	_check(c.is_contract_week(), "第1週は契約を見直せる")
	_eq(c.change_contract("gald", "commission"), "", "ガルドを歩合にする")
	_eq(c.payroll(), full - c.adventurer("gald").def.salary, "歩合の人の月給は払わない")
	_check(c.change_contract("gald", "freelance") != "", "ない雇用形態にはできない")
	c.dispatch(c.quest("q01"), _ids(["tom"]), 0)
	_check(c.change_contract("tom", "commission") != "", "派遣中の人は変えられない")
	_advance_weeks(c, 1)
	_check(not c.is_contract_week(), "第2週は見直せない")
	_check(c.change_contract("gald", "regular") != "", "第2週には変えられない")
	_advance_weeks(c, 3)
	_eq(c.week, 5, "第5週")
	_check(c.is_contract_week(), "第5週（2月目の最初）は見直せる")
	_eq(c.change_contract("gald", "regular"), "", "専属に戻す")
	_eq(c.payroll(), full, "月給がまた全員分になる")


func _test_commission_split() -> void:
	# 出目は常に1。ガルド（腕前2・戦士）・ミラ（腕前1）で q01（戦士）：判定値 1 + 2 + 2 + 3 = 8
	var c := _fixed_die_controller()
	c.change_contract("gald", "commission")
	c.quest("q01").def.difficulty = 5  # 差 +3 → 成功（報酬 80G）
	var party := _ids(["gald", "mira"])
	var expected := c.expected_company_income(c.quest("q01"), party, 0)
	_eq(expected, 80.0 - roundi(80 * 0.25), "期待値（出目が1通りなので確定）= 80 − 歩合20")
	c.dispatch(c.quest("q01"), party, 0)
	var entry := c.end_week().entries[0]
	_eq(entry.reward, 80, "報酬")
	_eq(entry.commissions.size(), 1, "歩合はガルドだけ（ミラは専属）")
	_eq(int(entry.commissions[0]["amount"]), 20, "ガルドの取り分 25%")
	_eq(entry.company_income, 60, "会社の手取り")
	_eq(c.gold, 300 + 60, "所持金は手取りだけ増える")
	_eq(c.adventurer("gald").earned_this_month, 20, "ガルドの今月の稼ぎ")

	# 失敗なら歩合も0
	var c2 := _fixed_die_controller()
	c2.change_contract("gald", "commission")
	c2.dispatch(c2.quest("q01"), _ids(["gald"]), 0)  # 判定値 6、難易度12 → 失敗
	var e2 := c2.end_week().entries[0]
	_eq(e2.reward, 0, "失敗")
	_eq(int(e2.commissions[0]["amount"]), 0, "失敗なら歩合も0")
	_eq(c2.adventurer("gald").earned_this_month, 0, "稼ぎなし")

	# 3人とも歩合なら、報酬から3人分が引かれる
	var c3 := _fixed_die_controller()
	for id: String in ["gald", "lina", "oswald"]:
		c3.change_contract(id, "commission")
	c3.quest("q01").def.difficulty = 0
	c3.dispatch(c3.quest("q01"), _ids(["gald", "lina", "oswald"]), 0)
	var e3 := c3.end_week().entries[0]
	var paid := 0
	for one: Dictionary in e3.commissions:
		paid += int(one["amount"])
	_eq(paid, roundi(e3.reward * 0.25) + roundi(e3.reward * 0.2) + roundi(e3.reward * 0.3), "3人分の歩合")
	_eq(e3.company_income, e3.reward - paid, "会社の手取り")


func _test_discontent() -> void:
	var c := GameController.new(_data(), 1)
	c.change_contract("tom", "commission")
	c.change_contract("lina", "commission")
	c.gold = 10000
	# 1か月、トムには仕事なし。リーナには月給の半分以上を稼がせる
	_advance_weeks(c, 3)
	c.adventurer("lina").earned_this_month = c.discontent_threshold(c.adventurer("lina"))
	c.end_week()
	var report := c.finish_week()
	_eq(report.discontented, ["トム"] as Array[String], "稼げなかったトムは不満")
	_eq(c.adventurer("tom").discontent, 1, "トムの不満1")
	_eq(c.adventurer("lina").discontent, 0, "稼いだリーナは不満なし")
	_eq(c.adventurer("tom").earned_this_month, 0, "稼ぎは月ごとにリセット")
	_check(not c.adventurer("tom").left, "1か月目ではまだ辞めない")

	# 2か月目も稼げなければ退職。派遣中のリーナは不満にならない
	_advance_weeks(c, 3)
	c.gold = 10000
	c.dispatch(c.quest("s01"), _ids(["lina"]), 0)
	c.quest("s01").weeks_left = 5
	c.end_week()
	var report2 := c.finish_week()
	_eq(report2.departed, ["トム"] as Array[String], "2か月続けて稼げないと退職")
	_check(c.adventurer("tom").left, "トムは退職")
	_eq(c.adventurer("tom").status(), AdventurerState.Status.LEFT, "状態は退職")
	_eq(c.adventurer("lina").discontent, 0, "派遣中は不満にならない")
	_check(not c.idle_adventurers().has(c.adventurer("tom")), "退職した人は待機中に出ない")
	_check(c.dispatch_error(c.quest("q07"), _ids(["tom"]), 0) != "", "退職した人は派遣できない")
	_check(c.change_contract("tom", "regular") != "", "退職した人の契約は変えられない")
	_eq(c.salary_for(c.adventurer("tom")), 0, "退職した人に月給は払わない")

	# 専属は稼ぎがなくても辞めない
	var c2 := GameController.new(_data(), 1)
	c2.gold = 10000
	_advance_weeks(c2, 8)
	for a: AdventurerState in c2.adventurers:
		_check(not a.left, "専属の%sは辞めない" % a.def.name)


func _test_hook() -> void:
	var c := GameController.new(_data(), 1)
	var calls: Array[String] = []
	c.mission_week_hooks.append(func(controller: GameController, q: QuestState, report: WeekReport) -> void:
		calls.append("%d:%s:%d" % [controller.week, q.def.id, q.weeks_left])
		report.events.append({"quest": q.def.id}))
	_advance_weeks(c, 1)
	c.dispatch(c.quest("q04"), _ids(["gald"]), 0)  # 2週
	_advance_weeks(c, 2)
	_eq(calls, ["2:q04:2", "3:q04:1"] as Array[String], "進行中の週ごとに、残り週を減らす前に呼ばれる")


func _play_scripted(seed_value: int) -> Array:
	var c := GameController.new(_data(), seed_value)
	var log := []
	c.dispatch(c.quest("q01"), _ids(["gald", "tom"]), 1)
	c.dispatch(c.quest("q02"), _ids(["mira"]), 0)
	c.dispatch(c.quest("q03"), _ids(["oswald", "lina"]), 0)
	for w in 12:
		var report := c.end_week()
		for e: QuestReportEntry in report.entries:
			log.append([e.quest_id, e.check.dice, e.check.outcome.id])
		for case: InjuryCase in c.pending_injuries():
			log.append(case.adventurer_id)
			c.decide_injury(case, c.can_pay_medical())
		c.finish_week()
		if c.is_over():
			break
	log.append(c.gold)
	return log


func _test_reproducible() -> void:
	_eq(_play_scripted(42), _play_scripted(42), "同じシードなら同じ展開")
	_check(_play_scripted(42) != _play_scripted(43) or _play_scripted(42) != _play_scripted(44), "シードが違えば展開が変わる")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _test_ui_flow() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(2)
	var c: GameController = main.controller
	_check(c != null, "メイン画面がゲームを作る")
	_check(main.top_bar.end_week_button.disabled == false, "週を終えるボタンが押せる")

	# 評判不足のクエストは詳細は見られるが派遣できない
	c.reputation = 0
	c.quest("q01").def.required_reputation = 5
	main.refresh()
	main._on_quest_selected("q01")
	_check(main.detail.dispatch_button.disabled, "評判不足なら派遣ボタンが押せない")
	_check(main.detail._status_label.text.contains("評判5で受注可"), "評判不足の理由を表示")
	c.quest("q01").def.required_reputation = 0
	c.reputation = 10
	main.refresh()
	_check(not main.detail.dispatch_button.disabled, "評判が足りれば派遣ボタンが押せる")

	# 派遣パネル：選ぶたびに、実判定と同じ計算の成功率を表示する
	main.detail.dispatch_button.pressed.emit()
	var panel: Control = main.dispatch_panel
	_check(panel.visible, "派遣パネルが開く")
	_check(panel.confirm_button.disabled, "誰も選んでいなければ派遣できない")
	var party: Array[String] = []
	for id: String in ["gald", "mira", "oswald"]:
		panel.set_adventurer(id, true)
		party.append(id)
		var expected := UiKit.percent(c.preview_probabilities(c.quest("q01"), party, 0).success_rate())
		_eq(panel.rate_label.text, expected, "%d人のときの成功率表示" % party.size())
	panel.set_adventurer("tom", true)
	_eq(panel.selected_ids.size(), 3, "4人目は選べない")
	panel.set_supply(2)
	_eq(panel.rate_label.text, UiKit.percent(c.preview_probabilities(c.quest("q01"), party, 2).success_rate()), "支度金を変えると更新")
	panel.set_adventurer("oswald", false)
	party.erase("oswald")
	_eq(panel.rate_label.text, UiKit.percent(c.preview_probabilities(c.quest("q01"), party, 2).success_rate()), "外すと更新")
	panel.confirm_button.pressed.emit()
	_check(not panel.visible, "派遣すると閉じる")
	_eq(c.quest("q01").status, QuestState.Status.IN_PROGRESS, "受注中になる")
	_eq(c.gold, 240, "支度金60Gを払った")
	main.dispatch_panel.open("s01")
	main.dispatch_panel.set_adventurer("gald", true)
	_eq(main.dispatch_panel.selected_ids.size(), 0, "派遣中の冒険者は選べない")
	main.dispatch_panel.set_adventurer("tom", true)
	_eq(main.dispatch_panel.selected_ids, ["tom"] as Array[String], "待機中の冒険者は選べる")
	main.dispatch_panel.cancel_button.pressed.emit()
	_eq(c.quest("s01").status, QuestState.Status.POSTED, "キャンセルなら派遣しない")

	# 週を終える → 結果レポート → （負傷）→ 次の週。最後まで進めて結果画面を出す
	var guard := 0
	while not main.result_screen.visible and guard < 100:
		guard += 1
		if main.report_dialog.visible:
			main.report_dialog.next_button.pressed.emit()
		elif main.injury_dialog.visible:
			main.injury_dialog.skip_button.pressed.emit()
		elif main.message_dialog.visible:
			main.message_dialog.ok_button.pressed.emit()
		else:
			c.gold = maxi(c.gold, 1000)
			main.top_bar.end_week_button.pressed.emit()
		await _frames(1)
	_check(main.result_screen.visible, "結果画面が出る")
	_eq(c.phase, GameController.Phase.CLEARED, "クリア")
	main.result_screen.restart_button.pressed.emit()
	await _frames(1)
	_eq(c.week, 1, "もう一度遊ぶと第1週から")
	_eq(c.gold, 300, "所持金も初期値")
	main.queue_free()
	await _frames(1)


var _last_mouse := Vector2.ZERO


func _mouse_motion(pos: Vector2, mask: int) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = pos - _last_mouse
	_last_mouse = pos
	ev.button_mask = mask
	root.push_input(ev)


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(ev)


## 実際のマウス操作で from から to へドラッグする
func _drag(from: Control, to: Control) -> void:
	var a := from.get_global_rect().get_center()
	var b := to.get_global_rect().get_center()
	_mouse_motion(a, 0)
	await _frames(1)
	_mouse_button(a, true)
	await _frames(1)
	_mouse_motion(a + Vector2(30, 0), MOUSE_BUTTON_MASK_LEFT)
	await _frames(1)
	_mouse_motion(b, MOUSE_BUTTON_MASK_LEFT)
	await _frames(1)
	_mouse_button(b, false)
	await _frames(2)


func _click(target: Control) -> void:
	var a := target.get_global_rect().get_center()
	_mouse_motion(a, 0)
	await _frames(1)
	_mouse_button(a, true)
	await _frames(1)
	_mouse_button(a, false)
	await _frames(2)


## node の下にある、冒険者 adventurer_id のポートレート
func _portrait_in(node: Node, adventurer_id: String) -> Control:
	for child in node.find_children("*", "Control", true, false):
		if child.get_script() == preload("res://scripts/ui/portrait.gd") and child.def != null and child.def.id == adventurer_id:
			return child
	return null


func _test_ui_drag() -> void:
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	var c: GameController = main.controller
	var panel: Control = main.dispatch_panel
	main._on_quest_selected("q01")
	main.detail.dispatch_button.pressed.emit()
	await _frames(2)

	# 一覧 → 2番目の枠
	await _drag(_portrait_in(panel._pool_box, "gald"), panel._slot_box.get_child(1))
	_eq(panel.slots, ["", "gald", ""] as Array[String], "ドラッグした枠に入る")
	_eq(panel.selected_ids, ["gald"] as Array[String], "パーティはガルド")
	_eq(panel.rate_label.text, UiKit.percent(c.preview_probabilities(c.quest("q01"), panel.selected_ids, 0).success_rate()), "ドロップで成功率が更新される")
	_check(not _portrait_in(panel._pool_box, "gald").draggable, "パーティにいる人は一覧からはドラッグできない")

	# クリックでも入れられる（空いている左の枠から）
	await _click(_portrait_in(panel._pool_box, "mira"))
	_eq(panel.slots, ["mira", "gald", ""] as Array[String], "クリックで空き枠に入る")

	# 枠どうしで入れ替え
	await _drag(_portrait_in(panel._slot_box, "gald"), panel._slot_box.get_child(0))
	_eq(panel.slots, ["gald", "mira", ""] as Array[String], "枠どうしのドラッグで入れ替わる")

	# 一覧から、人のいる枠へ → 前の人は外れる
	await _drag(_portrait_in(panel._pool_box, "tom"), panel._slot_box.get_child(1))
	_eq(panel.slots, ["gald", "tom", ""] as Array[String], "人のいる枠に置くと入れ替わりで外れる")

	# 枠から一覧へ戻す
	await _drag(_portrait_in(panel._slot_box, "tom"), panel._pool_box)
	_eq(panel.slots, ["gald", "", ""] as Array[String], "一覧へドラッグすると外れる")

	# 枠のポートレートをクリックしても外れる
	await _click(_portrait_in(panel._slot_box, "gald"))
	_eq(panel.selected_ids.size(), 0, "枠のクリックで外れる")
	_check(panel.confirm_button.disabled, "誰もいなければ派遣できない")

	# 派遣して、派遣中の人はドラッグできない
	await _drag(_portrait_in(panel._pool_box, "oswald"), panel._slot_box.get_child(0))
	panel.confirm_button.pressed.emit()
	await _frames(2)
	_eq(c.quest("q01").party_ids, ["oswald"] as Array[String], "ドラッグで選んだ人が派遣される")
	main._on_quest_selected("q03")
	main.detail.dispatch_button.pressed.emit()
	await _frames(2)
	_check(not _portrait_in(panel._pool_box, "oswald").draggable, "派遣中の人はドラッグできない")
	await _drag(_portrait_in(panel._pool_box, "oswald"), panel._slot_box.get_child(0))
	_eq(panel.selected_ids.size(), 0, "派遣中の人は枠に入らない")
	await _click(_portrait_in(panel._pool_box, "oswald"))
	_eq(panel.selected_ids.size(), 0, "派遣中の人はクリックしても入らない")
	panel.cancel_button.pressed.emit()
	await _frames(2)

	# 名簿のポートレートを掲示板の紙へ → その人が入った派遣パネルが開く
	var paper: Control = null
	for child in main.board._grid.get_children():
		if child.quest_id == "q02":
			paper = child
	await _drag(_portrait_in(main.roster, "lina"), paper)
	_check(panel.visible, "紙に落とすと派遣パネルが開く")
	_eq(panel.quest_id, "q02", "落とした紙の依頼")
	_eq(panel.selected_ids, ["lina"] as Array[String], "落とした人が入っている")
	_eq(main.selected_quest_id, "q02", "その依頼が選ばれる")
	panel.cancel_button.pressed.emit()
	await _frames(2)
	# 受注中の紙や、派遣中の人は落とせない
	for child in main.board._grid.get_children():
		if child.quest_id == "q01":
			paper = child
	await _drag(_portrait_in(main.roster, "lina"), paper)
	_check(not panel.visible, "受注中の依頼には落とせない")
	_check(not _portrait_in(main.roster, "oswald").draggable, "名簿でも派遣中の人はドラッグできない")
	main.queue_free()
	await _frames(1)
