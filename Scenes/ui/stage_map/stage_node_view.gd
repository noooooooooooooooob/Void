class_name StageNodeView
extends Control
## 스테이지 지도의 노드 하나를 그리는 화면 부품. stage_node_view.tscn 의 스크립트.
## StageMap 이 노드 수만큼 instantiate 해서 set_node() 로 데이터를 넣는다.
## 모양(크기, 글자 크기 등)은 stage_node_view.tscn 에서 에디터로 고친다.

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

## 이 화면이 보여주는 노드 데이터
var node: StageNode

@onready var _body: ColorRect = %Body
@onready var _label: Label = %KindLabel


## 노드 데이터를 넣고 색·글자를 바꾼다.
## ※ add_child 한 뒤에 불러야 한다 (그 전에는 %Body 등을 아직 못 찾는다)
func set_node(p_node: StageNode) -> void:
	node = p_node
	_body.color = kind_colors[node.kind]
	_label.text = KIND_NAMES[node.kind]
