# 安楽椅子冒険者（仮題）

家から出られない主人公が、「声だけ」でつながる冒険者をノートと照合しながらナビゲートする、情報照合サスペンス。

- 企画: [docs/GDD.md](docs/GDD.md)
- 照合画面（MVP）の設計: [docs/MVP_MATCHING_SCREEN.md](docs/MVP_MATCHING_SCREEN.md)

## 動かし方（Godot 4.6.3）

1. Godot 4.6.3 でこのフォルダ（`project.godot`）を開く
2. F5 で実行（メインシーン: `scenes/prep_screen.tscn`。準備画面で冒険者を選んで「探索に出発」すると、照合画面 `scenes/matching_screen.tscn` に進む）

遊び方: 準備画面で、冒険者（幼なじみ／傭兵／医師／没落貴族）を選び、情報や道具を買って出発する。探索が終わると報酬が入り、生活費が引かれて、また準備に戻る。通信ログの黄色い語をノートの項目へドラッグ → 能力値ボタンで指示 → ダイス判定。
ノートの育ち（埋めた虫食い・訂正）は次の探索にも引き継がれ、`user://notebook.json` に保存される（準備画面の「最初からやり直す」でリセット。資金・日数・道具も保存される）。
虫食い（`？？？`）には、報告から拾った語をドロップして埋める。

> 日本語表示はOSのフォントへのフォールバックに頼っている。エクスポートして配布する前に、日本語フォントを同梱すること。

## イラスト

絵の置き場所と差し替え方は [assets/illustrations/README.md](assets/illustrations/README.md)。いまの絵は仮の絵（ヘタウマ風のSVG）で、同じ名前の `.png` を置けば置き換わる。

## テスト

```sh
godot --headless --path . --import                       # 初回のみ（クラス名キャッシュの生成）
godot --headless --path . --script tests/run_tests.gd    # 判定ロジック・UIの流れ・実マウス操作のドラッグ
```

## 構成

| パス | 内容 |
|---|---|
| `scripts/core/` | 判定・状態管理・報告文パーサ（UI に依存しない） |
| `scripts/core/rules.gd` | バランス数値を集約した定義（仮の初期値） |
| `scripts/data/` | ノート項目・イベント・冒険者の Resource と、サンプルシナリオ |
| `scripts/ui/` | 照合画面、キーワードチップ、ノート項目、虫食い穴 |
| `assets/illustrations/` | イラスト（仮の絵）。差し替え方は同フォルダの README |
| `tools/` | 仮の絵を作るスクリプト |
| `tests/` | ヘッドレステスト |
