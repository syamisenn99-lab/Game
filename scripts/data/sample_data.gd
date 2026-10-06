class_name SampleData
extends RefCounted
## MVP サンプルシナリオ（幼なじみ・第1層）。設計書 §8 に対応。


static func adventurer() -> Adventurer:
	var a := Adventurer.new()
	a.display_name = "幼なじみ"
	a.stats = {&"battle": 3, &"explore": 4, &"evade": 3}
	return a


static func entries() -> Array[NoteEntry]:
	var list: Array[NoteEntry] = []
	list.append(_entry(&"mushroom_poison", &"plants", "毒キノコの見分け方",
		"傘に青い斑点があるものは猛毒。触れただけでも手がかぶれるらしい。近づかず、触れないように避けて通ること。"))
	list.append(_entry(&"glow_moss", &"plants", "光る苔",
		"暗い通路で光る苔は食べられる。苦味が強い。毒のある苔と似ているので、よく調べてから採ること。", {}, 0))
	list.append(_entry(&"beast_claw", &"monsters", "鋭い爪の獣（第2層）",
		"爪で獲物を引き裂く。{blank:beast_aversion}を極端に嫌うらしい。怯んだ隙に、正面から押し返して追い払える。",
		{&"beast_aversion": "火"}, 0))
	list.append(_entry(&"cave_bat", &"monsters", "岩穴の蝙蝠",
		"群れで天井に張りつく。大きな音に弱い。刺激せず、静かに離れるのがいちばん。"))
	list.append(_entry(&"statue_trap", &"traps", "石像の罠",
		"目が光る石像は台座に隠しスイッチがある。台座をよく調べて見つけて押せば止まる。壊そうとすると作動する。"))
	list.append(_entry(&"pit_trap", &"traps", "落とし穴",
		"床の色が違う場所は踏まずに避けて通ること。"))
	return list


static func events() -> Array[EventDef]:
	var list: Array[EventDef] = []
	list.append(_event(&"e1_mushroom",
		"あっ、見て！洞窟の隅に[kw:mushroom]青い斑点のキノコ[/kw]が生えてる。おいしそう…食べても平気かな？",
		&"evade", 12, {&"mushroom": &"mushroom_poison"},
		"待って、それは毒だ！",
		"よく見たら怪しい色だね。触らずに避けて通り過ぎたよ。",
		"つい手を伸ばしちゃった…手がかぶれたかも。"))
	list.append(_entry_event_beast())
	list.append(_event(&"e3_statue",
		"奥に不気味な[kw:statue]石像[/kw]がある…目が光った気がする。この先に進みたいんだけど、どうしよう？",
		&"explore", 12, {&"statue": &"statue_trap"},
		"それは罠かも。壊さずに、台座を調べて隠しスイッチを探して！",
		"台座を調べたら、裏にスイッチを見つけた！ 石像の目の光が消えたよ。",
		"石像が動き出して、慌てて逃げ出した…荷物が少し落ちちゃった。"))
	return list


static func _entry_event_beast() -> EventDef:
	# 穴を埋める根拠は、冒険者が「実際に見たこと」（松明で怯んだ）。推測では埋めない。
	return _event(&"e2_beast",
		"爪の長い獣がこっちに来る！とっさに[kw:torch]松明[/kw]を振ったら、怯んで後ずさった！今のうちにどうする？",
		&"battle", 13, {&"torch": &"beast_aversion"},
		"松明で怯んだ…ってことは、火が苦手なんだ！ノートに書いておくね。",
		"火を突きつけながら押し返したら、獣は唸って去っていったよ。",
		"押し切れなくて、飛びかかられて荷物の一部を落としちゃった…")


static func _entry(id: StringName, page: StringName, title: String, body: String,
		fills: Dictionary = {}, reliability: int = 1) -> NoteEntry:
	var e := NoteEntry.new()
	e.id = id
	e.page = page
	e.title = title
	e.body = body
	e.blank_fills = fills
	e.reliability = reliability
	return e


static func _event(id: StringName, report: String, stat: StringName, base: int,
		targets: Dictionary, correct_line: String, success: String, fail: String) -> EventDef:
	var ev := EventDef.new()
	ev.id = id
	ev.report = report
	ev.required_stat = stat
	ev.base_target = base
	ev.keyword_targets = targets
	ev.correct_line = correct_line
	ev.success_text = success
	ev.fail_text = fail
	return ev
