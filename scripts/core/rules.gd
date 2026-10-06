class_name Rules
extends RefCounted
## ゲームバランスの数値をここに集約する（すべて仮の初期値。プレイして調整する）。

const DICE_SIDES := 20

## 不一致ドロップで消費する時間（秒）
const MISMATCH_PENALTY_SEC := 1.5

## 判定の目標値補正
const MOD_MATCHED_CORRECT_STAT := -8
const MOD_MATCHED_WRONG_STAT := 0
const MOD_UNMATCHED_CORRECT_STAT := 0
const MOD_UNMATCHED_WRONG_STAT := 4
const MOD_NO_INSTRUCTION := 2

## 失敗時の持ち帰り報酬の減少率
const FAIL_REWARD_LOSS := 0.10
const CRIT_FAIL_REWARD_LOSS := 0.20
const INITIAL_REWARD := 300.0

## 経済（すべて仮の初期値。遊んで調整する）
const START_FUNDS := 200
## 1日（探索1回）ごとにかかる生活費
const LIVING_COST := 120
## 上質な砂時計: 制限時間にかかる倍率
const HOURGLASS_TIME_SCALE := 1.2
## 上質な付箋: 不一致ドロップで失う時間にかかる倍率
const STICKY_PENALTY_SCALE := 0.5


## 指示（＝判定に使う能力値）。MVP では戦闘・探索・回避の3つに絞る
const STATS: Array[StringName] = [&"battle", &"explore", &"evade"]
const STAT_LABELS := {
	&"battle": "戦闘",
	&"explore": "探索",
	&"evade": "回避",
}
