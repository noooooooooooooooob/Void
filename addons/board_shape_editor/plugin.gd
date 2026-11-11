@tool
extends EditorPlugin
## 전투 격자판 모양 편집 플러그인.
## BattleBoard 를 고르면 판 네 모서리, GridCell 을 고르면 그 칸의 네 꼭짓점에 핸들이 뜬다.
## 핸들을 드래그하면 값이 바뀌고, 놓을 때 한 번의 실행 취소로 기록된다.
## 칸은 처음 드래그할 때 자동 모양을 시작값으로 삼아 custom_corners 를 갖게 된다.

## 핸들을 잡는 반경과 그리는 반경 (화면 픽셀)
const GRAB_RADIUS := 12.0
const DRAW_RADIUS := 6.0
const HANDLE_COLOR := Color(1.0, 0.85, 0.3)
const LINE_COLOR := Color(1.0, 0.85, 0.3, 0.7)

var _target: Control = null  # 지금 고른 BattleBoard 또는 GridCell
var _drag_index := -1  # 잡고 있는 핸들 번호, 없으면 -1
var _drag_before: PackedVector2Array  # 드래그 시작 전 속성 값 (실행 취소용)
var _drag_points: PackedVector2Array  # 드래그 중인 네 점 (판 기준 좌표)


func _handles(object: Object) -> bool:
	return object is BattleBoard or (object is GridCell and object.get_parent() is BattleBoard)


func _edit(object: Object) -> void:
	_target = object as Control
	_drag_index = -1
	update_overlays()


func _make_visible(visible: bool) -> void:
	if not visible:
		_target = null
		_drag_index = -1
	update_overlays()


## 지금 대상이 속한 판
func _board() -> BattleBoard:
	return _target as BattleBoard if _target is BattleBoard else _target.get_parent() as BattleBoard


## 대상의 판 자리. 전투 좌표(cell)는 전투마다 달라서 노드 이름 Cell_<열>_<행> 으로 읽는다
func _cell_position() -> Vector2i:
	var parts := _target.name.split("_")
	return Vector2i(parts[1].to_int(), parts[2].to_int())


## 지금 핸들 네 점 (판 기준 좌표)
func _points() -> PackedVector2Array:
	if _drag_index >= 0:
		return _drag_points
	if _target is BattleBoard:
		return _target.corners
	var at := _cell_position()
	return _board().cell_corners(at.x, at.y)


## 판 기준 좌표 → 에디터 화면 좌표 변환
func _to_screen() -> Transform2D:
	var board := _board()
	return board.get_viewport_transform() * board.get_global_transform()


## 드래그한 값을 대상의 속성 이름으로
func _property() -> StringName:
	return &"corners" if _target is BattleBoard else &"custom_corners"


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not is_instance_valid(_target):
		return
	var points := _points()
	if points.size() != 4:
		return
	var xf := _to_screen()
	# 1. 외곽선
	var outline := PackedVector2Array()
	for p in points:
		outline.append(xf * p)
	outline.append(outline[0])
	overlay.draw_polyline(outline, LINE_COLOR, 2.0)
	# 2. 핸들
	for i in 4:
		overlay.draw_circle(outline[i], DRAW_RADIUS, HANDLE_COLOR)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not is_instance_valid(_target):
		return false
	# 1. 왼쪽 버튼을 누르면 핸들을 잡고, 놓으면 기록한다
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return _on_press(event.position) if event.pressed else _on_release()
	# 2. 잡고 있으면 따라 움직인다
	if event is InputEventMouseMotion and _drag_index >= 0:
		_drag_points[_drag_index] = _to_screen().affine_inverse() * event.position
		_target.set(_property(), _drag_points)
		update_overlays()
		return true
	return false


## 누른 자리에 핸들이 있으면 드래그를 시작한다. 입력을 가져갔으면 true.
func _on_press(at: Vector2) -> bool:
	var points := _points()
	if points.size() != 4:
		return false
	var screen := PackedVector2Array()
	var xf := _to_screen()
	for p in points:
		screen.append(xf * p)
	var index := BoardShape.nearest_handle(screen, at, GRAB_RADIUS)
	if index < 0:
		return false
	# 칸의 첫 드래그는 _points() 의 자동 모양에서 시작하고, 실행 취소하면 빈 값으로 돌아간다
	_drag_before = _target.get(_property())
	_drag_points = points.duplicate()
	_drag_index = index
	return true


## 드래그를 끝내고 한 번의 실행 취소로 기록한다. 입력을 가져갔으면 true.
func _on_release() -> bool:
	if _drag_index < 0:
		return false
	_drag_index = -1
	var undo := get_undo_redo()
	undo.create_action("격자판 모양 조정")
	undo.add_do_property(_target, _property(), _drag_points)
	undo.add_undo_property(_target, _property(), _drag_before)
	undo.add_do_method(self, &"update_overlays")
	undo.add_undo_method(self, &"update_overlays")
	undo.commit_action()
	return true
