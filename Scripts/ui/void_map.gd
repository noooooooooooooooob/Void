class_name VoidMap
extends Control
## 공허 지도 화면 (월드맵). void_map.tscn 의 스크립트. 사무소의 "의뢰/출발"에서 온다.
## 세계 지도 그림 위에 공허 표식을 놓고, 표식을 고르면 오른쪽 정보 패널에 이름·설명·층·정화 여부와 "들어가기"가 뜬다.
## 들어가기 → 그 공허로 새 의뢰 시작 → 스테이지 지도. 의뢰가 끝나면(성공/실패) 여기로 돌아온다.
## 조작: 표식 클릭으로 고르기, 엔터 = 들어가기, ESC = 사무소로

## 표식 하나를 그리는 틀 씬
const MARKER := preload("res://Scenes/ui/void_map/void_marker.tscn")

## 지도에 놓을 공허들 (인스펙터에서 voids/*.tres 를 넣는다)
@export var sites: Array[VoidSiteData] = []

## 공허마다 만든 표식 (sites 와 같은 순서)
var markers: Array[VoidMarker] = []
## 지금 고른 공허 (없으면 null)
var selected: VoidSiteData = null

@onready var _markers_layer: Control = %Markers   # 지도 그림 위 표식들이 놓이는 곳 (지도 그림 좌표)
@onready var _info: Control = %InfoPanel
@onready var _site_name: Label = %SiteName
@onready var _site_desc: Label = %SiteDesc
@onready var _site_state: Label = %SiteState
@onready var _enter: Button = %EnterButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	_enter.pressed.connect(enter)
	_back.pressed.connect(Router.goto.bind(Router.Screen.OFFICE))
	_info.visible = false
	_enter.disabled = true
	# 공허마다 표식을 틀에서 복제해서 지도 위 위치(map_position, 표식 중심)에 놓는다
	for site in sites:
		var m: VoidMarker = MARKER.instantiate()
		_markers_layer.add_child(m)
		m.set_site(site, StageRun.is_cleared(site.id))
		m.position = site.map_position - m.size / 2
		m.clicked.connect(select)
		markers.append(m)


## site 를 골라 정보 패널을 연다
func select(site: VoidSiteData) -> void:
	selected = site
	for m in markers:
		m.set_selected(m.site == site)
	_site_name.text = site.display_name
	_site_desc.text = site.description
	_site_state.text = "%d층 · %s" % [site.floor_level, "정화됨" if StageRun.is_cleared(site.id) else "미정화"]
	_info.visible = true
	_enter.disabled = false
	_enter.grab_focus()


## 고른 공허로 새 의뢰를 시작하고 스테이지 지도로
func enter() -> void:
	if selected == null:
		return
	StageRun.start_run(selected)
	Router.goto(Router.Screen.STAGE_MAP)


## 엔터: 들어가기(고른 공허가 있을 때), ESC: 사무소로
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and selected:
		get_viewport().set_input_as_handled()
		enter()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Router.goto(Router.Screen.OFFICE)
