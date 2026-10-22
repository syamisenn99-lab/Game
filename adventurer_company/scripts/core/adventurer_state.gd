class_name AdventurerState
extends RefCounted
## 冒険者のゲーム中の状態。

enum Status { IDLE, ON_MISSION, RESTING }

var def: AdventurerDef
## 雇用形態（定義から写す。将来、ゲーム中に変わりうる）
var employment_type: String = "regular"
## 休養の残り週数
var rest_weeks: int = 0
## 派遣中のクエストID。空なら派遣していない
var mission_id: String = ""


func _init(definition: AdventurerDef) -> void:
	def = definition
	employment_type = definition.employment_type


func status() -> Status:
	if mission_id != "":
		return Status.ON_MISSION
	if rest_weeks > 0:
		return Status.RESTING
	return Status.IDLE


func is_idle() -> bool:
	return status() == Status.IDLE
