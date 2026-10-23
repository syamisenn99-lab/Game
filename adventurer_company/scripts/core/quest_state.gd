class_name QuestState
extends RefCounted
## クエストのゲーム中の状態。

enum Status {
	UPCOMING,     ## まだ掲示されていない
	POSTED,       ## 掲示板に出ている（受注可・評判不足の両方）
	IN_PROGRESS,  ## 派遣中
	COMPLETED,    ## 判定まで終わった
	EXPIRED,      ## 受注されないまま掲示期間が過ぎた
	UNFINISHED,   ## 最終週の終わりに完了していなかった（報酬なし）
}

var def: QuestDef
var status: Status = Status.UPCOMING
## 残り週数（派遣中）
var weeks_left: int = 0
var party_ids: Array[String] = []
var supply_tier: int = 0
var accepted_week: int = 0
## 最後の判定結果
var result: CheckResult
## 完了した回数（常設依頼は何度でも完了する）
var times_completed: int = 0


func _init(definition: QuestDef) -> void:
	def = definition
