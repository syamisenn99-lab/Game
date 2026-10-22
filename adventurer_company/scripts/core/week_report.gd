class_name WeekReport
extends RefCounted
## 1週の終わりに起きたことのまとめ。

var week: int = 0
var entries: Array[QuestReportEntry] = []
var injuries: Array[InjuryCase] = []
## 週ごとの進行フックが書き込む欄（今回は未使用。伝令イベントなどを想定）
var events: Array[Dictionary] = []

var payday: bool = false
var payroll: int = 0
var gold_before_payday: int = 0
var paid: bool = false

## 次の週に掲示されたクエスト名・消えたクエスト名
var new_quests: Array[String] = []
var expired_quests: Array[String] = []
## 最終週に未完了で報酬なしになったクエスト名
var unfinished_quests: Array[String] = []
