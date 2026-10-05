class_name Adventurer
extends Resource

@export var display_name: String
## battle / observe / knowledge / spirit -> 値
@export var stats: Dictionary = {}


## 能力値の値。無指示（空）のときは平均値。
func stat_for(stat: StringName) -> int:
	if stat != &"" and stats.has(stat):
		return int(stats[stat])
	var sum := 0
	for key in stats:
		sum += int(stats[key])
	return roundi(float(sum) / maxf(1.0, float(stats.size())))
