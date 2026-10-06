class_name SampleData
extends RefCounted
## MVP サンプルシナリオ（幼なじみ・傭兵）。設計書 §8 に対応。

const CHILDHOOD := &"childhood"
const MERCENARY := &"mercenary"


## 選択画面に並べる冒険者
static func adventurers() -> Array[Adventurer]:
	var list: Array[Adventurer] = []
	list.append(adventurer(CHILDHOOD))
	list.append(adventurer(MERCENARY))
	return list


static func adventurer(id: StringName = CHILDHOOD) -> Adventurer:
	var a := Adventurer.new()
	a.id = id
	if id == MERCENARY:
		a.display_name = "傭兵"
		a.tagline = "自由を買い戻すため、一気に稼ぎたいドライな戦闘屋"
		a.report_style = "短く事務的。「割に合うか」で判断する。報告は正確だが、遺物や仕掛けの手がかりは「金にならん」と流しがち。"
		a.chars_per_sec = 32.0
		a.stats = {&"battle": 5, &"explore": 2, &"evade": 3}
	else:
		a.display_name = "幼なじみ"
		a.tagline = "あなたに元気になってほしい、姉を一緒に探してくれる冒険者"
		a.report_style = "ふつう。見たことを素直に、感じたままに伝えてくれる。"
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
		"群れで天井に張りつく。{blank:bat_weak}に弱いらしい。弱点を突けば追い払える。ふだんは刺激せず、静かに離れて通ること。",
		{&"bat_weak": "大きな音"}, 0))
	list.append(_entry(&"statue_trap", &"traps", "石像の罠",
		"目が光る石像は台座に隠しスイッチがある。台座をよく調べて見つけて押せば止まる。壊そうとすると作動する。"))
	# 落とし穴: 目印は虫食い、深さは間違った記述（どちらも冒険者の報告で育つ）
	var pit := _entry(&"pit_trap", &"traps", "落とし穴",
		"床の{blank:pit_sign}が違う場所に、落とし穴が仕掛けられている。穴は{fix:pit_depth}。見つけたら、踏まずに避けて通ること。",
		{&"pit_sign": "色", &"pit_depth": "底が見えないほど深い"}, 0)
	pit.fix_olds = {&"pit_depth": "浅い"}
	list.append(pit)
	list.append(_entry(&"geo_pattern", &"relics", "壁や床の幾何学模様",
		"壁と床に同じ幾何学模様があるのは、仕掛けの合図。模様をたどってよく調べると、隠された扉が見つかる。", {}, 0))
	list.append(_entry(&"old_tablet", &"relics", "古い石板",
		"文字が刻まれた石板は、古代の記録。{blank:tablet_light}を近づけると文字が浮かぶ。浮かんだ文字を調べれば、隠し部屋の場所が分かることがある。持ち帰れば高く売れるが、とても重い。",
		{&"tablet_light": "灯り"}, 0))
	return list


## ノートに書き込める（虫食い・訂正）箇所の id -> 表示用の名前（例: 「火」（鋭い爪の獣））
static func growth_spots() -> Dictionary:
	var spots: Dictionary = {}
	for entry in entries():
		for id in entry.blank_fills:
			# 項目名の補足（「（第2層）」など）は省いて、カッコが重ならないようにする
			spots[StringName(id)] = "「%s」（%s）" % [entry.blank_fills[id], entry.title.split("（")[0]]
	return spots


## 準備フェーズで売っているダンジョンの情報。買うと、ノートの育つ箇所が1つ埋まる
static func info_offers() -> Array[ShopItem]:
	var list: Array[ShopItem] = []
	list.append(_offer(&"beast_aversion", "爪の獣が嫌うもの", "第2層の「鋭い爪の獣」の弱点を、情報屋が教えてくれる。", 90))
	list.append(_offer(&"moss_safe", "光る苔の本当の性質", "「触っても無害」という又聞きは、本当だろうか。確かめた人から話を聞く。", 90))
	list.append(_offer(&"pit_sign", "落とし穴の見つけ方", "仕掛けの目印を、通りがかりの冒険者が知っている。", 70))
	list.append(_offer(&"pit_depth", "落とし穴の深さ", "「浅い」という話は本当か。落ちたことのある人に聞く。", 90))
	list.append(_offer(&"bat_weak", "コウモリの弱点", "群れで天井に張りつく蝙蝠の、追い払い方。", 70))
	list.append(_offer(&"tablet_light", "石板の読み方", "古い石板の文字を浮かばせる方法を、遺物商が知っている。", 110))
	return list


## 準備フェーズで買える道具（資金の使い道）
static func items() -> Array[ShopItem]:
	var list: Array[ShopItem] = []
	var hourglass := ShopItem.new()
	hourglass.id = &"hourglass"
	hourglass.kind = &"item"
	hourglass.title = "上質な砂時計"
	hourglass.description = "指示を出すまでの制限時間が、2割のびる。"
	hourglass.price = 150
	list.append(hourglass)
	var sticky := ShopItem.new()
	sticky.id = &"sticky"
	sticky.kind = &"item"
	sticky.title = "上質な付箋"
	sticky.description = "貼って剥がせる付箋。間違えて失う時間が、半分になる。"
	sticky.price = 120
	list.append(sticky)
	return list


static func _offer(target: StringName, title: String, description: String, price: int) -> ShopItem:
	var item := ShopItem.new()
	item.id = StringName("info_%s" % target)
	item.kind = &"info"
	item.title = title
	item.description = description
	item.price = price
	item.target = target
	return item


static func events(id: StringName = CHILDHOOD) -> Array[EventDef]:
	if id == MERCENARY:
		return _mercenary_events()
	return _childhood_events()


static func _childhood_events() -> Array[EventDef]:
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
	list.append(_event(&"e6_pit_sign",
		"通路の床に、[kw:dark_floor]色の濃い四角い床[/kw]がある。試しに石を投げたら、床が抜けて石が落ちていった…落とし穴だ！ ここ、どうしよう？",
		&"evade", 12, {&"dark_floor": &"pit_sign"},
		"床の色が違う場所…それが落とし穴の目印なんだ。ノートに書いておくね。",
		"色の濃い床を避けて、遠回りして渡れたよ。",
		"つい近づいちゃって、足を取られた…荷物が少し落ちたよ。"))
	list.append(_event(&"e7_pit_depth",
		"奥の落とし穴に石を落としたら、[kw:no_bottom]いつまで経っても音がしない[/kw]…。底が見えないよ…！ ノートには浅いって書いてあったよね？ どうしよう？",
		&"evade", 12, {&"no_bottom": &"pit_depth"},
		"底が見えないなんて…ノートが間違ってた。「底が見えないほど深い」に直しておくね。",
		"縁から離れて、慎重に迂回できたよ。落ちたら戻れなかったね…",
		"縁に近づきすぎて、ひやっとした…荷物が少し落ちちゃった。"))
	return list


static func _entry_event_beast() -> EventDef:
	# 穴を埋める根拠は、冒険者が「実際に見たこと」（松明で怯んだ）。推測では埋めない。
	return _event(&"e2_beast",
		"爪の長い獣がこっちに来る！とっさに[kw:torch]松明[/kw]を振ったら、怯んで後ずさった！今のうちにどうする？",
		&"battle", 13, {&"torch": &"beast_aversion"},
		"松明で怯んだ…ってことは、火が苦手なんだ！ノートに書いておくね。",
		"火を突きつけながら押し返したら、獣は唸って去っていったよ。",
		"押し切れなくて、飛びかかられて荷物の一部を落としちゃった…")


## 傭兵のシナリオ。報告は短く事務的で、「割に合うか」で判断する。遺物や仕掛けの手がかりは流しがち。
static func _mercenary_events() -> Array[EventDef]:
	var list: Array[EventDef] = []
	list.append(_merc_event(&"m1_bats",
		"天井にコウモリ。三体。[kw:bat]天井の群れ[/kw]を相手にしても、報酬は出ない。損だ。迂回ルートを出せ。",
		&"evade", 12, {&"bat": &"cave_bat"},
		"音に弱くて、刺激しなければいい…静かに離れて通ろう。",
		"静かに迂回した。損失なし。",
		"気づかれた。多少、消耗した。"))
	list.append(_merc_event(&"m2_beast",
		"獣が一体。爪が長い。[kw:torch]松明を向けたら、退いた[/kw]。戦えば報酬に見合う。判断を。",
		&"battle", 13, {&"torch": &"beast_aversion"},
		"松明で退いた…火が苦手ってことだな。ノートに書いておく。",
		"叩き伏せた。報酬に見合う戦いだった。",
		"押し切れなかった。損害が出た。"))
	list.append(_merc_event(&"m3_pattern",
		"壁に模様。どうでもいい。…[kw:pattern]床の石にも同じ模様[/kw]があるが、金にならん。先へ進むぞ。",
		&"explore", 13, {&"pattern": &"geo_pattern"},
		"壁と床に同じ模様…仕掛けの合図だって、ノートに書いてある。調べさせよう。",
		"模様をたどると、壁に隠し扉。……報酬の足しにはなる。",
		"何も出なかった。時間の無駄だったな。"))
	list.append(_merc_event(&"m4_statue",
		"石像だ。目が光る。壊せば早い。…[kw:statue]この石像[/kw]、壊すぞ。止めるなら今だ。",
		&"explore", 13, {&"statue": &"statue_trap"},
		"壊すと作動する、ってノートに書いてある。台座を調べさせよう。",
		"台座にスイッチ。壊すより安く済んだな。",
		"止まらなかったか。…荷が少し減った。"))
	list.append(_merc_event(&"m5_bats_again",
		"またコウモリ。天井に群れ。…[kw:clap]手を叩いたら、三体とも飛び去った[/kw]。音が効くらしい。追い払うか、判断しろ。",
		&"battle", 13, {&"clap": &"bat_weak"},
		"手を叩いたら逃げた…大きな音に弱いってことだな。ノートに書いておく。",
		"音で追い払った。消耗なし。割に合う。",
		"追い払えなかった。多少の損害が出た。"))
	var tablet := _merc_event(&"m6_tablet",
		"石板だ。金になる。重い。…[kw:glow_text]ランプを近づけたら、文字が淡く光った[/kw]が、読めん。報酬になるか、判断を。",
		&"explore", 14, {&"glow_text": &"tablet_light"},
		"灯りで文字が浮かぶ…ノートに書いておく。浮かんだ文字を調べさせよう。",
		"浮かんだ文字を写させた。隠し部屋の場所だ。……金になる。",
		"読み取れなかった。時間の無駄だったな。")
	list.append(tablet)
	return list


static func _merc_event(id: StringName, report: String, stat: StringName, base: int,
		targets: Dictionary, correct_line: String, success: String, fail: String) -> EventDef:
	var ev := _event(id, report, stat, base, targets, correct_line, success, fail)
	ev.time_limit = 20.0
	return ev


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
