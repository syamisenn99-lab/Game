class_name EnemyData
extends Resource
## 敵の定義。行動パターンは「順番どおり」か「重み付きランダム」。

enum Pattern { SEQUENCE, WEIGHTED }

@export var id: StringName
@export var display_name: String = ""
@export var max_hp: int = 10
@export var pattern: Pattern = Pattern.SEQUENCE
@export var actions: Array[EnemyAction] = []
