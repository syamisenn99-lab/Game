extends SceneTree
## 画面を自動で操作してスクリーンショットを撮る（表示崩れ・豆腐の確認用）。
## 描画が必要なので --headless では動かない。Linux なら Xvfb で:
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --script res://tools/capture_screens.gd -- --seed 7 --out /tmp/screens

var _out := "user://screens"
var _main: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--out")
	if i >= 0 and i + 1 < args.size():
		_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(4)
	await _shot("01_board")

	_main.top_bar.contract_button.pressed.emit()
	_main.contract_dialog.set_contract("gald", "commission")
	_main.contract_dialog.set_contract("mira", "commission")
	await _shot("01a_contract")
	_main.contract_dialog.close_button.pressed.emit()

	_main._on_quest_selected("q03")
	await _shot("02_detail")

	var dispatch: Control = _main.dispatch_panel
	dispatch.open("q03")
	dispatch.set_adventurer("oswald", true)
	dispatch.set_adventurer("lina", true)
	dispatch.set_supply(1)
	await _shot("03_dispatch")
	dispatch.confirm_button.pressed.emit()
	dispatch.open("q01")
	dispatch.set_adventurer("gald", true)
	dispatch.set_adventurer("tom", true)
	dispatch.set_adventurer("mira", true)
	await _shot("04_dispatch_lucky_ironwall")
	dispatch.confirm_button.pressed.emit()
	_main._on_quest_selected("q01")
	await _shot("05_in_progress")

	_main._on_quest_selected("s01")
	await _shot("05a_standing_detail")
	dispatch.open("s01")
	dispatch.set_adventurer("tom", true)
	await _shot("05b_standing_dispatch")
	dispatch.cancel_button.pressed.emit()

	var shots := 6
	var guard := 0
	while not _main.result_screen.visible and guard < 200:
		guard += 1
		if _main.report_dialog.visible:
			if shots < 9:
				await _shot("%02d_report" % shots)
				shots += 1
			_main.report_dialog.next_button.pressed.emit()
		elif _main.injury_dialog.visible:
			if shots < 12:
				await _shot("%02d_injury" % shots)
				shots += 1
			if _main.injury_dialog.pay_button.disabled:
				_main.injury_dialog.skip_button.pressed.emit()
			else:
				_main.injury_dialog.pay_button.pressed.emit()
		elif _main.message_dialog.visible:
			if shots < 12:
				await _shot("%02d_message" % shots)
				shots += 1
			_main.message_dialog.ok_button.pressed.emit()
		else:
			_auto_dispatch()
			_main.top_bar.end_week_button.pressed.emit()
		await _frames(2)
	await _shot("99_result")
	print("saved to ", ProjectSettings.globalize_path(_out))
	quit()


## 受けられる依頼に、待機中の冒険者を1人ずつ送る（画面を進めるためだけの簡単な操作）
func _auto_dispatch() -> void:
	var c: GameController = _main.controller
	for q: QuestState in c.board_quests():
		var idle := c.idle_adventurers()
		if idle.is_empty():
			return
		if q.status == QuestState.Status.POSTED and c.is_unlocked(q):
			var party: Array[String] = [idle[0].def.id]
			if idle.size() > 1:
				party.append(idle[1].def.id)
			c.dispatch(q, party, 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("shot: ", path)
