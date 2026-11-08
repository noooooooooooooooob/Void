class_name TitleScreen
extends Control
## 게임 시작 화면. 게임을 켜면 가장 먼저 나오는 화면(메인 씬).
## "시작" 버튼을 누르면 사무소로 넘어간다.
## 개발용 바로가기 패널(DevPanel): 개발 빌드(에디터 실행, 디버그 빌드)에서만 보인다. 플레이테스트 때 각 화면으로 바로 간다.

## 개발용 "스테이지" 바로가기가 들어갈 공허 (인스펙터에서 voids/*.tres 를 넣는다)
@export var dev_site: VoidSiteData

@onready var _start_button: Button = %StartButton
@onready var _dev_panel: Control = %DevPanel


func _ready() -> void:
	# 엔터·스페이스로도 바로 누를 수 있게 시작 버튼에 포커스를 준다
	_start_button.grab_focus()
	# 개발용 패널: 출시용 빌드에서는 숨긴다
	_dev_panel.visible = OS.is_debug_build()
	%DevOffice.pressed.connect(Router.goto.bind(Router.Screen.OFFICE))
	%DevStorage.pressed.connect(Router.goto.bind(Router.Screen.STORAGE))
	%DevRoster.pressed.connect(Router.goto.bind(Router.Screen.ROSTER))
	%DevWorkshop.pressed.connect(Router.goto.bind(Router.Screen.CARD_WORKSHOP))
	%DevVoidMap.pressed.connect(Router.goto.bind(Router.Screen.VOID_MAP))
	%DevStage.pressed.connect(_dev_stage)
	%DevBattle.pressed.connect(_dev_battle)


## 시작 버튼의 pressed 시그널에 연결되어 있다 (title_screen.tscn 에서 연결) → 사무소로
func _on_start_button_pressed() -> void:
	Router.goto(Router.Screen.OFFICE)


## 개발용: dev_site 공허로 새 의뢰를 시작하고 스테이지 지도로
func _dev_stage() -> void:
	StageRun.start_run(dev_site)
	Router.goto(Router.Screen.STAGE_MAP)


## 개발용: 의뢰 없이 시험 전투 하나 (전투 화면 기본 데이터, 결과 버튼 = 다시 하기)
func _dev_battle() -> void:
	StageRun.end_run()
	Router.goto(Router.Screen.BATTLE)
