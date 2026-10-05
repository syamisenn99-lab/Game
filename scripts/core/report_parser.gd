class_name ReportParser
extends RefCounted
## 報告文 "…[kw:id]語[/kw]…" を、通常テキストとキーワードの断片列に分解する。


static func parse(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pos := 0
	while pos < text.length():
		var open := text.find("[kw:", pos)
		if open == -1:
			out.append({"text": text.substr(pos), "kw": &""})
			break
		if open > pos:
			out.append({"text": text.substr(pos, open - pos), "kw": &""})
		var id_end := text.find("]", open)
		var close := text.find("[/kw]", id_end) if id_end != -1 else -1
		if id_end == -1 or close == -1:
			out.append({"text": text.substr(open), "kw": &""})
			break
		var id := text.substr(open + 4, id_end - open - 4)
		out.append({"text": text.substr(id_end + 1, close - id_end - 1), "kw": StringName(id)})
		pos = close + 5
	return out


## 断片列の表示文字数の合計（タイプライター用）
static func total_chars(segments: Array[Dictionary]) -> int:
	var n := 0
	for seg in segments:
		n += String(seg["text"]).length()
	return n
