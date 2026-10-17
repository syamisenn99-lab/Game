class_name EnemyData
extends Resource
## 敵の定義。行動は順番どおりに繰り返す。

@export var id: StringName
@export var display_name: String = ""
@export var max_hp: int = 10
@export var actions: Array[EnemyAction] = []
