class_name AdventurerState
extends RefCounted
## 冒険者のゲーム中の状態。

enum Status { IDLE, ON_MISSION, RESTING, LEFT }

var def: AdventurerDef
## 雇用形態（"regular" = 専属、"commission" = 歩合）。月の最初の週に見直せる
var employment_type: String = "regular"
## 歩合で今月稼いだ額
var earned_this_month: int = 0
## 稼ぎが足りなかった月が何か月続いているか（歩合のみ）
var discontent: int = 0
## 退職したか
var left: bool = false
## 休養の残り週数
var rest_weeks: int = 0
## 派遣中のクエストID。空なら派遣していない
var mission_id: String = ""


func _init(definition: AdventurerDef) -> void:
	def = definition
	employment_type = definition.employment_type


func status() -> Status:
	if left:
		return Status.LEFT
	if mission_id != "":
		return Status.ON_MISSION
	if rest_weeks > 0:
		return Status.RESTING
	return Status.IDLE


func is_commission() -> bool:
	return employment_type == "commission"


func is_idle() -> bool:
	return status() == Status.IDLE
