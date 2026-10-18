extends Node
## ラン全体の状態（オートロード）：シード、デッキ、記憶、HP、何戦目か、統計。
## 乱数は「ラン開始時のシード」と用途ごとの名前(salt)から作る。
## 同じシードなら、初期デッキも敵の並びも、各戦闘のシャッフルも毎回同じになる。

const BALANCE_PATH := "res://data/balance.tres"
const CHAPTER_PATH := "res://data/chapter1.tres"
const POOL_PATH := "res://data/pools/main_pool.tres"
const SCENE_TITLE := "res://scenes/title/title.tscn"
const SCENE_BATTLE := "res://scenes/battle/battle.tscn"
const SCENE_RELEASE := "res://scenes/release/release.tscn"
const SCENE_RESULT := "res://scenes/result/result.tscn"

var balance: BalanceConfig
var chapter: ChapterData
var pool: CardPool

var active: bool = false
var run_seed: int = 0

var deck: Array[CardInstance] = []
var memories: Array[MemoryInstance] = []
var hp: int = 0
var max_hp: int = 0
## 今の（または次の）戦闘番号。1〜（通常戦闘の回数+1）。最後がボス
var battle_number: int = 1
var encounter_plan: Array[EncounterData] = []
## 今回の手放しで、あと何枚手放せるか
var release_remaining: int = 0

# 統計
var released_count: int = 0
var cards_played: int = 0
var best_omoide: int = 0
var best_omoide_card: String = ""
var won: bool = false


func _ready() -> void:
	balance = load(BALANCE_PATH) as BalanceConfig
	chapter = load(CHAPTER_PATH) as ChapterData
	pool = load(POOL_PATH) as CardPool


## 用途ごとに独立した乱数を作る（前の選択が後の展開を変えないように）
func make_rng(salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = ("%d:%s" % [run_seed, salt]).hash()
	return r


func start_run(seed_value: int = -1) -> void:
	if seed_value < 0:
		var picker := RandomNumberGenerator.new()
		picker.randomize()
		seed_value = picker.randi() % 1000000
	run_seed = seed_value
	active = true
	CardInstance.reset_uids()
	MemoryInstance.reset_uids()
	memories.clear()
	max_hp = balance.max_hp
	hp = max_hp
	battle_number = 1
	release_remaining = 0
	released_count = 0
	cards_played = 0
	best_omoide = 0
	best_omoide_card = ""
	won = false
	_build_initial_deck()
	_build_encounter_plan()
	print("[RunState] ラン開始 シード=%d デッキ=%d枚 戦闘=%d回" % [run_seed, deck.size(), encounter_plan.size()])


# ---------- 初期デッキと戦闘の並び ----------

func _build_initial_deck() -> void:
	deck = []
	var r := make_rng("deck")
	for card in pool.guaranteed:
		for i in pool.guaranteed_count:
			deck.append(CardInstance.new(card))
	var rarities: Array[CardData.Rarity] = []
	for rarity in [CardData.Rarity.BASIC, CardData.Rarity.COMMON, CardData.Rarity.RARE]:
		if not _cards_of(rarity).is_empty():
			rarities.append(rarity)
	while deck.size() < balance.initial_deck_size:
		var total := 0.0
		for rarity in rarities:
			total += pool.weight_of(rarity)
		var roll := r.randf() * total
		var chosen: CardData.Rarity = rarities[rarities.size() - 1]
		for rarity in rarities:
			roll -= pool.weight_of(rarity)
			if roll <= 0.0:
				chosen = rarity
				break
		var candidates := _cards_of(chosen)
		deck.append(CardInstance.new(candidates[r.randi_range(0, candidates.size() - 1)]))


func _cards_of(rarity: CardData.Rarity) -> Array[CardData]:
	var result: Array[CardData] = []
	for c in pool.cards:
		if c.rarity == rarity:
			result.append(c)
	return result


func _build_encounter_plan() -> void:
	encounter_plan = []
	var r := make_rng("encounters")
	var early_bag: Array[EncounterData] = []
	var mid_bag: Array[EncounterData] = []
	for n in range(1, balance.normal_battle_count + 1):
		if n <= balance.early_battle_count:
			encounter_plan.append(_draw_from_bag(early_bag, chapter.early_encounters, r))
		else:
			encounter_plan.append(_draw_from_bag(mid_bag, chapter.mid_encounters, r))
	encounter_plan.append(chapter.boss_encounter)


## 袋から1つ取り出す（空になったら候補を全部入れ直してシャッフル）。同じ敵が続けて出にくい
func _draw_from_bag(bag: Array[EncounterData], source: Array[EncounterData], r: RandomNumberGenerator) -> EncounterData:
	if bag.is_empty():
		bag.append_array(source)
		for i in range(bag.size() - 1, 0, -1):
			var j := r.randi_range(0, i)
			var tmp := bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
	return bag.pop_back()


func total_battles() -> int:
	return encounter_plan.size()


func is_boss(number: int) -> bool:
	return number >= total_battles()


func current_encounter() -> EncounterData:
	return encounter_plan[clampi(battle_number, 1, total_battles()) - 1]


func release_count_for(number: int) -> int:
	if is_boss(number):
		return 0
	var counts := balance.release_counts
	return counts[mini(number, counts.size()) - 1]


# ---------- 戦闘のあと ----------

## 戦闘が終わったとき、画面から呼ぶ
func record_battle_end(player_hp: int, plays: int, victory: bool) -> void:
	hp = player_hp
	cards_played += plays
	track_best()
	if not victory or is_boss(battle_number):
		won = victory
	if victory and not is_boss(battle_number):
		release_remaining = release_count_for(battle_number)


func track_best() -> void:
	for c in deck:
		if c.omoide > best_omoide:
			best_omoide = c.omoide
			best_omoide_card = c.data.display_name


# ---------- 手放し ----------

func memory_tier(omoide: int) -> int:
	if omoide >= balance.tier_vivid_at:
		return 2
	if omoide >= balance.tier_certain_at:
		return 1
	return 0


## 次の段階まで、あと何回使えばよいか（最高段階なら -1）
func uses_until_next_tier(omoide: int) -> int:
	match memory_tier(omoide):
		0: return balance.tier_certain_at - omoide
		1: return balance.tier_vivid_at - omoide
	return -1


## カードを手放して記憶にする。7つ目が入ったら needs_forget() が true になる
func release_card(card: CardInstance) -> MemoryInstance:
	track_best()
	if card.omoide > best_omoide:
		best_omoide = card.omoide
		best_omoide_card = card.data.display_name
	deck.erase(card)
	released_count += 1
	release_remaining = maxi(0, release_remaining - 1)
	var m := MemoryInstance.new(card.data.memory, memory_tier(card.omoide), card.data.display_name)
	memories.append(m)
	print("[RunState] 手放した: %s（思い出%d）→ 記憶「%s」(%s)" % [
		card.data.display_name, card.omoide, m.data.display_name, m.tier_label()])
	return m


func needs_forget() -> bool:
	return memories.size() > balance.memory_slots


func forget_memory(m: MemoryInstance) -> void:
	memories.erase(m)
	print("[RunState] 記憶「%s」を忘れた" % m.data.display_name)


## 「今回は手放さない」：HPを回復して、1回分の手放しを消費する
func skip_release() -> void:
	hp = mini(max_hp, hp + balance.skip_release_heal)
	release_remaining = maxi(0, release_remaining - 1)
	print("[RunState] 手放さない HP=%d" % hp)


func advance_to_next_battle() -> void:
	battle_number += 1
	release_remaining = 0


# ---------- 画面の移動 ----------

func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
