class_name QuestReportEntry
extends RefCounted
## 結果レポートの1行（完了したクエスト1件）。

var quest_id: String = ""
var quest_name: String = ""
var party_names: Array[String] = []
var supply_cost: int = 0
var check: CheckResult
var base_reward: int = 0
var reward: int = 0
## 歩合で冒険者に払った分 {"name": String, "rate": float, "amount": int}
var commissions: Array[Dictionary] = []
## 会社に入った額（報酬 − 歩合）
var company_income: int = 0
## 実際に変わった評判（上下限で切られたあと）
var reputation_delta: int = 0
## 依頼の評判上限のせいで、評判が本来より上がらなかったか
var reputation_capped: bool = false
## 負傷者（いなければ null）
var injury: InjuryCase
