class_name TitleScreen
extends Control
## 게임 시작 화면. 게임을 켜면 가장 먼저 나오는 화면(메인 씬).
## "시작" 버튼을 누르면 스테이지 지도(stage_map.tscn)로 넘어간다.

## 시작을 누르면 넘어갈 씬. 인스펙터에서 stage_map.tscn 을 끌어다 넣는다.
## (경로 글자 대신 씬을 직접 넣어 두면 파일을 옮겨도 연결이 안 깨진다)
@export var next_scene: PackedScene

@onready var _start_button: Button = %StartButton


func _ready() -> void:
	# 엔터·스페이스로도 바로 누를 수 있게 시작 버튼에 포커스를 준다
	_start_button.grab_focus()


## 시작 버튼의 pressed 시그널에 연결한다 (에디터의 노드 탭에서 연결)
func _on_start_button_pressed() -> void:
	if next_scene == null:
		push_warning("TitleScreen: next_scene 이 비어 있어요")
		return
	get_tree().change_scene_to_packed(next_scene)
