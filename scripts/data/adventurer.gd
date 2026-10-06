class_name Adventurer
extends Resource

@export var id: StringName
@export var display_name: String
## 選択画面に出す紹介文
@export var tagline: String
## 報告のクセ（選択画面に出す）
@export var report_style: String
## 報告の表示速度（文字/秒）。事務的で短い報告ほど速い
@export var chars_per_sec: float = 25.0
## battle / explore / evade -> 値
@export var stats: Dictionary = {}


## 能力値の値。無指示（空）のときは平均値。
func stat_for(stat: StringName) -> int:
	if stat != &"" and stats.has(stat):
		return int(stats[stat])
	var sum := 0
	for key in stats:
		sum += int(stats[key])
	return roundi(float(sum) / maxf(1.0, float(stats.size())))
