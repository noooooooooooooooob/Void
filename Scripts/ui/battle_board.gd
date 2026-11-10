class_name BattleBoard
extends Control
## 전투 격자판 하나 (한 편 몫, 5×5 칸). battle_board.tscn 의 스크립트.
## 배경 씬(Scenes/backgrounds/…)에 아군용·적용으로 하나씩 넣고, 칸의 위치·크기·모양을 에디터에서 직접 꾸민다.
## 전투 화면이 배경에서 두 판을 찾으면 기본 격자 대신 이 칸들을 쓴다.
##
## 칸 이름: Cell_<열>_<행>. 화면 기준으로 왼쪽 열이 0, 위 행이 0 (꾸밀 때 보이는 자리 그대로).
## 전투가 시작되면 전투 크기만큼만 칸을 켜고 나머지는 숨긴다 (2026-11-10 사용자 결정):
##   - 열: 상대와 맞닿는 쪽부터 (아군 판 = 오른쪽부터, 적 판 = 왼쪽부터)
##   - 행: 가운데부터 (예: 3행 전투면 판의 1~3행)

## 판 한 변의 칸 수 (전투 격자의 최대 열·행 수)
const SIZE := 5

## 이 판이 어느 편의 칸인지 (BattleTypes.Side). 배경 씬에 넣은 뒤 인스펙터에서 고른다
@export var side: BattleTypes.Side = BattleTypes.Side.ALLY


## 판에서 (열, 행) 자리에 있는 칸 노드의 이름
static func cell_name(col: int, row: int) -> String:
	return "Cell_%d_%d" % [col, row]


## 이 판으로 cols 열 × rows 행 전투를 그릴 수 있는지 (5×5 를 넘으면 못 그린다)
func supports(cols: int, rows: int) -> bool:
	return cols >= 1 and rows >= 1 and cols <= SIZE and rows <= SIZE


## 전투 좌표(열 0 = 뒤, 열 cols-1 = 맨 앞)를 판 자리(화면 기준 왼쪽·위가 0)로 바꾼다.
@warning_ignore("integer_division")
func board_position(cell: Vector2i, cols: int, rows: int) -> Vector2i:
	# 1. 열: 맨 앞에서 몇 칸 뒤인지 → 아군은 오른쪽 끝, 적은 왼쪽 끝이 맨 앞
	var from_front := cols - 1 - cell.x
	var col := SIZE - 1 - from_front if side == BattleTypes.Side.ALLY else from_front
	# 2. 행: 남는 줄을 위아래로 나눠 가운데부터
	var row := (SIZE - rows) / 2 + cell.y
	return Vector2i(col, row)


## 전투 크기에 맞는 칸만 보이게 하고, 그 칸들을 돌려준다.
## 돌려주는 값: 전투 좌표 Vector2i(열, 행) → GridCell. 칸이 없는 자리는 빠진다.
func use_cells(cols: int, rows: int) -> Dictionary:
	# 1. 먼저 판의 모든 칸을 숨긴다 (다시 하기로 크기가 바뀌어도 남은 칸이 없게)
	for c in get_children():
		if c is GridCell:
			c.visible = false
	# 2. 전투 칸마다 판 자리를 찾아 켠다
	var out := {}
	for x in cols:
		for y in rows:
			var at := board_position(Vector2i(x, y), cols, rows)
			var c := get_node_or_null(cell_name(at.x, at.y)) as GridCell
			if c:
				c.visible = true
				out[Vector2i(x, y)] = c
	return out
