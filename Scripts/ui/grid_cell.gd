class_name GridCell
extends ColorRect
## 전투 격자의 칸 하나. 전투 화면(battle_screen)이 격자 크기만큼 grid_cell.tscn 을 복제해서 깐다.
## 칸 색으로 "이동 가능 / 대상 가능 / 범위 강조"를 표시하고, 클릭하면 어느 편의 어느 칸인지 알린다.

## 칸 표시 종류
enum Mark {
	NONE,    ## 표시 없음
	MOVE,    ## 이동할 수 있는 칸
	TARGET,  ## 지금 고른 카드의 대상으로 고를 수 있는 유닛이 있는 칸
	AREA,    ## 대상에 마우스를 올렸을 때 광역 범위에 들어가는 칸
}

## 칸이 눌렸을 때. side = BattleTypes.Side, cell = 격자 좌표 (x 열, y 행)
signal pressed(side: int, cell: Vector2i)

## 표시 종류별 덧칠 색 (씬 인스펙터에서 바꿀 수 있다)
@export var mark_colors: Dictionary = {
	Mark.NONE: Color(0, 0, 0, 0),
	Mark.MOVE: Color(0.35, 0.8, 0.95, 0.35),
	Mark.TARGET: Color(0.95, 0.3, 0.3, 0.35),
	Mark.AREA: Color(1.0, 0.55, 0.2, 0.55),
}

## 이 칸이 속한 편 (BattleTypes.Side)
var side: int = BattleTypes.Side.ALLY
## 이 칸의 격자 좌표
var cell: Vector2i

@onready var _mark: ColorRect = %Mark  # 표시 색을 덧칠하는 자식


## 어느 편의 어느 칸인지 정한다 (복제한 직후 화면이 부른다).
func setup(cell_side: int, at: Vector2i) -> void:
	side = cell_side
	cell = at


## 칸 표시를 바꾼다 (Mark 값).
func set_mark(kind: int) -> void:
	_mark.color = mark_colors.get(kind, Color(0, 0, 0, 0))


## 지금 덧칠 색 (테스트용)
func mark_color() -> Color:
	return _mark.color


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(side, cell)
		accept_event()
