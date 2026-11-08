class_name VoidMarker
extends Control
## 공허 지도 위의 공허 표식 하나. void_marker.tscn 의 스크립트.
## VoidMap 이 공허 수만큼 instantiate 해서 set_site() 로 데이터를 넣는다. 모양(점 크기·색·이름 글자)은 씬에서 고친다.

## 표식을 클릭했을 때 (VoidMap 이 정보 패널을 연다)
signal clicked(site: VoidSiteData)

## 정화 안 된 공허의 점 색
@export var open_color := Color("8e4bd6")
## 정화된 공허의 점 색
@export var cleared_color := Color("8a8a8a")

## 이 표식의 공허
var site: VoidSiteData

@onready var _dot: ColorRect = %Dot
@onready var _ring: Control = %Ring        # 고른 표식 테두리
@onready var _name: Label = %NameLabel


## 공허 데이터와 정화 여부를 넣는다. ※ add_child 한 뒤에 부른다
func set_site(p_site: VoidSiteData, cleared: bool) -> void:
	site = p_site
	_name.text = site.display_name + (" (정화됨)" if cleared else "")
	_dot.color = cleared_color if cleared else open_color


## 고른 표식이면 테두리를 보인다
func set_selected(on: bool) -> void:
	_ring.visible = on


## 왼쪽 클릭 → clicked (자식 노드는 마우스를 무시해서 여기로 온다)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(site)
		accept_event()
