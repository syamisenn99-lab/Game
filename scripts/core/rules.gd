class_name Rules
extends RefCounted
## ゲームバランスの数値をここに集約する（すべて仮の初期値。プレイして調整する）。

const DICE_SIDES := 20

## 不一致ドロップで消費する時間（秒）
const MISMATCH_PENALTY_SEC := 1.5

## 判定の目標値補正
const MOD_MATCHED_CORRECT_STAT := -4
const MOD_MATCHED_WRONG_STAT := 0
const MOD_UNMATCHED_CORRECT_STAT := 0
const MOD_UNMATCHED_WRONG_STAT := 4
const MOD_NO_INSTRUCTION := 2

## 失敗時の持ち帰り報酬の減少率
const FAIL_REWARD_LOSS := 0.10
const CRIT_FAIL_REWARD_LOSS := 0.20
const INITIAL_REWARD := 300.0

## タイプライター表示の速度（文字/秒）
const CHARS_PER_SEC := 25.0

const STATS: Array[StringName] = [&"battle", &"observe", &"knowledge", &"spirit"]
const STAT_LABELS := {
	&"battle": "戦闘",
	&"observe": "観察",
	&"knowledge": "知識",
	&"spirit": "精神",
}
