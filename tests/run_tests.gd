extends SceneTree
## ヘッドレスで実行するテスト。
##   godot --headless --path . --script tests/run_tests.gd
## （初回は --import でクラス名キャッシュを作っておく）

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, message: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", message)


func _reset_session() -> void:
	# テストではファイルを読み書きせず、ノートは毎回まっさらにする
	GameSession.persist = false
	GameSession._loaded = true
	GameSession.reset_all()
	GameSession.adventurer_id = SampleData.CHILDHOOD


func _run() -> void:
	_reset_session()
	_test_parser()
	_test_note_entry()
	_test_judge()
	_test_state()
	await _test_ui_flow()
	await _test_real_drag()
	await _test_effects()
	await _test_slot_hover()
	_test_mercenary_data()
	await _test_start_screen()
	await _test_economy()
	await _test_mercenary_flow()
	_test_new_adventurers_data()
	await _test_doctor_and_noble_flow()
	_test_carry_over()
	await _test_carry_over_ui()
	_test_illustrations()
	await _test_illustrations_ui()
	_test_sfx_waveforms()
	await _test_sfx_events()
	Sfx.shutdown()
	await _frames(2)
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_parser() -> void:
	var segs := ReportParser.parse("あ[kw:x]赤い[/kw]い[kw:y]青[/kw]")
	_check(segs.size() == 4, "parser: 4 segments (got %d)" % segs.size())
	_check(segs[1]["kw"] == &"x" and segs[1]["text"] == "赤い", "parser: first keyword")
	_check(segs[3]["kw"] == &"y", "parser: second keyword")
	_check(ReportParser.total_chars(segs) == 1 + 2 + 1 + 1, "parser: total chars")
	var broken := ReportParser.parse("a[kw:x]b")
	_check(broken.size() == 2 and broken[1]["kw"] == &"", "parser: unterminated tag kept as text")


func _test_note_entry() -> void:
	var e := NoteEntry.new()
	e.body = "前{blank:b1}後"
	var segs := e.body_segments()
	_check(segs.size() == 3, "note: 3 segments")
	_check(segs[1]["blank"] == &"b1" and segs[0]["text"] == "前" and segs[2]["text"] == "後", "note: blank parsed")


func _test_judge() -> void:
	_check(Judge.modifier(true, &"explore", &"explore") == -8, "judge: matched+correct")
	_check(Judge.modifier(true, &"battle", &"explore") == 0, "judge: matched+wrong stat")
	_check(Judge.modifier(false, &"explore", &"explore") == 0, "judge: unmatched+correct")
	_check(Judge.modifier(false, &"battle", &"explore") == 4, "judge: unmatched+wrong")
	_check(Judge.modifier(false, &"", &"explore") == 2, "judge: no instruction")
	var r := Judge.resolve(12, -4, 4, 5)
	_check(r["target"] == 8 and r["total"] == 9 and r["success"], "judge: success by total")
	_check(not Judge.resolve(12, 0, 4, 1)["success"], "judge: natural 1 always fails")
	_check(Judge.resolve(12, 0, 4, 1)["crit_fail"], "judge: natural 1 is crit fail")
	_check(Judge.resolve(30, 0, 0, 20)["success"], "judge: natural 20 always succeeds")


func _new_state() -> MatchingState:
	return MatchingState.new(SampleData.adventurer(), SampleData.events(), SampleData.entries())


func _test_state() -> void:
	var s := _new_state()
	_check(s.begin_next_event(), "state: begin event")
	_check(s.drop(&"mushroom", &"mushroom_poison") == MatchingState.DropResult.MATCHED, "state: correct drop matches")
	_check(s.drop(&"mushroom", &"mushroom_poison") == MatchingState.DropResult.IGNORED, "state: second drop ignored")

	var s2 := _new_state()
	s2.begin_next_event()
	var before := s2.time_left
	_check(s2.drop(&"mushroom", &"glow_moss") == MatchingState.DropResult.MISMATCH, "state: wrong target mismatches")
	_check(is_equal_approx(s2.time_left, before - Rules.MISMATCH_PENALTY_SEC), "state: mismatch costs time")
	_check(not s2.matched, "state: mismatch does not match")

	# 虫食いはイベントをまたいで保持される
	var s3 := _new_state()
	s3.begin_next_event()
	s3.begin_next_event()
	_check(s3.current.id == &"e2_beast", "state: second event is the beast")
	_check(s3.drop(&"torch", &"beast_claw") == MatchingState.DropResult.MISMATCH, "state: blank owner entry itself is not the target")
	_check(s3.drop(&"torch", &"beast_aversion") == MatchingState.DropResult.MATCHED, "state: blank drop matches")
	_check(s3.is_blank_filled(&"beast_aversion"), "state: blank is filled")
	s3.begin_next_event()
	_check(s3.is_blank_filled(&"beast_aversion"), "state: blank stays filled in later events")

	# 2匹目の獣: 「火」を埋めていれば照合済みで始まる。埋めていなければ自分で照合する
	var s6 := _new_state()
	s6.begin_next_event(); s6.begin_next_event()
	s6.drop(&"torch", &"beast_aversion")
	s6.begin_next_event(); s6.begin_next_event()
	_check(s6.current.id == &"e4_beast_again", "state: fourth event is the second beast")
	_check(s6.matched and s6.auto_matched, "state: known note starts the fourth event as matched")
	_check(is_equal_approx(s6.time_left, 15.0), "state: second beast has a short time limit")
	_check(s6.drop(&"torch", &"beast_aversion") == MatchingState.DropResult.IGNORED, "state: no double matching")
	var s7 := _new_state()
	for i in 4:
		s7.begin_next_event()
	_check(not s7.matched and not s7.auto_matched, "state: without the note the fourth event is not pre-matched")
	_check(s7.drop(&"torch", &"beast_aversion") == MatchingState.DropResult.MATCHED, "state: the fourth event can still be matched by hand")

	# 食い違い: 訂正は記述が間違っている箇所にだけ入り、ずっと残る
	var s8 := _new_state()
	for i in 5:
		s8.begin_next_event()
	_check(s8.current.id == &"e5_moss" and s8.is_fix(&"moss_safe"), "state: fifth event targets a fix spot")
	_check(s8.drop(&"numb", &"glow_moss") == MatchingState.DropResult.MISMATCH, "state: the entry itself is not the fix spot")
	_check(s8.drop(&"numb", &"moss_safe") == MatchingState.DropResult.MATCHED, "state: the fix spot accepts the keyword")
	_check(s8.is_blank_filled(&"moss_safe"), "state: the correction is remembered")
	var seg_note := SampleData.entries()[1]
	var kinds := 0
	for seg in seg_note.body_segments():
		if seg["fix"] != &"":
			kinds += 1
	_check(kinds == 1, "note: the moss body has one fix spot")

	# 時間切れは一度だけ通知される
	var s4 := _new_state()
	s4.begin_next_event()
	_check(not s4.tick(1.0), "state: tick before timeout")
	_check(s4.tick(100.0), "state: tick reports timeout once")
	_check(not s4.tick(1.0), "state: timeout not re-reported")

	# 失敗で報酬が減る（乱数を固定せず、境界を判定で直接確認）
	var s5 := _new_state()
	s5.begin_next_event()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var res := s5.resolve(&"battle", rng)
	_check(res.has("success"), "state: resolve returns result")
	_check(s5.resolve(&"battle", rng).is_empty(), "state: cannot resolve twice")
	if not res["success"]:
		_check(s5.reward < Rules.INITIAL_REWARD, "state: failure reduces reward")
	else:
		_check(is_equal_approx(s5.reward, Rules.INITIAL_REWARD), "state: success keeps reward")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _test_ui_flow() -> void:
	_reset_session()
	var screen: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	_check(screen.state.event_index == 0, "ui: first event started")
	_check(screen._chips.size() == 1, "ui: one keyword chip")
	_check(not screen._chips[0].enabled, "ui: chip not grabbable before it is revealed")
	screen._reveal_all()
	await _frames(2)
	_check(screen._chips[0].enabled, "ui: chip grabbable after reveal")

	# 不一致 → 一致 → 判定
	var tl := screen.state.time_left
	screen._on_keyword_dropped(&"mushroom", &"glow_moss")
	_check(screen.state.time_left < tl, "ui: mismatch drop reduces time")
	screen._on_keyword_dropped(&"mushroom", &"mushroom_poison")
	_check(screen.state.matched, "ui: matched after correct drop")
	_check((screen._entry_views[&"mushroom_poison"] as NoteEntryView)._stamp.visible, "ui: stamp shown")
	screen._on_stat_chosen(&"evade")
	await create_timer(1.0).timeout
	_check(screen._phase == MatchingScreen.Phase.RESULT, "ui: reached result phase")
	_check(screen._next_button.visible, "ui: next button visible")
	_check(screen._dice_label.text.begins_with("判定:"), "ui: dice result text (%s)" % screen._dice_label.text)

	# 2つ目: 虫食い
	screen._start_next_event()
	await _frames(2)
	screen._reveal_all()
	await _frames(2)
	screen._on_keyword_dropped(&"torch", &"beast_aversion")
	var slot: BlankSlot = (screen._entry_views[&"beast_claw"] as NoteEntryView).slots[&"beast_aversion"]
	_check(slot.filled and slot._label.text == "火", "ui: blank filled with the stamp text")
	screen._on_stat_chosen(&"battle")
	await create_timer(1.0).timeout

	# 3つ目: 時間切れ → 無指示
	screen._start_next_event()
	await _frames(2)
	screen.state.time_left = 0.05
	await create_timer(1.2).timeout
	_check(screen.state.results.size() == 3, "ui: timeout resolved the third event (results=%d)" % screen.state.results.size())
	_check(screen.state.results[2]["chosen"] == &"", "ui: timeout is a no-instruction result")
	# 4つ目: 2つ目で埋めた「火」のおかげで、照合済みで始まる
	screen._start_next_event()
	await _frames(4)
	_check(screen.state.current.id == &"e4_beast_again" and screen.state.matched, "ui: fourth event starts pre-matched")
	_check(screen._cmd_hint_active, "ui: command panel is already lit")
	var beast_view: NoteEntryView = screen._entry_views[&"beast_claw"]
	_check(beast_view._stamp.visible, "ui: the beast note shows the stamp")
	_check(screen._tabs.get_tab_control(screen._tabs.current_tab).is_ancestor_of(beast_view), "ui: the monsters page is opened automatically")
	_check(screen._line_label.text.contains("ノートに"), "ui: the protagonist reacts to the note")
	screen._on_stat_chosen(&"battle")
	await create_timer(1.0).timeout
	_check(screen.state.results.size() == 4, "ui: fourth event resolved")

	# 5つ目: ノートと報告の食い違い（訂正）
	screen._start_next_event()
	await _frames(3)
	screen._reveal_all()
	await _frames(2)
	_check(screen.state.current.id == &"e5_moss" and not screen.state.matched, "ui: fifth event starts unmatched")
	var moss: NoteEntryView = screen._entry_views[&"glow_moss"]
	var fix_slot: BlankSlot = moss.slots[&"moss_safe"]
	_check(fix_slot.is_fix() and fix_slot._label.text == "触っても無害", "ui: the note still says it is harmless")
	_check(fix_slot.suspect, "ui: the contradicting spot is marked as suspect")
	_check(screen._tabs.get_tab_title(0).ends_with("●"), "ui: the plants tab is marked (%s)" % screen._tabs.get_tab_title(0))
	_check(fix_slot.size.x >= 100.0 and fix_slot.size.y >= 40.0, "ui: the fix slot is easy to hit (%s)" % fix_slot.size)
	screen._on_keyword_dropped(&"numb", &"glow_moss")
	_check(not screen.state.matched, "ui: dropping on the entry body is a mismatch")
	screen._on_keyword_dropped(&"numb", &"moss_safe")
	await _frames(3)
	_check(screen.state.matched and fix_slot.filled, "ui: the correction is accepted")
	_check(fix_slot._label.text == "触るとしびれる", "ui: the note is rewritten (%s)" % fix_slot._label.text)
	_check(moss._stamp.visible and moss._stamp.text == "訂正済", "ui: the stamp says corrected (%s)" % moss._stamp.text)
	_check(not fix_slot.suspect and screen._tabs.get_tab_title(0) == "植物", "ui: suspect marks are cleared after the correction")
	_check(screen._cmd_hint_active, "ui: command panel lights up after the correction")
	screen._on_stat_chosen(&"evade")
	await create_timer(1.0).timeout
	_check(screen.state.results.size() == 5, "ui: fifth event resolved")

	# 6つ目・7つ目: 落とし穴の目印（穴埋め）と深さ（訂正）
	for step in [[&"dark_floor", &"pit_sign"], [&"no_bottom", &"pit_depth"]]:
		screen._start_next_event()
		await _frames(3)
		screen._reveal_all()
		await _frames(2)
		screen._on_keyword_dropped(step[0], step[1])
		_check(screen.state.matched, "ui: %s is matched" % step[1])
		screen._on_stat_chosen(&"evade")
		await create_timer(1.0).timeout
	var pit: NoteEntryView = screen._entry_views[&"pit_trap"]
	_check((pit.slots[&"pit_sign"] as BlankSlot)._label.text == "色", "ui: the pit sign is written in the note")
	_check((pit.slots[&"pit_depth"] as BlankSlot)._label.text == "底が見えないほど深い", "ui: the pit depth is corrected")
	_check(screen.state.results.size() == 7, "ui: seventh event resolved")
	screen._start_next_event()
	await _frames(2)
	_check(screen._phase == MatchingScreen.Phase.SUMMARY, "ui: summary after the last event")
	_check(screen.settlement.get("day") == 1 and GameSession.day == 2, "ui: the expedition is settled and the day advances")
	_check(screen.settlement["funds_after"] == GameSession.funds and GameSession.funds == Rules.START_FUNDS + screen.settlement["reward"] - Rules.LIVING_COST, "ui: the funds reflect the reward and the living cost")
	screen.queue_free()
	await _frames(2)


## ドロップ結果の演出（出て、終わったら片付く）
func _test_effects() -> void:
	_reset_session()
	root.size = Vector2i(1280, 720)
	var screen: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	screen._reveal_all()
	await _frames(3)
	var wrong: NoteEntryView = screen._entry_views[&"glow_moss"]
	screen._on_keyword_dropped(&"mushroom", &"glow_moss")
	await _frames(3)
	_check(screen._overlay.get_child_count() > 0, "fx: mismatch spawns effects")
	_check(absf(wrong.rotation) > 0.0, "fx: mismatch wobbles the entry")
	var good: NoteEntryView = screen._entry_views[&"mushroom_poison"]
	_check(not screen._cmd_hint_active, "fx: command panel is not lit before a match")
	screen._on_keyword_dropped(&"mushroom", &"mushroom_poison")
	await _frames(3)
	_check(screen._cmd_hint_active, "fx: command panel lights up after a match")
	_check(good._stamp.scale.x > 1.0, "fx: stamp slams in (scale %.2f)" % good._stamp.scale.x)
	_check(good.scale.x > 1.0, "fx: entry pops (scale %.2f)" % good.scale.x)
	screen._on_stat_chosen(&"evade")
	_check(not screen._cmd_hint_active, "fx: command panel stops lighting once a command is chosen")
	await create_timer(1.8).timeout
	_check(screen._overlay.get_child_count() == 0, "fx: effects are cleaned up (%d left)" % screen._overlay.get_child_count())
	_check(is_zero_approx(wrong.rotation) and is_equal_approx(good.scale.x, 1.0), "fx: entries return to rest")
	_check(is_equal_approx(good._stamp.scale.x, 1.0) and is_equal_approx(good._stamp.modulate.a, 1.0), "fx: stamp settles")
	screen.queue_free()
	await _frames(2)


## 獣の穴: ドラッグ中、穴の上では穴だけが光り、項目の上（穴の外）では項目だけが光る
func _test_slot_hover() -> void:
	_reset_session()
	root.size = Vector2i(1280, 720)
	var screen: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	screen.state.resolved = true
	screen._start_next_event()
	await _frames(2)
	screen._reveal_all()
	screen._tabs.current_tab = 1
	await _frames(4)
	var chip := screen._chips[0]
	var entry: NoteEntryView = screen._entry_views[&"beast_claw"]
	var slot: BlankSlot = entry.slots[&"beast_aversion"]
	_check(slot.size.x >= 140.0 and slot.size.y >= 48.0, "slot: is large enough to hit (%s)" % slot.size)

	var from := chip.get_global_rect().get_center()
	_last_mouse = from
	_push_mouse_motion(from, 0)
	_push_mouse_button(from, true)
	await _frames(2)
	_push_mouse_motion(from + Vector2(30, 0), MOUSE_BUTTON_MASK_LEFT)
	await _frames(3)
	_check(slot.hint == BlankSlot.Hint.DRAGGING, "slot: shows a faint hint while dragging")
	# 項目の上（穴ではない場所）
	var on_entry := entry.get_global_rect().position + Vector2(40, 12)
	_push_mouse_motion(on_entry, MOUSE_BUTTON_MASK_LEFT)
	await _frames(3)
	_check(entry.hint == NoteEntryView.Hint.HOVER and slot.hint == BlankSlot.Hint.DRAGGING, "hover: entry lights up, slot does not")
	# 穴の上
	_push_mouse_motion(slot.get_global_rect().get_center(), MOUSE_BUTTON_MASK_LEFT)
	await _frames(3)
	_check(slot.hint == BlankSlot.Hint.HOVER and entry.hint != NoteEntryView.Hint.HOVER, "hover: only the slot lights up over the slot")
	_check(slot._label.text == "？？？", "hover: the slot text stays the same (only the glow changes)")
	_push_mouse_button(slot.get_global_rect().get_center(), false)
	await _frames(4)
	_check(screen.state.matched and slot.filled, "drop: the large slot accepts the torch")
	_check(slot.hint == BlankSlot.Hint.NONE and entry.hint == NoteEntryView.Hint.NONE, "hover: highlights are cleared after the drop")
	screen.queue_free()
	await _frames(2)


## 傭兵のシナリオのデータ（各イベントの正解が、ノートの正しい項目に結びついている）
func _test_mercenary_data() -> void:
	var merc := SampleData.adventurer(SampleData.MERCENARY)
	_check(merc.display_name == "傭兵" and merc.stat_for(&"battle") > merc.stat_for(&"explore"), "merc: strong in battle, weak in explore")
	_check(merc.chars_per_sec > SampleData.adventurer(SampleData.CHILDHOOD).chars_per_sec, "merc: reports come in faster")
	var events := SampleData.events(SampleData.MERCENARY)
	_check(events.size() == 6, "merc: six events (%d)" % events.size())
	var state := MatchingState.new(merc, events, SampleData.entries())
	var expected := [&"evade", &"battle", &"explore", &"explore", &"battle", &"explore"]
	var i := 0
	while state.begin_next_event():
		var ev := state.current
		_check(ev.required_stat == expected[i], "merc: event %d asks for the expected command" % (i + 1))
		var kw: StringName = ev.keyword_targets.keys()[0]
		var target: StringName = ev.keyword_targets[kw]
		_check(state.drop(kw, target) == MatchingState.DropResult.MATCHED, "merc: event %d matches by the intended keyword" % (i + 1))
		_check(ReportParser.parse(ev.report).any(func(seg: Dictionary) -> bool: return seg["kw"] == kw), "merc: event %d report contains its keyword" % (i + 1))
		i += 1
	_check(i == 6, "merc: iterated all events")
	# 手がかりを流しがちな傭兵: 3つ目のキーワードは「金にならん」と一緒に流される
	_check(events[2].report.contains("金にならん"), "merc: the relic clue is brushed off in the report")


## 選択画面: 2人が並び、選ぶとセッションに保存される
func _test_start_screen() -> void:
	_reset_session()
	var screen: PrepScreen = load("res://scenes/prep_screen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	_check(screen.cards.size() == 4 and screen.cards.has(SampleData.MERCENARY) and screen.cards.has(SampleData.CHILDHOOD) and screen.cards.has(SampleData.DOCTOR) and screen.cards.has(SampleData.NOBLE), "prep: all four adventurers are offered")
	screen.choose(SampleData.MERCENARY)
	_check(GameSession.adventurer_id == SampleData.MERCENARY, "prep: the choice is remembered")
	_check((screen.select_buttons[SampleData.MERCENARY] as Button).disabled and not (screen.select_buttons[SampleData.CHILDHOOD] as Button).disabled, "prep: the chosen adventurer is marked")
	screen.choose(SampleData.CHILDHOOD)
	_check(GameSession.adventurer_id == SampleData.CHILDHOOD, "prep: the choice can be changed")
	_check(screen.day_label.text == "1日目" and screen.funds_label.text.contains("200"), "prep: day and funds are shown (%s / %s)" % [screen.day_label.text, screen.funds_label.text])
	_check(screen.shop_rows.size() == 10, "prep: eight pieces of information and two items are for sale (%d)" % screen.shop_rows.size())
	screen.queue_free()
	await _frames(2)


## 準備フェーズの買い物と精算
func _test_economy() -> void:
	_reset_session()
	var screen: PrepScreen = load("res://scenes/prep_screen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	# 情報を買う: 資金が減り、ノートの箇所が埋まる
	_check(screen.buy(&"info_beast_aversion"), "econ: buying information succeeds")
	_check(GameSession.funds == Rules.START_FUNDS - 90 and GameSession.filled_blanks.has(&"beast_aversion"), "econ: the funds drop and the note spot is filled (%d)" % GameSession.funds)
	_check(not screen.buy(&"info_beast_aversion") and GameSession.funds == Rules.START_FUNDS - 90, "econ: the same information cannot be bought twice")
	_check((screen.shop_rows[&"info_beast_aversion"]["button"] as Button).text == "購入済", "econ: the row shows it is bought")
	# 足りないと買えない
	_check(not screen.buy(&"hourglass") and GameSession.funds == Rules.START_FUNDS - 90, "econ: an item the funds cannot cover is refused")
	_check((screen.shop_rows[&"hourglass"]["button"] as Button).disabled, "econ: the button is disabled when the funds are short")
	GameSession.funds = 500
	screen._refresh()
	_check(screen.buy(&"hourglass") and screen.buy(&"sticky") and GameSession.funds == 500 - 150 - 120, "econ: items can be bought with enough funds")
	_check(GameSession.has_item(&"hourglass") and GameSession.has_item(&"sticky"), "econ: the items are owned")
	screen.queue_free()
	await _frames(2)

	# 道具の効果は探索に反映される
	var matching: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
	root.add_child(matching)
	await _frames(3)
	_check(is_equal_approx(matching.state.event_time_limit, 25.0 * Rules.HOURGLASS_TIME_SCALE), "econ: the hourglass stretches the time limit (%.1f)" % matching.state.event_time_limit)
	var before := matching.state.time_left
	matching.state.drop(&"mushroom", &"glow_moss")
	_check(is_equal_approx(before - matching.state.time_left, Rules.MISMATCH_PENALTY_SEC * Rules.STICKY_PENALTY_SCALE), "econ: the sticky notes halve the penalty")
	matching.queue_free()
	await _frames(2)

	# 精算: 報酬 - 生活費、日が進む
	_reset_session()
	var result := GameSession.settle(250)
	_check(result["funds_after"] == Rules.START_FUNDS + 250 - Rules.LIVING_COST and GameSession.day == 2 and not result["bankrupt"], "econ: settlement pays the reward and the living cost")
	# 資金が尽きる
	GameSession.funds = 10
	var broke := GameSession.settle(20)
	_check(broke["bankrupt"] and GameSession.funds == 0, "econ: running out of money ends the game")
	GameSession.reset_all()
	_check(GameSession.funds == Rules.START_FUNDS and GameSession.day == 1 and GameSession.filled_blanks.is_empty() and GameSession.owned_items.is_empty(), "econ: reset_all restores everything")

	# 保存と読み込み（資金・日数・道具）
	var temp_path := "user://test_save.json"
	GameSession.persist = true
	GameSession.save_path = temp_path
	GameSession.funds = 321
	GameSession.day = 5
	GameSession.owned_items = {&"hourglass": true}
	GameSession.filled_blanks = {&"pit_sign": true}
	GameSession.save_notebook()
	GameSession.funds = 0
	GameSession.day = 1
	GameSession.owned_items = {}
	GameSession.filled_blanks = {}
	GameSession._loaded = false
	GameSession.load_notebook()
	_check(GameSession.funds == 321 and GameSession.day == 5 and GameSession.has_item(&"hourglass") and GameSession.filled_blanks.has(&"pit_sign"), "econ: funds, day, items and notes are saved and loaded")
	# 古い保存ファイル（ノートだけ）も読める
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"filled": ["bat_weak"]}))
	file.close()
	GameSession.funds = 0
	GameSession.filled_blanks = {}
	GameSession._loaded = false
	GameSession.load_notebook()
	_check(GameSession.filled_blanks.has(&"bat_weak") and GameSession.funds == Rules.START_FUNDS and GameSession.day == 1, "econ: an old save with only notes still loads")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	GameSession.save_path = "user://notebook.json"
	_reset_session()


## 傭兵で最後まで遊ぶ（実際の画面を通す）
func _test_mercenary_flow() -> void:
	_reset_session()
	GameSession.adventurer_id = SampleData.MERCENARY
	var screen: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	_check(screen._name_label.text.contains("傭兵"), "merc ui: the header shows the mercenary")
	_check(screen._tabs.get_tab_count() == 4, "merc ui: the relics page is in the note (%d tabs)" % screen._tabs.get_tab_count())
	var steps := [
		[&"bat", &"cave_bat", &"evade"],
		[&"torch", &"beast_aversion", &"battle"],
		[&"pattern", &"geo_pattern", &"explore"],
		[&"statue", &"statue_trap", &"explore"],
		[&"clap", &"bat_weak", &"battle"],
		[&"glow_text", &"tablet_light", &"explore"],
	]
	for n in steps.size():
		if n > 0:
			screen._start_next_event()
			await _frames(3)
		screen._reveal_all()
		await _frames(2)
		var step: Array = steps[n]
		screen._on_keyword_dropped(step[0], step[1])
		_check(screen.state.matched, "merc ui: event %d is matched" % (n + 1))
		screen._on_stat_chosen(step[2])
		await create_timer(1.0).timeout
	_check(screen.state.results.size() == 6, "merc ui: six events resolved")
	for res in screen.state.results:
		_check(res["target"] == res["base_target"] + Rules.MOD_MATCHED_CORRECT_STAT, "merc ui: correct play lowers the target")
	screen._start_next_event()
	await _frames(2)
	_check(screen._phase == MatchingScreen.Phase.SUMMARY, "merc ui: summary at the end")
	screen.queue_free()
	GameSession.adventurer_id = SampleData.CHILDHOOD
	await _frames(2)


## 医師と貴族のデータ（報告のクセが、遊びの違いになっている）
func _test_new_adventurers_data() -> void:
	var doctor := SampleData.adventurer(SampleData.DOCTOR)
	var noble := SampleData.adventurer(SampleData.NOBLE)
	_check(doctor.display_name == "医師" and noble.display_name == "没落貴族", "new adv: names")
	_check(doctor.stat_for(&"battle") == 1 and noble.stat_for(&"battle") == 1, "new adv: neither can fight")
	_check(noble.stat_for(&"explore") > noble.stat_for(&"evade"), "new adv: the noble is a scholar, not a runner")
	_check(doctor.panic_factor > 1.0 and SampleData.adventurer(SampleData.CHILDHOOD).panic_factor == 1.0, "new adv: only the doctor panics")
	_check(noble.chars_per_sec > doctor.chars_per_sec and doctor.chars_per_sec > SampleData.adventurer(SampleData.CHILDHOOD).chars_per_sec, "new adv: reports get faster and faster")

	var d_events := SampleData.events(SampleData.DOCTOR)
	var n_events := SampleData.events(SampleData.NOBLE)
	_check(d_events.size() == 4 and n_events.size() == 4, "new adv: four events each")
	for ev in d_events:
		_check(is_equal_approx(ev.time_limit, 15.0), "new adv: doctor event %s is short (%.0fs)" % [ev.id, ev.time_limit])
	for ev in n_events:
		_check(is_equal_approx(ev.time_limit, 30.0), "new adv: noble event %s is long (%.0fs)" % [ev.id, ev.time_limit])
		# 貴族の報告は長く、正解は1つで、残りはおとり
		var segs := ReportParser.parse(ev.report)
		var chips := segs.filter(func(seg: Dictionary) -> bool: return seg["kw"] != &"")
		_check(ev.report.length() > 90, "new adv: the noble talks a lot in %s (%d chars)" % [ev.id, ev.report.length()])
		_check(chips.size() >= 3 and ev.keyword_targets.size() == 1, "new adv: %s has decoy keywords (%d chips, 1 answer)" % [ev.id, chips.size()])
		_check(chips.any(func(seg: Dictionary) -> bool: return ev.keyword_targets.has(seg["kw"])), "new adv: the answer is in the report of %s" % ev.id)
	# おとりを運ぶと、どこへ置いても不一致で時間を失う
	var state := MatchingState.new(noble, n_events, SampleData.entries())
	state.begin_next_event()
	var before := state.time_left
	_check(state.drop(&"nb_pigment", &"geo_pattern") == MatchingState.DropResult.MISMATCH and state.time_left < before, "new adv: carrying a decoy costs time")
	_check(state.drop(&"nb_pattern", &"geo_pattern") == MatchingState.DropResult.MATCHED, "new adv: the real keyword still matches")
	# 医師はパニック: 間違いのロスが大きい
	var d_state := MatchingState.new(doctor, d_events, SampleData.entries())
	d_state.penalty_scale = doctor.panic_factor
	d_state.begin_next_event()
	var d_before := d_state.time_left
	d_state.drop(&"rash", &"glow_moss")
	_check(is_equal_approx(d_before - d_state.time_left, Rules.MISMATCH_PENALTY_SEC * 1.5), "new adv: the doctor loses more time for a mistake")


## 医師・貴族で最後まで遊ぶ（実際の画面を通す）
func _test_doctor_and_noble_flow() -> void:
	var plans := {
		SampleData.DOCTOR: [
			[&"rash", &"mushroom_poison", &"evade"],
			[&"herb", &"herb_effect", &"explore"],
			[&"numb_d", &"moss_safe", &"evade"],
			[&"d_bat", &"cave_bat", &"evade"],
		],
		SampleData.NOBLE: [
			[&"nb_pattern", &"geo_pattern", &"explore"],
			[&"nb_light", &"tablet_light", &"explore"],
			[&"nb_statue", &"statue_trap", &"explore"],
			[&"nb_star", &"keyhole_shape", &"explore"],
		],
	}
	for adventurer_id in plans:
		_reset_session()
		GameSession.adventurer_id = adventurer_id
		var screen: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
		root.add_child(screen)
		await _frames(3)
		_check(screen._name_label.text.contains(SampleData.adventurer(adventurer_id).display_name), "flow %s: the header shows the adventurer" % adventurer_id)
		var steps: Array = plans[adventurer_id]
		for n in steps.size():
			if n > 0:
				screen._start_next_event()
				await _frames(3)
			screen._reveal_all()
			await _frames(2)
			_check(screen._sketch_frame != null, "flow %s: event %d has a sketch" % [adventurer_id, n + 1])
			var step: Array = steps[n]
			screen._on_keyword_dropped(step[0], step[1])
			_check(screen.state.matched, "flow %s: event %d is matched" % [adventurer_id, n + 1])
			screen._on_stat_chosen(step[2])
			await create_timer(1.0).timeout
		_check(screen.state.results.size() == 4, "flow %s: four events resolved" % adventurer_id)
		screen._start_next_event()
		await _frames(2)
		_check(screen._phase == MatchingScreen.Phase.SUMMARY, "flow %s: summary at the end" % adventurer_id)
		screen.queue_free()
		await _frames(2)
	# 医師の画面では、パニックの倍率が反映される
	_reset_session()
	GameSession.adventurer_id = SampleData.DOCTOR
	var doctor_screen: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
	root.add_child(doctor_screen)
	await _frames(3)
	_check(is_equal_approx(doctor_screen.state.penalty_scale, 1.5), "flow doctor: the panic factor reaches the match state (%.2f)" % doctor_screen.state.penalty_scale)
	_check(is_equal_approx(doctor_screen.state.event_time_limit, 15.0), "flow doctor: the time limit is short (%.1f)" % doctor_screen.state.event_time_limit)
	doctor_screen.queue_free()
	await _frames(2)
	_reset_session()


## ノートの引き継ぎ
func _test_carry_over() -> void:
	_reset_session()
	# 同じ辞書を共有すると、別の探索（別の冒険者）にも育ちが引き継がれる
	var shared: Dictionary = {}
	var first := MatchingState.new(SampleData.adventurer(SampleData.CHILDHOOD), SampleData.events(SampleData.CHILDHOOD), SampleData.entries(), shared)
	first.begin_next_event(); first.begin_next_event()
	_check(not first.auto_matched, "carry: nothing is known on the first run")
	first.drop(&"torch", &"beast_aversion")
	_check(shared.has(&"beast_aversion") and first.learned == [&"beast_aversion"], "carry: the fill is shared and recorded as learned")
	var second := MatchingState.new(SampleData.adventurer(SampleData.MERCENARY), SampleData.events(SampleData.MERCENARY), SampleData.entries(), shared)
	second.begin_next_event()
	_check(not second.auto_matched, "carry: an unrelated event is not pre-matched")
	second.begin_next_event()
	_check(second.current.id == &"m2_beast" and second.auto_matched and second.auto_target == &"beast_aversion", "carry: the mercenary's beast event starts pre-matched")
	_check(second.drop(&"torch", &"beast_aversion") == MatchingState.DropResult.IGNORED, "carry: no double matching")
	_check(second.learned.is_empty(), "carry: nothing new is learned the second time")
	_check(SampleData.growth_spots().size() == 8, "carry: the note has eight spots that can grow (%d)" % SampleData.growth_spots().size())
	# 引数を省略した状態は、互いに共有されない
	var a := MatchingState.new(SampleData.adventurer(), SampleData.events(), SampleData.entries())
	var b := MatchingState.new(SampleData.adventurer(), SampleData.events(), SampleData.entries())
	a.begin_next_event(); a.begin_next_event(); a.drop(&"torch", &"beast_aversion")
	_check(not b.filled_blanks.has(&"beast_aversion"), "carry: states without a shared dictionary stay separate")
	# 幼なじみの訂正（苔）も、同じ仕組みで引き継がれる
	var third := MatchingState.new(SampleData.adventurer(), SampleData.events(), SampleData.entries(), {&"moss_safe": true})
	for i in 5:
		third.begin_next_event()
	_check(third.current.id == &"e5_moss" and third.auto_matched and third.auto_target == &"moss_safe", "carry: a known correction pre-matches the contradiction event")

	# ファイルへの保存と読み込み
	var temp_path := "user://test_notebook.json"
	GameSession.persist = true
	GameSession.save_path = temp_path
	GameSession.filled_blanks = {&"beast_aversion": true, &"moss_safe": true}
	GameSession.save_notebook()
	GameSession.filled_blanks = {}
	GameSession._loaded = false
	GameSession.load_notebook()
	_check(GameSession.filled_blanks.has(&"beast_aversion") and GameSession.filled_blanks.has(&"moss_safe"), "carry: the notebook is saved and loaded")
	GameSession.reset_notebook()
	GameSession._loaded = false
	GameSession.filled_blanks = {}
	GameSession.load_notebook()
	_check(GameSession.filled_blanks.is_empty(), "carry: reset also clears the saved file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	GameSession.save_path = "user://notebook.json"
	_reset_session()


## 引き継いだノートで探索を始める（画面）。選択画面の表示とリセットも確認する。
func _test_carry_over_ui() -> void:
	_reset_session()
	GameSession.filled_blanks[&"beast_aversion"] = true
	var screen: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	var beast: NoteEntryView = screen._entry_views[&"beast_claw"]
	var slot: BlankSlot = beast.slots[&"beast_aversion"]
	_check(slot.filled and slot._label.text == "火", "carry ui: the known fill is already written in the note")
	# 幼なじみのイベント2（獣）は、照合済みで始まる
	screen.state.resolved = true
	screen._start_next_event()
	await _frames(4)
	_check(screen.state.auto_matched and screen._cmd_hint_active, "carry ui: the beast event starts pre-matched and the commands are lit")
	_check(screen._line_label.text.contains("火"), "carry ui: the protagonist mentions what the note says (%s)" % screen._line_label.text)
	screen.queue_free()
	await _frames(2)

	_reset_session()
	var start: PrepScreen = load("res://scenes/prep_screen.tscn").instantiate()
	root.add_child(start)
	await _frames(3)
	_check(start.notebook_label.text.contains("0 / 8"), "carry ui: the prep screen shows no growth at first (%s)" % start.notebook_label.text)
	GameSession.filled_blanks[&"beast_aversion"] = true
	GameSession.funds = 50
	start._refresh()
	_check(start.notebook_label.text.contains("1 / 8") and start.notebook_label.text.contains("火"), "carry ui: the prep screen shows what has been written (%s)" % start.notebook_label.text)
	_check(start.warning_label.text.contains("生活費"), "carry ui: low funds trigger a warning")
	start.request_reset()
	_check(GameSession.filled_blanks.has(&"beast_aversion") and GameSession.funds == 50, "carry ui: the first press only asks for confirmation")
	start.request_reset()
	_check(GameSession.filled_blanks.is_empty() and GameSession.funds == Rules.START_FUNDS and start.notebook_label.text.contains("0 / 8"), "carry ui: the second press resets everything")
	start.queue_free()
	await _frames(2)
	_reset_session()


## 絵の読み込み口
func _test_illustrations() -> void:
	Illustrations.clear_cache()
	var paths := Illustrations.candidate_paths("sketches", &"beast", &"mercenary")
	_check(paths[0].ends_with("/sketches/mercenary/beast.png") and paths[4].ends_with("/sketches/beast.png"), "art: the adventurer's own drawing is searched first")
	_check(paths[0].ends_with(".png") and paths[3].ends_with(".svg"), "art: png is preferred over svg (%s)" % paths[3])
	for id in [&"mushroom", &"beast", &"statue", &"moss", &"pit", &"pit_deep", &"bat", &"pattern", &"tablet", &"herb", &"keyhole"]:
		_check(Illustrations.find("sketches", id) != null, "art: sketch %s is available" % id)
	for id in [SampleData.CHILDHOOD, SampleData.MERCENARY, SampleData.DOCTOR, SampleData.NOBLE]:
		_check(Illustrations.find("portraits", id) != null, "art: portrait %s is available" % id)
	# 冒険者ごとの絵柄: 専用の絵があれば、共通の絵と別のものが返る
	_check(Illustrations.find("sketches", &"bat", SampleData.NOBLE) == Illustrations.find("sketches", &"bat"), "art: an adventurer without their own bat drawing uses the shared one")
	_check(Illustrations.find("sketches", &"bat", SampleData.DOCTOR) != Illustrations.find("sketches", &"bat"), "art: the doctor draws the bat in his own style")
	_check(Illustrations.find("sketches", &"pattern", SampleData.NOBLE) != Illustrations.find("sketches", &"pattern"), "art: the noble draws the pattern in his own style")
	_check(Illustrations.find("sketches", &"no_such_drawing") == null, "art: a missing drawing is just null")
	_check(Illustrations.find("sketches", &"") == null, "art: an empty id is null")
	# どのイベントのスケッチも、絵のファイルがある
	for adventurer_id in [SampleData.CHILDHOOD, SampleData.MERCENARY, SampleData.DOCTOR, SampleData.NOBLE]:
		for ev in SampleData.events(adventurer_id):
			_check(ev.sketch != &"" and Illustrations.find("sketches", ev.sketch, adventurer_id) != null, "art: event %s has its sketch" % ev.id)


## 絵が画面に出る（通信ログのスケッチ、顔）
func _test_illustrations_ui() -> void:
	_reset_session()
	var screen: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	_check(screen._portrait_rect.visible and screen._portrait_rect.texture != null, "art ui: the adventurer's face is in the header")
	_check(screen._sketch_frame != null and screen._sketch_frame.modulate.a == 0.0, "art ui: the sketch is hidden while the report is still being typed")
	screen._reveal_all()
	await create_timer(0.7).timeout
	_check(screen._sketch_frame.modulate.a > 0.99, "art ui: the sketch fades in when the report is complete")
	screen.state.resolved = true
	screen._start_next_event()
	await _frames(3)
	_check(screen._sketch_frame != null and screen._sketch_frame.modulate.a == 0.0, "art ui: the next event starts with a fresh, hidden sketch")
	# 絵のファイルが無いイベントでも壊れない（何も出ないだけ）
	screen.state.events[screen.state.event_index + 1].sketch = &"no_such_drawing"
	screen.state.resolved = true
	screen._start_next_event()
	await _frames(3)
	screen._reveal_all()
	await _frames(2)
	_check(screen._sketch_frame == null and screen._phase == MatchingScreen.Phase.REPORTING, "art ui: an event without a drawing simply shows none")
	screen.queue_free()
	await _frames(2)

	var prep: PrepScreen = load("res://scenes/prep_screen.tscn").instantiate()
	root.add_child(prep)
	await _frames(3)
	var faces := 0
	for card: PanelContainer in prep.cards.values():
		for node in card.find_children("*", "TextureRect", true, false):
			faces += 1
	_check(faces == 4, "art ui: every adventurer card shows a face (%d)" % faces)
	prep.queue_free()
	await _frames(2)
	_reset_session()


## 合成した効果音の波形（無音・音割れ・プチッというノイズが無いか）
func _test_sfx_waveforms() -> void:
	for sound in Sfx.names():
		var st := Sfx.stream(sound)
		_check(st != null, "sfx: %s can be synthesized" % sound)
		if st == null:
			continue
		var length := Synth.length_sec(st)
		var peak := Synth.peak(st)
		var first := absf(float(st.data.decode_s16(0)) / 32768.0)
		var last := absf(float(st.data.decode_s16(st.data.size() - 4)) / 32768.0)
		_check(length >= 0.01 and length <= 1.0, "sfx: %s has a sensible length (%.2fs)" % [sound, length])
		_check(peak >= 0.05 and peak < 0.98, "sfx: %s is audible but not clipping (peak %.2f)" % [sound, peak])
		_check(first < 0.05 and last < 0.01, "sfx: %s starts and ends softly (%.3f / %.3f)" % [sound, first, last])
	_check(Sfx.stream(&"no_such_sound") == null, "sfx: an unknown sound is ignored")


## 操作に応じて、正しい効果音が鳴る
func _test_sfx_events() -> void:
	_reset_session()
	Sfx.muted = false
	var screen: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	screen._reveal_all()
	await _frames(2)

	Sfx.played_log.clear()
	screen._on_keyword_dropped(&"mushroom", &"glow_moss")
	_check(Sfx.played_log.has(&"mismatch") and not Sfx.played_log.has(&"match"), "sfx ui: a wrong drop plays the mismatch sound")
	Sfx.played_log.clear()
	screen._on_keyword_dropped(&"mushroom", &"mushroom_poison")
	_check(Sfx.played_log.has(&"match") and Sfx.played_log.has(&"stamp"), "sfx ui: a right drop plays the chime and the stamp")
	await create_timer(0.5).timeout
	_check(Sfx.played_log.has(&"ting"), "sfx ui: the command panel lighting up plays a ting")

	# ミュート中は鳴らない
	Sfx.set_muted(true)
	Sfx.played_log.clear()
	Sfx.play(&"click")
	_check(Sfx.played_log.is_empty(), "sfx ui: nothing plays while muted")
	_check(Sfx.mute_button_text() == "音: OFF", "sfx ui: the mute button label follows the setting")
	Sfx.set_muted(false)

	Sfx.played_log.clear()
	screen._on_stat_chosen(&"evade")
	await create_timer(1.2).timeout
	var ticks := Sfx.played_log.filter(func(n: StringName) -> bool: return n == &"tick").size()
	_check(Sfx.played_log.has(&"click") and ticks == 10, "sfx ui: choosing a command clicks and the dice rattle (%d ticks)" % ticks)
	_check(Sfx.played_log.has(&"success") or Sfx.played_log.has(&"fail") or Sfx.played_log.has(&"crit_fail"), "sfx ui: the result has its own sound")

	# 以前に埋めたノートが効くイベント: ノートが役に立った音
	GameSession.filled_blanks[&"beast_aversion"] = true
	Sfx.played_log.clear()
	screen._start_next_event()
	await create_timer(0.6).timeout
	_check(screen.state.auto_matched and Sfx.played_log.has(&"known"), "sfx ui: a pre-matched event plays the known-note sound")

	# 残り5秒を切ると、1秒ごとに知らせる
	screen.state.resolved = true
	screen._start_next_event()
	await _frames(2)
	Sfx.played_log.clear()
	screen.state.time_left = 4.5
	await _frames(3)
	_check(Sfx.played_log.has(&"warn"), "sfx ui: a low-time warning ticks")
	screen.queue_free()
	await _frames(2)
	_reset_session()
	Sfx.muted = false


## 実際のマウス入力（押す→動かす→離す）でドラッグ＆ドロップできるか。
func _test_real_drag() -> void:
	_reset_session()
	# ヘッドレスのウィンドウは 64x64 なので、入力が届くよう実寸にする
	root.size = Vector2i(1280, 720)
	var screen: MatchingScreen = load("res://scenes/matching_screen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	screen._reveal_all()
	await _frames(3)
	var chip := screen._chips[0]
	var target: NoteEntryView = screen._entry_views[&"mushroom_poison"]
	var from := chip.get_global_rect().get_center()
	var to := target.get_global_rect().get_center()
	_push_mouse_motion(from, 0)
	_push_mouse_button(from, true)
	await _frames(2)
	_push_mouse_motion(from + Vector2(30, 0), MOUSE_BUTTON_MASK_LEFT)
	await _frames(2)
	_check(root.gui_is_dragging(), "real drag: dragging started after moving the pressed mouse")
	_push_mouse_motion(to, MOUSE_BUTTON_MASK_LEFT)
	await _frames(2)
	_push_mouse_button(to, false)
	await _frames(3)
	_check(screen.state.matched, "real drag: dropping the chip on the right entry matches")
	screen.queue_free()
	await _frames(2)


var _last_mouse := Vector2.ZERO


func _push_mouse_motion(pos: Vector2, mask: int) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = pos - _last_mouse
	_last_mouse = pos
	ev.button_mask = mask
	root.push_input(ev)


func _push_mouse_button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(ev)
