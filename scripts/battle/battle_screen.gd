extends Control
## 戦闘画面（マイルストーン1：固定デッキ10枚 vs 紙魚）。
## 見た目はすべて仮（色付きの四角と文字）。画面の部品はコードで組み立てる。

const BALANCE_PATH := "res://data/balance.tres"
const ENEMY_PATH := "res://data/enemies/silverfish.tres"
const STRIKE_PATH := "res://data/cards/strike.tres"
const DEFEND_PATH := "res://data/cards/defend.tres"
const ATTACK_COLOR := Color(0.75, 0.3, 0.28)
const SKILL_COLOR := Color(0.3, 0.5, 0.75)

var _balance: BalanceConfig
var _battle: BattleState

var _seed_label: Label
var _enemy_name: Label
var _enemy_hp: Label
var _enemy_intent: Label
var _player_stats: Label
var _pile_info: Label
var _fatigue_info: Label
var _hand_box: HBoxContainer
var _end_button: Button
var _log_label: RichTextLabel
var _result_overlay: CenterContainer
var _result_panel: PanelContainer
var _result_label: Label


func _ready() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig
	_build_ui()
	_start_battle(-1)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.13, 0.17)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_seed_label = _make_label(14)
	_seed_label.position = Vector2(12, 8)
	add_child(_seed_label)

	# 敵
	var enemy_box := VBoxContainer.new()
	enemy_box.position = Vector2(460, 60)
	enemy_box.custom_minimum_size = Vector2(360, 0)
	enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(enemy_box)
	_enemy_intent = _make_label(26)
	_enemy_intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_box.add_child(_enemy_intent)
	var enemy_sprite := ColorRect.new()
	enemy_sprite.color = Color(0.55, 0.5, 0.35)
	enemy_sprite.custom_minimum_size = Vector2(160, 110)
	enemy_box.add_child(enemy_sprite)
	_enemy_name = _make_label(22)
	_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_box.add_child(_enemy_name)
	_enemy_hp = _make_label(20)
	_enemy_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_box.add_child(_enemy_hp)

	# 自分
	_player_stats = _make_label(22)
	_player_stats.position = Vector2(40, 300)
	add_child(_player_stats)

	# 山札・捨て札・疲労
	_pile_info = _make_label(18)
	_pile_info.position = Vector2(40, 400)
	add_child(_pile_info)
	_fatigue_info = _make_label(16)
	_fatigue_info.position = Vector2(40, 460)
	add_child(_fatigue_info)

	# ログ
	_log_label = RichTextLabel.new()
	_log_label.position = Vector2(900, 60)
	_log_label.size = Vector2(360, 380)
	_log_label.scroll_following = true
	_log_label.add_theme_font_size_override("normal_font_size", 14)
	add_child(_log_label)

	# 手札
	_hand_box = HBoxContainer.new()
	_hand_box.position = Vector2(140, 500)
	_hand_box.size = Vector2(900, 200)
	_hand_box.add_theme_constant_override("separation", 8)
	add_child(_hand_box)

	_end_button = Button.new()
	_end_button.text = "ターン終了"
	_end_button.position = Vector2(1080, 620)
	_end_button.size = Vector2(160, 60)
	_end_button.pressed.connect(_on_end_turn)
	add_child(_end_button)

	# 結果（画面全体を覆う中央寄せの枠の中に置く）
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
	again_same.pressed.connect(func() -> void: _start_battle(RunState.run_seed))
	rbox.add_child(again_same)
	var again_new := Button.new()
	again_new.text = "新しいシードで遊ぶ"
	again_new.pressed.connect(func() -> void: _start_battle(-1))
	rbox.add_child(again_new)


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _start_battle(seed_value: int) -> void:
	RunState.start_run(seed_value)
	var deck: Array[CardData] = []
	var strike := load(STRIKE_PATH) as CardData
	var defend := load(DEFEND_PATH) as CardData
	for i in 5:
		deck.append(strike)
		deck.append(defend)
	_battle = BattleState.new(_balance, load(ENEMY_PATH) as EnemyData, deck, RunState.rng)
	_battle.changed.connect(_refresh)
	_battle.log_added.connect(_on_log)
	_battle.finished.connect(_on_finished)
	_log_label.clear()
	_result_overlay.visible = false
	_seed_label.text = "シード: %d" % RunState.run_seed
	_battle.start()


func _on_log(text: String) -> void:
	_log_label.append_text(text + "\n")


func _on_end_turn() -> void:
	_battle.end_turn()
	_refresh()


func _on_finished(won: bool) -> void:
	_refresh()
	_result_label.text = "勝利！" if won else "敗北…"
	_result_overlay.visible = true


func _refresh() -> void:
	var b := _battle
	_enemy_name.text = b.enemy_data.display_name
	_enemy_hp.text = "HP %d / %d" % [b.enemy_hp, b.enemy_data.max_hp]
	if b.phase == BattleState.Phase.WON:
		_enemy_intent.text = ""
	else:
		_enemy_intent.text = "次: " + b.current_enemy_action().describe()
	_player_stats.text = "HP %d / %d\nブロック %d\nエネルギー %d / %d" % [
		b.player_hp, b.player_max_hp, b.player_block, b.energy, _balance.energy_per_turn]
	_pile_info.text = "山札 %d枚\n捨て札 %d枚" % [b.draw_pile.size(), b.discard_pile.size()]
	var warn := "（次のシャッフルで疲労が増える）" if b.next_reshuffle_adds_fatigue() else ""
	_fatigue_info.text = "疲労 %d / シャッフル %d回%s" % [b.fatigue, b.reshuffle_count, warn]
	_end_button.disabled = b.phase != BattleState.Phase.PLAYER_TURN
	_rebuild_hand()


func _rebuild_hand() -> void:
	for child in _hand_box.get_children():
		child.queue_free()
	for card in _battle.hand:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 160)
		btn.text = "%s\nコスト %d\n\n%s" % [card.display_name, card.cost, card.describe()]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var color := ATTACK_COLOR if card.card_type == CardData.CardType.ATTACK else SKILL_COLOR
		btn.add_theme_stylebox_override("normal", _box(color))
		btn.add_theme_stylebox_override("hover", _box(color.lightened(0.2)))
		btn.add_theme_stylebox_override("pressed", _box(color.darkened(0.2)))
		btn.add_theme_stylebox_override("disabled", _box(color.darkened(0.55)))
		btn.disabled = not _battle.can_play(card)
		btn.pressed.connect(_battle.play_card.bind(card))
		_hand_box.add_child(btn)


func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	return s
