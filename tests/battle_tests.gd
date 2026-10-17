extends SceneTree
## 戦闘計算のヘッドレステスト。
##   godot --headless --path . --script tests/battle_tests.gd
## （初回は godot --headless --path . --import でクラス名キャッシュを作る）

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, message: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", message)


func _balance() -> BalanceConfig:
	return load("res://data/balance.tres") as BalanceConfig


func _deck() -> Array[CardData]:
	var strike := load("res://data/cards/strike.tres") as CardData
	var defend := load("res://data/cards/defend.tres") as CardData
	var deck: Array[CardData] = []
	for i in 5:
		deck.append(strike)
		deck.append(defend)
	return deck


func _battle(seed_value: int, enemy_path: String = "res://data/enemies/silverfish.tres") -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := BattleState.new(_balance(), load(enemy_path) as EnemyData, _deck(), rng)
	b.start()
	return b


func _run() -> void:
	_test_data()
	_test_start()
	_test_play_and_block()
	_test_enemy_turn()
	_test_win()
	_test_lose()
	_test_hand_limit()
	_test_reshuffle_and_fatigue()
	_test_seed_repro()
	print("テスト %d件中 %d件失敗" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_data() -> void:
	_check(_balance().max_hp == 60, "balance.tres が読める")
	var e := load("res://data/enemies/silverfish.tres") as EnemyData
	_check(e.max_hp == 22 and e.actions.size() == 2, "紙魚の定義")
	_check(e.actions[0].damage == 6 and e.actions[1].discard_top == 1, "紙魚の行動")


func _test_start() -> void:
	var b := _battle(1)
	_check(b.hand.size() == 5, "最初に5枚引く")
	_check(b.draw_pile.size() == 5, "山札は残り5枚")
	_check(b.energy == 3, "エネルギー3")
	_check(b.player_hp == 60 and b.enemy_hp == 22, "HP")
	_check(b.current_enemy_action().damage == 6, "最初の予告は攻撃6")


func _find(b: BattleState, id: StringName) -> CardData:
	for c in b.hand:
		if c.id == id:
			return c
	return null


func _test_play_and_block() -> void:
	var b := _battle(2)
	var strike := _find(b, &"strike")
	if strike != null:
		b.play_card(strike)
		_check(b.enemy_hp == 16, "打撃で6ダメージ")
		_check(b.energy == 2, "エネルギーが減る")
		_check(b.hand.size() == 4 and b.discard_pile.size() == 1, "使ったカードは手札から捨て札へ")
	var defend := _find(b, &"defend")
	if defend != null:
		b.play_card(defend)
		_check(b.player_block == 5, "防御でブロック5")
	# エネルギー切れ
	b.energy = 0
	var any: CardData = b.hand[0] if not b.hand.is_empty() else null
	if any != null:
		_check(not b.play_card(any), "エネルギー0ではカードを使えない")


func _test_enemy_turn() -> void:
	var b := _battle(3)
	b.end_turn()
	_check(b.player_hp == 54, "紙魚の1手目で6ダメージ（ブロックなし）")
	_check(b.turn == 2 and b.hand.size() == 5, "次のターンが始まり5枚引く")
	_check(b.player_block == 0, "ブロックはターン開始で0")
	_check(b.current_enemy_action().discard_top == 1, "次の予告は山札かじり")

	# 山札かじり：山札の上の1枚が捨て札へ送られる（ドロー2枚で数えやすくする）
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var bal := _balance().duplicate() as BalanceConfig
	bal.draw_per_turn = 2
	var c := BattleState.new(bal, load("res://data/enemies/silverfish.tres") as EnemyData, _deck(), rng)
	c.start()
	c.enemy_action_index = 1
	c.end_turn()
	_check(c.discard_pile.size() == 3, "手札2枚＋かじられた1枚が捨て札に")
	_check(c.draw_pile.size() == 5, "山札は10-2-1-2=5枚")


func _test_win() -> void:
	var b := _battle(4)
	var won: Array[bool] = []
	b.finished.connect(func(w: bool) -> void: won.append(w))
	b.enemy_hp = 6
	var strike := _find(b, &"strike")
	if strike == null:
		b.hand.append(load("res://data/cards/strike.tres") as CardData)
		strike = b.hand.back()
	b.play_card(strike)
	_check(b.phase == BattleState.Phase.WON and won == [true], "敵HP0で勝利")
	_check(not b.play_card(b.hand[0]) if not b.hand.is_empty() else true, "勝利後はカードを使えない")


func _test_lose() -> void:
	var b := _battle(5)
	var won: Array[bool] = []
	b.finished.connect(func(w: bool) -> void: won.append(w))
	b.player_hp = 6
	b.end_turn()
	_check(b.phase == BattleState.Phase.LOST and won == [false], "HP0で敗北")


func _test_hand_limit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var bal := _balance().duplicate() as BalanceConfig
	bal.hand_limit = 3
	var b := BattleState.new(bal, load("res://data/enemies/silverfish.tres") as EnemyData, _deck(), rng)
	b.start()
	_check(b.hand.size() == 3, "手札上限3で3枚まで")
	_check(b.discard_pile.size() == 2, "超えた分は捨て札へ")


func _test_reshuffle_and_fatigue() -> void:
	var b := _battle(7)
	# 疲労が増えるまで、ブロックだけで何ターンも回す（敵のダメージで死なないよう体力を盛る）
	b.player_hp = 99999
	_check(b.fatigue == 0 and b.reshuffle_count == 0, "最初は疲労0")
	for i in 40:
		if b.fatigue > 0:
			break
		b.end_turn()
	_check(b.reshuffle_count >= 3, "リシャッフルが3回以上起きた")
	_check(b.fatigue >= 1, "3回目のリシャッフルで疲労1")
	_check(b.next_draw_count() == 4, "疲労1でドローが4枚に減る")
	b.fatigue = 10
	_check(b.next_draw_count() == 2, "ドローは最低2枚")


func _test_seed_repro() -> void:
	var a := _battle(123)
	var b := _battle(123)
	var ids_a: Array = a.hand.map(func(c: CardData) -> StringName: return c.id)
	var ids_b: Array = b.hand.map(func(c: CardData) -> StringName: return c.id)
	_check(ids_a == ids_b, "同じシードなら同じ手札")
