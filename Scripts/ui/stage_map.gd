class_name StageMap
extends Control
## 스테이지 지도 화면. stage_map.tscn 의 스크립트.
## 들어올 때마다 StageGenerator 로 지도를 새로 만들고, 노드마다 StageNodeView 를 하나씩 놓는다.

## 노드 하나를 그리는 틀 씬
const NODE_VIEW := preload("res://Scenes/ui/stage_map/stage_node_view.tscn")

## 열 사이 간격 (px, 노드 중심 기준)
@export var column_gap := 260.0
## 행 사이 간격 (px, 노드 중심 기준)
@export var row_gap := 180.0
## 지도 seed. 0 이면 들어올 때마다 다른 지도, 숫자를 넣으면 항상 같은 지도 (확인용)
@export var map_seed := 0

## 지금 지도의 노드들 ([0] = 시작, 마지막 = 보스)
var nodes: Array[StageNode] = []
## 노드마다 하나씩 만든 화면 부품 (nodes 와 같은 순서)
var views: Array[StageNodeView] = []

@onready var _map: Control = %Map


func _ready() -> void:
	# 1. 지도 데이터를 새로 만든다
	nodes = StageGenerator.new(map_seed).generate()
	# 2. 노드마다 틀 씬을 복제해서 Map 안에 놓는다
	for node in nodes:
		var view: StageNodeView = NODE_VIEW.instantiate()
		_map.add_child(view)
		view.set_node(node)
		# 위치는 노드 "중심" 기준이라 크기의 절반만큼 당긴다
		view.position = cell_position(node) - view.size / 2
		views.append(view)


## 노드의 화면 위치 (Map 기준, 노드 중심). 열 → 가로, 행 → 세로
func cell_position(node: StageNode) -> Vector2:
	return Vector2(node.column * column_gap, node.row * row_gap)
