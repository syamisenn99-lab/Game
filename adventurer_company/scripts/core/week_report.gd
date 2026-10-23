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

## 給料日に不満を持った歩合の冒険者（次も稼げないと退職）・退職した冒険者
var discontented: Array[String] = []
var departed: Array[String] = []

## 次の週に掲示されたクエスト名・消えたクエスト名
var new_quests: Array[String] = []
var expired_quests: Array[String] = []
## 最終週に未完了で報酬なしになったクエスト名
var unfinished_quests: Array[String] = []
