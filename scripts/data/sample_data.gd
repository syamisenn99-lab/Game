class_name SampleData
extends RefCounted
## MVP サンプルシナリオ（幼なじみ・傭兵）。設計書 §8 に対応。

const CHILDHOOD := &"childhood"
const MERCENARY := &"mercenary"
const DOCTOR := &"doctor"
const NOBLE := &"noble"


## 選択画面に並べる冒険者
static func adventurers() -> Array[Adventurer]:
	var list: Array[Adventurer] = []
	list.append(adventurer(CHILDHOOD))
	list.append(adventurer(MERCENARY))
	list.append(adventurer(DOCTOR))
	list.append(adventurer(NOBLE))
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
	elif id == DOCTOR:
		a.display_name = "医師"
		a.tagline = "未知の薬草を求めて潜る、訳ありの医師"
		a.report_style = "体の変化や、動植物の生態にやたら詳しい。ただしパニックになりやすく、早口。間違えたときの時間のロスが大きい。"
		a.chars_per_sec = 36.0
		a.panic_factor = 1.5
		a.stats = {&"battle": 1, &"explore": 4, &"evade": 3}
	elif id == NOBLE:
		a.display_name = "没落貴族"
		a.tagline = "古代文明の真理を追う、遺物狂いの没落貴族"
		a.report_style = "知識は豊富だが、話が長くて専門用語だらけ。ハイライトされた語の大半は、本筋と関係のない蘊蓄。必要な手がかりは、長話に埋もれている。"
		a.chars_per_sec = 42.0
		a.stats = {&"battle": 1, &"explore": 5, &"evade": 1}
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
	list.append(_entry(&"herb_moon", &"plants", "月影草",
		"銀色の葉脈を持つ草。{blank:herb_effect}作用があるらしい。摘むときは、まわりをよく調べて、根を傷めないように採ること。",
		{&"herb_effect": "心を落ち着ける"}, 0))
	list.append(_entry(&"geo_pattern", &"relics", "壁や床の幾何学模様",
		"壁と床に同じ幾何学模様があるのは、仕掛けの合図。模様をたどってよく調べると、隠された扉が見つかる。", {}, 0))
	list.append(_entry(&"stone_door", &"relics", "石の扉の鍵穴",
		"古代の石の扉には、{blank:keyhole_shape}の鍵穴がある。合う形の鍵を探して、まわりをよく調べること。",
		{&"keyhole_shape": "星形"}, 0))
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
	list.append(_offer(&"herb_effect", "月影草の効き目", "銀色の葉脈の草の効き目を、薬師が知っている。", 80))
	list.append(_offer(&"keyhole_shape", "石の扉の鍵穴", "古代の扉の鍵穴の形を、遺物商が覚えている。", 100))
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
	if id == DOCTOR:
		return _doctor_events()
	if id == NOBLE:
		return _noble_events()
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


## 医師のシナリオ。体の変化や生態の描写が多く、早口。パニックになりやすく、制限時間は短い。
static func _doctor_events() -> Array[EventDef]:
	var list: Array[EventDef] = []
	list.append(_timed(_event(&"d1_rash",
		"[kw:rash]傘の青い斑点のキノコ[/kw]…！ 近づいただけで、皮膚が赤く熱をもって、脈がどんどん速くなってきました…！ これは触れたらまずいです、どうすれば…！",
		&"evade", 12, {&"rash": &"mushroom_poison"},
		"赤く熱をもつなんて…やっぱり毒キノコだ。近づかずに避けないと！",
		"素早く離れました！ 脈も落ち着いてきました…ふぅ。",
		"慌てて転んでしまって…少し荷物を落としました…！"), 15.0))
	list.append(_timed(_event(&"d2_herb",
		"銀色の葉脈の草…！ [kw:herb]葉に触れると、速かった脈がすっと落ち着いて[/kw]いきます…これは鎮静の作用かもしれません！ 採ってもいいですか…！？",
		&"explore", 13, {&"herb": &"herb_effect"},
		"脈が落ち着く…心を落ち着ける作用があるんだ。ノートに書いておくね。まわりをよく調べて採って！",
		"根を傷めないよう、よく調べて採れました！ これで救える人がいるかも…！",
		"慌てて引き抜いたら、根がちぎれて…すみません…！"), 15.0))
	list.append(_timed(_event(&"d3_numb",
		"光る苔に、うっかり触れてしまって…[kw:numb_d]指先の感覚が鈍って、脈も不規則に[/kw]なっています…！ ノートには触っても無害とあったはず…これは神経に作用する毒です…！",
		&"evade", 12, {&"numb_d": &"moss_safe"},
		"指がしびれて脈も乱れるなんて…ノートが間違ってた。「触るとしびれる」に直すね。離れて！",
		"息を止めて離れたら、しびれも引いてきました…！",
		"動揺して、苔の上を歩き回ってしまいました…荷物を落として…！"), 15.0))
	list.append(_timed(_event(&"d4_bats_high",
		"天井から、耳に刺さるような高い声が…！ [kw:d_bat]天井の蝙蝠の群れ[/kw]です、動悸が止まらなくて…！ 刺激しないほうがいいですよね…！？",
		&"evade", 12, {&"d_bat": &"cave_bat"},
		"刺激せず静かに離れるのがいちばん、ってノートに書いてある。静かに離れて！",
		"音を立てずに離れました…心臓が飛び出しそうでしたが…！",
		"悲鳴を上げてしまって…群れが騒ぎ出して、荷物が少し…！"), 15.0))
	return list


## 没落貴族のシナリオ。報告が長く、ハイライトされた語の大半は本筋と関係のない蘊蓄（おとり）。
## 正解のキーワードは1つだけ。間違った語を運ぶと、時間を失う。
static func _noble_events() -> Array[EventDef]:
	var list: Array[EventDef] = []
	list.append(_timed(_event(&"n1_pattern",
		"おお！ この壁の幾何学模様は第三紀の様式…いや待て、[kw:nb_pigment]壁面に塗られた朱の顔料[/kw]は鉱物由来で、おそらく辰砂だな。それにしても[kw:nb_beam]天井の梁の組み方[/kw]は実に見事で…むむ、[kw:nb_pattern]壁と同じ模様が、床の石にも連なっている[/kw]ぞ！ これは何かの合図に違いない。どう思う？",
		&"explore", 13, {&"nb_pattern": &"geo_pattern"},
		"壁と床に同じ模様…仕掛けの合図だって、ノートに書いてある。調べて！",
		"模様をたどると、壁に隠し扉が…！ 素晴らしい、実に素晴らしい！",
		"ううむ、何も見つからぬ…私の見立てが誤りだったか…。"), 30.0))
	list.append(_timed(_event(&"n2_tablet",
		"なんと、古代の石板だ！ [kw:nb_weather]表面の風化の具合[/kw]から察するに、数千年は経っておるな。刻まれた文字は第一紀のもので…ふむ、[kw:nb_light]灯りを近づけると、刻まれた文字がうっすらと浮かび上がる[/kw]ではないか！ だが肝心の[kw:nb_text]文字の意味[/kw]は、私にも分からぬ…どうすれば？",
		&"explore", 14, {&"nb_light": &"tablet_light"},
		"灯りで文字が浮かぶ…ノートに書いておくね。浮かんだ文字を調べて！",
		"浮かんだ文字を写した。隠し部屋の場所が記されておる！ 実に愉快だ！",
		"文字は読み取れなんだ…無念だ。"), 30.0))
	list.append(_timed(_event(&"n3_statue",
		"ふむ、目の光る石像か。[kw:nb_style]この像の様式は第二紀後期[/kw]で、[kw:nb_robe]衣の襞の彫り[/kw]が…いや、そんなことよりだ。[kw:nb_statue]台座の付いた、目が光る石像[/kw]、これは見るからに仕掛けだな。壊して通るのは野蛮だと思うが…どうしたものか。",
		&"explore", 13, {&"nb_statue": &"statue_trap"},
		"壊すと作動する、ってノートに書いてある。台座を調べて！",
		"台座の裏にスイッチを発見した！ 実に優雅な解決だ。",
		"石像が動き出した…！ 逃げるぞ…荷物が落ちたが…！"), 30.0))
	list.append(_timed(_event(&"n4_keyhole",
		"見よ、巨大な石の扉だ！ [kw:nb_carve]扉の彫刻の見事さ[/kw]は、[kw:nb_king]古代の王の権威[/kw]を示すもので…おっと、それよりも、[kw:nb_star]扉の中央にある、五つの角をもつ星の形のくぼみ[/kw]を見たまえ。これが鍵穴に違いない！ 合う鍵を探さねば…どうすればよい？",
		&"explore", 13, {&"nb_star": &"keyhole_shape"},
		"五つの角をもつ星の形の鍵穴…ノートに書いておくね。まわりを調べて、合う鍵を探して！",
		"壁の隅に、星形の鍵が埋まっていた！ 見事だ！",
		"鍵は見つからなかった…時間ばかりが過ぎたな。"), 30.0))
	return list


## イベントの制限時間を変える
static func _timed(ev: EventDef, seconds: float) -> EventDef:
	ev.time_limit = seconds
	return ev


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


## イベントごとの冒険者のスケッチ（絵の名前）。絵のファイルが無ければ、何も表示されない
const SKETCHES := {
	&"e1_mushroom": &"mushroom", &"e2_beast": &"beast", &"e3_statue": &"statue", &"e4_beast_again": &"beast",
	&"e5_moss": &"moss", &"e6_pit_sign": &"pit", &"e7_pit_depth": &"pit_deep",
	&"m1_bats": &"bat", &"m2_beast": &"beast", &"m3_pattern": &"pattern", &"m4_statue": &"statue",
	&"m5_bats_again": &"bat", &"m6_tablet": &"tablet",
	&"d1_rash": &"mushroom", &"d2_herb": &"herb", &"d3_numb": &"moss", &"d4_bats_high": &"bat",
	&"n1_pattern": &"pattern", &"n2_tablet": &"tablet", &"n3_statue": &"statue", &"n4_keyhole": &"keyhole",
}


static func _event(id: StringName, report: String, stat: StringName, base: int,
		targets: Dictionary, correct_line: String, success: String, fail: String) -> EventDef:
	var ev := EventDef.new()
	ev.id = id
	ev.sketch = SKETCHES.get(id, &"")
	ev.report = report
	ev.required_stat = stat
	ev.base_target = base
	ev.keyword_targets = targets
	ev.correct_line = correct_line
	ev.success_text = success
	ev.fail_text = fail
	return ev
