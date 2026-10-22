class_name InjuryCase
extends RefCounted
## 判定で出た負傷者1人ぶん。医療費を払うかどうかの選択待ちになる。

var adventurer_id: String = ""
var adventurer_name: String = ""
var quest_name: String = ""
## 負傷ID（light / heavy）
var injury: String = ""
var injury_name: String = ""
## 負傷した時点の休養週数
var rest_weeks: int = 0
var decided: bool = false
var paid_medical: bool = false
