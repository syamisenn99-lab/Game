class_name NoteEntry
extends Resource
## ノートの1項目。本文中の記法で、書き換わる箇所を表す。
##   "{blank:id}" … 虫食いの穴（最初は空欄）
##   "{fix:id}"   … 間違っているかもしれない記述（最初は fix_olds の古い文が書いてあり、報告で訂正できる）

@export var id: StringName
@export var page: StringName
@export var title: String
@export_multiline var body: String
## 穴／訂正箇所の id -> 埋まった（訂正された）ときに表示する語
@export var blank_fills: Dictionary = {}
## 訂正箇所の id -> 最初に書いてある（間違っている）語
@export var fix_olds: Dictionary = {}
## 0 = 不確か（又聞き）, 1 = 確定
@export var reliability: int = 1


## 本文を {text, blank, fix} の断片列に分解する。blank / fix が空でなければ、そこが書き換わる箇所。
func body_segments() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pos := 0
	while pos < body.length():
		var open_blank := body.find("{blank:", pos)
		var open_fix := body.find("{fix:", pos)
		var open := -1
		var is_fix := false
		if open_blank != -1 and (open_fix == -1 or open_blank < open_fix):
			open = open_blank
		elif open_fix != -1:
			open = open_fix
			is_fix = true
		if open == -1:
			out.append({"text": body.substr(pos), "blank": &"", "fix": &""})
			break
		if open > pos:
			out.append({"text": body.substr(pos, open - pos), "blank": &"", "fix": &""})
		var close := body.find("}", open)
		if close == -1:
			out.append({"text": body.substr(open), "blank": &"", "fix": &""})
			break
		var prefix_len := 5 if is_fix else 7
		var key := StringName(body.substr(open + prefix_len, close - open - prefix_len))
		out.append({"text": "", "blank": &"" if is_fix else key, "fix": key if is_fix else &""})
		pos = close + 1
	return out
