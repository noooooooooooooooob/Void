@tool
class_name BattleBoard
extends Control
## 전투 격자판 하나 (한 편 몫, 5×5 칸). battle_board.tscn 의 스크립트.
## 배경 씬(Scenes/backgrounds/…)에 아군용·적용으로 하나씩 넣고, 칸의 위치·크기·모양을 에디터에서 직접 꾸민다.
## 전투 화면이 배경에서 두 판을 찾으면 기본 격자 대신 이 칸들을 쓴다.
##
## 모양: 판의 네 모서리(corners)를 바닥에 맞추면 25칸이 원근대로 자동으로 나뉜다.
## 칸 하나만 다르게 하고 싶으면 그 칸의 custom_corners 를 쓴다 (2026-11-11 사용자 결정).
## 드래그 핸들은 addons/board_shape_editor 가 제공한다. 에디터에서 모양이 보이도록 @tool.
##
## 칸 이름: Cell_<열>_<행>. 화면 기준으로 왼쪽 열이 0, 위 행이 0 (꾸밀 때 보이는 자리 그대로).
## 전투가 시작되면 전투 크기만큼만 칸을 켜고 나머지는 숨긴다 (2026-11-10 사용자 결정):
##   - 열: 상대와 맞닿는 쪽부터 (아군 판 = 오른쪽부터, 적 판 = 왼쪽부터)
##   - 행: 가운데부터 (예: 3행 전투면 판의 1~3행)

## 판 한 변의 칸 수 (전투 격자의 최대 열·행 수)
const SIZE := 5

## 이 판이 어느 편의 칸인지 (BattleTypes.Side). 배경 씬에 넣은 뒤 인스펙터에서 고른다
@export var side: BattleTypes.Side = BattleTypes.Side.ALLY

## 판 5×5 전체의 네 모서리 (판 기준 좌표, 왼쪽 위부터 시계 방향). 3행 전투는 이 테두리의 가운데 3행만 쓴다.
## 기본값은 650 정사각형: 틈 절반만큼 밖으로 잡아 칸이 130 간격·120 크기로 놓인다
@export var corners: PackedVector2Array = PackedVector2Array([Vector2(-5, -5), Vector2(645, -5), Vector2(645, 645), Vector2(-5, 645)]):
	set(value):
		corners = value
		if is_node_ready():
			layout_cells()

## 칸 사이 틈 (칸 피치 대비 비율, 0 이상 0.5 미만)
@export_range(0.0, 0.49, 0.001) var cell_gap: float = 10.0 / 130.0:
	set(value):
		cell_gap = value
		if is_node_ready():
			layout_cells()


func _ready() -> void:
	# 칸의 꼭짓점이 바뀌면 다시 배치한다 (@tool 이라 에디터에서도 연결된다)
	for c in get_children():
		if c is GridCell and not c.custom_corners_changed.is_connected(layout_cells):
			c.custom_corners_changed.connect(layout_cells)
	layout_cells()


## 25칸을 지금 모양대로 배치한다. 네 모서리가 4개가 아니면(인스펙터 입력 중) 그대로 둔다.
func layout_cells() -> void:
	if corners.size() != 4:
		return
	for col in SIZE:
		for row in SIZE:
			var c := get_node_or_null(cell_name(col, row)) as GridCell
			if c:
				c.apply_quad(cell_corners(col, row))


## 판의 (col, row) 칸 네 꼭짓점 (판 기준 좌표). 직접 잡은 값이 정확히 4개면 그것, 아니면 자동 계산.
func cell_corners(col: int, row: int) -> PackedVector2Array:
	var c := get_node_or_null(cell_name(col, row)) as GridCell
	if c and c.custom_corners.size() == 4:
		return c.custom_corners
	return BoardShape.cell_quad(corners, col, row, cell_gap, SIZE)


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
