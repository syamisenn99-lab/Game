class_name BattleState
extends RefCounted
## 戦闘の進行と計算（画面に依存しない。ヘッドレステストで動かせる）。

signal changed
signal log_added(text: String)
signal finished(won: bool)
## 記憶が発動した（画面で光らせる用）
signal memory_triggered(memory: MemoryInstance)

enum Phase { PLAYER_TURN, ENEMY_TURN, WON, LOST }

var balance: BalanceConfig
var rng: RandomNumberGenerator

var phase: Phase = Phase.PLAYER_TURN
var turn: int = 0

var player: Combatant = Combatant.new()
var enemies: Array[BattleEnemy] = []
var energy: int = 0

var draw_pile: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []

var reshuffle_count: int = 0
var fatigue: int = 0

## ラン全体から受け取るもの
var memories: Array[MemoryInstance] = []
var released_count: int = 0

## 今使っているカードにだけ上乗せする攻撃ダメージ（記憶「研ぎ澄まし」）
var attack_bonus: int = 0
var cards_played: int = 0
var _plays_this_turn: Dictionary = {}  # CardType -> 枚数


func _init(p_balance: BalanceConfig, encounter: EncounterData, deck: Array[CardInstance], p_rng: RandomNumberGenerator,
		start_hp: int = -1, p_memories: Array[MemoryInstance] = [], p_released_count: int = 0) -> void:
	balance = p_balance
	rng = p_rng
	memories = p_memories
	released_count = p_released_count
	player.display_name = "あなた"
	player.max_hp = balance.max_hp
	player.hp = player.max_hp if start_hp < 0 else start_hp
	_spawn_enemies(encounter)
	draw_pile = deck.duplicate()
	_shuffle(draw_pile)
	print("[Battle] 開始 戦闘=%s 敵=%d体 デッキ=%d枚" % [encounter.display_name, enemies.size(), deck.size()])


func start() -> void:
	_start_player_turn()


func add_log(text: String) -> void:
	print("[Battle] ", text)
	log_added.emit(text)


# ---------- 問い合わせ ----------

func living_enemies() -> Array[BattleEnemy]:
	var result: Array[BattleEnemy] = []
	for e in enemies:
		if e.is_alive():
			result.append(e)
	return result


func can_play(card: CardInstance) -> bool:
	return phase == Phase.PLAYER_TURN and hand.has(card) and card.data.cost <= energy


## 次のリシャッフルで疲労が増えるか（画面表示用）
func next_reshuffle_adds_fatigue() -> bool:
	return reshuffle_count + 1 >= balance.fatigue_start_reshuffle


func next_draw_count() -> int:
	return maxi(balance.min_draw, balance.draw_per_turn - fatigue)


## 攻撃のダメージ計算：(基本+筋力) → 弱体(攻撃側) → 脆弱(受ける側)。各段階で端数切り捨て
func calc_damage(base: int, source: Combatant, target: Combatant) -> int:
	var d := maxi(0, base + source.stacks(Status.STRENGTH))
	if source.stacks(Status.WEAK) > 0:
		d = floori(d * balance.weak_multiplier)
	if target.stacks(Status.VULNERABLE) > 0:
		d = floori(d * balance.vulnerable_multiplier)
	return d


func resolve_targets(source: Combatant, target: EffectData.Target, chosen: Combatant) -> Array[Combatant]:
	var result: Array[Combatant] = []
	var from_player := source == player
	match target:
		EffectData.Target.SELF:
			result.append(source)
		EffectData.Target.OPPONENT:
			if not from_player:
				result.append(player)
			elif chosen != null and chosen.is_alive():
				result.append(chosen)
			else:
				var alive := living_enemies()
				if not alive.is_empty():
					result.append(alive[0])
		EffectData.Target.RANDOM_OPPONENT:
			if not from_player:
				result.append(player)
			else:
				var alive := living_enemies()
				if not alive.is_empty():
					result.append(alive[rng.randi_range(0, alive.size() - 1)])
		EffectData.Target.ALL_OPPONENTS:
			if from_player:
				for e in living_enemies():
					result.append(e)
			else:
				result.append(player)
	return result


# ---------- プレイヤーの操作 ----------

func play_card(card: CardInstance, chosen: BattleEnemy = null) -> bool:
	if not can_play(card):
		return false
	hand.erase(card)
	energy -= card.data.cost
	cards_played += 1
	add_log("「%s」を使った（残りエネルギー%d）" % [card.data.display_name, energy])
	var type_key := int(card.data.card_type)
	_plays_this_turn[type_key] = int(_plays_this_turn.get(type_key, 0)) + 1
	attack_bonus = 0
	_fire_memories(MemoryData.Timing.CARD_PLAYED, card)
	for e in card.data.effects:
		if phase != Phase.PLAYER_TURN:
			break
		e.apply(self, player, chosen, card)
	attack_bonus = 0
	card.omoide = mini(card.omoide + 1, balance.omoide_max)
	discard_pile.append(card)
	changed.emit()
	return true


func end_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	phase = Phase.ENEMY_TURN
	var kept: Array[CardInstance] = []
	for c in hand:
		if c.has_keyword(Keyword.RETAIN):
			kept.append(c)
		else:
			discard_pile.append(c)
	hand = kept
	add_log("ターン終了")
	for m in memories:
		if m.sealed_turns > 0:
			m.sealed_turns -= 1
	_end_of_turn_tick(player)
	if _terminal():
		return
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		_enemy_act(enemy)
		if _terminal():
			return
	_start_player_turn()


# ---------- 効果から呼ばれる処理 ----------

func hit(source: Combatant, target: Combatant, base: int) -> void:
	var amount := calc_damage(base, source, target)
	var absorbed := mini(target.block, amount)
	target.block -= absorbed
	var dealt := amount - absorbed
	target.hp = maxi(0, target.hp - dealt)
	add_log("%sに%dダメージ（ブロックで%d軽減、残りHP%d）" % [target.display_name, dealt, absorbed, target.hp])
	_after_damage(target)


func lose_hp(target: Combatant, amount: int) -> void:
	target.hp = maxi(0, target.hp - amount)
	add_log("%sは%dのダメージ（残りHP%d）" % [target.display_name, amount, target.hp])
	_after_damage(target)


func heal(target: Combatant, amount: int) -> void:
	target.hp = mini(target.max_hp, target.hp + amount)
	add_log("%sはHPを%d回復（HP%d）" % [target.display_name, amount, target.hp])


func gain_block(who: Combatant, amount: int) -> void:
	who.block += amount
	add_log("%sはブロックを%d得た（合計%d）" % [who.display_name, amount, who.block])


func add_status(target: Combatant, id: StringName, amount: int) -> void:
	target.add_stacks(id, amount)
	add_log("%sに%s%dが付いた（合計%d）" % [target.display_name, Status.label(id), amount, target.stacks(id)])


func gain_energy(amount: int) -> void:
	energy += amount
	add_log("エネルギーを%d得た（合計%d）" % [amount, energy])


func draw_cards(count: int) -> void:
	for i in count:
		_draw_one()


func discard_deck_top(count: int) -> void:
	for i in count:
		if draw_pile.is_empty():
			add_log("山札が空なので何も起きなかった")
			return
		var lost: CardInstance = draw_pile.pop_back()
		discard_pile.append(lost)
		add_log("山札の上の「%s」が捨て札へ送られた" % lost.data.display_name)


func discard_whole_hand() -> void:
	add_log("手札%d枚をすべて捨てさせられた" % hand.size())
	discard_pile.append_array(hand)
	hand.clear()


## デバッグ用：好きなカードを手札に足す
func debug_add_to_hand(data: CardData) -> void:
	hand.append(CardInstance.new(data))
	changed.emit()


## ランダムな記憶を数ターン封印する（敵の行動用）
func seal_random_memory(turns: int) -> void:
	var candidates: Array[MemoryInstance] = []
	for m in memories:
		if m.sealed_turns <= 0:
			candidates.append(m)
	if candidates.is_empty():
		add_log("封印できる記憶がなかった")
		return
	var target := candidates[rng.randi_range(0, candidates.size() - 1)]
	target.sealed_turns = turns
	add_log("記憶「%s」が%dターン封印された" % [target.data.display_name, turns])


# ---------- 内部処理 ----------

## 指定のタイミングの記憶を、持っている順に発動する
func _fire_memories(timing: MemoryData.Timing, card: CardInstance = null) -> void:
	for m in memories:
		if _terminal_for_memories(timing):
			return
		if m.data.timing != timing or m.sealed_turns > 0:
			continue
		if timing == MemoryData.Timing.CARD_PLAYED:
			var type_key := int(card.data.card_type)
			if not m.data.matches_card(card, int(_plays_this_turn.get(type_key, 0))):
				continue
		var value := m.data.values[m.tier]
		if value <= 0:
			continue
		add_log("記憶「%s」（%s）が発動：%s" % [m.data.display_name, m.tier_label(), m.data.describe(m.tier)])
		memory_triggered.emit(m)
		for template in m.data.effects:
			var e: EffectData = template.duplicate()
			if e.memory_scaled:
				e.set_value(value)
			e.apply(self, player, null, null)


func _terminal_for_memories(timing: MemoryData.Timing) -> bool:
	# 戦闘勝利時の記憶は、勝った後に発動するので止めない
	if timing == MemoryData.Timing.BATTLE_WIN:
		return phase == Phase.LOST
	return phase == Phase.WON or phase == Phase.LOST


func _spawn_enemies(encounter: EncounterData) -> void:
	var counts := {}
	for d in encounter.enemies:
		counts[d.id] = int(counts.get(d.id, 0)) + 1
	var seen := {}
	for d in encounter.enemies:
		var nm := d.display_name
		if int(counts[d.id]) > 1:
			var n := int(seen.get(d.id, 0))
			seen[d.id] = n + 1
			nm += String.chr(65 + n)
		var e := BattleEnemy.new(d, nm)
		e.choose_next(rng, true)
		enemies.append(e)


func _start_player_turn() -> void:
	turn += 1
	phase = Phase.PLAYER_TURN
	player.block = 0
	energy = balance.energy_per_turn
	_plays_this_turn.clear()
	attack_bonus = 0
	var count := next_draw_count()
	add_log("--- %dターン目 --- カードを%d枚引く" % [turn, count])
	draw_cards(count)
	if turn == 1:
		_fire_memories(MemoryData.Timing.BATTLE_START)
	_fire_memories(MemoryData.Timing.TURN_START)
	changed.emit()


func _draw_one() -> void:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return
		_reshuffle()
	var card: CardInstance = draw_pile.pop_back()
	if hand.size() >= balance.hand_limit:
		discard_pile.append(card)
		add_log("手札がいっぱいで「%s」は捨て札へ" % card.data.display_name)
	else:
		hand.append(card)


func _reshuffle() -> void:
	reshuffle_count += 1
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	_shuffle(draw_pile)
	if reshuffle_count >= balance.fatigue_start_reshuffle:
		fatigue += 1
		add_log("捨て札をシャッフルした（%d回目）疲労が%dになった" % [reshuffle_count, fatigue])
	else:
		add_log("捨て札をシャッフルした（%d回目）" % reshuffle_count)
	_fire_memories(MemoryData.Timing.RESHUFFLE)


func _shuffle(cards: Array[CardInstance]) -> void:
	# Fisher-Yates。乱数はシード由来の rng だけを使う
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


func _enemy_act(enemy: BattleEnemy) -> void:
	enemy.block = 0
	var action := enemy.next_action
	add_log("%sの「%s」" % [enemy.display_name, action.label])
	for e in action.effects:
		e.apply(self, enemy, player, null)
		if _terminal():
			return
	_end_of_turn_tick(enemy)
	if _terminal():
		return
	enemy.choose_next(rng)


## ターン終了時：毒のダメージ（その後1減る）、脆弱・弱体が1減る
func _end_of_turn_tick(who: Combatant) -> void:
	var poison := who.stacks(Status.POISON)
	if poison > 0:
		add_log("%sは毒で%dダメージ" % [who.display_name, poison])
		lose_hp(who, poison)
		who.add_stacks(Status.POISON, -1)
	who.add_stacks(Status.VULNERABLE, -1)
	who.add_stacks(Status.WEAK, -1)


func _after_damage(target: Combatant) -> void:
	if target.hp > 0:
		return
	if target == player:
		_finish(false)
	else:
		add_log("%sを倒した" % target.display_name)
		if living_enemies().is_empty():
			_finish(true)


func _finish(won: bool) -> void:
	if phase == Phase.WON or phase == Phase.LOST:
		return
	phase = Phase.WON if won else Phase.LOST
	if won:
		_fire_memories(MemoryData.Timing.BATTLE_WIN)
	add_log("勝利！" if won else "敗北…")
	print("[Battle] %s ターン=%d プレイヤーHP=%d" % ["勝利" if won else "敗北", turn, player.hp])
	changed.emit()
	finished.emit(won)


func _terminal() -> bool:
	return phase == Phase.WON or phase == Phase.LOST
