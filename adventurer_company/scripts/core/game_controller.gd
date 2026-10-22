class_name GameController
extends RefCounted
## ゲームの進行（派遣・週の終わり・負傷・給料日・勝敗）。UI に依存しない。
##
## 1週の流れ:
##   PLANNING で dispatch() を好きなだけ呼ぶ
##   → end_week()       進行中クエストを進め、終わったものを判定（WEEK_ENDING へ）
##   → decide_injury()  負傷者ごとに医療費を払うか決める
##   → finish_week()    給料日の支払い・歩合の冒険者の不満と退職・勝敗判定・次の週へ
## 月の最初の週の計画フェーズでは change_contract() で雇用形態（専属／歩合）を見直せる。

signal changed

enum Phase { PLANNING, WEEK_ENDING, GAME_OVER, CLEARED }

var data: GameData
var config: BalanceConfig
var rng: GameRng

var phase: Phase = Phase.PLANNING
var week: int = 1
var gold: int = 0
var reputation: int = 0
var adventurers: Array[AdventurerState] = []
var quests: Array[QuestState] = []
## 成功（success_outcome 以上）したクエスト数
var success_count: int = 0
var completed_count: int = 0
## 倒産した週（倒産していなければ 0）
var bankrupt_week: int = 0
## いま締めている週のレポート（WEEK_ENDING 中と、終わった直後に参照できる）
var report: WeekReport

## 進行中クエストの「週ごとの進行処理」に差し込むフック。
## 残り週数を減らす直前に、進行中のクエストごとに hook.call(controller, quest_state, report) で呼ぶ。
## 今回は空。伝令イベントなどを後から足すための口。
var mission_week_hooks: Array[Callable] = []


func _init(game_data: GameData, seed_value: int = 0) -> void:
	data = game_data
	config = game_data.config
	rng = GameRng.new(seed_value)
	new_game(seed_value)


func new_game(seed_value: int) -> void:
	rng.set_seed(seed_value)
	phase = Phase.PLANNING
	week = 1
	gold = config.initial_gold
	reputation = config.initial_reputation
	success_count = 0
	completed_count = 0
	bankrupt_week = 0
	report = null
	adventurers.clear()
	for def: AdventurerDef in data.adventurers:
		adventurers.append(AdventurerState.new(def))
	quests.clear()
	for def: QuestDef in data.quests:
		quests.append(QuestState.new(def))
	_update_board(null)
	changed.emit()


# ---- 参照 ----

func is_over() -> bool:
	return phase == Phase.GAME_OVER or phase == Phase.CLEARED


func month() -> int:
	return config.month_of(week)


func next_payday_week() -> int:
	return config.next_payday(week)


## 次の給料日まであと何週か（今週末なら 0、もうなければ -1）
func weeks_until_payday() -> int:
	var w := next_payday_week()
	return w - week if w > 0 else -1


## 給料日に払う月給。歩合の冒険者と退職した冒険者は 0
func salary_for(adventurer: AdventurerState) -> int:
	if adventurer.left:
		return 0
	match adventurer.employment_type:
		"commission":
			return 0
		_:
			return adventurer.def.salary


## 歩合の冒険者がこの月に稼がないと不満になる額
func discontent_threshold(adventurer: AdventurerState) -> int:
	return roundi(adventurer.def.salary * config.discontent_ratio)


## 報酬 reward のうち、パーティの歩合の冒険者に払う分 {"id", "name", "rate", "amount"} の一覧
func commission_split(party_ids: Array[String], reward: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for adventurer_id: String in party_ids:
		var a := adventurer(adventurer_id)
		if a != null and a.is_commission():
			list.append({"id": a.def.id, "name": a.def.name, "rate": a.def.commission_rate,
				"amount": roundi(reward * a.def.commission_rate)})
	return list


## 会社の手取りの期待値（報酬 − 歩合 の期待値 − 支度金）。派遣画面と AI が使う
func expected_company_income(q: QuestState, party_ids: Array[String], supply_tier: int) -> float:
	var table := preview_probabilities(q, party_ids, supply_tier)
	var expected := 0.0
	for o: OutcomeDef in config.outcomes:
		var reward := roundi(q.def.reward * o.reward_rate)
		var paid := 0
		for c: Dictionary in commission_split(party_ids, reward):
			paid += int(c["amount"])
		expected += table.rate(o.id) * (reward - paid)
	return expected - config.supply_cost(supply_tier)


# ---- 契約 ----

## いま契約を見直せるか（月の最初の週の計画フェーズ）
func is_contract_week() -> bool:
	return phase == Phase.PLANNING and config.is_month_start(week)


## 契約を変えられないときの理由。変えられるなら空文字
func contract_error(adventurer_id: String, type_id: String) -> String:
	var a := adventurer(adventurer_id)
	if a == null or not config.employment_types.has(type_id):
		return "契約の指定がおかしい"
	if not is_contract_week():
		return "契約を見直せるのは月の最初の週だけ"
	if a.left:
		return "%sはもう辞めている" % a.def.name
	if a.mission_id != "":
		return "%sは派遣中" % a.def.name
	return ""


## 雇用形態を変える。変えられなければ理由を返す（成功なら空文字）
func change_contract(adventurer_id: String, type_id: String) -> String:
	var error := contract_error(adventurer_id, type_id)
	if error != "":
		return error
	var a := adventurer(adventurer_id)
	if a.employment_type != type_id:
		a.employment_type = type_id
		a.discontent = 0
		a.earned_this_month = 0
	changed.emit()
	return ""


## 給料日に払う総額
func payroll() -> int:
	var total := 0
	for a: AdventurerState in adventurers:
		total += salary_for(a)
	return total


func adventurer(adventurer_id: String) -> AdventurerState:
	for a: AdventurerState in adventurers:
		if a.def.id == adventurer_id:
			return a
	return null


func quest(quest_id: String) -> QuestState:
	for q: QuestState in quests:
		if q.def.id == quest_id:
			return q
	return null


## 掲示板に貼られている紙（掲示中と受注中）
func board_quests() -> Array[QuestState]:
	var list: Array[QuestState] = []
	for q: QuestState in quests:
		if q.status == QuestState.Status.POSTED or q.status == QuestState.Status.IN_PROGRESS:
			list.append(q)
	return list


## 掲示がこの週で終わるか（受注されないと次の週に消える）。常設依頼は最終週まで
func last_listed_week(q: QuestState) -> int:
	if q.def.repeatable:
		return config.total_weeks
	return q.def.appear_week + config.quest_listing_weeks - 1


func is_unlocked(q: QuestState) -> bool:
	return reputation >= q.def.required_reputation


func idle_adventurers() -> Array[AdventurerState]:
	var list: Array[AdventurerState] = []
	for a: AdventurerState in adventurers:
		if a.is_idle():
			list.append(a)
	return list


func party_defs(party_ids: Array[String]) -> Array[AdventurerDef]:
	var defs: Array[AdventurerDef] = []
	for adventurer_id: String in party_ids:
		var a := adventurer(adventurer_id)
		if a != null:
			defs.append(a.def)
	return defs


## 派遣画面・AI 用。実判定と同じ補正
func preview_modifiers(q: QuestState, party_ids: Array[String], supply_tier: int) -> CheckModifiers:
	return CheckRules.build_modifiers(party_defs(party_ids), q.def, supply_tier, config)


## 派遣画面・AI 用。実判定と同じ補正・同じ判定関数から出した確率
func preview_probabilities(q: QuestState, party_ids: Array[String], supply_tier: int) -> ProbabilityTable:
	return CheckRules.probabilities(preview_modifiers(q, party_ids, supply_tier), config)


# ---- 派遣 ----

## 派遣できないときの理由。派遣できるなら空文字
func dispatch_error(q: QuestState, party_ids: Array[String], supply_tier: int) -> String:
	if phase != Phase.PLANNING:
		return "いまは派遣できない"
	if q == null or q.status != QuestState.Status.POSTED:
		return "このクエストは受注できない"
	if not is_unlocked(q):
		return "評判%dで受注可" % q.def.required_reputation
	if party_ids.size() < config.party_min:
		return "冒険者を選んでください"
	if party_ids.size() > config.party_max:
		return "パーティは%d人まで" % config.party_max
	var seen := {}
	for adventurer_id: String in party_ids:
		var a := adventurer(adventurer_id)
		if a == null or seen.has(adventurer_id):
			return "冒険者の指定がおかしい"
		seen[adventurer_id] = true
		if not a.is_idle():
			return "%sは待機中ではない" % a.def.name
	if supply_tier < 0 or supply_tier >= config.supply_tier_count():
		return "支度金の指定がおかしい"
	if config.supply_cost(supply_tier) > gold:
		return "所持金が足りない"
	return ""


## 派遣する。失敗したら理由を返す（成功なら空文字）
func dispatch(q: QuestState, party_ids: Array[String], supply_tier: int) -> String:
	var error := dispatch_error(q, party_ids, supply_tier)
	if error != "":
		return error
	gold -= config.supply_cost(supply_tier)
	q.status = QuestState.Status.IN_PROGRESS
	q.weeks_left = q.def.weeks
	q.party_ids = party_ids.duplicate()
	q.supply_tier = supply_tier
	q.accepted_week = week
	for adventurer_id: String in party_ids:
		adventurer(adventurer_id).mission_id = q.def.id
	changed.emit()
	return ""


# ---- 週の終わり ----

func end_week() -> WeekReport:
	assert(phase == Phase.PLANNING)
	report = WeekReport.new()
	report.week = week

	# 休養中の冒険者の休養を1週進める（今週負傷した人は、このあと設定されるので減らない）
	for a: AdventurerState in adventurers:
		if a.mission_id == "" and a.rest_weeks > 0:
			a.rest_weeks -= 1

	for q: QuestState in quests:
		if q.status != QuestState.Status.IN_PROGRESS:
			continue
		for hook: Callable in mission_week_hooks:
			hook.call(self, q, report)
		q.weeks_left -= 1
		if q.weeks_left <= 0:
			_complete(q)

	phase = Phase.WEEK_ENDING
	changed.emit()
	return report


func _complete(q: QuestState) -> void:
	var mods := CheckRules.build_modifiers(party_defs(q.party_ids), q.def, q.supply_tier, config)
	var result := CheckRules.resolve(mods, config, rng)
	q.result = result
	q.status = QuestState.Status.COMPLETED
	q.times_completed += 1
	completed_count += 1
	if config.is_success(result.outcome):
		success_count += 1

	var entry := QuestReportEntry.new()
	entry.quest_id = q.def.id
	entry.quest_name = q.def.name
	for adventurer_id: String in q.party_ids:
		entry.party_names.append(adventurer(adventurer_id).def.name)
	entry.supply_cost = config.supply_cost(q.supply_tier)
	entry.check = result
	entry.base_reward = q.def.reward
	entry.reward = roundi(q.def.reward * result.outcome.reward_rate)
	entry.commissions = commission_split(q.party_ids, entry.reward)
	entry.company_income = entry.reward
	for c: Dictionary in entry.commissions:
		entry.company_income -= int(c["amount"])
		adventurer(str(c["id"])).earned_this_month += int(c["amount"])
	gold += entry.company_income
	var gain := reputation_gain(q.def, result.outcome)
	entry.reputation_capped = gain < result.outcome.reputation
	entry.reputation_delta = _change_reputation(gain)

	for adventurer_id: String in q.party_ids:
		adventurer(adventurer_id).mission_id = ""

	if result.outcome.injury != "":
		var injured := adventurer(q.party_ids[rng.pick_index(q.party_ids.size())])
		var case := InjuryCase.new()
		case.adventurer_id = injured.def.id
		case.adventurer_name = injured.def.name
		case.quest_name = q.def.name
		case.injury = result.outcome.injury
		case.injury_name = config.injury_name(case.injury)
		case.rest_weeks = config.injury_rest_weeks(case.injury)
		injured.rest_weeks = maxi(injured.rest_weeks, case.rest_weeks)
		entry.injury = case
		report.injuries.append(case)
	report.entries.append(entry)

	# 常設依頼は掲示板に戻り、次の週からまた受けられる
	if q.def.repeatable:
		q.status = QuestState.Status.POSTED
		q.party_ids.clear()
		q.supply_tier = 0


## この依頼のこの結果で変わる評判（評判上限を反映。上限を超えている分は上がらないが、下がりもしない）
func reputation_gain(quest_def: QuestDef, outcome: OutcomeDef) -> int:
	var delta := outcome.reputation
	if delta > 0 and quest_def.reputation_cap >= 0:
		delta = clampi(quest_def.reputation_cap - reputation, 0, delta)
	return delta


func _change_reputation(delta: int) -> int:
	var before := reputation
	reputation = clampi(reputation + delta, config.reputation_min, config.reputation_max)
	return reputation - before


# ---- 負傷 ----

func pending_injuries() -> Array[InjuryCase]:
	var list: Array[InjuryCase] = []
	if report != null and phase == Phase.WEEK_ENDING:
		for c: InjuryCase in report.injuries:
			if not c.decided:
				list.append(c)
	return list


func can_pay_medical() -> bool:
	return gold >= config.medical_cost


## 医療費を払うかを決める。払えなければ理由を返す（成功なら空文字）
func decide_injury(case: InjuryCase, pay: bool) -> String:
	if phase != Phase.WEEK_ENDING or case.decided:
		return "この負傷はもう処理済み"
	if pay:
		if not can_pay_medical():
			return "所持金が足りない"
		gold -= config.medical_cost
		var a := adventurer(case.adventurer_id)
		a.rest_weeks = maxi(0, a.rest_weeks - config.medical_rest_reduction)
		_change_reputation(config.medical_reputation)
	case.decided = true
	case.paid_medical = pay
	changed.emit()
	return ""


# ---- 給料日・次の週 ----

func finish_week() -> WeekReport:
	assert(phase == Phase.WEEK_ENDING)
	assert(pending_injuries().is_empty())

	if config.is_payday(week):
		report.payday = true
		report.payroll = payroll()
		report.gold_before_payday = gold
		if gold < report.payroll:
			report.paid = false
			bankrupt_week = week
			phase = Phase.GAME_OVER
			changed.emit()
			return report
		gold -= report.payroll
		report.paid = true
		if week < config.total_weeks:
			_check_discontent()

	if week >= config.total_weeks:
		for q: QuestState in quests:
			if q.status == QuestState.Status.IN_PROGRESS:
				q.status = QuestState.Status.UNFINISHED
				report.unfinished_quests.append(q.def.name)
				for adventurer_id: String in q.party_ids:
					adventurer(adventurer_id).mission_id = ""
		phase = Phase.CLEARED
		changed.emit()
		return report

	week += 1
	_update_board(report)
	phase = Phase.PLANNING
	changed.emit()
	return report


## 給料日に、歩合の冒険者の今月の稼ぎを見て、不満と退職を決める。
## 派遣中の冒険者は「仕事がある」ので不満は増えない（減りもしない）。
func _check_discontent() -> void:
	for a: AdventurerState in adventurers:
		if a.left or not a.is_commission():
			continue
		if a.earned_this_month >= discontent_threshold(a):
			a.discontent = 0
		elif a.mission_id == "":
			a.discontent += 1
			if a.discontent >= config.leave_after_months:
				a.left = true
				report.departed.append(a.def.name)
			else:
				report.discontented.append(a.def.name)
		a.earned_this_month = 0


## 週の初めに掲示板を更新する（出現・期限切れ）
func _update_board(week_report: WeekReport) -> void:
	for q: QuestState in quests:
		if q.status == QuestState.Status.UPCOMING and q.def.appear_week <= week:
			if week <= last_listed_week(q):
				q.status = QuestState.Status.POSTED
				if week_report != null:
					week_report.new_quests.append(q.def.name)
			else:
				q.status = QuestState.Status.EXPIRED
		elif q.status == QuestState.Status.POSTED and week > last_listed_week(q):
			q.status = QuestState.Status.EXPIRED
			if week_report != null:
				week_report.expired_quests.append(q.def.name)
