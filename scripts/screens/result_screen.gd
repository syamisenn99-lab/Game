extends Control
## 結果画面：勝敗、到達した戦闘、最終デッキ枚数、記憶、いちばん思い出が多かったカード、シード。


func _ready() -> void:
	if not RunState.active:
		RunState.start_run(-1)
	UIKit.background(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var head := UIKit.label("ラン達成！ ボスに勝った！" if RunState.won else "力尽きた…", 40)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	box.add_child(UIKit.label("到達した戦闘：%d / %d" % [RunState.battle_number, RunState.total_battles()], 20))
	box.add_child(UIKit.label("最終デッキ：%d枚（手放した枚数：%d）" % [RunState.deck.size(), RunState.released_count], 20))
	var best := "なし"
	if RunState.best_omoide > 0:
		best = "%s（思い出 %d）" % [RunState.best_omoide_card, RunState.best_omoide]
	box.add_child(UIKit.label("いちばん思い出が多かったカード：%s" % best, 20))
	box.add_child(UIKit.label("使ったカードの数：%d" % RunState.cards_played, 20))
	box.add_child(UIKit.label("記憶（%d / %d）：" % [RunState.memories.size(), RunState.balance.memory_slots], 20))
	if RunState.memories.is_empty():
		box.add_child(UIKit.label("　なし", 16))
	for m in RunState.memories:
		box.add_child(UIKit.label("　【%s】%s　%s" % [m.data.display_name, m.tier_label(), m.describe()], 16))
	box.add_child(UIKit.label("シード：%d" % RunState.run_seed, 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	row.add_child(UIKit.button("同じシードでもう一度", func() -> void:
		RunState.start_run(RunState.run_seed)
		RunState.go_to(RunState.SCENE_BATTLE), Vector2(240, 56)))
	row.add_child(UIKit.button("タイトルへ", func() -> void: RunState.go_to(RunState.SCENE_TITLE), Vector2(240, 56)))
