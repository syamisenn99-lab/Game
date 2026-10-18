extends SceneTree
## 戦闘計算のヘッドレステスト。
##   godot --headless --path . --script tests/battle_tests.gd
## （初回は godot --headless --path . --import でクラス名キャッシュを作る）

var _failures := 0
var _checks := 0

const CARD_IDS: Array[String] = [
	"strike", "defend", "old_cloak", "double_thrust", "sweep", "heavy_blow",
	"poison_vial", "deep_breath", "light_step", "whetstone", "stargazing", "farewell"]
const ENEMY_IDS: Array[String] = ["silverfish", "bat", "frog", "sentinel", "shadow", "librarian"]


func _initialize() -> void:
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


func _balance() -> BalanceConfig:
	return load("res://data/balance.tres") as BalanceConfig


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _deck10() -> Array[CardInstance]:
	var deck: Array[CardInstance] = []
	for i in 5:
		deck.append(CardInstance.new(_card("strike")))
		deck.append(CardInstance.new(_card("defend")))
	return deck


func _battle(encounter: String, seed_value: int = 1, deck: Array[CardInstance] = []) -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if deck.is_empty():
		deck = _deck10()
	var b := BattleState.new(_balance(), load("res://data/encounters/%s.tres" % encounter) as EncounterData, deck, rng)
	b.start()
	return b


## 手札を指定のカードだけにして、エネルギーも十分にした状態を作る
func _with_hand(b: BattleState, ids: Array[String]) -> Array[CardInstance]:
	b.hand.clear()
	var result: Array[CardInstance] = []
	for id in ids:
		var c := CardInstance.new(_card(id))
		b.hand.append(c)
		result.append(c)
	b.energy = 10
	return result


func _play(b: BattleState, id: String, target: BattleEnemy = null) -> CardInstance:
	var c := _with_hand(b, [id])[0]
	_check(b.play_card(c, target), "「%s」を使えた" % id)
	return c


func _run() -> void:
	CardInstance.reset_uids()
	_test_data_loads()
	_test_descriptions()
	_test_start()
	_test_each_card()
	_test_statuses()
	_test_turn_flow()
	_test_enemies()
	_test_weighted_pattern()
	_test_end_conditions()
	_test_hand_limit_and_fatigue()
	_test_seed_repro()
	print("テスト %d件中 %d件失敗" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_data_loads() -> void:
	_eq(_balance().max_hp, 60, "balance.tres が読める")
	for id in CARD_IDS:
		_check(load("res://data/cards/%s.tres" % id) is CardData, "カード %s が読める" % id)
	for id in ENEMY_IDS:
		_check(load("res://data/enemies/%s.tres" % id) is EnemyData, "敵 %s が読める" % id)
	_eq(Status.ALL.size(), 4, "状態異常は4種類")


func _test_descriptions() -> void:
	var expected := {
		"strike": "6ダメージ",
		"defend": "ブロック5",
		"old_cloak": "ブロック4、保持",
		"double_thrust": "3ダメージ×2回",
		"sweep": "5ダメージ、敵に弱体1",
		"heavy_blow": "14ダメージ",
		"poison_vial": "敵に毒4",
		"deep_breath": "2枚引く",
		"light_step": "ブロック3",
		"whetstone": "筋力2",
		"stargazing": "3枚引く、エネルギー1を得る",
		"farewell": "8ダメージ＋このカードの思い出×2ダメージ",
	}
	for id in expected:
		_eq(_card(id).describe(), expected[id], "説明文 %s" % id)
	var costs := {"strike": 1, "heavy_blow": 2, "deep_breath": 0, "light_step": 0, "farewell": 2}
	for id in costs:
		_eq(_card(id).cost, costs[id], "コスト %s" % id)


func _test_start() -> void:
	var b := _battle("silverfish")
	_eq(b.hand.size(), 5, "最初に5枚引く")
	_eq(b.draw_pile.size(), 5, "山札は残り5枚")
	_eq(b.energy, 3, "エネルギー3")
	_eq(b.player.hp, 60, "プレイヤーHP")
	_eq(b.enemies[0].hp, 22, "紙魚のHP")
	_eq(b.enemies[0].next_action.intent_text(b, b.enemies[0]), "攻撃 6", "最初の予告は攻撃6")


func _test_each_card() -> void:
	var b := _battle("silverfish")
	var fish := b.enemies[0]
	_play(b, "strike")
	_eq(fish.hp, 16, "打撃：6ダメージ")
	_eq(b.energy, 9, "打撃：コスト1")

	b = _battle("silverfish")
	_play(b, "defend")
	_eq(b.player.block, 5, "防御：ブロック5")

	b = _battle("silverfish")
	_play(b, "old_cloak")
	_eq(b.player.block, 4, "古びた外套：ブロック4")

	b = _battle("silverfish")
	_play(b, "double_thrust")
	_eq(b.enemies[0].hp, 16, "二連突き：3×2")

	b = _battle("silverfish")
	_play(b, "sweep")
	_eq(b.enemies[0].hp, 17, "足払い：5ダメージ")
	_eq(b.enemies[0].stacks(Status.WEAK), 1, "足払い：弱体1")

	b = _battle("silverfish")
	_play(b, "heavy_blow")
	_eq(b.enemies[0].hp, 8, "重い一撃：14ダメージ")
	_eq(b.energy, 8, "重い一撃：コスト2")

	b = _battle("silverfish")
	_play(b, "poison_vial")
	_eq(b.enemies[0].stacks(Status.POISON), 4, "毒の小瓶：毒4")

	b = _battle("silverfish")
	var before := b.hand.size()
	_play(b, "deep_breath")
	_eq(b.hand.size(), 2, "深呼吸：手札が増える（使った1枚は捨て札へ）")
	_check(before == 5, "深呼吸の準備")
	_eq(b.energy, 10, "深呼吸：コスト0")

	b = _battle("silverfish")
	_play(b, "light_step")
	_eq(b.player.block, 3, "身軽な一歩：ブロック3")

	b = _battle("silverfish")
	_play(b, "whetstone")
	_eq(b.player.stacks(Status.STRENGTH), 2, "刃研ぎ：筋力2")
	_play(b, "strike")
	_eq(b.enemies[0].hp, 14, "筋力2で打撃は8ダメージ")

	b = _battle("silverfish")
	_play(b, "stargazing")
	_eq(b.hand.size(), 3, "星読み：3枚引く")
	_eq(b.energy, 10, "星読み：コスト1 エネルギー1を得る")

	b = _battle("silverfish")
	var f := _with_hand(b, ["farewell"])[0]
	f.omoide = 3
	b.play_card(f)
	_eq(b.enemies[0].hp, 22 - 14, "決別の一閃：8＋思い出3×2=14")
	_eq(f.omoide, 4, "使うと思い出が1増える")
	f.omoide = 10
	b.hand.append(f)
	b.play_card(f)
	_eq(f.omoide, 10, "思い出の上限は10")

	# 敵全体を狙う効果と、敵の選択
	b = _battle("bats")
	var target := b.enemies[1]
	_play(b, "strike", target)
	_eq(target.hp, 4, "選んだ蝙蝠にだけ当たる")
	_eq(b.enemies[0].hp, 10, "ほかの蝙蝠は無傷")
	_play(b, "strike")
	_eq(b.enemies[0].hp, 4, "対象を選ばないと最初の生きている敵に当たる")


func _test_statuses() -> void:
	var b := _battle("silverfish")
	var fish := b.enemies[0]
	# 脆弱：1.5倍切り捨て
	fish.add_stacks(Status.VULNERABLE, 2)
	_play(b, "strike")
	_eq(fish.hp, 22 - 9, "脆弱：6→9")
	# 弱体（プレイヤー）：0.75倍切り捨て
	b.player.add_stacks(Status.WEAK, 1)
	b.player.add_stacks(Status.STRENGTH, 0)
	_play(b, "strike")
	_eq(fish.hp, 13 - 6, "弱体＋脆弱：6→4→6（端数切り捨て）")
	# 筋力→弱体→脆弱の順
	b.player.add_stacks(Status.STRENGTH, 2)
	_eq(b.calc_damage(6, b.player, fish), 9, "(6+2)=8 → 弱体6 → 脆弱9")
	var weak_only := Combatant.new()
	weak_only.add_stacks(Status.WEAK, 1)
	_eq(b.calc_damage(5, weak_only, b.player), 3, "弱体：5→3（3.75を切り捨て）")
	# ターン終了で脆弱・弱体が1減る
	b = _battle("silverfish")
	b.player.add_stacks(Status.WEAK, 2)
	b.player.add_stacks(Status.VULNERABLE, 1)
	b.player.add_stacks(Status.STRENGTH, 3)
	b.end_turn()
	_eq(b.player.stacks(Status.WEAK), 1, "弱体は1減る")
	_eq(b.player.stacks(Status.VULNERABLE), 0, "脆弱は1減って消える")
	_eq(b.player.stacks(Status.STRENGTH), 3, "筋力は戦闘中ずっと続く")
	# 毒：敵のターン終了時にスタック数ぶんのダメージ、その後1減る
	b = _battle("silverfish")
	_play(b, "poison_vial")
	b.end_turn()
	_eq(b.enemies[0].hp, 18, "毒4：敵のターン終了で4ダメージ")
	_eq(b.enemies[0].stacks(Status.POISON), 3, "毒は1減る")
	b.end_turn()
	_eq(b.enemies[0].hp, 15, "毒3：次は3ダメージ")
	# 毒はブロックで防げない
	b = _battle("silverfish")
	b.player.add_stacks(Status.POISON, 2)
	b.player.block = 99
	b.end_turn()
	_eq(b.player.hp, 58, "毒はブロックを無視する")
	# 弱体の敵は攻撃が弱くなる
	b = _battle("silverfish")
	b.enemies[0].add_stacks(Status.WEAK, 1)
	b.end_turn()
	_eq(b.player.hp, 60 - 4, "弱体の紙魚の攻撃は6→4")


func _test_turn_flow() -> void:
	var b := _battle("silverfish", 3)
	b.end_turn()
	_eq(b.player.hp, 54, "紙魚の1手目で6ダメージ")
	_eq(b.turn, 2, "次のターンになる")
	_eq(b.hand.size(), 5, "5枚引く")
	_eq(b.player.block, 0, "ブロックはターン開始で0")
	# 保持：ターン終了で捨てない
	b = _battle("silverfish")
	var cs := _with_hand(b, ["old_cloak", "defend"])
	b.end_turn()
	_check(b.hand.has(cs[0]) or b.discard_pile.has(cs[0]), "外套の行き先")
	_check(not b.discard_pile.has(cs[0]) or b.hand.has(cs[0]), "保持カードは捨てられない")
	_check(b.discard_pile.has(cs[1]), "防御は捨て札へ")
	# エネルギー切れ
	b = _battle("silverfish")
	b.energy = 0
	_check(not b.play_card(b.hand[0]), "エネルギー0ではカードを使えない")


func _test_enemies() -> void:
	# 紙魚：6ダメージ→山札かじり
	var b := _battle("silverfish", 2)
	b.end_turn()
	_eq(b.player.hp, 54, "紙魚 1手目")
	_eq(b.enemies[0].next_action.label, "山札をかじる", "紙魚 2手目の予告")
	var total := b.draw_pile.size() + b.discard_pile.size() + b.hand.size()
	b.end_turn()
	_eq(b.player.hp, 54, "山札かじりはダメージなし")
	_eq(b.draw_pile.size() + b.discard_pile.size() + b.hand.size(), total, "カードの総数は変わらない")

	# 蝙蝠3体：それぞれ4ダメージ
	b = _battle("bats")
	_eq(b.enemies.size(), 3, "蝙蝠は3体")
	_eq(b.enemies[2].display_name, "群れの蝙蝠C", "同名の敵にはA/B/Cが付く")
	b.end_turn()
	_eq(b.player.hp, 48, "蝙蝠3体で12ダメージ")
	# 倒した敵は行動しない
	b.enemies[0].hp = 0
	b.end_turn()
	_eq(b.player.hp, 40, "生きている2体だけが攻撃")

	# 蛙：毒3→8ダメージ
	b = _battle("frog")
	b.end_turn()
	_eq(b.player.stacks(Status.POISON), 3, "蛙の1手目で毒3")
	_eq(b.enemies[0].next_action.intent_text(b, b.enemies[0]), "攻撃 8", "蛙 2手目の予告")
	b.end_turn()
	# 毒3は自分のターン終了時に3ダメージ→毒2。その後蛙の8ダメージ→毒2の分も
	_eq(b.player.hp, 60 - 3 - 8, "蛙：毒3の後に8ダメージ（その後の毒はまだ）")
	_eq(b.player.stacks(Status.POISON), 2, "毒は1減った")

	# 番兵：ブロック10→12ダメージ
	b = _battle("sentinel")
	b.end_turn()
	_eq(b.enemies[0].block, 10, "番兵 1手目でブロック10")
	_eq(b.player.hp, 60, "ダメージなし")
	_play(b, "heavy_blow")
	_eq(b.enemies[0].hp, 40 - 4, "ブロック10を超えた4ダメージ")
	_eq(b.enemies[0].block, 0, "ブロックが消える")
	b.end_turn()
	_eq(b.player.hp, 48, "番兵 2手目で12ダメージ")

	# 影：5×2、5×2、3ターン目に25（カウントダウン）
	b = _battle("shadow")
	var shadow := b.enemies[0]
	_eq(shadow.turns_until_countdown(), 2, "カウントダウンはあと2ターン")
	b.end_turn()
	_eq(b.player.hp, 50, "影 1ターン目 5×2")
	_eq(shadow.turns_until_countdown(), 1, "あと1ターン")
	b.end_turn()
	_eq(b.player.hp, 40, "影 2ターン目 5×2")
	_eq(shadow.turns_until_countdown(), 0, "今回が大技")
	_eq(shadow.next_action.intent_text(b, shadow), "攻撃 25", "予告は25")
	b.end_turn()
	_eq(b.player.hp, 15, "影 3ターン目 25ダメージ")
	_eq(shadow.turns_until_countdown(), 2, "また最初から数える")

	# 司書：8＋封印→18→ブロック15＋筋力2→手札全捨て＋6
	b = _battle("librarian")
	var lib := b.enemies[0]
	_eq(lib.next_action.intent_text(b, lib), "攻撃 8 + 記憶封印", "司書 予告")
	b.end_turn()
	_eq(b.player.hp, 52, "司書 1手目")
	b.end_turn()
	_eq(b.player.hp, 34, "司書 2手目 18ダメージ")
	b.end_turn()
	_eq(lib.block, 15, "司書 3手目 ブロック15")
	_eq(lib.stacks(Status.STRENGTH), 2, "司書 3手目 筋力2")
	var hand_before := b.hand.size()
	_check(hand_before > 0, "4手目の前に手札がある")
	b.end_turn()
	_eq(b.player.hp, 34 - 8, "司書 4手目 6+筋力2=8ダメージ")
	_eq(lib.next_action.label, "禁書の一撃", "司書は最初に戻る")
	_eq(lib.next_action.intent_text(b, lib), "攻撃 10 + 記憶封印", "筋力2で予告が10に")
	_eq(lib.data.max_hp, 120, "司書のHP")


func _test_weighted_pattern() -> void:
	var data := EnemyData.new()
	data.id = &"test"
	data.display_name = "試験体"
	data.pattern = EnemyData.Pattern.WEIGHTED
	var a1 := EnemyAction.new()
	a1.label = "A"
	a1.weight = 1.0
	var a2 := EnemyAction.new()
	a2.label = "B"
	a2.weight = 0.0
	data.actions = [a1, a2]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var e := BattleEnemy.new(data, "試験体")
	var labels: Array[String] = []
	for i in 10:
		e.choose_next(rng)
		labels.append(e.next_action.label)
	_check(not labels.has("B"), "重み0の行動は選ばれない")
	a2.weight = 1.0
	a1.weight = 1.0
	var seen := {}
	for i in 60:
		e.choose_next(rng)
		seen[e.next_action.label] = true
	_check(seen.has("A") and seen.has("B"), "重みがあれば両方出る")
	# 同じシードなら同じ並び
	var run1: Array[String] = []
	var run2: Array[String] = []
	for run in [run1, run2]:
		var r := RandomNumberGenerator.new()
		r.seed = 99
		var en := BattleEnemy.new(data, "x")
		for i in 8:
			en.choose_next(r)
			run.append(en.next_action.label)
	_eq(run1, run2, "重み付きランダムも同じシードで再現")


func _test_end_conditions() -> void:
	var b := _battle("silverfish")
	var results: Array[bool] = []
	b.finished.connect(func(w: bool) -> void: results.append(w))
	b.enemies[0].hp = 6
	_play(b, "strike")
	_eq(b.phase, BattleState.Phase.WON, "敵HP0で勝利")
	_eq(results, [true], "勝利は1回だけ通知")
	_check(not b.can_play(b.discard_pile[0]), "勝利後はカードを使えない")

	b = _battle("silverfish")
	results = []
	b.finished.connect(func(w: bool) -> void: results.append(w))
	b.player.hp = 6
	b.end_turn()
	_eq(b.phase, BattleState.Phase.LOST, "HP0で敗北")
	_eq(results, [false], "敗北は1回だけ通知")

	# 毒で敵が倒れて勝利
	b = _battle("silverfish")
	b.enemies[0].hp = 4
	_play(b, "poison_vial")
	b.end_turn()
	_eq(b.phase, BattleState.Phase.WON, "毒で倒して勝利")
	# 毒で自分が倒れて敗北
	b = _battle("silverfish")
	b.player.hp = 3
	b.player.add_stacks(Status.POISON, 3)
	b.end_turn()
	_eq(b.phase, BattleState.Phase.LOST, "毒で倒れて敗北")
	# 蝙蝠を全部倒すと勝利
	b = _battle("bats")
	for e in b.enemies:
		e.hp = 1
	_with_hand(b, ["strike", "strike", "strike"])
	for e in b.enemies.duplicate():
		b.play_card(b.hand[0], e)
	_eq(b.phase, BattleState.Phase.WON, "3体とも倒すと勝利")


func _test_hand_limit_and_fatigue() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var bal := _balance().duplicate() as BalanceConfig
	bal.hand_limit = 3
	var b := BattleState.new(bal, load("res://data/encounters/silverfish.tres") as EncounterData, _deck10(), rng)
	b.start()
	_eq(b.hand.size(), 3, "手札上限3で3枚まで")
	_eq(b.discard_pile.size(), 2, "超えた分は捨て札へ")

	b = _battle("silverfish", 7)
	b.player.hp = 99999
	b.player.max_hp = 99999
	_eq(b.fatigue, 0, "最初は疲労0")
	for i in 40:
		if b.fatigue > 0:
			break
		b.end_turn()
	_check(b.reshuffle_count >= 3, "リシャッフルが3回以上")
	_eq(b.fatigue, 1, "3回目のリシャッフルで疲労1")
	_eq(b.next_draw_count(), 4, "疲労1でドローは4枚")
	b.fatigue = 10
	_eq(b.next_draw_count(), 2, "ドローは最低2枚")


func _test_seed_repro() -> void:
	CardInstance.reset_uids()
	var a := _battle("frog_silverfish", 123)
	CardInstance.reset_uids()
	var b := _battle("frog_silverfish", 123)
	var ids_a: Array = a.hand.map(func(c: CardInstance) -> int: return c.uid)
	var ids_b: Array = b.hand.map(func(c: CardInstance) -> int: return c.uid)
	_eq(ids_a, ids_b, "同じシードなら同じ手札")
