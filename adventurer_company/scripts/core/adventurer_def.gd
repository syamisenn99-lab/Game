class_name AdventurerDef
extends RefCounted
## 冒険者の定義（data/adventurers.json の1件）。ゲーム中に変わらない値。

var id: String = ""
var name: String = ""
var job: String = ""
## 腕前
var ability: int = 0
## 月給（専属契約のとき）
var salary: int = 0
## 歩合契約のとき、依頼の報酬から本人に払う割合（0〜1）
var commission_rate: float = 0.0
## 最初の雇用形態（"regular" = 専属、"commission" = 歩合）
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
## ポートレートの見た目（任意）。{"hair": 色, "skin": 色, "beard": bool}
var portrait: Dictionary = {}
