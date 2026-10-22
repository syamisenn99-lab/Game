extends SceneTree
## バランスシミュレーター。貪欲AI（tools/greedy_ai.gd）で何度もプレイして集計する。
##   godot --headless --path . --script res://tools/balance_sim.gd -- --runs 1000 --seed 1
## オプション:
##   --runs N         プレイ回数（既定 1000）
##   --seed S         最初のシード。i 回目は S + i（既定 1）
##   --data DIR       data/*.json の代わりに読むフォルダ（例: res://data または絶対パス）
##   --threshold R    支度金を出す成功率のしきい値（既定 0.65）
##   --contracts P    AI の契約の方針: regular（全員専属）/ commission（全員歩合）/ adaptive（状況に合わせる）（既定 regular）

const GreedyAI := preload("res://tools/greedy_ai.gd")
## 「序盤」とみなす週数
const EARLY_WEEKS := 4
## 「最終所持金が目標以上」の割合を出す目標額
const GOAL_STEPS: Array[int] = [300, 500, 700, 900]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var runs := int(args.get("runs", "1000"))
	var first_seed := int(args.get("seed", "1"))
	var data_dir := str(args.get("data", GameData.DEFAULT_DIR))
	var threshold := float(args.get("threshold", "0.65"))
	var policy := str(args.get("contracts", "regular"))

	var data := GameData.load_from(data_dir)
	if not data.is_valid():
		for e: String in data.errors:
			printerr(e)
		quit(1)
		return
	var config := data.config

	var cleared := 0
	var cleared_gold: Array[int] = []
	var all_gold: Array[int] = []
	var bankrupt_weeks := {}
	var reputation_sum := 0
	var success_sum := 0
	var completed_sum := 0
	var supply_sum := 0
	var medical_sum := 0
	var commission_sum := 0
	var departed_sum := 0
	var departed_by := {}
	var quest_stats := {}
	for q: QuestDef in data.quests:
		quest_stats[q.id] = {"accepted": 0, "success": 0, "unfinished": 0, "predicted": 0.0}
	## 序盤（第1〜4週）に失敗した数（3以上はまとめる）→ [回数, クリア数]
	var by_early_failures := {}

	var started := Time.get_ticks_msec()
	for i in runs:
		var c := GameController.new(data, first_seed + i)
		var ai := GreedyAI.new()
		ai.support_threshold = threshold
		ai.contract_policy = policy
		var early_failures := 0
		while not c.is_over():
			ai.plan_week(c)
			var report := c.end_week()
			for e: QuestReportEntry in report.entries:
				var s: Dictionary = quest_stats[e.quest_id]
				s["accepted"] += 1
				s["predicted"] += float(ai.predicted_rates[e.quest_id])
				for one: Dictionary in e.commissions:
					commission_sum += int(one["amount"])
				if config.is_success(e.check.outcome):
					s["success"] += 1
				elif report.week <= EARLY_WEEKS and not c.quest(e.quest_id).def.repeatable:
					early_failures += 1
			ai.decide_injuries(c)
			c.finish_week()
		for q: QuestState in c.quests:
			if q.status == QuestState.Status.UNFINISHED or q.status == QuestState.Status.IN_PROGRESS:
				quest_stats[q.def.id]["accepted"] += 1
				quest_stats[q.def.id]["unfinished"] += 1
		var early_key := mini(early_failures, 3)
		if not by_early_failures.has(early_key):
			by_early_failures[early_key] = [0, 0]
		by_early_failures[early_key][0] += 1
		all_gold.append(c.gold)
		if c.phase == GameController.Phase.CLEARED:
			cleared += 1
			cleared_gold.append(c.gold)
			by_early_failures[early_key][1] += 1
		else:
			bankrupt_weeks[c.bankrupt_week] = int(bankrupt_weeks.get(c.bankrupt_week, 0)) + 1
		reputation_sum += c.reputation
		success_sum += c.success_count
		completed_sum += c.completed_count
		supply_sum += ai.supply_spent
		medical_sum += ai.medical_paid
		for a: AdventurerState in c.adventurers:
			if a.left:
				departed_sum += 1
				departed_by[a.def.name] = int(departed_by.get(a.def.name, 0)) + 1
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0

	print("")
	print("== バランスシミュレーション ==")
	print("データ: %s / 回数: %d / シード: %d〜%d / 支度金しきい値: %d%% / 契約の方針: %s / 所要 %.1f 秒" % [data_dir, runs, first_seed, first_seed + runs - 1, roundi(threshold * 100), policy, elapsed])
	print("")
	print("クリア率: %.1f%%（%d / %d）" % [100.0 * cleared / runs, cleared, runs])
	print("")
	print("最終所持金（クリアした回）: %s" % _summary(cleared_gold))
	print("最終所持金（全体・倒産は倒産時点）: %s" % _summary(all_gold))
	var goals := []
	for goal: int in GOAL_STEPS:
		var n := 0
		for g: int in cleared_gold:
			if g >= goal:
				n += 1
		goals.append("%dG以上 %.1f%%" % [goal, 100.0 * n / runs])
	print("クリアして最終所持金が目標以上だった割合: %s" % " / ".join(goals))
	print("")
	print("最終所持金の分布（クリアした回、100G刻み）:")
	_print_histogram(cleared_gold, 100, cleared)
	print("")
	print("倒産した週:")
	if bankrupt_weeks.is_empty():
		print("  なし")
	for w: int in config.payday_weeks:
		if bankrupt_weeks.has(w):
			var n := int(bankrupt_weeks[w])
			print("  第%2d週: %4d 回（全体の %.1f%%）" % [w, n, 100.0 * n / runs])
	print("")
	print("平均: 最終評判 %.1f / 成功数 %.2f / 完了数 %.2f / 支度金 %.0fG / 医療費 %.0fG" % [
		float(reputation_sum) / runs, float(success_sum) / runs, float(completed_sum) / runs,
		float(supply_sum) / runs, float(medical_sum) / runs])
	print("歩合の支払い 平均 %.0fG / 退職 平均 %.2f人 %s" % [float(commission_sum) / runs, float(departed_sum) / runs, departed_by])
	print("")
	print("序盤（第1〜%d週）の通常の依頼の失敗数ごとのクリア率（挽回できるかの目安）:" % EARLY_WEEKS)
	var keys := by_early_failures.keys()
	keys.sort()
	for k: int in keys:
		var row: Array = by_early_failures[k]
		print("  失敗 %s: 全体の %5.1f%% → クリア率 %5.1f%%" % [
			"%d回" % k if k < 3 else "3回以上", 100.0 * row[0] / runs, 100.0 * row[1] / row[0]])
	print("")
	print("クエスト別（受注：通常は受注率、常設は1プレイあたりの回数 / 成功率：実際と、派遣画面の予測の平均 / 未完了）:")
	for q: QuestDef in data.quests:
		var s: Dictionary = quest_stats[q.id]
		var accepted := int(s["accepted"])
		var resolved := maxi(1, accepted - int(s["unfinished"]))
		var taken := "平均 %4.1f回" % (float(accepted) / runs) if q.repeatable else "受注 %5.1f%%" % (100.0 * accepted / runs)
		print("  %-14s 必要評判%2d  %s  成功 実際 %5.1f%% / 予測 %5.1f%%  未完了 %d" % [
			q.name, q.required_reputation, taken, 100.0 * int(s["success"]) / resolved,
			100.0 * float(s["predicted"]) / resolved, int(s["unfinished"])])
	quit(0)


func _parse_args(list: PackedStringArray) -> Dictionary:
	var args := {}
	var i := 0
	while i < list.size():
		var key := list[i]
		if key.begins_with("--") and i + 1 < list.size():
			args[key.substr(2)] = list[i + 1]
			i += 2
		else:
			i += 1
	return args


func _summary(values: Array[int]) -> String:
	if values.is_empty():
		return "（該当なし）"
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0
	for v: int in sorted:
		sum += v
	var mean := float(sum) / sorted.size()
	var variance := 0.0
	for v: int in sorted:
		variance += (v - mean) * (v - mean)
	var sd := sqrt(variance / sorted.size())
	return "平均 %.0fG / 標準偏差 %.0fG / 最小 %dG / 10%%点 %dG / 中央値 %dG / 90%%点 %dG / 最大 %dG" % [
		mean, sd, sorted[0], _percentile(sorted, 0.1), _percentile(sorted, 0.5), _percentile(sorted, 0.9), sorted[sorted.size() - 1]]


func _percentile(sorted: Array, p: float) -> int:
	return int(sorted[clampi(int(floor(p * (sorted.size() - 1))), 0, sorted.size() - 1)])


func _print_histogram(values: Array[int], bin: int, total: int) -> void:
	if values.is_empty():
		print("  （該当なし）")
		return
	var bins := {}
	for v: int in values:
		var b := int(floor(float(v) / bin)) * bin
		bins[b] = int(bins.get(b, 0)) + 1
	var keys := bins.keys()
	keys.sort()
	for b: int in range(int(keys[0]), int(keys[keys.size() - 1]) + bin, bin):
		var n := int(bins.get(b, 0))
		print("  %5d〜%5dG: %4d %s" % [b, b + bin - 1, n, "#".repeat(roundi(60.0 * n / maxi(1, total)))])
