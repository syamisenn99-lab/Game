class_name SampleData
extends RefCounted
## MVP サンプルシナリオ（幼なじみ・傭兵）。設計書 §8 に対応。

const CHILDHOOD := &"childhood"
const MERCENARY := &"mercenary"
const DOCTOR := &"doctor"
const NOBLE := &"noble"
## 最初の探索（チュートリアル）のイベント列を指す名前。冒険者ではなく、events() に渡す
const FIRST_ADVENTURE := &"first_adventure"


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
	# 謎の遺物: 冒険者ごとに、別の面だけを報告する。3つの断片がそろうと、正体を推理できる
	list.append(_entry(&"black_cube", &"relics", "黒い立方体（第4層・調査中）",
		"床の中央に置かれた、黒い立方体。表面は{blank:cube_cold}。触れた者は、{blank:cube_memory}らしい。近づくと、{blank:cube_voice}という。",
		{&"cube_cold": "霜のつかない氷のように冷たい", &"cube_memory": "直前の記憶が曖昧になる", &"cube_voice": "聞き覚えのある声がする"}, 0))
	list.append(_entry(&"cube_truth_note", &"relics", "立方体の正体（推理）",
		"冷たさ、記憶、声。三つの断片が重なるなら、あの立方体は、{blank:cube_truth}ではないか。",
		{&"cube_truth": "人の記憶を預かる「器」"}, 0))
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
	if id == FIRST_ADVENTURE:
		return _first_adventure_events()
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


## 幼なじみとの初めての冒険（プロローグのあとの、物語の一場面）。第1層の入口で、3つの出来事。
## 緊張する幼なじみと、耳飾りで初めてつながる。姉の話を書き留めたノートが、初めて役に立つ。
## 操作の案内は、物語のセリフとして伝える（coach）。出来事の前後には、会話（before_lines / after_lines）を挟む。
## ここで埋めた・直したノートは、そのまま本番のノートに残る（姉の話を、あなたが育て始める）。
static func _first_adventure_events() -> Array[EventDef]:
	var list: Array[EventDef] = []

	# ① 青い斑点のキノコ: ノートの項目へ運ぶ（照合）→ 回避
	var f1 := _timed(_event(&"f1_mushroom",
		"えっと、入口の近くは、静かだね……あっ、何かある。洞窟の隅に、[kw:fm_mushroom]青い斑点のキノコ[/kw]が生えてるの。きれい……お金になるかな？ ちょっと、採ってみてもいい？",
		&"evade", 12, {&"fm_mushroom": &"mushroom_poison"},
		"「青い斑点のキノコは、絶対に食べちゃだめだよ」——姉の声が、文字の向こうから、聞こえた気がした。",
		"ふう……。避けて通れたよ。ありがとう。",
		"つい手を伸ばしちゃった…手がかぶれたかも。"), 60.0)
	f1.before_lines = [
		_nl("耳飾りが、かすかに震えた。……声が、届く。"),
		_cl("幼なじみ", "あ、あれ？ 聞こえてる……？ 聞こえてたら、何か言って！"),
		_nl("久しぶりに、誰かの声を聞いた。喉が、きゅっと鳴った。"),
		_nl("あなたは息をひとつ吸って、小さく答えた。——聞こえてる。"),
		_cl("幼なじみ", "よかったぁ……！ ごめんね、さっきから心臓がうるさくて。一人でダンジョンに入るの、初めてなんだ。"),
		_nl("手元には、姉の話を書き留めたノート。これが、あなたの武器だ。"),
	]
	f1.coach = {
		"report": _co("", "耳飾りの向こうで、幼なじみの息づかいがする。声は、文字になって通信ログに流れてくる。映像も、物音もない。頼りになるのは、声と、ノートだけだ。"),
		"drag": _co("", "青い斑点……どこかで聞いた気がする。ノートをめくると、姉が話してくれた、あのページが光って見えた。黄色い言葉を、そのページへ運ぼう。"),
		"wrong_drop": _co("", "……そこじゃない。金色に光っているページに、運んでみよう。"),
		"matched": _co("", "見つけた。「近づかず、触れないように避けて通ること」。書き留めたのは、あなた自身の字だ。でも、確かに、姉の言葉だった。"),
		"command": _co("", "あとは、幼なじみに、どうしてほしいかを伝えるだけだ。近づかず、避けて通る。——下の「回避」を選ぼう。"),
		"wrong_command": _co("", "……違う。ノートには「避けて通ること」とある。伝えるのは、「回避」だ。"),
		"result": _co("幼なじみ", "ふう……！ ね、ね、今のすごい！ そのノート、お姉さんの話なんでしょ？ ちゃんと、生きてるよ。"),
	}
	f1.after_lines = [
		_nl("姉の言葉が、役に立った。胸の奥が、少しだけ、温かくなった。"),
		_cl("幼なじみ", "もうちょっと奥に行くね。……手、まだ震えてる。でも、行けそう。"),
	]
	list.append(f1)

	# ② 爪の獣と松明: ノートの空欄を、見たことで埋める → 戦闘
	var f2 := _timed(_event(&"f2_beast",
		"つ、爪の長い獣が、こっちを見てる……！ 足が、動かない……！ どうしよう、手には[kw:fm_torch]松明[/kw]しかない……えいっ、振ってみる！ ……あっ、獣が、怯んで後ずさった！",
		&"battle", 13, {&"fm_torch": &"beast_aversion"},
		"松明で怯んだ……ってことは、火が苦手なんだ。",
		"火を突きつけながら押し返したら、獣は唸って去っていったよ。",
		"押し切れなくて、飛びかかられて荷物の一部を落としちゃった…"), 60.0)
	f2.before_lines = [
		_nl("洞窟の奥から、乾いた足音が聞こえた。"),
		_cl("幼なじみ", "……ねえ。今、何か聞こえなかった？"),
	]
	f2.coach = {
		"report": _co("", "足音。獣だ。ノートの「鋭い爪の獣」は、「？？？を極端に嫌うらしい」と、空欄になっている。姉も、そこまでは聞き出せなかったのだ。"),
		"drag": _co("", "幼なじみは、見た。松明に、獣が怯むのを。——見たことを、ノートの空欄に書き足そう。「松明」を、「？？？」へ。"),
		"wrong_drop": _co("", "……書き足す場所は、金色に光っている空欄だ。そこへ、運んでみよう。"),
		"matched": _co("", "空白に、「火」と書き足した。姉が聞き逃した続きを、あなたが、初めて埋めた。ノートは、こうして育っていく。"),
		"command": _co("", "怯んだ今が、押し返すチャンスだ。立ち向かうなら、下の「戦闘」を選ぼう。"),
		"wrong_command": _co("", "ノートには「正面から押し返して追い払える」とある。立ち向かうなら、「戦闘」だ。"),
		"result": _co("幼なじみ", "……やった。やった、追い払えた！ ねえ、見た？ 私、一人でできたよ！"),
	}
	f2.after_lines = [
		_nl("いや、一人じゃない。耳飾りの向こうに、あなたがいる。"),
		_cl("幼なじみ", "……うん。そうだね。声があるだけで、全然ちがうよ。ありがとう。"),
	]
	list.append(f2)

	# ③ 光る苔: ノートの間違いを訂正する → 回避。最後は、洞窟を出る場面で締める
	var f3 := _timed(_event(&"f3_moss",
		"光る苔だ、すごい……！ ノートに「触っても無害」ってあったでしょ？ だから、そっと触ってみたんだけど……[kw:fm_numb]手がしびれて[/kw]きた……！ ごめん、ごめんね、私、疑わなかったから……！",
		&"evade", 12, {&"fm_numb": &"moss_safe"},
		"触るとしびれるなんて……ノートが間違ってた。",
		"息を止めて苔から離れたら、しびれもすぐに治まったよ。",
		"しびれたまま慌てて動いて、荷物を少し落としちゃった…"), 60.0)
	f3.before_lines = [
		_cl("幼なじみ", "あっ、光ってる……！ きれい……。"),
		_nl("壁一面に、青白い苔が光っている。"),
	]
	f3.coach = {
		"report": _co("", "ノートの「光る苔」には、「触っても無害」と書いてある。——それは、姉が、誰かから聞いた話だ。聞き間違いが、混じっていたのかもしれない。"),
		"drag": _co("", "報告と、ノートが食い違っている。オレンジに光っている記述が、怪しい。「手がしびれて」を、そこへ運んで、書き直そう。"),
		"wrong_drop": _co("", "……直すのは、光っている記述だ。そこへ、運んでみよう。"),
		"matched": _co("", "「触っても無害」を、「触るとしびれる」に書き直した。姉の話は、完璧じゃなかった。だから、あなたが、直していける。"),
		"command": _co("", "今は、苔から離れるのが先だ。離れて、避けて通る。下の「回避」を選ぼう。"),
		"wrong_command": _co("", "ノートには「立ち止まらずに離れて通ること」とある。離れるなら、「回避」だ。"),
		"result": _co("幼なじみ", "ふう……しびれ、引いてきた。ごめんね、でも、ノートを直せたから、いいよね？"),
	}
	f3.after_lines = [
		_nl("洞窟の入口に、光が見えてきた。"),
		_cl("幼なじみ", "外だ……！ 出られた……！ ねえ、聞こえてる？ ありがとう。あなたの声があったから、最後まで歩けた。"),
		_nl("耳飾りを外すと、静かな部屋が戻ってきた。——けれど、さっきまでとは、少しだけ、違って感じられた。"),
	]
	list.append(f3)
	return list


## 会話の1行（語り）
static func _nl(text: String) -> Dictionary:
	return {"speaker": "", "text": text, "portrait": &""}


## 会話の1行（キャラのセリフ。顔は、冒険者の名前に対応する絵）
static func _cl(speaker: String, text: String) -> Dictionary:
	var faces := {"幼なじみ": CHILDHOOD, "傭兵": MERCENARY, "医師": DOCTOR, "没落貴族": NOBLE}
	return {"speaker": speaker, "text": text, "portrait": faces.get(speaker, &"")}


## 案内の1つ（物語のセリフとして、操作を伝える）
static func _co(speaker: String, text: String) -> Dictionary:
	return {"speaker": speaker, "text": text}


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


## 謎の遺物「黒い立方体」の報告。同じものを見ても、冒険者ごとに、別の面だけを話す。
## すでにノートに書いてある断片は、もう出ない。幼なじみの最後の報告は、3つの断片がそろったときだけ出る（推理の材料がそろった合図）。
static func relic_event(adventurer_id: StringName, filled: Dictionary) -> EventDef:
	var ev: EventDef = null
	if adventurer_id == MERCENARY and not filled.has(&"cube_cold"):
		ev = _merc_event(&"r_merc",
			"第4層。床に黒い箱。一辺、膝の高さ。攻撃は仕掛けてこない。…[kw:r_cold]手袋ごしでも骨まで冷える。なのに霜ひとつ付いていない[/kw]。金になるかは分からん。どうする。",
			&"explore", 13, {&"r_cold": &"cube_cold"},
			"冷たいのに霜が付かない…それだけ、ノートに書いておく。",
			"手を引いた。それ以上は触っていない。……耳鳴りだけが、しばらく残った。",
			"不用意に触れすぎた。手が痺れて、荷を少し落とした。")
	elif adventurer_id == DOCTOR and not filled.has(&"cube_memory"):
		ev = _timed(_event(&"r_doctor",
			"あの、あの黒い箱に、同行者が触れたんです！ 脈は正常、瞳孔も普通、でも…[kw:r_memory]触れる直前の数分の出来事を、彼は思い出せない[/kw]んです！ 外傷はありません、でも、でも、[kw:r_pulse]脈が一瞬だけ止まった[/kw]ような気がして…どうすれば！",
			&"explore", 14, {&"r_memory": &"cube_memory"},
			"直前の記憶だけが抜けている…ノートに書いておくね。それ以上、触れさせないで。",
			"同行者を箱から離したら、少しずつ、記憶が戻ってきたようです…でも、数分だけは、ずっと空白のままで…。",
			"離れさせるのが遅れました…彼の様子が、まだおかしいです…。"), 15.0)
	elif adventurer_id == NOBLE and not filled.has(&"cube_voice"):
		ev = _timed(_event(&"r_noble",
			"おお、これは…！ 黒曜石に似ているが、[kw:nb_cube_stone]表面の光沢は未知の組成[/kw]で、おそらく第零紀の…いや待て。[kw:nb_cube_script]側面に刻まれた、読めぬ古代文字[/kw]もあるが、それよりだ。[kw:r_voice]近づくと、聞き覚えのある声が、耳の奥で囁く[/kw]のだ。…私の、亡き母の声に、似ている。どうすればよい？",
			&"explore", 14, {&"r_voice": &"cube_voice"},
			"近づくと、聞き覚えのある声がする…ノートに書いておくね。それ以上、近づかないで。",
			"後ずさると、声は遠のいた。…あれは、遺物が人の何かを、映しているのだろうか。",
			"声に引き寄せられ、つい手を伸ばしてしまった…少し、荷物を落としたようだ。"), 30.0)
	elif adventurer_id == CHILDHOOD and not filled.has(&"cube_truth") \
			and filled.has(&"cube_cold") and filled.has(&"cube_memory") and filled.has(&"cube_voice"):
		ev = _timed(_event(&"r_child",
			"あのね、前に三人が見た黒い箱を、私も見つけたの。[kw:r_floor]床の模様が、箱を囲むように広がってる[/kw]。それで、[kw:r_truth]箱の中から、姉さんの声がして、私、昨日の晩ごはんを思い出せなくなったの。すごく、冷たい空気の中で[/kw]……ねえ、これって、何なの？",
			&"explore", 13, {&"r_truth": &"cube_truth"},
			"冷たさ、記憶、声…三つがそろった。これは、人の記憶を預かる「器」だ。",
			"箱から離れたら、声はふっと消えた。……あの声は、姉さんが残した記憶の欠片なのかもしれない。",
			"箱に呑まれそうになって、慌てて逃げた…少し、荷物を落としたよ。"), 20.0)
	if ev != null:
		ev.known_line = ""
	return ev


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
	&"f1_mushroom": &"mushroom", &"f2_beast": &"beast", &"f3_moss": &"moss",
	&"d1_rash": &"mushroom", &"d2_herb": &"herb", &"d3_numb": &"moss", &"d4_bats_high": &"bat",
	&"r_merc": &"cube", &"r_doctor": &"cube", &"r_noble": &"cube", &"r_child": &"cube",
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
