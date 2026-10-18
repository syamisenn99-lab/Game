class_name EncounterData
extends Resource
## 1回の戦闘に出てくる敵の組み合わせ。

@export var id: StringName
@export var display_name: String = ""
@export var enemies: Array[EnemyData] = []
