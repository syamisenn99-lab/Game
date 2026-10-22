class_name AdventurerDef
extends RefCounted
## 冒険者の定義（data/adventurers.json の1件）。ゲーム中に変わらない値。

var id: String = ""
var name: String = ""
var job: String = ""
## 腕前
var ability: int = 0
## 月給
var salary: int = 0
## 雇用形態。今回は全員 "regular"。将来、契約・歩合などを足すときの入口
var employment_type: String = "regular"
var skill_name: String = ""
var skill_description: String = ""
## スキルの種類（CheckRules.build_modifiers が解釈する）
##   party_bonus   : パーティの判定 +value
##   supply_bonus  : 支度金を出したとき支度金補正 +value
##   advantage     : d20 を value 回振って高い方を使う
##   outcome_floor : 結果が value（結果ID）より悪くならない
##   none          : 判定への効果なし
var skill_type: String = "none"
var skill_value: Variant = 0
