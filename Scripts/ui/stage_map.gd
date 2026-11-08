class_name StageMap
extends Control
## 스테이지 지도 화면. stage_map.tscn 의 스크립트.
## StageRun(자동 로드)의 지도를 그리고, 다음 노드 고르기·실행 입력을 받는다.
## 의뢰 중이 아니면(이 씬을 F6 으로 바로 열었을 때) 공허 없이 새 의뢰를 시작한다.
##
## 조작 (림버스 컴퍼니처럼):
##   - W / ↑, S / ↓ : 갈 수 있는 다음 노드 사이에서 커서를 위·아래로 옮긴다
##   - 마우스 클릭   : 갈 수 있는 노드를 누르면 커서가 그리로. 커서가 있는 노드를 한 번 더 누르면 실행
##   - 스페이스 / 엔터 : 커서가 있는 노드를 실행
## 노드 모양은 stage_node_view.tscn, 선 모양은 이 씬의 Map/LinkTemplate(숨겨 둔 Line2D 틀)에서 고친다.

## 노드 하나를 그리는 틀 씬
const NODE_VIEW := preload("res://Scenes/ui/stage_map/stage_node_view.tscn")

## 열 사이 간격 (px, 노드 중심 기준)
@export var column_gap := 260.0
## 행 사이 간격 (px, 노드 중심 기준)
@export var row_gap := 180.0
## 새 의뢰를 시작할 때의 지도 seed. 0 이면 매번 다른 지도, 숫자를 넣으면 항상 같은 지도 (확인용)
@export var map_seed := 0
## 지나온 길의 선 색
@export var passed_link_color := Color("c9b98f")
## 지금 갈 수 있는 길의 선 색
@export var choice_link_color := Color("f2d16b")

## 지금 지도의 노드들 ([0] = 시작, 마지막 = 보스)
var nodes: Array[StageNode] = []
## 노드마다 하나씩 만든 화면 부품 (nodes 와 같은 순서)
var views: Array[StageNodeView] = []

var _links := {}  # [출발 노드, 도착 노드] → Line2D

@onready var _map: Control = %Map
@onready var _link_template: Line2D = %LinkTemplate


func _ready() -> void:
	# 1. 의뢰 중이 아니면 새 의뢰(새 지도 + 새 파티)를 시작한다
	if not StageRun.is_active():
		StageRun.start_run(null, map_seed)
	nodes = StageRun.progress.nodes
	# 2. 길(선)을 먼저 긋는다 → 나중에 놓는 노드 네모가 선 위에 덮여서, 선이 네모 밑에 깔린다
	_draw_links()
	# 3. 노드마다 틀 씬을 복제해서 Map 안에 놓는다
	for node in nodes:
		var view: StageNodeView = NODE_VIEW.instantiate()
		_map.add_child(view)
		view.set_node(node)
		# 위치는 노드 "중심" 기준이라 크기의 절반만큼 당긴다
		view.position = cell_position(node) - view.size / 2
		view.clicked.connect(_on_view_clicked)
		views.append(view)
	# 4. 현재 위치·커서·지나온 길 표시
	refresh()


## 노드의 화면 위치 (Map 기준, 노드 중심). 열 → 가로, 행 → 세로
func cell_position(node: StageNode) -> Vector2:
	return Vector2(node.column * column_gap, node.row * row_gap)


## 진행 상태대로 노드 상태(현재·고름·갈 수 있음·지나옴·잠김)와 선 색을 다시 칠한다
func refresh() -> void:
	var progress := StageRun.progress
	var choices := progress.choices()
	var selected := progress.selected()
	# 1. 노드 상태
	for view in views:
		var node := view.node
		if node == progress.current:
			view.set_state(StageNodeView.State.CURRENT)
		elif node == selected:
			view.set_state(StageNodeView.State.SELECTED)
		elif node in choices:
			view.set_state(StageNodeView.State.CHOICE)
		elif node.cleared:
			view.set_state(StageNodeView.State.CLEARED)
		else:
			view.set_state(StageNodeView.State.LOCKED)
	# 2. 선 색: 지금 갈 수 있는 길 / 지나온 길 / 나머지(틀 색 그대로)
	for key in _links:
		var line: Line2D = _links[key]
		var from: StageNode = key[0]
		var to: StageNode = key[1]
		if from == progress.current and to in choices:
			line.default_color = choice_link_color
		elif from.cleared and to.cleared:
			line.default_color = passed_link_color
		else:
			line.default_color = _link_template.default_color


# --- 입력 ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_up"):
		StageRun.progress.move_cursor(-1)
		refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map_down"):
		StageRun.progress.move_cursor(1)
		refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		StageRun.enter_selected()


## 노드 클릭: 커서가 있는 노드면 실행, 갈 수 있는 다른 노드면 커서만 옮긴다
func _on_view_clicked(view: StageNodeView) -> void:
	var progress := StageRun.progress
	if view.node == progress.selected():
		StageRun.enter_selected()
	elif progress.select(view.node):
		refresh()


# --- 선 ---

## 노드 사이 길을 선으로 긋는다. 길 하나마다 LinkTemplate(숨겨 둔 Line2D 틀)을 복제한다.
## 선은 출발 노드 중심 → 도착 노드 중심. 양 끝은 노드 네모에 가려져서 네모 사이만 보인다
## (이름이 _draw 가 아닌 이유: _draw 는 Godot 이 직접 그리기용으로 쓰는 이름이라 겹친다)
func _draw_links() -> void:
	for node in nodes:
		for to in node.next:
			var line: Line2D = _link_template.duplicate()
			line.visible = true
			line.points = PackedVector2Array([cell_position(node), cell_position(to)])
			_map.add_child(line)
			_links[[node, to]] = line
