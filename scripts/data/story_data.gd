class_name StoryData
extends RefCounted
## 導入・ストーリーの場面のデータ。世界観と、姉の手がかりを、ゲームの中で見せる。
## 場面の並びの順番が、同じ条件のときに出る優先順になる。

const NARRATOR := ""


static func all() -> Array[StoryScene]:
	var list: Array[StoryScene] = []
	list.append(_prologue())
	list.append(_prologue_after_tutorial())
	list.append(_intro_mercenary())
	list.append(_intro_doctor())
	list.append(_intro_noble())
	list.append(_clue_1())
	list.append(_clue_2())
	list.append(_clue_3())
	list.append(_clue_4())
	list.append(_clue_5())
	return list


static func find(id: StringName) -> StoryScene:
	for scene in all():
		if scene.id == id:
			return scene
	return null


## 手がかり帳に載る場面（並び順）
static func clues() -> Array[StoryScene]:
	var list: Array[StoryScene] = []
	for scene in all():
		if scene.is_clue():
			list.append(scene)
	return list


# ---------------------------------------------------------------- プロローグ

static func _prologue() -> StoryScene:
	var s := _scene(&"prologue", "プロローグ")
	_n(s, "地下深くに、巨大な遺跡が見つかった。人々はそれを、ダンジョンと呼んだ。")
	_n(s, "中には、見たこともない植物や生き物。そして、人の技では作れない不思議な道具――「遺物」が眠っていた。")
	_n(s, "それらを持ち帰って暮らす人々は、いつしか「冒険者」と呼ばれるようになった。")
	_n(s, "あなたの姉も、その一人だった。")
	_n(s, "あなたは、体質のせいで、家から出られない。だから姉は、離れていても「声だけ」が届く遺物を、贈ってくれた。「道連れの耳飾り」。")
	_c(s, "姉", "今日はね、天井にコウモリがぶら下がっててさ。……ちょっと、ちゃんと聞いてる？", &"sister")
	_n(s, "姉は毎晩のように、冒険の話を聞かせてくれた。あなたはそれを、紙に書き留めていった。それが、あなたの「ノート」の始まりだった。")
	_n(s, "ある日、姉の声が、深い場所で、ぷつりと途切れた。")
	_n(s, "数日後、役人が訪ねてきた。「遺品です」と言って、姉がつけていた耳飾りを置いていった。")
	_n(s, "耳飾りは、もう、何も聞かせてくれなかった。")
	_n(s, "部屋にこもる日が、続いた。")
	_c(s, "幼なじみ", "久しぶり。……あのね、私、冒険者になったんだ。", &"childhood")
	_c(s, "幼なじみ", "浅い階層だけでいいの。耳飾りで、道案内してくれない？ あなたのノートが、きっと役に立つから。", &"childhood")
	_n(s, "あなたは、しばらく迷って、耳飾りを、そっと耳につけた。")
	s.starts_tutorial = true
	return s


## チュートリアルの冒険のあと
static func _prologue_after_tutorial() -> StoryScene:
	var s := _scene(&"prologue_2", "プロローグ（つづき）")
	s.requires_seen = [&"tutorial"]
	_n(s, "探索を終えて、耳飾りを外すと、静かな部屋に戻ってきた。久しぶりに、誰かの声を聞いた気がした。")
	_c(s, "幼なじみ", "ねえ。この耳飾り、ほかの冒険者にも貸さない？ あなたがガイドになって、いろんな人から手がかりを集めるの。", &"childhood")
	_c(s, "幼なじみ", "ダンジョンの情報は、公にはほとんど出回ってない。だったら、お姉さんの手がかりも、冒険者たちが持ってるかもしれないでしょ？", &"childhood")
	_n(s, "あなたは、ノートを閉じて、小さくうなずいた。")
	_n(s, "こうして、あなたの「ガイド業」が始まった。")
	return s


# ---------------------------------------------------------------- 冒険者の紹介（初めて出発するとき）

static func _intro_mercenary() -> StoryScene:
	var s := _depart_scene(&"intro_mercenary", "傭兵との探索", SampleData.MERCENARY)
	_c(s, "傭兵", "あんたが、耳飾りの「ガイド屋」か。……勘違いするな。俺は金で動く。割に合わない指示は、聞かん。", &"mercenary")
	_c(s, "傭兵", "稼いで、一日でも早く自由を買い戻す。それだけだ。報酬は、きっちり分けてもらう。", &"mercenary")
	_n(s, "傭兵の報告は短くて、速い。その代わり、遺物や仕掛けの手がかりは「金にならん」と流しがちだ。聞き逃さないように。")
	return s


static func _intro_doctor() -> StoryScene:
	var s := _depart_scene(&"intro_doctor", "医師との探索", SampleData.DOCTOR)
	_c(s, "医師", "あ、あの……！ 薬草を探しているんです。助けたい人がいて……。でも、私、戦えなくて……怖くて……！", &"doctor")
	_n(s, "医師は、体の変化や植物の生態に、とても詳しい。ただ、慌てると早口になる。")
	_n(s, "間違えた分だけ、余計に焦ってしまうようだ。落ち着いて、一つずつ。")
	return s


static func _intro_noble() -> StoryScene:
	var s := _depart_scene(&"intro_noble", "没落貴族との探索", SampleData.NOBLE)
	_c(s, "没落貴族", "ほう、君が噂のガイドか。私はかつて貴族でね。今は、古代文明の研究に生涯を捧げておる。", &"noble")
	_c(s, "没落貴族", "……君の姉君のことなら、よく覚えているよ。その話は、また今度。今は、遺跡の話をしようではないか。", &"noble")
	_n(s, "貴族の話は、長い。大事な手がかりは、長話の中に埋もれている。ハイライトされた言葉の大半は、ただの蘊蓄だ。")
	return s


# ---------------------------------------------------------------- 姉の手がかり

static func _clue_1() -> StoryScene:
	var s := _clue_scene(&"clue_1", "姉の手がかり①", "姉は、あなたの体質を調べていた",
		"最後の探索の前、姉は幼なじみに「あの子の体質を、なんとかできるかもしれない」と話していた。")
	s.after_runs = {SampleData.CHILDHOOD: 1}
	_n(s, "探索を終えたあと、幼なじみが、ぽつりと言った。")
	_c(s, "幼なじみ", "あのね、黙ってたんだけど……お姉さん、最後の探索の前に、私に言ったの。", &"childhood")
	_c(s, "幼なじみ", "「あの子の体質を、なんとかできるかもしれない」って。", &"childhood")
	_n(s, "姉は、あなたの体質のことを、調べていたのだ。")
	return s


static func _clue_2() -> StoryScene:
	var s := _clue_scene(&"clue_2", "姉の手がかり②", "姉は、古代の「器」を調べていた",
		"姉は貴族の研究室に通い、ダンジョンが古代文明の「器」だという説を、熱心に聞いていた。")
	s.after_runs = {SampleData.NOBLE: 1}
	_c(s, "没落貴族", "約束だったな、姉君の話をしよう。彼女は、よく私の研究室に来ていた。", &"noble")
	_c(s, "没落貴族", "ダンジョンは、ただの遺跡ではない。古代の人々が作った「器」だ、という私の説を、熱心に聞いておった。", &"noble")
	_c(s, "没落貴族", "何を入れる器か、までは、私にも分からぬ。だが、彼女は何かに気づいたようだった。", &"noble")
	_n(s, "姉は、ダンジョンの正体を、探っていた。")
	return s


static func _clue_3() -> StoryScene:
	var s := _clue_scene(&"clue_3", "姉の手がかり③", "あなたの体質は、人の強い感情に反応する",
		"医師によれば、あなたは人の強い感情に触れると、具合が悪くなる体質かもしれない。姉もそれに気づいていた。")
	s.after_runs = {SampleData.DOCTOR: 1}
	_c(s, "医師", "あの……お姉さんは、私の診療所に来たことがあるんです。あなたのことを、心配して。", &"doctor")
	_c(s, "医師", "「あの子は、人の強い感情に触れると、具合が悪くなるの」と。怒りや、恥のような……。", &"doctor")
	_c(s, "医師", "ダンジョンの中でも、似たことが起こります。感情の強い場所ほど、体が、おかしくなる。", &"doctor")
	_n(s, "あなたの体質は、人の強い感情に、反応していたのかもしれない。")
	return s


static func _clue_4() -> StoryScene:
	var s := _clue_scene(&"clue_4", "姉の手がかり④", "姉は、自分の意思で奥へ進んだ",
		"傭兵は、深層の入口で、一人で奥へ向かう姉を見た。姉は、振り返って笑ったという。")
	s.after_runs = {SampleData.MERCENARY: 1}
	_c(s, "傭兵", "……金にならん話だが、一つだけ。深層の入口で、女の冒険者を見た。", &"mercenary")
	_c(s, "傭兵", "一人で、さらに奥へ向かっていた。誰かに連れていかれたわけじゃない。自分の足で、歩いていった。", &"mercenary")
	_c(s, "傭兵", "俺は止めなかった。……一度だけ、こっちを振り返って、笑った。それだけだ。", &"mercenary")
	_n(s, "姉は、誰かに連れ去られたのではなかった。自分の意思で、奥へ進んだのだ。")
	return s


static func _clue_5() -> StoryScene:
	var s := _clue_scene(&"clue_5", "姉の手がかり⑤", "手がかりが、つながった",
		"姉は、あなたの体質を解く鍵を探して、自分の意思で深層へ向かった。この先は、もっと深い場所だ。")
	s.requires_seen = [&"clue_1", &"clue_2", &"clue_3", &"clue_4"]
	_n(s, "ノートの隅に、手がかりを書き並べてみる。")
	_n(s, "姉は、あなたの体質を調べていた。ダンジョンは、古代の「器」。あなたの体質は、人の強い感情に反応する。")
	_n(s, "そして姉は、誰にも連れていかれず、自分の意思で、深層へ向かった。")
	_c(s, "幼なじみ", "お姉さんは、あなたのために……自分から、奥へ行ったんだね。", &"childhood")
	_n(s, "あなたは、何を思っただろう。怒りか。悲しみか。それとも、まだ、よく分からないか。")
	_c(s, "幼なじみ", "どう思っても、いいんだよ。お礼を言わなくても、怒ってもいい。私は、あなたの味方だから。", &"childhood")
	_n(s, "姉のいる場所は、まだ遠い。この先は、もっと深い階層。")
	_n(s, "――物語は、まだ、つづく。（今は、ここまで）")
	return s


# ---------------------------------------------------------------- ヘルパー

static func _scene(id: StringName, title: String) -> StoryScene:
	var s := StoryScene.new()
	s.id = id
	s.title = title
	return s


static func _depart_scene(id: StringName, title: String, adventurer: StringName) -> StoryScene:
	var s := _scene(id, title)
	s.trigger = &"depart"
	s.adventurer = adventurer
	return s


static func _clue_scene(id: StringName, title: String, clue_title: String, clue_summary: String) -> StoryScene:
	var s := _scene(id, title)
	s.clue_title = clue_title
	s.clue_summary = clue_summary
	return s


## 語り（顔なし）
static func _n(scene: StoryScene, text: String) -> void:
	scene.lines.append({"speaker": NARRATOR, "text": text, "portrait": &""})


## キャラのセリフ（顔つき）
static func _c(scene: StoryScene, speaker: String, text: String, portrait: StringName) -> void:
	scene.lines.append({"speaker": speaker, "text": text, "portrait": portrait})
