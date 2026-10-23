class_name ProbabilityTable
extends RefCounted
## 5段階それぞれの出方を、全ての目を数え上げた件数で持つ（厳密な確率）。

var config: BalanceConfig
## 結果ID → 件数
var counts: Dictionary = {}
## 数え上げた目の組み合わせの総数（20 または 400）
var total: int = 0


func count(outcome_id: String) -> int:
	return int(counts.get(outcome_id, 0))


func rate(outcome_id: String) -> float:
	return float(count(outcome_id)) / float(total) if total > 0 else 0.0


func success_count() -> int:
	var n := 0
	for o: OutcomeDef in config.outcomes:
		if config.is_success(o):
			n += count(o.id)
	return n


## 成功率（success_outcome 以上の確率）
func success_rate() -> float:
	return float(success_count()) / float(total) if total > 0 else 0.0
