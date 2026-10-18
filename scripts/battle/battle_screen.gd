extends Control
## 戦闘画面。見た目はすべて仮（色付きの四角と文字）。画面の部品はコードで組み立てる。
## 敵は複数体、カードを使うとき敵を選ぶ操作、デバッグ機能（F1/F3/F5）を含む。

const BALANCE_PATH := "res://data/balance.tres"
const CARD_DIR := "res://data/cards"
const ENCOUNTER_DIR := "res://data/encounters"
const DEFAULT_ENCOUNTER := "silverfish"
const ATTACK_COLOR := Color(0.75, 0.3, 0.28)
const SKILL_COLOR := Color(0.3, 0.5, 0.75)

var _balance: BalanceConfig
var _battle: BattleState
var _encounter: EncounterData
var _encounters: Array[EncounterData] = []
var _cards: Array[CardData] = []

var _pending_card: CardInstance = null

var _seed_label: Label
var _hint_label: Label
var _enemy_row: HBoxContainer
var _player_stats: Label
var _pile_info: Label
var _fatigue_info: Label
var _hand_box: HBoxContainer
var _end_button: Button
var _log_label: RichTextLabel
var _result_overlay: CenterContainer
var _result_panel: PanelContainer
var _result_label: Label
var _debug_panel: PanelContainer
var _debug_encounter: OptionButton


func _ready() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig
	for r in _load_dir(ENCOUNTER_DIR):
		_encounters.append(r as EncounterData)
	for r in _load_dir(CARD_DIR):
		_cards.append(r as CardData)
	_build_ui()
	_start_battle(-1, DEFAULT_ENCOUNTER)


func _load_dir(path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var names: Array[String] = []
	for f in DirAccess.get_files_at(path):
		names.append(f.trim_suffix(".remap"))
	names.sort()
	for n in names:
		if n.ends_with(".tres"):
			result.append(load("%s/%s" % [path, n]))
	return result


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_cancel_targeting()
	if not OS.is_debug_build() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_F1:
			_debug_win()
		KEY_F3:
			_debug_panel.visible = not _debug_panel.visible
		KEY_F5:
			_battle.heal(_battle.player, _battle.player.max_hp)
			_refresh()
		KEY_F6:
			_start_battle(RunState.run_seed, String(_encounter.id))


# ---------- 画面の組み立て ----------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.13, 0.17)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_seed_label = _make_label(14)
	_seed_label.position = Vector2(12, 8)
	add_child(_seed_label)

	_hint_label = _make_label(18)
	_hint_label.position = Vector2(400, 8)
	_hint_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	add_child(_hint_label)

	_enemy_row = HBoxContainer.new()
	_enemy_row.position = Vector2(180, 40)
	_enemy_row.size = Vector2(700, 250)
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_row.add_theme_constant_override("separation", 10)
	add_child(_enemy_row)

	_player_stats = _make_label(20)
	_player_stats.position = Vector2(30, 300)
	add_child(_player_stats)

	_pile_info = _make_label(18)
	_pile_info.position = Vector2(30, 410)
	add_child(_pile_info)
	_fatigue_info = _make_label(14)
	_fatigue_info.position = Vector2(30, 470)
	add_child(_fatigue_info)

	_log_label = RichTextLabel.new()
	_log_label.position = Vector2(900, 40)
	_log_label.size = Vector2(360, 340)
	_log_label.scroll_following = true
	_log_label.add_theme_font_size_override("normal_font_size", 13)
	add_child(_log_label)

	_hand_box = HBoxContainer.new()
	_hand_box.position = Vector2(110, 500)
	_hand_box.size = Vector2(1000, 200)
	_hand_box.add_theme_constant_override("separation", 4)
	add_child(_hand_box)

	_end_button = Button.new()
	_end_button.text = "ターン終了"
	_end_button.position = Vector2(1090, 400)
	_end_button.size = Vector2(160, 56)
	_end_button.pressed.connect(_on_end_turn)
	add_child(_end_button)

	_build_result()
	_build_debug_panel()


func _build_result() -> void:
	_result_overlay = CenterContainer.new()
	_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.visible = false
	add_child(_result_overlay)
	_result_panel = PanelContainer.new()
	_result_panel.custom_minimum_size = Vector2(400, 200)
	_result_overlay.add_child(_result_panel)
	var rbox := VBoxContainer.new()
	rbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_panel.add_child(rbox)
	_result_label = _make_label(32)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rbox.add_child(_result_label)
	var again_same := Button.new()
	again_same.text = "同じシードでもう一度"
	again_same.pressed.connect(func() -> void: _start_battle(RunState.run_seed, String(_encounter.id)))
	rbox.add_child(again_same)
	var again_new := Button.new()
	again_new.text = "新しいシードで遊ぶ"
	again_new.pressed.connect(func() -> void: _start_battle(-1, String(_encounter.id)))
	rbox.add_child(again_new)


## デバッグ実行のときだけ使える操作パネル（F3で開閉）
func _build_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.position = Vector2(340, 300)
	_debug_panel.visible = false
	add_child(_debug_panel)
	var box := VBoxContainer.new()
	_debug_panel.add_child(box)
	var title := _make_label(14)
	title.text = "デバッグ（F1:即勝利 F3:このパネル F5:HP全快 F6:同じシードで最初から）"
	box.add_child(title)
	var enc_row := HBoxContainer.new()
	box.add_child(enc_row)
	var enc_label := _make_label(14)
	enc_label.text = "戦闘を選ぶ："
	enc_row.add_child(enc_label)
	_debug_encounter = OptionButton.new()
	for e in _encounters:
		_debug_encounter.add_item(e.display_name)
	_debug_encounter.item_selected.connect(func(i: int) -> void:
		_start_battle(RunState.run_seed, String(_encounters[i].id)))
	enc_row.add_child(_debug_encounter)
	var card_label := _make_label(14)
	card_label.text = "クリックで手札に追加："
	box.add_child(card_label)
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for data in _cards:
		var b := Button.new()
		b.text = data.display_name
		b.pressed.connect(func() -> void:
			_battle.debug_add_to_hand(data)
			print("[Debug] 手札に追加: ", data.display_name))
		grid.add_child(b)


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	return l


# ---------- 戦闘の開始と進行 ----------

func _start_battle(seed_value: int, encounter_id: String) -> void:
	RunState.start_run(seed_value)
	CardInstance.reset_uids()
	_encounter = null
	for e in _encounters:
		if String(e.id) == encounter_id:
			_encounter = e
	if _encounter == null:
		_encounter = _encounters[0]
	var deck: Array[CardInstance] = []
	for i in 5:
		deck.append(CardInstance.new(load("%s/strike.tres" % CARD_DIR) as CardData))
		deck.append(CardInstance.new(load("%s/defend.tres" % CARD_DIR) as CardData))
	_battle = BattleState.new(_balance, _encounter, deck, RunState.rng)
	_battle.changed.connect(_refresh)
	_battle.log_added.connect(_on_log)
	_battle.finished.connect(_on_finished)
	_log_label.clear()
	_result_overlay.visible = false
	_pending_card = null
	_seed_label.text = "シード: %d　戦闘: %s" % [RunState.run_seed, _encounter.display_name]
	for i in _encounters.size():
		if _encounters[i] == _encounter:
			_debug_encounter.select(i)
	_battle.start()


func _on_log(text: String) -> void:
	_log_label.append_text(text + "\n")


func _on_end_turn() -> void:
	_pending_card = null
	_battle.end_turn()
	_refresh()


func _on_finished(won: bool) -> void:
	_pending_card = null
	_refresh()
	_result_label.text = "勝利！" if won else "敗北…"
	_result_overlay.visible = true


func _debug_win() -> void:
	print("[Debug] 即勝利")
	for e in _battle.enemies:
		if e.is_alive():
			_battle.lose_hp(e, e.hp)


func _on_card_pressed(card: CardInstance) -> void:
	if not _battle.can_play(card):
		return
	if _pending_card == card:
		_cancel_targeting()
		return
	var alive := _battle.living_enemies()
	if card.data.needs_target() and alive.size() > 1:
		_pending_card = card
		_refresh()
	else:
		_battle.play_card(card, alive[0] if not alive.is_empty() else null)


func _on_enemy_pressed(enemy: BattleEnemy) -> void:
	if _pending_card == null or not enemy.is_alive():
		return
	var card := _pending_card
	_pending_card = null
	_battle.play_card(card, enemy)


func _cancel_targeting() -> void:
	if _pending_card != null:
		_pending_card = null
		_refresh()


# ---------- 表示の更新 ----------

func _refresh() -> void:
	var b := _battle
	var p := b.player
	_hint_label.text = "対象の敵をクリックしてね（右クリックでやめる）" if _pending_card != null else ""
	_player_stats.text = "HP %d / %d\nブロック %d\nエネルギー %d / %d\n%s" % [
		p.hp, p.max_hp, p.block, b.energy, _balance.energy_per_turn, p.status_text()]
	_pile_info.text = "山札 %d枚\n捨て札 %d枚" % [b.draw_pile.size(), b.discard_pile.size()]
	var warn := "（次のシャッフルで疲労が増える）" if b.next_reshuffle_adds_fatigue() else ""
	_fatigue_info.text = "疲労 %d / シャッフル %d回%s" % [b.fatigue, b.reshuffle_count, warn]
	_end_button.disabled = b.phase != BattleState.Phase.PLAYER_TURN
	_rebuild_enemies()
	_rebuild_hand()


func _rebuild_enemies() -> void:
	for child in _enemy_row.get_children():
		child.queue_free()
	for enemy in _battle.enemies:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 230)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 15)
		var color := Color(0.5, 0.45, 0.3)
		if not enemy.is_alive():
			btn.text = "%s\n\n倒れた" % enemy.display_name
			color = Color(0.2, 0.2, 0.2)
			btn.disabled = true
		else:
			var lines: Array[String] = []
			lines.append("次: " + enemy.next_action.intent_text(_battle, enemy))
			var cd := enemy.turns_until_countdown()
			if cd > 0:
				lines.append("大技まであと%dターン" % cd)
			elif cd == 0:
				lines.append("今回が大技！")
			lines.append("")
			lines.append(enemy.display_name)
			lines.append("HP %d / %d" % [enemy.hp, enemy.max_hp])
			if enemy.block > 0:
				lines.append("ブロック %d" % enemy.block)
			if not enemy.statuses.is_empty():
				lines.append(enemy.status_text())
			btn.text = "\n".join(lines)
			if _pending_card != null and _pending_card.data.needs_target():
				color = Color(0.75, 0.6, 0.2)
		btn.add_theme_stylebox_override("normal", _box(color))
		btn.add_theme_stylebox_override("hover", _box(color.lightened(0.15)))
		btn.add_theme_stylebox_override("pressed", _box(color.darkened(0.2)))
		btn.add_theme_stylebox_override("disabled", _box(color))
		btn.pressed.connect(_on_enemy_pressed.bind(enemy))
		_enemy_row.add_child(btn)


func _rebuild_hand() -> void:
	for child in _hand_box.get_children():
		child.queue_free()
	for card in _battle.hand:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(98, 170)
		var memo := "\n思い出 %d" % card.omoide if card.omoide > 0 else ""
		btn.text = "%s\nコスト %d%s\n\n%s" % [card.data.display_name, card.data.cost, memo, card.data.describe()]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 13)
		var color := ATTACK_COLOR if card.data.card_type == CardData.CardType.ATTACK else SKILL_COLOR
		if card == _pending_card:
			color = color.lightened(0.35)
		btn.add_theme_stylebox_override("normal", _box(color))
		btn.add_theme_stylebox_override("hover", _box(color.lightened(0.2)))
		btn.add_theme_stylebox_override("pressed", _box(color.darkened(0.2)))
		btn.add_theme_stylebox_override("disabled", _box(color.darkened(0.55)))
		btn.disabled = not _battle.can_play(card)
		btn.pressed.connect(_on_card_pressed.bind(card))
		_hand_box.add_child(btn)


func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	return s
