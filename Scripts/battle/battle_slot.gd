class_name BattleSlot
extends Resource
## 전투 배치 한 칸: 어떤 유닛을 격자의 어느 칸에 세울지. BattleData 의 allies / enemies 목록에 들어간다.

## 세울 유닛의 데이터 (entities/units/*.tres)
@export var unit: UnitData
## 격자 칸 (x = 열, y = 행). 열은 0 이 후열, 큰 값이 전열(가운데 쪽) — 양 편 모두 같은 규칙.
@export var cell: Vector2i
