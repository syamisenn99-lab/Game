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


func _run() -> void:
	_test_parser()
	_test_note_entry()
	_test_judge()
	_test_state()
	await _test_ui_flow()
	await _test_real_drag()
	await _test_effects()
	await _test_slot_hover()
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
	screen._start_next_event()
	await _frames(2)
	_check(screen._phase == MatchingScreen.Phase.SUMMARY, "ui: summary after the last event")
	screen.queue_free()
	await _frames(2)


## ドロップ結果の演出（出て、終わったら片付く）
func _test_effects() -> void:
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


## 実際のマウス入力（押す→動かす→離す）でドラッグ＆ドロップできるか。
func _test_real_drag() -> void:
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
