class_name BalanceConfig
extends Resource
## 数値設定。調整は data/balance.tres の中だけで行う。

# --- 戦闘 ---
@export var max_hp: int = 60
@export var energy_per_turn: int = 3
@export var draw_per_turn: int = 5
@export var hand_limit: int = 10
## この回数目以降のリシャッフルから、1回ごとに疲労が1増える
@export var fatigue_start_reshuffle: int = 3
@export var min_draw: int = 2
## 弱体のとき、与えるダメージにかける倍率（端数切り捨て）
@export var weak_multiplier: float = 0.75
## 脆弱のとき、受けるダメージにかける倍率（端数切り捨て）
@export var vulnerable_multiplier: float = 1.5

# --- ランの流れ ---
@export var initial_deck_size: int = 30
## 通常戦闘の回数（このあとにボス戦が1回）
@export var normal_battle_count: int = 9
## 通常戦闘の最初の何戦を「序盤」の敵から選ぶか
@export var early_battle_count: int = 3
## 1戦目、2戦目…の勝利後に手放せる枚数（足りない分は最後の値を使う）
@export var release_counts: Array[int] = [2, 2, 2, 2, 2, 1, 1, 1, 1]
## 「今回は手放さない」を選んだときの回復量
@export var skip_release_heal: int = 10

# --- 思い出・記憶 ---
@export var omoide_max: int = 10
## 「確かな」になる思い出の数
@export var tier_certain_at: int = 3
## 「鮮明な」になる思い出の数
@export var tier_vivid_at: int = 7
@export var memory_slots: int = 6
