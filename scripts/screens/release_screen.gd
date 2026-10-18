extends Control
## 手放し画面：デッキから手放すカードを選び、記憶になった場合の効果を見て、決める。
## このゲームの核なので、悩むための情報（現在の段階、次の段階まであと何回、3段階の効果量）を全部出す。

enum Sort { OMOIDE, TYPE }

var _selected: CardInstance = null
var _sort: Sort = Sort.OMOIDE

var _header: Label
var _status: Label
var _grid: HFlowContainer
var _detail: Label
var _release_button: Button
var _skip_button: Button
var _confirm_layer: Control
var _message: Label


func _ready() -> void:
	if not RunState.active:
		RunState.start_run(-1)
	if RunState.release_remaining <= 0:
		RunState.release_remaining = maxi(1, RunState.release_count_for(RunState.battle_number))
	_build_ui()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_F4:
			if _selected != null:
				_selected.omoide = mini(_selected.omoide + 5, RunState.balance.omoide_max)
				print("[Debug] %s の思い出を+5 → %d" % [_selected.data.display_name, _selected.omoide])
				_refresh()
		KEY_F5:
			RunState.hp = RunState.max_hp
			_refresh()
		KEY_F6:
			RunState.start_run(RunState.run_seed)
			RunState.go_to(RunState.SCENE_BATTLE)


func _build_ui() -> void:
	UIKit.background(self)
	_header = UIKit.label("", 26)
	_header.position = Vector2(20, 12)
	add_child(_header)
	_status = UIKit.label("", 16)
	_status.position = Vector2(20, 52)
	add_child(_status)

	var sort_label := UIKit.label("並び替え：", 15)
	sort_label.position = Vector2(20, 88)
	add_child(sort_label)
	var sort_option := OptionButton.new()
	sort_option.add_item("思い出の多い順")
	sort_option.add_item("種別順")
	sort_option.position = Vector2(100, 84)
	sort_option.item_selected.connect(func(i: int) -> void:
		_sort = i as Sort
		_refresh())
	add_child(sort_option)

	var mem_button := UIKit.button("記憶一覧", _show_memories, Vector2(120, 36))
	mem_button.position = Vector2(1140, 12)
	add_child(mem_button)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 124)
	scroll.size = Vector2(720, 580)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.custom_minimum_size = Vector2(700, 0)
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

	var panel := PanelContainer.new()
	panel.position = Vector2(760, 90)
	panel.size = Vector2(500, 540)
	add_child(panel)
	_detail = UIKit.label("", 17)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(480, 0)
	panel.add_child(_detail)

	_release_button = UIKit.button("このカードを手放す", _ask_confirm, Vector2(240, 56))
	_release_button.position = Vector2(760, 640)
	add_child(_release_button)
	_skip_button = UIKit.button("今回は手放さない（HP%d回復）" % RunState.balance.skip_release_heal, _skip, Vector2(250, 56))
	_skip_button.position = Vector2(1010, 640)
	add_child(_skip_button)

	_message = UIKit.label("", 18)
	_message.position = Vector2(760, 704)
	_message.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	add_child(_message)

	_confirm_layer = Control.new()
	_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.visible = false
	add_child(_confirm_layer)


func _sorted_deck() -> Array[CardInstance]:
	var cards: Array[CardInstance] = RunState.deck.duplicate()
	if _sort == Sort.OMOIDE:
		cards.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			if a.omoide != b.omoide:
				return a.omoide > b.omoide
			return a.uid < b.uid)
	else:
		cards.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			if a.data.card_type != b.data.card_type:
				return a.data.card_type < b.data.card_type
			if a.data.display_name != b.data.display_name:
				return a.data.display_name < b.data.display_name
			return a.uid < b.uid)
	return cards


func _refresh() -> void:
	_header.text = "戦闘%dに勝った！ 手放すカードを選ぼう" % RunState.battle_number
	_status.text = "残り手放し枚数：%d　／　デッキ %d枚　／　HP %d / %d　／　記憶 %d / %d　／　シード %d" % [
		RunState.release_remaining, RunState.deck.size(), RunState.hp, RunState.max_hp,
		RunState.memories.size(), RunState.balance.memory_slots, RunState.run_seed]
	for child in _grid.get_children():
		child.queue_free()
	if _selected != null and not RunState.deck.has(_selected):
		_selected = null
	for card in _sorted_deck():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(112, 62)
		btn.text = "%s\n思い出 %d" % [card.data.display_name, card.omoide]
		btn.add_theme_font_size_override("font_size", 14)
		var color := UIKit.card_color(card.data)
		if card == _selected:
			color = color.lightened(0.45)
		UIKit.color_button(btn, color)
		btn.pressed.connect(func() -> void:
			_selected = card
			_message.text = ""
			_refresh())
		_grid.add_child(btn)
	_release_button.disabled = _selected == null
	_detail.text = _detail_text()


func _detail_text() -> String:
	if _selected == null:
		return "デッキのカードを選ぶと、\n手放したときの「記憶」の効果が見られるよ。\n\n思い出が多いほど、強い記憶になる。\n早く手放して軽くするか、使い込んでから送り出すか。"
	var card := _selected
	var kind := "攻撃" if card.data.card_type == CardData.CardType.ATTACK else "スキル"
	var lines: Array[String] = []
	lines.append("【%s】　コスト%d　%s　思い出 %d" % [card.data.display_name, card.data.cost, kind, card.omoide])
	lines.append(card.data.describe())
	lines.append("")
	lines.append("▼ 記憶にした場合")
	var mem := card.data.memory
	var tier := RunState.memory_tier(card.omoide)
	lines.append("【%s】　現在の段階：%s" % [mem.display_name, MemoryData.TIER_LABELS[tier]])
	lines.append(mem.describe(tier))
	lines.append("")
	lines.append("3段階の効果量（淡い／確かな／鮮明な）：")
	lines.append(mem.describe(-1))
	var rest := RunState.uses_until_next_tier(card.omoide)
	if rest < 0:
		lines.append("もう最高の段階（鮮明な）だよ。")
	else:
		lines.append("次の段階（%s）まで、あと%d回使う" % [MemoryData.TIER_LABELS[tier + 1], rest])
	lines.append("")
	lines.append("▼ 継承：マイルストーン4で実装予定")
	return "\n".join(lines)


func _ask_confirm() -> void:
	if _selected == null:
		return
	for child in _confirm_layer.get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var tier := RunState.memory_tier(_selected.omoide)
	var text := "「%s」を手放して、記憶「%s」（%s）にする？\n決めたら、もう戻せないよ。" % [
		_selected.data.display_name, _selected.data.memory.display_name, MemoryData.TIER_LABELS[tier]]
	var l := UIKit.label(text, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	row.add_child(UIKit.button("手放す", _do_release, Vector2(160, 48)))
	row.add_child(UIKit.button("やめる", func() -> void: _confirm_layer.visible = false, Vector2(160, 48)))
	_confirm_layer.visible = true


func _do_release() -> void:
	_confirm_layer.visible = false
	var card := _selected
	_selected = null
	var m := RunState.release_card(card)
	_message.text = "「%s」を手放した。記憶「%s」（%s）になった。" % [card.data.display_name, m.data.display_name, m.tier_label()]
	if RunState.needs_forget():
		var panel := (load("res://scenes/memories/memories_panel.tscn") as PackedScene).instantiate() as MemoriesPanel
		add_child(panel)
		panel.setup(RunState.memories, true, RunState.balance.memory_slots)
		panel.forgot.connect(func(forgotten: MemoryInstance) -> void:
			RunState.forget_memory(forgotten)
			_message.text += "　記憶「%s」を忘れた。" % forgotten.data.display_name
			_after_pick())
	else:
		_after_pick()


func _skip() -> void:
	RunState.skip_release()
	_message.text = "手放さなかった。HPを%d回復した。" % RunState.balance.skip_release_heal
	_after_pick()


func _after_pick() -> void:
	if RunState.release_remaining <= 0:
		RunState.advance_to_next_battle()
		RunState.go_to(RunState.SCENE_BATTLE)
	else:
		_refresh()


func _show_memories() -> void:
	var panel := (load("res://scenes/memories/memories_panel.tscn") as PackedScene).instantiate() as MemoriesPanel
	add_child(panel)
	panel.setup(RunState.memories, false, RunState.balance.memory_slots)
