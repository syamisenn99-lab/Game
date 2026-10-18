class_name Keyword
extends RefCounted
## カードのキーワード。MVPのマイルストーン2では「保持」だけ使う。

const RETAIN := "retain"


static func label(id: String) -> String:
	match id:
		RETAIN: return "保持"
	return id
