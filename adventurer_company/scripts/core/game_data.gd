class_name GameData
extends RefCounted
## data/*.json を読み込んだ定義一式。読み込みに失敗した点は errors に入る。

const DEFAULT_DIR := "res://data"
const SKILL_TYPES := ["none", "party_bonus", "supply_bonus", "advantage", "outcome_floor"]

var config: BalanceConfig = BalanceConfig.new()
var adventurers: Array[AdventurerDef] = []
var quests: Array[QuestDef] = []
var errors: Array[String] = []


static func load_from(dir: String = DEFAULT_DIR) -> GameData:
	var data := GameData.new()
	var balance: Variant = data._read_json(dir.path_join("balance.json"))
	var adventurers_json: Variant = data._read_json(dir.path_join("adventurers.json"))
	var quests_json: Variant = data._read_json(dir.path_join("quests.json"))
	if balance is Dictionary:
		data._parse_balance(balance)
	if adventurers_json is Array:
		data._parse_adventurers(adventurers_json)
	if quests_json is Array:
		data._parse_quests(quests_json)
	data._validate()
	return data


func is_valid() -> bool:
	return errors.is_empty()


func adventurer_def(adventurer_id: String) -> AdventurerDef:
	for a: AdventurerDef in adventurers:
		if a.id == adventurer_id:
			return a
	return null


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s が見つからない" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s の %d 行目: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _parse_balance(d: Dictionary) -> void:
	var c := config
	c.initial_gold = int(d.get("initial_gold", c.initial_gold))
	c.initial_reputation = int(d.get("initial_reputation", c.initial_reputation))
	c.reputation_min = int(d.get("reputation_min", c.reputation_min))
	c.reputation_max = int(d.get("reputation_max", c.reputation_max))
	c.total_weeks = int(d.get("total_weeks", c.total_weeks))
	c.weeks_per_month = int(d.get("weeks_per_month", c.weeks_per_month))
	for w: Variant in d.get("payday_weeks", []):
		c.payday_weeks.append(int(w))
	c.payday_weeks.sort()
	c.party_min = int(d.get("party_min", c.party_min))
	c.party_max = int(d.get("party_max", c.party_max))
	c.dice_sides = int(d.get("dice_sides", c.dice_sides))
	c.extra_member_bonus = int(d.get("extra_member_bonus", c.extra_member_bonus))
	c.job_match_bonus = int(d.get("job_match_bonus", c.job_match_bonus))
	c.quest_listing_weeks = int(d.get("quest_listing_weeks", c.quest_listing_weeks))
	c.success_outcome = str(d.get("success_outcome", c.success_outcome))
	c.jobs = d.get("jobs", {})
	for tier: Variant in d.get("supply_tiers", []):
		c.supply_costs.append(int(tier["cost"]))
		c.supply_bonuses.append(int(tier["bonus"]))
	var rank := 0
	for o: Variant in d.get("outcomes", []):
		var od := OutcomeDef.new()
		od.id = str(o["id"])
		od.name = str(o["name"])
		od.rank = rank
		od.has_min_diff = o.get("min_diff") != null
		od.min_diff = int(o["min_diff"]) if od.has_min_diff else 0
		od.reward_rate = float(o.get("reward_rate", 0.0))
		od.reputation = int(o.get("reputation", 0))
		od.injury = str(o.get("injury", ""))
		c.outcomes.append(od)
		rank += 1
	c.injuries = d.get("injuries", {})
	var medical: Dictionary = d.get("medical", {})
	c.medical_cost = int(medical.get("cost", c.medical_cost))
	c.medical_rest_reduction = int(medical.get("rest_reduction", c.medical_rest_reduction))
	c.medical_reputation = int(medical.get("reputation", c.medical_reputation))


func _parse_adventurers(list: Array) -> void:
	for d: Variant in list:
		var a := AdventurerDef.new()
		a.id = str(d["id"])
		a.name = str(d["name"])
		a.job = str(d["job"])
		a.ability = int(d["ability"])
		a.salary = int(d["salary"])
		a.employment_type = str(d.get("employment_type", "regular"))
		var skill: Dictionary = d.get("skill", {})
		a.skill_name = str(skill.get("name", ""))
		a.skill_description = str(skill.get("description", ""))
		a.skill_type = str(skill.get("type", "none"))
		a.skill_value = skill.get("value", 0)
		a.portrait = d.get("portrait", {})
		adventurers.append(a)


func _parse_quests(list: Array) -> void:
	for d: Variant in list:
		var q := QuestDef.new()
		q.id = str(d["id"])
		q.name = str(d["name"])
		q.difficulty = int(d["difficulty"])
		q.weeks = int(d["weeks"])
		q.reward = int(d["reward"])
		q.job = str(d["job"])
		q.required_reputation = int(d.get("required_reputation", 0))
		q.appear_week = int(d.get("appear_week", 1))
		q.description = str(d.get("description", ""))
		q.repeatable = bool(d.get("repeatable", false))
		q.reputation_cap = int(d.get("reputation_cap", -1))
		quests.append(q)


func _validate() -> void:
	var c := config
	if c.outcomes.is_empty():
		errors.append("balance.json: outcomes が空")
	else:
		for i in range(1, c.outcomes.size()):
			var prev := c.outcomes[i - 1]
			var cur := c.outcomes[i]
			if not prev.has_min_diff:
				errors.append("balance.json: 下限なし（null）の段階は最後に置く")
			elif cur.has_min_diff and cur.min_diff >= prev.min_diff:
				errors.append("balance.json: outcomes は min_diff の大きい順に並べる（%s）" % cur.id)
		if c.outcomes[c.outcomes.size() - 1].has_min_diff:
			errors.append("balance.json: 最後の段階の min_diff は null（下限なし）にする")
		if c.outcome_by_id(c.success_outcome) == null:
			errors.append("balance.json: success_outcome %s が outcomes にない" % c.success_outcome)
		for o: OutcomeDef in c.outcomes:
			if o.injury != "" and not c.injuries.has(o.injury):
				errors.append("balance.json: 負傷 %s が injuries にない" % o.injury)
	if c.supply_costs.is_empty() or c.supply_costs[0] != 0:
		errors.append("balance.json: supply_tiers の最初は cost 0 にする")
	if c.party_min < 1 or c.party_max < c.party_min:
		errors.append("balance.json: party_min / party_max がおかしい")
	var ids := {}
	for a: AdventurerDef in adventurers:
		if ids.has(a.id):
			errors.append("adventurers.json: id %s が重複" % a.id)
		ids[a.id] = true
		if not c.jobs.has(a.job):
			errors.append("adventurers.json: %s の職業 %s が jobs にない" % [a.name, a.job])
		if not SKILL_TYPES.has(a.skill_type):
			errors.append("adventurers.json: %s のスキル種類 %s は未対応" % [a.name, a.skill_type])
		if a.skill_type == "outcome_floor" and c.outcome_by_id(str(a.skill_value)) == null:
			errors.append("adventurers.json: %s のスキルの結果ID %s がない" % [a.name, a.skill_value])
	ids.clear()
	for q: QuestDef in quests:
		if ids.has(q.id):
			errors.append("quests.json: id %s が重複" % q.id)
		ids[q.id] = true
		if not c.jobs.has(q.job):
			errors.append("quests.json: %s の推奨職業 %s が jobs にない" % [q.name, q.job])
		if q.weeks < 1:
			errors.append("quests.json: %s の期間は1週以上にする" % q.name)
