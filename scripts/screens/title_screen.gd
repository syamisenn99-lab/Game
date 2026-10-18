extends Control
## タイトル画面：「はじめる」とシード入力。

var _seed_input: LineEdit


func _ready() -> void:
	UIKit.background(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := UIKit.label("引き算デッキ（仮）", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UIKit.label("重いデッキから、手放して、軽くなる。", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "シード（空欄ならランダム）"
	_seed_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_input.custom_minimum_size = Vector2(320, 40)
	_seed_input.text_submitted.connect(func(_t: String) -> void: _start())
	box.add_child(_seed_input)
	box.add_child(UIKit.button("はじめる", _start, Vector2(320, 64)))


func _start() -> void:
	var text := _seed_input.text.strip_edges()
	var seed_value := -1
	if text.is_valid_int():
		seed_value = absi(int(text))
	elif not text.is_empty():
		seed_value = absi(text.hash()) % 1000000
	RunState.start_run(seed_value)
	RunState.go_to(RunState.SCENE_BATTLE)
