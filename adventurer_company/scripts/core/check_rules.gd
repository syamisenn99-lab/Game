class_name CheckRules
extends RefCounted
## 判定のルール。
## 画面の成功率（probabilities）と実際の判定（resolve）は、どちらも
## build_modifiers で作った同じ補正を、同じ evaluate に通して出す。

## 確率表のキャッシュ（キー: BalanceConfig のID + CheckModifiers.key()）
static var _probability_cache: Dictionary = {}


## パーティ・クエスト・支度金から補正の内訳を作る
static func build_modifiers(party: Array[AdventurerDef], quest: QuestDef, supply_tier: int, config: BalanceConfig) -> CheckModifiers:
	var mods := CheckModifiers.new()
	mods.difficulty = quest.difficulty
	mods.dice_sides = config.dice_sides
	if party.is_empty():
		return mods

	var best: AdventurerDef = party[0]
	for a: AdventurerDef in party:
		if a.ability > best.ability:
			best = a
	mods.add("腕前（%s）" % best.name, best.ability)

	var extra := party.size() - 1
	if extra > 0:
		mods.add("追加メンバー ×%d" % extra, config.extra_member_bonus * extra)

	for a: AdventurerDef in party:
		if a.job == quest.job:
			mods.add("職業一致（%s）" % config.job_name(quest.job), config.job_match_bonus)
			break

	var supply_cost := config.supply_cost(supply_tier)
	if supply_cost > 0:
		mods.add("支度金 %dG" % supply_cost, config.supply_bonus(supply_tier))

	for a: AdventurerDef in party:
		match a.skill_type:
			"party_bonus":
				mods.add("%s（%s）" % [a.skill_name, a.name], int(a.skill_value))
			"supply_bonus":
				if supply_cost > 0:
					mods.add("%s（%s）" % [a.skill_name, a.name], int(a.skill_value))
			"advantage":
				mods.dice_count = maxi(mods.dice_count, int(a.skill_value))
				mods.notes.append("%s（%s）：d%dを%d回振って高い方を使う" % [a.skill_name, a.name, config.dice_sides, int(a.skill_value)])
			"outcome_floor":
				var floor_def := config.outcome_by_id(str(a.skill_value))
				var current := config.outcome_by_id(mods.outcome_floor)
				if current == null or floor_def.rank < current.rank:
					mods.outcome_floor = floor_def.id
				mods.notes.append("%s（%s）：%sより悪くならない" % [a.skill_name, a.name, floor_def.name])
	return mods


## 目から結果を決める。判定の唯一の関数
static func evaluate(dice: Array[int], mods: CheckModifiers, config: BalanceConfig) -> CheckResult:
	var r := CheckResult.new()
	r.modifiers = mods
	r.dice = dice.duplicate()
	r.used_die = dice.max()
	r.bonus = mods.total_bonus()
	r.total = r.used_die + r.bonus
	r.difficulty = mods.difficulty
	r.diff = r.total - r.difficulty
	r.raw_outcome = config.outcome_for_diff(r.diff)
	r.outcome = r.raw_outcome
	if mods.outcome_floor != "":
		var floor_def := config.outcome_by_id(mods.outcome_floor)
		if r.raw_outcome.rank > floor_def.rank:
			r.outcome = floor_def
			r.floored = true
	return r


## 全ての目の組み合わせを evaluate に通して数える（モンテカルロではない）
static func probabilities(mods: CheckModifiers, config: BalanceConfig) -> ProbabilityTable:
	var cache_key := "%d|%s" % [config.get_instance_id(), mods.key()]
	if _probability_cache.has(cache_key):
		return _probability_cache[cache_key]
	var table := ProbabilityTable.new()
	table.config = config
	for o: OutcomeDef in config.outcomes:
		table.counts[o.id] = 0
	var dice: Array[int] = []
	for i in mods.dice_count:
		dice.append(1)
	while true:
		var r := evaluate(dice, mods, config)
		table.counts[r.outcome.id] += 1
		table.total += 1
		var i := 0
		while i < dice.size():
			dice[i] += 1
			if dice[i] <= mods.dice_sides:
				break
			dice[i] = 1
			i += 1
		if i == dice.size():
			break
	_probability_cache[cache_key] = table
	return table


## 実際にダイスを振って判定する
static func resolve(mods: CheckModifiers, config: BalanceConfig, rng: GameRng) -> CheckResult:
	var dice: Array[int] = []
	for i in mods.dice_count:
		dice.append(rng.roll(mods.dice_sides))
	return evaluate(dice, mods, config)
