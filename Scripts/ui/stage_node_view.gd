class_name StageNodeView
extends Control
## 스테이지 지도의 노드 하나를 그리는 화면 부품. stage_node_view.tscn 의 스크립트.
## StageMap 이 노드 수만큼 instantiate 해서 set_node() 로 데이터를 넣고, 진행에 따라 set_state() 로 상태를 바꾼다.
## 모양(크기, 글자 크기, 커서 테두리, "현재" 표시 등)은 stage_node_view.tscn 에서 에디터로 고친다.

## 노드를 클릭했을 때 (StageMap 이 커서 이동·실행을 정한다)
signal clicked(view: StageNodeView)

## 지도 위에서의 상태
## LOCKED 아직 못 감 / CHOICE 지금 갈 수 있음 / SELECTED 커서가 있음 / CURRENT 지금 서 있는 곳 / CLEARED 지나옴
enum State { LOCKED, CHOICE, SELECTED, CURRENT, CLEARED }

## 종류별 화면 이름. 순서 = StageNode.Kind (시작, 전투, 이벤트, 상점, 보스)
const KIND_NAMES := ["시작", "전투", "이벤트", "상점", "보스"]

## 종류별 색. 순서 = StageNode.Kind (시작, 전투, 이벤트, 상점, 보스). 인스펙터에서 바꿀 수 있다
@export var kind_colors: Array[Color] = [
	Color("5b6170"),  # 시작: 회색
	Color("b8483e"),  # 전투: 빨강
	Color("4a7bd0"),  # 이벤트: 파랑
	Color("d0a43a"),  # 상점: 노랑
	Color("6b2d8f"),  # 보스: 보라
]
## 아직 못 가는 노드의 색 배율 (흐리게)
@export var locked_modulate := Color(1, 1, 1, 0.35)
## 지나온 노드의 색 배율 (어둡게)
@export var cleared_modulate := Color(0.55, 0.55, 0.55, 1)

## 이 화면이 보여주는 노드 데이터
var node: StageNode
## 지금 상태
var state: State = State.LOCKED

@onready var _body: ColorRect = %Body
@onready var _label: Label = %KindLabel
@onready var _ring: Control = %Ring          # 커서 테두리 (SELECTED 일 때만 보임)
@onready var _here: Control = %HereMark      # "현재" 표시 (CURRENT 일 때만 보임)


## 노드 데이터를 넣고 색·글자를 바꾼다.
## ※ add_child 한 뒤에 불러야 한다 (그 전에는 %Body 등을 아직 못 찾는다)
func set_node(p_node: StageNode) -> void:
	node = p_node
	_body.color = kind_colors[node.kind]
	_label.text = KIND_NAMES[node.kind]


## 상태에 맞게 흐림/어둡게, 커서 테두리, "현재" 표시를 바꾼다
func set_state(p_state: State) -> void:
	state = p_state
	match state:
		State.LOCKED:
			modulate = locked_modulate
		State.CLEARED:
			modulate = cleared_modulate
		_:
			modulate = Color.WHITE
	_ring.visible = state == State.SELECTED
	_here.visible = state == State.CURRENT


## 왼쪽 클릭을 clicked 시그널로 알린다 (자식 노드들은 마우스를 무시하게 해 둬서 여기로 온다)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()
