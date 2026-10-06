# 安楽椅子冒険者（仮題）

家から出られない主人公が、「声だけ」でつながる冒険者をノートと照合しながらナビゲートする、情報照合サスペンス。

- 企画: [docs/GDD.md](docs/GDD.md)
- 照合画面（MVP）の設計: [docs/MVP_MATCHING_SCREEN.md](docs/MVP_MATCHING_SCREEN.md)

## 動かし方（Godot 4.6.3）

1. Godot 4.6.3 でこのフォルダ（`project.godot`）を開く
2. F5 で実行（メインシーン: `scenes/start_screen.tscn`。冒険者を選ぶと、照合画面 `scenes/matching_screen.tscn` に進む）

遊び方: まず冒険者（幼なじみ／傭兵）を選ぶ。通信ログの黄色い語をノートの項目へドラッグ → 能力値ボタンで指示 → ダイス判定。
ノートの育ち（埋めた虫食い・訂正）は次の探索にも引き継がれ、`user://notebook.json` に保存される（選択画面の「ノートを最初に戻す」でリセット）。
虫食い（`？？？`）には、報告から拾った語をドロップして埋める。

> 日本語表示はOSのフォントへのフォールバックに頼っている。エクスポートして配布する前に、日本語フォントを同梱すること。

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
| `tests/` | ヘッドレステスト |
