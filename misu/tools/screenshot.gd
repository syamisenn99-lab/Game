extends SceneTree
## 画面写真を撮る（見た目の確認用）。画面のある環境で:
##   SHOT_DIR=/保存先 godot --path . --resolution 720x1280 --script tools/screenshot.gd
func _initialize() -> void:
	_run.call_deferred()
func _snap(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")
func _run() -> void:
	var gd: Node = root.get_node("GameData")
	gd.config["text_chars_per_sec"] = 0
	gd.config["save_playtest_log"] = false
	var fan: Node = root.get_node("Fan")
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.autostart = false
	root.add_child(main)
	main.title()
	await _snap("1_title")
	fan.press(true)
	main.play_session()
	for i in 12:
		await create_timer(0.05).timeout
		fan.press(true)
	await _snap("2_case")
	while not main._judging:
		await create_timer(0.05).timeout
		fan.press(true)
	await create_timer(0.5).timeout
	fan.press(true)
	await create_timer(0.3).timeout
	await _snap("3_judge")
	while main.body.text.find("振り返り") < 0 and main.speaker_label.text != "振り返り":
		await create_timer(0.1).timeout
		if not main._judging:
			fan.press(true)
	await _snap("4_reflect")
	quit()
