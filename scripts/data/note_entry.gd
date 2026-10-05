class_name NoteEntry
extends Resource
## ノートの1項目。本文中の "{blank:id}" が虫食いの穴になる。

@export var id: StringName
@export var page: StringName
@export var title: String
@export_multiline var body: String
## 穴 id -> 埋まったときに表示する語
@export var blank_fills: Dictionary = {}
## 0 = 不確か（又聞き）, 1 = 確定
@export var reliability: int = 1


## 本文を {text, blank} の断片列に分解する。blank が空でなければ穴。
func body_segments() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pos := 0
	while pos < body.length():
		var open := body.find("{blank:", pos)
		if open == -1:
			out.append({"text": body.substr(pos), "blank": &""})
			break
		if open > pos:
			out.append({"text": body.substr(pos, open - pos), "blank": &""})
		var close := body.find("}", open)
		if close == -1:
			out.append({"text": body.substr(open), "blank": &""})
			break
		out.append({"text": "", "blank": StringName(body.substr(open + 7, close - open - 7))})
		pos = close + 1
	return out
