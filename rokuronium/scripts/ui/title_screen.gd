extends Control
## タイトル画面: はじめから／つづきから／設定／終了

var _main_box: VBoxContainer
var _settings_panel: PanelContainer


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := UIKit.make_label("ロクロニウム冒険記", 76, Color(0.95, 0.88, 0.62))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 110)
	title.size = Vector2(1280, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_left = 0
	title.offset_right = 0
	add_child(title)
	var sub := UIKit.make_label("剣と魔法の異世界、冒険者の町で綴る選択式アドベンチャー", 22, Color(0.75, 0.75, 0.8))
	sub.position = Vector2(0, 215)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	_main_box = VBoxContainer.new()
	_main_box.position = Vector2(480, 320)
	_main_box.size = Vector2(320, 300)
	_main_box.add_theme_constant_override("separation", 14)
	add_child(_main_box)
	var start := UIKit.make_button("はじめから", 26)
	start.pressed.connect(_on_start)
	_main_box.add_child(start)
	var cont := UIKit.make_button("つづきから", 26)
	cont.disabled = true
	cont.tooltip_text = "セーブ／ロードはフェーズ2で対応予定"
	_main_box.add_child(cont)
	var settings := UIKit.make_button("設定", 26)
	settings.pressed.connect(_open_settings)
	_main_box.add_child(settings)
	var quit := UIKit.make_button("終了", 26)
	quit.pressed.connect(func(): get_tree().quit())
	_main_box.add_child(quit)
	for b in _main_box.get_children():
		(b as Button).custom_minimum_size = Vector2(320, 56)
	start.grab_focus()

	if OS.is_debug_build():
		var v: Dictionary = App.validation
		var dbg := UIKit.make_label("データ検証：エラー %d 件／警告 %d 件（詳細は出力パネル）" % [v["errors"].size(), v["warnings"].size()], 16,
			Color(1, 0.55, 0.5) if not v["errors"].is_empty() else Color(0.6, 0.8, 0.6))
		dbg.position = Vector2(20, 690)
		add_child(dbg)

	_build_settings()


func _on_start() -> void:
	App.new_game()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _build_settings() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.07, 0.08, 0.12, 0.97)))
	_settings_panel.position = Vector2(340, 190)
	_settings_panel.size = Vector2(600, 360)
	_settings_panel.visible = false
	add_child(_settings_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	_settings_panel.add_child(vb)
	vb.add_child(UIKit.make_label("設定", 30, Color(0.95, 0.88, 0.62)))

	var speed_label := UIKit.make_label("", 20)
	vb.add_child(speed_label)
	var speed := HSlider.new()
	speed.min_value = 0
	speed.max_value = 120
	speed.step = 5
	speed.value = App.settings["text_speed"]
	speed.custom_minimum_size = Vector2(520, 28)
	vb.add_child(speed)
	var upd_speed := func(v: float):
		App.settings["text_speed"] = int(v)
		speed_label.text = "文字速度：%s" % ("即時表示" if int(v) == 0 else "%d 文字/秒" % int(v))
	speed.value_changed.connect(upd_speed)
	upd_speed.call(speed.value)

	var vol_label := UIKit.make_label("", 20)
	vb.add_child(vol_label)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = App.settings["master_volume"]
	vol.custom_minimum_size = Vector2(520, 28)
	vb.add_child(vol)
	var upd_vol := func(v: float):
		App.settings["master_volume"] = v
		vol_label.text = "音量：%d%%" % int(round(v * 100.0))
	vol.value_changed.connect(upd_vol)
	upd_vol.call(vol.value)

	var detail := CheckBox.new()
	detail.text = "判定の内訳（出目・難易度）を表示する"
	detail.add_theme_font_size_override("font_size", 20)
	detail.button_pressed = App.settings["show_roll_detail"]
	detail.toggled.connect(func(on: bool): App.settings["show_roll_detail"] = on)
	vb.add_child(detail)

	var close := UIKit.make_button("閉じる", 22)
	close.pressed.connect(_close_settings)
	vb.add_child(close)


func _open_settings() -> void:
	_main_box.visible = false
	_settings_panel.visible = true


func _close_settings() -> void:
	App.save_settings()
	_settings_panel.visible = false
	_main_box.visible = true
