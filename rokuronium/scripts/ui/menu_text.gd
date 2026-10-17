class_name MenuText
extends RefCounted
## メニュー（ステータス／持ち物／親密度）に出す文章を作る。UIから切り離してテストしやすくする。


static func status(state: GameState) -> String:
	var out: Array[String] = []
	for id in state.party_order:
		var m: Dictionary = state.party[id]
		out.append("[b]%s[/b]　Lv%d　HP %d/%d　MP %d/%d" % [m["name"], m["level"], m["hp"], m["max_hp"], m["mp"], m["max_mp"]])
		var stat_parts: Array[String] = []
		for s in GameState.STAT_NAMES:
			stat_parts.append("%s %d" % [s, int(m["stats"].get(s, 0))])
		out.append("　" + "　".join(stat_parts))
		var skills: Array[String] = []
		for k in m["skills"]:
			skills.append("%sLv%d" % [k, m["skills"][k]])
		out.append("　スキル：" + ("、".join(skills) if not skills.is_empty() else "なし"))
		var eq: Array[String] = []
		for part in m["equipment"]:
			eq.append("%s＝%s" % [part, m["equipment"][part]])
		out.append("　装備：" + ("、".join(eq) if not eq.is_empty() else "なし"))
		out.append("")
	out.append("経験値（累計）：%d" % state.total_exp)
	return "\n".join(out)


static func items(state: GameState, db: GameDB) -> String:
	var out: Array[String] = ["所持金：%s" % Money.format(state.money), ""]
	if state.inventory.is_empty():
		out.append("持ち物はありません。")
	for id in state.inventory:
		var desc := str((db.items.get(id, {}) as Dictionary).get("description", ""))
		out.append("%s ×%d　%s" % [db.item_name(id), state.inventory[id], desc])
	return "\n".join(out)


## 出会ったヒロインだけを ♡ で表示する（内部の数値は見せない）。
static func affinity(state: GameState, db: GameDB) -> String:
	var out: Array[String] = []
	for id in state.affinity:
		if id == "kazuki":
			continue
		out.append("%s　%s" % [db.char_name(id), GameState.hearts_text(int(state.affinity[id]))])
	if out.is_empty():
		out.append("まだ誰とも親しくなっていません。")
	return "\n".join(out)
