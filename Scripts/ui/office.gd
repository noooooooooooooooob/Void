class_name Office
extends Control
## 사무소(허브) 화면. office.tscn 의 스크립트. 시작 화면 다음, 의뢰 사이에 오는 곳.
## 메뉴 (설정집 확정 목록): 창고 · 사원 명부 · 카드 공방 · 의뢰/출발 · 하루 마치기
## 지금은 버튼을 세로로 둔 단순 메뉴. 나중에 사무소 그림을 깔고 버튼을 그림 속 물건 위치로 옮긴다 (씬에서 편집).

@onready var _storage: Button = %StorageButton
@onready var _roster: Button = %RosterButton
@onready var _workshop: Button = %WorkshopButton
@onready var _depart: Button = %DepartButton
@onready var _end_day: Button = %EndDayButton  # 하루 마치기 — 아직 내용이 없어 비활성 (씬에서 disabled)


func _ready() -> void:
	_storage.pressed.connect(Router.goto.bind(Router.Screen.STORAGE))
	_roster.pressed.connect(Router.goto.bind(Router.Screen.ROSTER))
	_workshop.pressed.connect(Router.goto.bind(Router.Screen.CARD_WORKSHOP))
	_depart.pressed.connect(Router.goto.bind(Router.Screen.VOID_MAP))
	# 의뢰/출발에 먼저 포커스 (엔터로 바로 출발)
	_depart.grab_focus()


## ESC: 시작 화면으로
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Router.goto(Router.Screen.TITLE)
