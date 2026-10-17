class_name EnemyAction
extends Resource
## 敵の1回の行動（予告に出る内容）。

@export var label: String = ""
@export var damage: int = 0
@export var block: int = 0
## 山札の上から捨て札へ送る枚数
@export var discard_top: int = 0


func describe() -> String:
	var parts: Array[String] = []
	if damage > 0:
		parts.append("攻撃 %d" % damage)
	if block > 0:
		parts.append("防御 %d" % block)
	if discard_top > 0:
		parts.append("山札を%d枚捨てさせる" % discard_top)
	return " + ".join(parts)
