class_name BattleData
extends Resource
## 전투 하나의 데이터: 격자 크기와 유닛 배치. battles/*.tres 로 저장한다.
## BattleSession 이 이것으로 전투를 만든다 (전투 화면 시험판, 나중에 의뢰의 전투 칸).
##
## 규칙 (CLAUDE.md "격자 크기는 전투마다 데이터로 지정"):
## - 행 수는 양 편 공통, 열 수는 편마다 다를 수 있다 (기본 3행 × 4열).
## - allies 는 시험·고정 전투용. 의뢰에서는 파티 유닛을 밖에서 넣고 enemies 와 격자 크기만 쓴다.

## 격자 행 수 (양 편 공통)
@export var rows: int = BattleTypes.DEFAULT_GRID_ROWS
## 아군 격자 열 수
@export var ally_cols: int = BattleTypes.DEFAULT_GRID_COLS
## 적 격자 열 수
@export var enemy_cols: int = BattleTypes.DEFAULT_GRID_COLS
## 아군 배치 (시험·고정 전투용)
@export var allies: Array[BattleSlot] = []
## 적 배치
@export var enemies: Array[BattleSlot] = []
## 전투 화면 배경 씬 (보통 res://Scenes/backgrounds/*.tscn, 루트는 Control).
## 겹·패럴랙스·마우스 따라 움직이기는 배경 씬 안에서 만든다. 비우면 배경 단색만 보인다.
@export var background: PackedScene


## 아군 + 적 배치로 새 전투 유닛들을 만든다 (아군이 먼저). 부를 때마다 새 유닛이다.
func make_units() -> Array[BattleUnit]:
	var out := _make(allies, BattleTypes.Side.ALLY)
	out.append_array(make_enemy_units())
	return out


## 적 배치로만 새 전투 유닛들을 만든다 (아군을 밖에서 넣을 때).
func make_enemy_units() -> Array[BattleUnit]:
	return _make(enemies, BattleTypes.Side.ENEMY)


## 슬롯 목록 → 한 편의 전투 유닛들. 유닛 데이터가 빈 슬롯은 건너뛴다.
func _make(slots: Array[BattleSlot], side: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for s in slots:
		if s and s.unit:
			out.append(BattleUnit.new(s.unit, side, s.cell))
	return out
