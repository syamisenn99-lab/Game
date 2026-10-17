# ロクロニウム冒険記

剣と魔法の異世界・冒険者の町ロクロニウムが舞台の、選択式テキストアドベンチャー（Godot 製）。
もともとチャットで AI がゲームマスターを務めていた物語を、分岐する選択式ゲームとして再現していく。

- 作成に使った Godot：**4.4.1 stable**（4.3 以降なら動く想定）／言語：GDScript（静的型付け）
- 解像度 1280×720、ウィンドウのリサイズに追従（stretch mode: canvas_items）
- 同じリポジトリの `../`（安楽椅子冒険者）とは別プロジェクト。`rokuronium/` フォルダをそのまま Godot で開く

## 遊び方（起動方法）

1. Godot 4.4 以降で `rokuronium/project.godot` を開く（初回は自動でインポートされる）
2. F5 で実行 → タイトル画面 →「はじめから」
3. 操作：クリック／Enter／Space で文字送り（途中なら全文表示）。選択肢は**クリック**か**数字キー 1〜5**。右上の「メニュー」でステータス・持ち物・親密度を見られる。

コマンドラインから：

```sh
godot --path rokuronium                       # 実行
godot --headless --path rokuronium --import   # 初回のみ（リソースのインポート）
```

### 現在遊べる範囲（フェーズ1）

第1章「朝・乗合馬車」→「昼・ゴルム硝子瓶店で手間賃を選ぶ」まで（31 シーン）。
本編ルートで選ばれなかった選択肢の先も用意してあり、どの選択肢を選んでも行き止まりなく進める（本編で選ばれなかった部分のシーンには `"draft": true` が付いている）。
選択肢の並びは表示のたびにランダム。判定の内訳（出目・難易度）は「設定」で表示できる。

## テストと検証

```sh
# 全 JSON の検証（存在しない next、未定義ID、条件式の構文エラー、行き止まり、到達不能シーンなど）
godot --headless --path rokuronium --script tools/validate_data.gd

# ロジックのテスト + 3000 回のランダムプレイ（全シーン・全選択肢・全判定結果の網羅確認）
godot --headless --path rokuronium --script tests/run_tests.gd

# 画面を実際に動かし、ボタンを押しながら終端まで進める（オートロードが要るのでシーンとして起動）
godot --headless --path rokuronium res://tests/ui_smoke.tscn
```

いずれも失敗があれば終了コード 1。デバッグ実行時は、起動時にも検証が走り、結果がタイトル画面の左下とエラー出力に出る。

## フォルダ構成

| パス | 内容 |
|---|---|
| `data/config.json` | 開始シーン、初期所持金・所持品・パーティ、背景の仮色 |
| `data/characters.json` | キャラ（パーティの初期ステータス、NPC の名前と仮立ち絵の色、ヒロインの初期親密度） |
| `data/items.json` | アイテム定義 |
| `data/scenes/*.json` | シナリオ（シーンの配列。ファイルはいくつに分けてもよい） |
| `scripts/core/` | UI に依存しないロジック（`Rules` 判定式、`Cond` 条件式、`Fx` 効果、`StoryEngine` 進行、`GameState`、`GameDB`、`DataValidator`、`Money`） |
| `scripts/ui/` | タイトル・メイン画面・メニュー表示 |
| `scripts/app.gd` | オートロード `App`（DB・状態・エンジン・設定・BGM/SE の差し込み口） |
| `assets/` | フォント（Noto Sans JP, OFL）、立ち絵、背景、音 |
| `tests/` `tools/` | テストと検証スクリプト |

シナリオを足すときは `data/scenes/` に JSON を置くだけでよい（コードは触らない）。

> 書き出し（エクスポート）するときは、エクスポート設定の「リソース」→「フィルター」に `*.json` を足すこと。

## シナリオ JSON の形式

```jsonc
{
  "scenes": [
    {
      "id": "ch1_carriage",                 // 必須・全体で一意
      "location": "乗合馬車（…）",            // 状況欄に出る場所名
      "time": { "day": 1, "slot": "朝" },    // 入ったときに日付・時間帯を設定（朝/昼/夕方/夜/深夜）
      "background": "carriage",             // assets/backgrounds/carriage.png（無ければ仮色）
      "portraits": ["ayaka_shy"],           // 立ち絵 最大3人。左から順に並ぶ
      "bgm": "town", "se": "door",          // 任意。assets/audio/bgm|se/ の同名ファイルを鳴らす
      "draft": true,                        // 任意。本編外で新たに書いた部分の目印
      "on_enter": [ { "op": "set_flag", "key": "seen_dragonkin", "value": true } ],
      "text": [                             // 1要素=1ページ。文字列、または {"text":…, "if":"条件式"}
        "ガタン、と車輪が石を踏み、…",
        { "if": "flag.met_gorm", "text": "ゴルムが…" }
      ],
      "choices": [ /* 下記 */ ],
      "next": "…",                          // choices が無いとき: 「続ける」ボタン1つ（"continue_text" で文言変更）
      "auto": { /* choice と同じ形（check など） */ },  // choices が無いとき: 判定つきの「続ける」
      "end": true                           // 終端。「タイトルへ戻る」が出る
    }
  ]
}
```

### 選択肢（choices）

```jsonc
{
  "text": "ドワーフの商人に、言いかけた話の続きを尋ねる",
  "condition": "affinity.ayaka >= 40",       // 偽なら非表示
  "next": "ch1_gorm_tips",                   // check が無いとき
  "effects": [ … ],                          // 選んだ直後に適用
  "fixed": true,                             // 並びのシャッフルから外し、末尾に固定
  "check": { "stat": "運", "difficulty": 9,   // 判定。who（既定 kazuki）, skill, mod, mods も指定可
             "mods": [ { "if": "flag.ruu_sleeve", "value": 2 } ] },
  "next_success": "…", "next_failure": "…",  // check があるときは必須
  "next_critical": "…",                      // 任意。無ければ next_success
  "effects_success": [ … ], "effects_failure": [ … ], "effects_critical": [ … ]
}
```

- 選択肢は**表示のたびにランダム順**（`fixed: true` を除く）。基本は 3〜5 個。
- 判定結果は次シーンの本文冒頭に〔判定：運 → 成功〕のように出る。

### 判定（`scripts/core/rules.gd` に集約）

`2d6 + ステータス + スキルLv×2 + 補正 ≥ 難易度` で成功。出目 12 なら大成功（常に成功）、2 なら失敗（常に失敗）。係数や出目は `Rules` の定数だけ直せばよい。

### 条件式（`Cond`）

`flag.ruu_released == true` / `money >= 30` / `affinity.ayaka >= 60 && !flag.met_gorm` / `slot == '夜'`

| 名前 | 意味 |
|---|---|
| `flag.<key>` | フラグ（真偽・数値・文字列。未設定は false / 0） |
| `money` | 所持金（**銅貨単位**の整数） |
| `item.<id>` | 所持数 |
| `affinity.<キャラID>` | 親密度の内部値（0〜100） |
| `hp.<キャラID>` `mp.<キャラID>` `level.<キャラID>` | パーティ員の値 |
| `day` `slot` `location` `exp` | 日付・時間帯・場所・累計経験値 |

演算子：`== != >= <= > < && || !` と括弧。構文エラーや未定義の名前は検証スクリプトが報告する。

### 効果（`Fx`）— どれにも `"if": "条件式"` と `"silent": true` を付けられる

| op | 引数 |
|---|---|
| `set_flag` / `add_flag` | `key`, `value` |
| `add_money` | `value`（銅貨の整数、または `"3銀"` `"-1銀"` のような文字列） |
| `add_item` / `remove_item` | `id`, `count`（省略で1） |
| `add_hp` / `add_mp` | `who`, `value`（非戦闘では HP は 1 未満にならない） |
| `add_exp` | `value`（累計に加算。レベルアップはフェーズ3） |
| `add_affinity` | `who`, `value`（出会っていなければ出会い扱い） |
| `meet` | `who`, `value`（初期親密度） |
| `advance_time` | `slot`（その時間帯まで進める。過ぎていれば翌日）または `steps` |
| `set_time` / `set_location` | `day`,`slot` / `value` |

`start_battle` / `accept_quest` / `complete_quest` / `open_shop` は予約済みで、フェーズ2以降に実装する（いま書くと検証で警告が出る）。

## 物語を書くときのルール（守ること）

- 主人公カズキのセリフは書かない。心情・感想・決断も地の文で決めつけない。
- 会話系の選択肢のあとの本文は、相手の反応から描写を始める。
- 「おすすめ」表示や結果のネタバレをしない。リスクのある選択肢も混ぜる。
- 恋愛は積み重ね。1回の選択で親密度を大きく動かさない（いまは +1 ずつ）。
- 敗北しても即ゲームオーバーにしない（フェーズ3の戦闘で実装）。
- アヤカはカズキにタメ口（一人称「わたし」）。丁寧語は初対面・目上の相手にだけ。

## 素材の置き方

画像が無いものは、色付きの四角形と名前ラベルの仮素材で表示される。**同名の PNG を置けば自動で差し替わる**（コード変更なし）。

### 立ち絵 `assets/characters/<キャラID>_<表情>.png`

キャラIDは `data/characters.json` のキー。表情は自由に増やせる（シーン JSON の `portraits` に書く名前と一致させる）。
該当表情の画像が無ければ `<キャラID>_normal.png` に代わりに使う。

| キャラ | ID | 表情の例 |
|---|---|---|
| アヤカ | `ayaka` | `ayaka_normal.png` `ayaka_smile.png` `ayaka_shy.png` `ayaka_surprised.png` `ayaka_worried.png` |
| ルゥ | `ruu` | `ruu_normal.png` `ruu_hurt.png` |
| リュイ | `ryui` | `ryui_normal.png` `ryui_hood.png`（フードをかぶった姿） |
| ゴルム | `gorm` | `gorm_normal.png` |
| バルド | `baldo` | `baldo_normal.png` |

推奨サイズ：縦長（高さ 800px 前後・透過PNG）。画面では 270×390 の枠に収まるよう中央寄せで縮小される。

### 背景 `assets/backgrounds/<背景ID>.png`

背景IDは各シーンの `"background"`。現在：`carriage` `gate` `market` `alley` `gorm_shop`。推奨 1280×720。

### BGM・効果音（差し込み口のみ）

`assets/audio/bgm/<ID>.ogg|mp3|wav`、`assets/audio/se/<ID>.ogg|mp3|wav` を置き、シーンに `"bgm": "<ID>"` / `"se": "<ID>"` を書くと鳴る。

## フォント

`assets/fonts/NotoSansJP-Regular.ttf`（Noto Sans JP・可変フォント、SIL Open Font License 1.1。ライセンス全文は `OFL.txt`）。
`assets/theme/main_theme.tres` で太さ 400 を指定し、プロジェクト全体のテーマとして適用している。

## 既知の問題・今後

- セーブ／ロード、依頼、店、戦闘、レベルアップ、装備はこれから（フェーズ2・3）。「つづきから」「依頼」「セーブ・ロード」はボタンだけ置いて無効にしてある。
- 立ち絵・背景は仮素材。スマホ対応は後回し。
