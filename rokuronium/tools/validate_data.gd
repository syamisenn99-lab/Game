extends SceneTree
## 使い方:  godot --headless --path rokuronium --script tools/validate_data.gd
## エラーがあれば終了コード 1。

func _initialize() -> void:
	var db := GameDB.new()
	db.load_all()
	var r := DataValidator.validate(db)
	for line in r["info"]:
		print("[情報] ", line)
	for line in r["warnings"]:
		print("[警告] ", line)
	for line in r["errors"]:
		print("[エラー] ", line)
	print("検証結果: エラー %d 件／警告 %d 件" % [r["errors"].size(), r["warnings"].size()])
	quit(1 if not r["errors"].is_empty() else 0)
