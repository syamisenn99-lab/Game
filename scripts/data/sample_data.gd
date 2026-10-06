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
	# 又聞きの記述が間違っている例。報告と食い違ったとき、「触っても無害」を訂正できる
	var moss := _entry(&"glow_moss", &"plants", "光る苔",
		"暗い通路で光る苔は、{fix:moss_safe}。苦味が強い。群生している所は、立ち止まらずに離れて通ること。",
		{&"moss_safe": "触るとしびれる"}, 0)
	moss.fix_olds = {&"moss_safe": "触っても無害"}
	list.append(moss)
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
	list.append(_event_beast_again())
	list.append(_event_moss_contradiction())
	return list


static func _entry_event_beast() -> EventDef:
	# 穴を埋める根拠は、冒険者が「実際に見たこと」（松明で怯んだ）。推測では埋めない。
	return _event(&"e2_beast",
		"爪の長い獣がこっちに来る！とっさに[kw:torch]松明[/kw]を振ったら、怯んで後ずさった！今のうちにどうする？",
		&"battle", 13, {&"torch": &"beast_aversion"},
		"松明で怯んだ…ってことは、火が苦手なんだ！ノートに書いておくね。",
		"火を突きつけながら押し返したら、獣は唸って去っていったよ。",
		"押し切れなくて、飛びかかられて荷物の一部を落としちゃった…")


## 食い違い: ノートには「触っても無害」とあるが、報告では触ってしびれた。ノートを訂正して、回避を選ぶ。
static func _event_moss_contradiction() -> EventDef:
	return _event(&"e5_moss",
		"光る苔がびっしり生えてる！…試しに[kw:numb]触ってみたら、手がしびれて[/kw]きた…！ ノートには触っても無害って書いてあったよね？ どうしよう？",
		&"evade", 12, {&"numb": &"moss_safe"},
		"触るとしびれるなんて…ノートが間違ってた。「触るとしびれる」に直しておくね。",
		"息を止めて苔から離れたら、しびれもすぐに治まったよ。",
		"しびれたまま慌てて動いて、荷物を少し落としちゃった…")


## 2匹目の獣。2つ目のイベントで「火」を埋めていれば、照合済みの状態で始まる（ノートが育った効果）。
## 埋めていなければ、報告の中の観察から自分で照合できる。制限時間は短め。
static func _event_beast_again() -> EventDef:
	var ev := _event(&"e4_beast_again",
		"さっきの爪の長い獣が、また来た！[kw:torch]松明[/kw]を向けたら、すぐに怯んだみたい…！",
		&"battle", 13, {&"torch": &"beast_aversion"},
		"今度も火が効いてる！",
		"松明をかざして押し返したら、獣はあっさり逃げていったよ。ノートのおかげだね。",
		"油断しちゃった…少し荷物を落としちゃった。")
	ev.time_limit = 15.0
	ev.known_blank = &"beast_aversion"
	ev.known_line = "あ、ノートに「火」って書いてある！ これなら落ち着いて追い払えるよ！"
	return ev


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
