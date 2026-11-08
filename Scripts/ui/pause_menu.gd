class_name PauseMenu
extends ColorRect
## 공용 ESC 메뉴. pause_menu.tscn 의 스크립트. 화면마다 따로 만들지 않고 이 씬을 넣어서 쓴다 (전투 화면, 스테이지 지도).
## 반투명 덮개 + 버튼: 계속하기 / 전투 스킵(승리, 개발 빌드에서만) / 의뢰 포기(공허 지도로).
## 어떤 버튼을 보일지는 넣는 쪽 씬의 인스펙터(show_skip, show_abandon)나 스크립트에서 정한다.
## 버튼을 누르면 시그널만 낸다 — 실제 동작(전투 끝내기, 의뢰 포기)은 넣은 화면이 한다.

## "계속하기"를 눌렀을 때 (메뉴는 스스로 닫힌다)
signal resumed()
## "전투 스킵"을 눌렀을 때
signal skip_requested()
## "의뢰 포기"를 눌렀을 때
signal abandon_requested()

## 전투 스킵 버튼을 보일지 (true 여도 개발 빌드에서만 보인다 — 플레이테스트용)
@export var show_skip := false
## 의뢰 포기 버튼을 보일지
@export var show_abandon := false

@onready var _resume: Button = %ResumeButton
@onready var _skip: Button = %SkipButton
@onready var _abandon: Button = %AbandonButton


func _ready() -> void:
	visible = false
	_resume.pressed.connect(func():
		close()
		resumed.emit())
	_skip.pressed.connect(func(): skip_requested.emit())
	_abandon.pressed.connect(func(): abandon_requested.emit())


## 메뉴를 연다 (버튼 보이기 설정을 이때 반영)
func open() -> void:
	_skip.visible = show_skip and OS.is_debug_build()
	_abandon.visible = show_abandon
	visible = true
	_resume.grab_focus()


## 메뉴를 닫는다
func close() -> void:
	visible = false


## 열려 있으면 닫고, 닫혀 있으면 연다
func toggle() -> void:
	if visible:
		close()
	else:
		open()
