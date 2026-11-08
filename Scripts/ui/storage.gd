class_name Storage
extends Control
## 창고(인벤토리) 화면. storage.tscn 의 스크립트.
## 아이템 데이터가 아직 없어서 지금은 "아직 아이템이 없다" 안내와 뒤로 버튼만 있다 (안내 문구는 씬에서 편집).
## 아이템이 생기면 여기에 목록(틀 씬 복제)을 채운다.

@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.pressed.connect(Router.goto.bind(Router.Screen.OFFICE))
	_back.grab_focus()


## ESC: 사무소로
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Router.goto(Router.Screen.OFFICE)
