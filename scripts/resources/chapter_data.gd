class_name ChapterData
extends Resource
## 1章ぶんの戦闘の割り当て。序盤・中盤の候補から選び、最後はボス。

@export var early_encounters: Array[EncounterData] = []
@export var mid_encounters: Array[EncounterData] = []
@export var boss_encounter: EncounterData
