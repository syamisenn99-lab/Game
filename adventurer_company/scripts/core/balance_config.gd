class_name BalanceConfig
extends RefCounted
## バランス定数（data/balance.json）。

var initial_gold: int = 300
var initial_reputation: int = 10
## 経営目標：最終週の給料日のあと、この額以上残っていれば経営達成（0 なら倒産しなければ達成）
var goal_gold: int = 0
var reputation_min: int = 0
var reputation_max: int = 100
var total_weeks: int = 12
var weeks_per_month: int = 4
var payday_weeks: Array[int] = []
var party_min: int = 1
var party_max: int = 3
var dice_sides: int = 20
var extra_member_bonus: int = 2
var job_match_bonus: int = 3
## 受注されないまま掲示される週数（出現週を含む）
var quest_listing_weeks: int = 3
## この結果以上を「成功」として数える（成功率・成功数）
var success_outcome: String = "narrow_success"
## 職業ID → 表示名
var jobs: Dictionary = {}
var supply_costs: Array[int] = []
var supply_bonuses: Array[int] = []
## 良い順
var outcomes: Array[OutcomeDef] = []
## 負傷ID → {"name": String, "rest_weeks": int}
var injuries: Dictionary = {}
## 雇用形態ID → 表示名
var employment_types: Dictionary = {"regular": "専属", "commission": "歩合"}
## 歩合の冒険者は、その月の稼ぎが「月給 × これ」未満だと不満がたまる
var discontent_ratio: float = 0.5
## 不満がこの月数続くと退職する
var leave_after_months: int = 2
## 専属から歩合に切り替えられた冒険者が、最初から抱える不満（給料を切られた恨み）
var discontent_on_switch: int = 0
var medical_cost: int = 30
var medical_rest_reduction: int = 1
var medical_reputation: int = 2


func employment_name(type_id: String) -> String:
	return str(employment_types.get(type_id, type_id))


## 月の最初の週か（契約を見直せる週）
func is_month_start(week: int) -> bool:
	return (week - 1) % weeks_per_month == 0


func job_name(job_id: String) -> String:
	return str(jobs.get(job_id, job_id))


func supply_tier_count() -> int:
	return supply_costs.size()


func supply_cost(tier: int) -> int:
	return supply_costs[tier]


func supply_bonus(tier: int) -> int:
	return supply_bonuses[tier]


func outcome_by_id(outcome_id: String) -> OutcomeDef:
	for o: OutcomeDef in outcomes:
		if o.id == outcome_id:
			return o
	return null


## 差から段階を引く。outcomes は良い順に並んでいる
func outcome_for_diff(diff: int) -> OutcomeDef:
	for o: OutcomeDef in outcomes:
		if not o.has_min_diff or diff >= o.min_diff:
			return o
	return outcomes[outcomes.size() - 1]


func is_success(outcome: OutcomeDef) -> bool:
	return outcome.rank <= outcome_by_id(success_outcome).rank


func injury_name(injury_id: String) -> String:
	return str(injuries[injury_id]["name"])


func injury_rest_weeks(injury_id: String) -> int:
	return int(injuries[injury_id]["rest_weeks"])


func is_payday(week: int) -> bool:
	return payday_weeks.has(week)


func month_of(week: int) -> int:
	return (week - 1) / weeks_per_month + 1


## week 以降で最初の給料日。なければ 0
func next_payday(week: int) -> int:
	for w: int in payday_weeks:
		if w >= week:
			return w
	return 0
