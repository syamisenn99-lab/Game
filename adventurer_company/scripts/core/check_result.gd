class_name CheckResult
extends RefCounted
## 1回の判定の結果。出目と補正の内訳をそのまま持つ（結果レポートに出す）。

var modifiers: CheckModifiers
## 振った目すべて
var dice: Array[int] = []
## 採用した目
var used_die: int = 0
var bonus: int = 0
var total: int = 0
var difficulty: int = 0
## 判定値 − 難易度
var diff: int = 0
## 差だけで決まる段階
var raw_outcome: OutcomeDef
## スキル（鉄壁など）を反映した最終結果
var outcome: OutcomeDef
## 下限スキルで結果が引き上げられたか
var floored: bool = false
