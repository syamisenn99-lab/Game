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
## 弱体のとき、与えるダメージにかける倍率（端数切り捨て）
@export var weak_multiplier: float = 0.75
## 脆弱のとき、受けるダメージにかける倍率（端数切り捨て）
@export var vulnerable_multiplier: float = 1.5
## 思い出の上限
@export var omoide_max: int = 10
