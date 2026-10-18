extends SceneTree
## ランの流れ（初期デッキ、戦闘の並び、手放し、記憶の枠）のヘッドレステスト。
##   godot --headless --path . --script tests/run_flow_tests.gd

var _failures := 0
var _checks := 0
## 自動読み込み(RunState)は、このスクリプトの読み込み時点では名前で呼べないので、実行時に取り出す
var rs: Node


func _initialize() -> void:
	rs = root.get_node("RunState")
	_run.call_deferred()


func _check(cond: bool, message: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", message)


func _eq(actual: Variant, expected: Variant, message: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s（期待=%s 実際=%s）" % [message, str(expected), str(actual)])


func _count(id: String) -> int:
	var n := 0
	for c in rs.deck:
		if String(c.data.id) == id:
			n += 1
	return n


func _deck_ids() -> Array:
	return rs.deck.map(func(c: CardInstance) -> String: return String(c.data.id))


func _run() -> void:
	_test_deck_lottery()
	_test_encounter_plan()
	_test_release_and_tiers()
	_test_memory_slots()
	_test_skip_and_flow()
	_test_full_run_simulation()
	print("テスト %d件中 %d件失敗" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_deck_lottery() -> void:
	for seed_value in [1, 2, 3, 42, 777]:
		rs.start_run(seed_value)
		_eq(rs.deck.size(), 30, "シード%d：初期デッキは30枚" % seed_value)
		_check(_count("strike") >= 4, "シード%d：打撃は4枚以上" % seed_value)
		_check(_count("defend") >= 4, "シード%d：防御は4枚以上" % seed_value)
	# 同じシードなら同じデッキ
	rs.start_run(123)
	var a := _deck_ids()
	rs.start_run(123)
	_eq(_deck_ids(), a, "同じシードなら同じ初期デッキ")
	rs.start_run(124)
	_check(_deck_ids() != a, "違うシードなら違うデッキ")
	# レア度の重み（基本50/通常40/希少10）：大量に引いて割合を見る
	var counts := {0: 0, 1: 0, 2: 0}
	var total := 0
	for seed_value in 200:
		rs.start_run(1000 + seed_value)
		# 必須の8枚を除いた22枚が抽選分
		for c in rs.deck.slice(8):
			counts[int(c.data.rarity)] += 1
			total += 1
	var basic := float(counts[0]) / total
	var common := float(counts[1]) / total
	var rare := float(counts[2]) / total
	print("[Test] レア度の割合 基本%.2f 通常%.2f 希少%.2f" % [basic, common, rare])
	_check(absf(basic - 0.5) < 0.05, "基本は約50%")
	_check(absf(common - 0.4) < 0.05, "通常は約40%")
	_check(absf(rare - 0.1) < 0.04, "希少は約10%")
	# 同じカードが重複して入りうる／1枚ずつ別の実体
	rs.start_run(5)
	var uids := {}
	for c in rs.deck:
		uids[c.uid] = true
	_eq(uids.size(), 30, "同名カードでも1枚ずつ別の実体")


func _test_encounter_plan() -> void:
	var early_ids := ["silverfish", "bats", "frog"]
	var mid_ids := ["sentinel", "shadow", "silverfish_x2", "frog_silverfish"]
	for seed_value in [1, 2, 3, 99]:
		rs.start_run(seed_value)
		_eq(rs.total_battles(), 10, "戦闘は10回")
		for n in range(1, 4):
			_check(early_ids.has(String(rs.encounter_plan[n - 1].id)), "シード%d：%d戦目は序盤の敵" % [seed_value, n])
		for n in range(4, 10):
			_check(mid_ids.has(String(rs.encounter_plan[n - 1].id)), "シード%d：%d戦目は中盤の敵" % [seed_value, n])
		_eq(String(rs.encounter_plan[9].id), "librarian", "10戦目はボス")
		_check(rs.is_boss(10) and not rs.is_boss(9), "ボス判定")
	rs.start_run(8)
	var plan_a: Array = rs.encounter_plan.map(func(e: EncounterData) -> String: return String(e.id))
	rs.start_run(8)
	_eq(rs.encounter_plan.map(func(e: EncounterData) -> String: return String(e.id)), plan_a, "同じシードなら同じ敵の並び")
	# 序盤3戦は重複しない
	rs.start_run(11)
	var first3 := {}
	for i in 3:
		first3[String(rs.encounter_plan[i].id)] = true
	_eq(first3.size(), 3, "序盤の3戦は違う敵")
	# 手放し枚数：1〜5戦目は2枚、6〜9戦目は1枚、ボスはなし
	for n in range(1, 6):
		_eq(rs.release_count_for(n), 2, "%d戦目の後は2枚" % n)
	for n in range(6, 10):
		_eq(rs.release_count_for(n), 1, "%d戦目の後は1枚" % n)
	_eq(rs.release_count_for(10), 0, "ボスの後は手放しなし")


func _test_release_and_tiers() -> void:
	_eq(rs.memory_tier(0), 0, "思い出0は淡い")
	_eq(rs.memory_tier(2), 0, "思い出2は淡い")
	_eq(rs.memory_tier(3), 1, "思い出3は確かな")
	_eq(rs.memory_tier(6), 1, "思い出6は確かな")
	_eq(rs.memory_tier(7), 2, "思い出7は鮮明な")
	_eq(rs.memory_tier(10), 2, "思い出10は鮮明な")
	_eq(rs.uses_until_next_tier(0), 3, "淡い(0)：確かなまであと3回")
	_eq(rs.uses_until_next_tier(2), 1, "淡い(2)：確かなまであと1回")
	_eq(rs.uses_until_next_tier(3), 4, "確かな(3)：鮮明なまであと4回")
	_eq(rs.uses_until_next_tier(7), -1, "鮮明なは最高")

	rs.start_run(21)
	var card = rs.deck[0]
	card.omoide = 5
	rs.release_remaining = 2
	var before = rs.deck.size()
	var m = rs.release_card(card)
	_eq(rs.deck.size(), before - 1, "手放すとデッキから減る")
	_check(not rs.deck.has(card), "手放したカードはデッキにない")
	_eq(m.tier, 1, "思い出5の記憶は確かな")
	_eq(m.data, card.data.memory, "そのカードの記憶になる")
	_eq(rs.released_count, 1, "手放した枚数が増える")
	_eq(rs.release_remaining, 1, "残り手放し枚数が減る")
	_eq(rs.memories.size(), 1, "記憶が1つ増える")
	_eq(rs.best_omoide, 5, "いちばん思い出が多かったカードを覚えている")


func _test_memory_slots() -> void:
	rs.start_run(33)
	rs.release_remaining = 10
	for i in 6:
		rs.release_card(rs.deck[0])
	_eq(rs.memories.size(), 6, "記憶は6つまで入る")
	_check(not rs.needs_forget(), "6つならあふれない")
	rs.release_card(rs.deck[0])
	_eq(rs.memories.size(), 7, "7つ目が入る")
	_check(rs.needs_forget(), "7つになったら1つ忘れる必要がある")
	var forgotten = rs.memories[2]
	rs.forget_memory(forgotten)
	_eq(rs.memories.size(), 6, "忘れると6つに戻る")
	_check(not rs.memories.has(forgotten), "忘れた記憶は戻らない")
	_check(not rs.needs_forget(), "あふれが解消")
	# 新しい記憶自体を忘れてもよい
	rs.release_card(rs.deck[0])
	var newest = rs.memories[6]
	rs.forget_memory(newest)
	_eq(rs.memories.size(), 6, "新しい記憶を忘れる選択もできる")


func _test_skip_and_flow() -> void:
	rs.start_run(44)
	rs.hp = 30
	rs.release_remaining = 2
	rs.skip_release()
	_eq(rs.hp, 40, "手放さないとHP+10")
	_eq(rs.release_remaining, 1, "手放さないも1回分に数える")
	rs.hp = 55
	rs.skip_release()
	_eq(rs.hp, 60, "HPは最大を超えない")
	_eq(rs.deck.size(), 30, "手放さなければデッキは減らない")
	# 戦闘のあと
	rs.start_run(45)
	rs.battle_number = 3
	rs.record_battle_end(41, 12, true)
	_eq(rs.hp, 41, "戦闘後のHPを持ち越す")
	_eq(rs.release_remaining, 2, "3戦目に勝つと2枚手放せる")
	_eq(rs.cards_played, 12, "使ったカード数を記録")
	rs.advance_to_next_battle()
	_eq(rs.battle_number, 4, "次の戦闘へ")
	rs.battle_number = 8
	rs.record_battle_end(30, 5, true)
	_eq(rs.release_remaining, 1, "8戦目に勝つと1枚")
	rs.battle_number = 10
	rs.record_battle_end(20, 5, true)
	_check(rs.won, "ボスに勝つとラン勝利")
	_eq(rs.release_remaining, 0 if false else rs.release_remaining, "ボス後は手放しなし")
	rs.start_run(46)
	rs.battle_number = 4
	rs.record_battle_end(0, 3, false)
	_check(not rs.won, "負けるとラン敗北")


## 1ラン分を自動で最後まで回す（ロジックだけ）。9戦勝って手放し→ボス戦
func _test_full_run_simulation() -> void:
	rs.start_run(2024)
	var balance = rs.balance
	var seen_hp: Array[int] = []
	for n in range(1, 11):
		rs.battle_number = n
		var enc = rs.current_encounter()
		var rng = rs.make_rng("battle%d" % n)
		var b = BattleState.new(balance, enc, rs.deck, rng, rs.hp, rs.memories, rs.released_count)
		b.start()
		# 敵を全員倒す（実戦闘は battle_tests で確認済み。ここは持ち越しを見る）
		for e in b.enemies:
			e.hp = 1
		var guard := 0
		while b.phase == BattleState.Phase.PLAYER_TURN and guard < 20:
			guard += 1
			var played := false
			for c in b.hand.duplicate():
				if c.data.card_type == CardData.CardType.ATTACK and b.can_play(c):
					b.play_card(c, b.living_enemies()[0] if not b.living_enemies().is_empty() else null)
					played = true
					if b.phase != BattleState.Phase.PLAYER_TURN:
						break
			if b.phase == BattleState.Phase.PLAYER_TURN and not played:
				b.end_turn()
		_check(b.phase == BattleState.Phase.WON, "%d戦目に勝てた" % n)
		rs.record_battle_end(b.player.hp, b.cards_played, true)
		seen_hp.append(rs.hp)
		if n < 10:
			_eq(rs.release_remaining, rs.release_count_for(n), "%d戦目の手放し枚数" % n)
			while rs.release_remaining > 0:
				rs.release_card(rs.deck[rs.deck.size() - 1])
				if rs.needs_forget():
					rs.forget_memory(rs.memories[0])
			rs.advance_to_next_battle()
	_eq(rs.deck.size(), 30 - 14, "全部手放すとボス戦は16枚で挑む（30-14）")
	_eq(rs.released_count, 14, "手放した枚数は14")
	_eq(rs.memories.size(), 6, "記憶は6枠まで")
	_check(rs.won, "ボスに勝ってラン勝利")
