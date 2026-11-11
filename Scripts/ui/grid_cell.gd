@tool
class_name GridCell
extends Control
## 전투 격자의 칸 하나. 전투 화면(battle_screen)이 격자 크기만큼 grid_cell.tscn 을 복제해서 깔거나,
## 격자판(battle_board.tscn)의 칸으로 쓴다.
## 칸 색으로 "이동 가능 / 대상 가능 / 범위 강조"를 표시하고, 클릭하면 어느 편의 어느 칸인지 알린다.
##
## 격자판의 칸은 네 꼭짓점을 가진 사각형(quad)으로 그려지고 클릭도 그 모양만 받는다.
## 기본 격자의 칸은 quad 가 비어 있어 네모 그대로다.
## 에디터에서도 모양이 보이도록 @tool.

## 표시 종류
enum Mark {
	NONE,    ## 표시 없음
	MOVE,    ## 이동할 수 있는 칸
	TARGET,  ## 지금 고른 카드의 대상으로 고를 수 있는 유닛이 있는 칸
	AREA,    ## 대상에 마우스를 올렸을 때 광역 범위에 들어가는 칸
}

## 칸이 눌렸을 때. side = BattleTypes.Side, cell = 격자 좌표 (x 열, y 행)
signal pressed(side: int, cell: Vector2i)
## custom_corners 가 바뀌었을 때. 격자판이 받아서 칸을 다시 배치한다
signal custom_corners_changed

## 칸 바탕색
@export var fill_color: Color = Color(0.16470589, 0.15294118, 0.2, 1):
	set(value):
		fill_color = value
		queue_redraw()

## 표시 종류별 덧칠 색 (씬 인스펙터에서 바꿀 수 있다)
@export var mark_colors: Dictionary = {
	Mark.NONE: Color(0, 0, 0, 0),
	Mark.MOVE: Color(0.35, 0.8, 0.95, 0.35),
	Mark.TARGET: Color(0.95, 0.3, 0.3, 0.35),
	Mark.AREA: Color(1.0, 0.55, 0.2, 0.55),
}

## 직접 잡은 네 꼭짓점 (판 기준 좌표, 왼쪽 위부터 시계 방향).
## 비어 있거나 4개가 아니면 판의 네 모서리로 자동 계산한다. 격자판 칸에서만 쓴다
@export var custom_corners: PackedVector2Array:
	set(value):
		custom_corners = value
		custom_corners_changed.emit()

## 이 칸이 속한 편 (BattleTypes.Side)
var side: int = BattleTypes.Side.ALLY
## 이 칸의 격자 좌표
var cell: Vector2i
## 지금 모양의 네 꼭짓점 (칸 기준 좌표). 비어 있으면 칸 네모 전체
var quad: PackedVector2Array

var _mark_color := Color(0, 0, 0, 0)  # 지금 덧칠 색


## 어느 편의 어느 칸인지 정한다 (복제한 직후 화면이 부른다).
func setup(cell_side: int, at: Vector2i) -> void:
	side = cell_side
	cell = at


## 칸 표시를 바꾼다 (Mark 값).
func set_mark(kind: int) -> void:
	_mark_color = mark_colors.get(kind, Color(0, 0, 0, 0))
	queue_redraw()


## 지금 덧칠 색 (테스트용)
func mark_color() -> Color:
	return _mark_color


## 판 기준 네 꼭짓점으로 칸 모양을 정한다. 칸의 위치·크기는 그 경계 상자가 된다.
func apply_quad(board_quad: PackedVector2Array) -> void:
	# 1. 네 점을 모두 담는 경계 상자를 구한다
	var box := Rect2(board_quad[0], Vector2.ZERO)
	for p in board_quad:
		box = box.expand(p)
	position = box.position
	size = box.size
	# 2. 꼭짓점을 칸 기준 좌표로 옮긴다
	var local := PackedVector2Array()
	for p in board_quad:
		local.append(p - box.position)
	quad = local
	queue_redraw()


## 칸 기준 중심. 유닛 박스를 놓을 자리. 사각형이면 경계 상자 중심이 아니라 네 꼭짓점 평균이다.
func center() -> Vector2:
	if quad.is_empty():
		# 기본 격자는 배치 전이라 size 가 0 일 수 있어 최소 크기도 본다
		return size.max(custom_minimum_size) * 0.5
	var sum := Vector2.ZERO
	for p in quad:
		sum += p
	return sum / quad.size()


## 지금 모양을 색으로 채울 수 있는지. 꼭짓점이 꼬이거나 일직선이면 false.
func can_fill() -> bool:
	return quad.is_empty() or not Geometry2D.triangulate_polygon(quad).is_empty()


func _draw() -> void:
	# 1. 기본 격자: 네모
	if quad.is_empty():
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, fill_color)
		draw_rect(rect, _mark_color)
		return
	# 2. 꼬인 모양은 채울 수 없으니 외곽선만 그린다 (드래그 도중에 생길 수 있음)
	if not can_fill():
		var outline := quad.duplicate()
		outline.append(quad[0])
		draw_polyline(outline, fill_color, 2.0)
		return
	# 3. 사각형을 채우고 표시 색을 덧칠한다
	draw_colored_polygon(quad, fill_color)
	if _mark_color.a > 0.0:
		draw_colored_polygon(quad, _mark_color)


## 클릭 판정: 사각형 안쪽만 받는다 (이웃 칸과 경계 상자가 겹쳐도 정확한 칸이 눌린다).
func _has_point(point: Vector2) -> bool:
	if quad.is_empty():
		return Rect2(Vector2.ZERO, size).has_point(point)
	return Geometry2D.is_point_in_polygon(point, quad)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(side, cell)
		accept_event()
