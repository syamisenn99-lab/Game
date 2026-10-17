class_name BalanceConfig
extends Resource
## 数値設定。調整は data/balance.tres の中だけで行う。

@export var max_hp: int = 60
@export var energy_per_turn: int = 3
@export var draw_per_turn: int = 5
@export var hand_limit: int = 10
## この回数目以降のリシャッフルから、1回ごとに疲労が1増える
@export var fatigue_start_reshuffle: int = 3
@export var min_draw: int = 2
