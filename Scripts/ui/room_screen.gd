class_name RoomScreen
extends Control
## 이벤트·의뢰 성공을 보여주는 간단한 방 화면. room_screen.tscn 의 스크립트.
## 상점은 상점 화면(shop_screen.tscn)이 맡는다 (2026-11-17).
## 이벤트는 아직 효과가 없는 자리만 마련한 단계 (CLAUDE.md: 이벤트 효과는 미정):
##   - 이벤트: A / B 선택지 중 아무거나 누르면 그냥 다음 (지도로)
##   - 의뢰 성공(보스 승리 뒤): "처음으로" 버튼 → 시작 화면
## 어떤 방인지는 StageRun.room() 이 정한다. 글자·배치는 room_screen.tscn 에서 에디터로 고친다.

@onready var _title: Label = %TitleLabel
@onready var _body: Label = %BodyLabel
@onready var _choice_a: Button = %ChoiceA
@onready var _choice_b: Button = %ChoiceB
@onready var _next: Button = %NextButton

## 지금 보여주는 방 (StageRun.Room)
var room: int


func _ready() -> void:
	_choice_a.pressed.connect(_on_choice)
	_choice_b.pressed.connect(_on_choice)
	_next.pressed.connect(_on_next)
	room = StageRun.room()
	# 방 종류마다 글자와 보일 버튼을 바꾼다
	match room:
		StageRun.Room.EVENT:
			_title.text = "이벤트"
			_body.text = "무언가 일어났다. 어떻게 할까?\n(아직 선택지 효과는 없다)"
			_show_buttons(true, false)
			_choice_a.grab_focus()
		StageRun.Room.CLEAR:
			_title.text = "의뢰 성공"
			_body.text = "보스를 쓰러뜨렸다."
			_next.text = "처음으로"
			_show_buttons(false, true)
			_next.grab_focus()


## 선택지 A/B 와 다음 버튼 중 무엇을 보일지
func _show_buttons(choices: bool, next: bool) -> void:
	_choice_a.visible = choices
	_choice_b.visible = choices
	_next.visible = next


## 이벤트 선택지 (지금은 A·B 결과가 같다)
func _on_choice() -> void:
	StageRun.complete_node()


## 의뢰 성공 "처음으로" (그 밖의 방에서는 다음 노드로)
func _on_next() -> void:
	if room == StageRun.Room.CLEAR:
		StageRun.finish_run()
	else:
		StageRun.complete_node()
