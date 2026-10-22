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
## 実際に変わった評判（上下限で切られたあと）
var reputation_delta: int = 0
## 負傷者（いなければ null）
var injury: InjuryCase
