extends RefCounted
## バランス確認用の単純な貪欲AI。GameController の公開APIだけを使う（UIと同じ入口）。
##
## 毎週:
##   受注できるクエストを報酬の高い順に見て、待機中の冒険者から
##   成功率（0G のとき）が最も高い編成を選ぶ（同点なら人数が少ない方 → 月給の合計が安い方）。
##   成功率が support_threshold 未満なら、それに届く最小の支度金を出す。
##   届かなければ出せる範囲で最大の支度金を出す。支度金と医療費は、次の給料日の支払額を残せる範囲でだけ使う。

var support_threshold: float = 0.65

## 統計用
var supply_spent: int = 0
var medical_paid: int = 0
## クエストID → 派遣したときの成功率（画面に出る値と同じ）
var predicted_rates: Dictionary = {}


func plan_week(c: GameController) -> void:
	var candidates: Array[QuestState] = []
	for q: QuestState in c.board_quests():
		if q.status == QuestState.Status.POSTED and c.is_unlocked(q):
			candidates.append(q)
	candidates.sort_custom(func(a: QuestState, b: QuestState) -> bool: return a.def.reward > b.def.reward)

	for q: QuestState in candidates:
		var idle := c.idle_adventurers()
		if idle.is_empty():
			return
		var party := _best_party(c, q, idle)
		var tier := _choose_supply(c, q, party)
		predicted_rates[q.def.id] = c.preview_probabilities(q, party, tier).success_rate()
		var error := c.dispatch(q, party, tier)
		assert(error == "", error)
		supply_spent += c.config.supply_cost(tier)


func decide_injuries(c: GameController) -> void:
	for case: InjuryCase in c.pending_injuries():
		var pay := c.gold - c.config.medical_cost >= _reserve(c)
		c.decide_injury(case, pay)
		if pay:
			medical_paid += c.config.medical_cost


## 次の給料日のために残しておく額
func _reserve(c: GameController) -> int:
	return c.payroll() if c.next_payday_week() > 0 else 0


func _best_party(c: GameController, q: QuestState, idle: Array[AdventurerState]) -> Array[String]:
	var best: Array[String] = []
	var best_rate := -1.0
	var best_salary := 0
	for party: Array[String] in _subsets(idle, c.config.party_min, c.config.party_max):
		var rate := c.preview_probabilities(q, party, 0).success_rate()
		var salary := 0
		for adventurer_id: String in party:
			salary += c.adventurer(adventurer_id).def.salary
		var better := rate > best_rate + 1e-12
		if not better and absf(rate - best_rate) <= 1e-12:
			better = party.size() < best.size() or (party.size() == best.size() and salary < best_salary)
		if better:
			best = party
			best_rate = rate
			best_salary = salary
	return best


func _choose_supply(c: GameController, q: QuestState, party: Array[String]) -> int:
	if c.preview_probabilities(q, party, 0).success_rate() >= support_threshold:
		return 0
	var budget := c.gold - _reserve(c)
	var affordable := 0
	for tier in range(1, c.config.supply_tier_count()):
		if c.config.supply_cost(tier) > budget:
			break
		affordable = tier
		if c.preview_probabilities(q, party, tier).success_rate() >= support_threshold:
			return tier
	return affordable


func _subsets(pool: Array[AdventurerState], min_size: int, max_size: int) -> Array:
	var result := []
	var n := pool.size()
	for mask in range(1, 1 << n):
		var party: Array[String] = []
		for i in n:
			if mask & (1 << i):
				party.append(pool[i].def.id)
		if party.size() >= min_size and party.size() <= max_size:
			result.append(party)
	return result
