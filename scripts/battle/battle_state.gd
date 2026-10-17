class_name BattleState
extends RefCounted
## 戦闘の進行と計算（画面に依存しない。ヘッドレステストで動かせる）。

signal changed
signal log_added(text: String)
signal finished(won: bool)

enum Phase { PLAYER_TURN, ENEMY_TURN, WON, LOST }

var balance: BalanceConfig
var rng: RandomNumberGenerator
var enemy_data: EnemyData

var phase: Phase = Phase.PLAYER_TURN
var turn: int = 0

var player_hp: int
var player_max_hp: int
var player_block: int = 0
var energy: int = 0

var enemy_hp: int
var enemy_block: int = 0
var enemy_action_index: int = 0

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []

var reshuffle_count: int = 0
var fatigue: int = 0


func _init(p_balance: BalanceConfig, p_enemy: EnemyData, deck: Array[CardData], p_rng: RandomNumberGenerator, start_hp: int = -1) -> void:
	balance = p_balance
	enemy_data = p_enemy
	rng = p_rng
	player_max_hp = balance.max_hp
	player_hp = player_max_hp if start_hp < 0 else start_hp
	enemy_hp = enemy_data.max_hp
	draw_pile = deck.duplicate()
	_shuffle(draw_pile)
	print("[Battle] 開始 敵=%s HP=%d デッキ=%d枚" % [enemy_data.display_name, enemy_hp, deck.size()])


func start() -> void:
	_start_player_turn()


func current_enemy_action() -> EnemyAction:
	return enemy_data.actions[enemy_action_index % enemy_data.actions.size()]


func can_play(card: CardData) -> bool:
	return phase == Phase.PLAYER_TURN and hand.has(card) and card.cost <= energy


func play_card(card: CardData) -> bool:
	if not can_play(card):
		return false
	hand.erase(card)
	energy -= card.cost
	discard_pile.append(card)
	_log("「%s」を使った（残りエネルギー%d）" % [card.display_name, energy])
	if card.block > 0:
		player_block += card.block
		_log("ブロックを%d得た（合計%d）" % [card.block, player_block])
	if card.damage > 0:
		_damage_enemy(card.damage)
	changed.emit()
	return true


func end_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	phase = Phase.ENEMY_TURN
	discard_pile.append_array(hand)
	hand.clear()
	_log("ターン終了")
	_enemy_act()
	if phase == Phase.LOST:
		return
	_start_player_turn()


## 次のリシャッフルで疲労が増えるか（画面表示用）
func next_reshuffle_adds_fatigue() -> bool:
	return reshuffle_count + 1 >= balance.fatigue_start_reshuffle


func next_draw_count() -> int:
	return maxi(balance.min_draw, balance.draw_per_turn - fatigue)


func _start_player_turn() -> void:
	turn += 1
	phase = Phase.PLAYER_TURN
	player_block = 0
	energy = balance.energy_per_turn
	var count := next_draw_count()
	_log("--- %dターン目 --- カードを%d枚引く" % [turn, count])
	for i in count:
		_draw_one()
	changed.emit()


func _draw_one() -> void:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return
		_reshuffle()
	var card: CardData = draw_pile.pop_back()
	if hand.size() >= balance.hand_limit:
		discard_pile.append(card)
		_log("手札がいっぱいで「%s」は捨て札へ" % card.display_name)
	else:
		hand.append(card)


func _reshuffle() -> void:
	reshuffle_count += 1
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	_shuffle(draw_pile)
	if reshuffle_count >= balance.fatigue_start_reshuffle:
		fatigue += 1
		_log("捨て札をシャッフルした（%d回目）疲労が%dになった" % [reshuffle_count, fatigue])
	else:
		_log("捨て札をシャッフルした（%d回目）" % reshuffle_count)


func _shuffle(cards: Array[CardData]) -> void:
	# Fisher-Yates。乱数はシード由来の rng だけを使う
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


func _damage_enemy(amount: int) -> void:
	var absorbed := mini(enemy_block, amount)
	enemy_block -= absorbed
	var dealt := amount - absorbed
	enemy_hp = maxi(0, enemy_hp - dealt)
	_log("%sに%dダメージ（残りHP%d）" % [enemy_data.display_name, dealt, enemy_hp])
	if enemy_hp <= 0:
		phase = Phase.WON
		_log("勝利！")
		print("[Battle] 勝利 ターン=%d プレイヤーHP=%d" % [turn, player_hp])
		finished.emit(true)


func _enemy_act() -> void:
	enemy_block = 0
	var action := current_enemy_action()
	enemy_action_index += 1
	_log("%sの「%s」" % [enemy_data.display_name, action.label])
	if action.block > 0:
		enemy_block += action.block
	if action.damage > 0:
		var absorbed := mini(player_block, action.damage)
		player_block -= absorbed
		var dealt := action.damage - absorbed
		player_hp = maxi(0, player_hp - dealt)
		_log("%dダメージを受けた（ブロックで%d軽減、残りHP%d）" % [dealt, absorbed, player_hp])
	for i in action.discard_top:
		if draw_pile.is_empty():
			_log("山札が空なので何も起きなかった")
			break
		var lost: CardData = draw_pile.pop_back()
		discard_pile.append(lost)
		_log("山札の上の「%s」が捨て札へ送られた" % lost.display_name)
	if player_hp <= 0:
		phase = Phase.LOST
		_log("敗北…")
		print("[Battle] 敗北 ターン=%d 敵HP=%d" % [turn, enemy_hp])
		changed.emit()
		finished.emit(false)


func _log(text: String) -> void:
	print("[Battle] ", text)
	log_added.emit(text)
