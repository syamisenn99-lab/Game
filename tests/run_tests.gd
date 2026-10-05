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
	_check(Judge.modifier(true, &"observe", &"observe") == -4, "judge: matched+correct")
	_check(Judge.modifier(true, &"battle", &"observe") == 0, "judge: matched+wrong stat")
	_check(Judge.modifier(false, &"observe", &"observe") == 0, "judge: unmatched+correct")
	_check(Judge.modifier(false, &"battle", &"observe") == 4, "judge: unmatched+wrong")
	_check(Judge.modifier(false, &"", &"observe") == 2, "judge: no instruction")
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
	screen._on_stat_chosen(&"observe")
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
	screen._start_next_event()
	await _frames(2)
	_check(screen._phase == MatchingScreen.Phase.SUMMARY, "ui: summary after the last event")
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
