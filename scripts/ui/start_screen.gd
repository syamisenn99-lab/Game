class_name StartScreen
extends Control
## 探索の前に「誰をガイドするか」を選ぶ画面（準備フェーズの最初の一歩）。

const MATCHING_SCENE := "res://scenes/matching_screen.tscn"
const STAT_ORDER: Array[StringName] = [&"battle", &"explore", &"evade"]

var cards: Dictionary = {}


func _ready() -> void:
	theme = Palette.make_theme()
	var desk := ColorRect.new()
	desk.color = Palette.DESK
	desk.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(desk)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	var title := Label.new()
	title.text = "誰をガイドする？"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.DESK_TEXT)
	root.add_child(title)
	var sub := Label.new()
	sub.text = "冒険者によって、報告のクセも、得意な力もちがう。耳飾りをつなぐ相手を選ぼう。"
	sub.add_theme_color_override("font_color", Palette.DESK_TEXT)
	root.add_child(sub)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	root.add_child(row)
	for adventurer in SampleData.adventurers():
		var card := _build_card(adventurer)
		row.add_child(card)
		cards[adventurer.id] = card


func _build_card(adventurer: Adventurer) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, Palette.INK_FAINT, 2, 8, 20.0))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var name_label := Label.new()
	name_label.text = adventurer.display_name
	name_label.add_theme_font_size_override("font_size", 34)
	vbox.add_child(name_label)
	vbox.add_child(_wrapped(adventurer.tagline, Palette.INK))

	var style_title := Label.new()
	style_title.text = "報告のクセ"
	style_title.add_theme_color_override("font_color", Palette.INK_FAINT)
	vbox.add_child(style_title)
	vbox.add_child(_wrapped(adventurer.report_style, Palette.INK))

	var stats_title := Label.new()
	stats_title.text = "得意な力"
	stats_title.add_theme_color_override("font_color", Palette.INK_FAINT)
	vbox.add_child(stats_title)
	for stat in STAT_ORDER:
		var value := adventurer.stat_for(stat)
		var line := Label.new()
		line.text = "%s  %s%s" % [Rules.STAT_LABELS[stat], "■".repeat(value), "□".repeat(maxi(0, 6 - value))]
		vbox.add_child(line)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	var button := Button.new()
	button.text = "%sをガイドする" % adventurer.display_name
	button.custom_minimum_size = Vector2(0, 52)
	button.pressed.connect(select.bind(adventurer.id))
	vbox.add_child(button)
	return card


func _wrapped(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.add_theme_color_override("font_color", color)
	return label


## 冒険者を選んで探索へ。テストでは go=false にしてシーン遷移を避ける。
func select(id: StringName, go: bool = true) -> void:
	GameSession.adventurer_id = id
	if go:
		get_tree().change_scene_to_file(MATCHING_SCENE)
