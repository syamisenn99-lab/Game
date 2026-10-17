class_name Rules
extends RefCounted
## 判定などのバランス数値と計算式を1か所に集約する（調整はここだけ触る）。
##
## 判定式:  2d6 + ステータス + スキルLv×SKILL_WEIGHT + 補正  >=  難易度  なら成功
##   出目が CRITICAL_ROLL (12) なら大成功（常に成功）、FUMBLE_ROLL (2) なら失敗（常に失敗）。

const DICE_COUNT := 2
const DICE_SIDES := 6
const SKILL_WEIGHT := 2
const CRITICAL_ROLL := 12
const FUMBLE_ROLL := 2

const OUTCOME_CRITICAL := "critical"
const OUTCOME_SUCCESS := "success"
const OUTCOME_FAILURE := "failure"

const OUTCOME_LABEL := {
	OUTCOME_CRITICAL: "大成功",
	OUTCOME_SUCCESS: "成功",
	OUTCOME_FAILURE: "失敗",
}

## レベルアップに必要な累計経験値（Lv2から）。以降はデータ側で拡張予定（フェーズ3）。
const LEVEL_EXP := [0, 0, 30, 70, 120, 180]


static func roll_dice(rng: RandomNumberGenerator) -> int:
	var total := 0
	for i in DICE_COUNT:
		total += rng.randi_range(1, DICE_SIDES)
	return total


## 判定結果を計算する。出目は呼び出し側で振って渡す（テストしやすくするため）。
static func evaluate(roll: int, stat: int, skill_lv: int, mod: int, difficulty: int) -> Dictionary:
	var total := roll + stat + skill_lv * SKILL_WEIGHT + mod
	var outcome := OUTCOME_FAILURE
	if roll == CRITICAL_ROLL:
		outcome = OUTCOME_CRITICAL
	elif roll == FUMBLE_ROLL:
		outcome = OUTCOME_FAILURE
	elif total >= difficulty:
		outcome = OUTCOME_SUCCESS
	return {
		"outcome": outcome,
		"roll": roll,
		"stat": stat,
		"skill_lv": skill_lv,
		"mod": mod,
		"total": total,
		"difficulty": difficulty,
	}
