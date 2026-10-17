extends Node
## 画面を実際に動かして、ボタンを押しながら終端まで進める煙テスト。
## 使い方:  godot --headless --path rokuronium res://tests/ui_smoke.tscn
## （オートロード App が必要なので --script ではなくシーンとして起動する）

var _fails := 0


func _ready() -> void:
	await _run()
	print("UIテスト完了: 失敗 %d 件" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("  [失敗] ", msg)


func _run() -> void:
	for mode in [0, 400]:   # 0=即時表示 / 400=文字送りあり（高速）
		for seed_i in 25:
			App.settings["text_speed"] = mode
			App.state.rng.seed = 777 + seed_i
			App.new_game()
			var screen: Control = load("res://scenes/game.tscn").instantiate()
			add_child(screen)
			await get_tree().process_frame
			var steps := 0
			var guard := 0
			while steps < 120 and guard < 4000:
				guard += 1
				await get_tree().process_frame
				var buttons: Array = screen.debug_choice_buttons()
				if buttons.is_empty():
					# 文字送り中・ページ送り中: クリック相当で進める
					var ev := InputEventMouseButton.new()
					ev.button_index = MOUSE_BUTTON_LEFT
					ev.pressed = true
					screen.gui_input.emit(ev)
					continue
				var b: Button = buttons[App.state.rng.randi_range(0, buttons.size() - 1)]
				if b.text == "タイトルへ戻る":
					steps = -1
					break
				ok(b.text.length() > 0, "ボタンに文字がある")
				b.pressed.emit()
				steps += 1
			ok(steps == -1, "終端(タイトルへ戻る)に着く: mode=%d seed=%d scene=%s" % [mode, seed_i, App.state.current_scene])
			screen.queue_free()
			await get_tree().process_frame
	# 状況欄の文字列と、メニューの描画が例外なく作れること
	App.new_game()
	var s2: Control = load("res://scenes/game.tscn").instantiate()
	add_child(s2)
	await get_tree().process_frame
	for tab in ["status", "items", "affinity"]:
		s2._show_menu_tab(tab)
	s2.queue_free()
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	title.queue_free()
