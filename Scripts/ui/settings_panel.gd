class_name SettingsPanel
extends Control
## 설정 창. 씬: `Scenes/ui/settings_panel/settings_panel.tscn`. 타이틀·사무소·전투 화면에 하나씩 인스턴스로 들어가 있고
## 타이틀·사무소는 "설정" 버튼이, 전투는 취소할 게 없을 때의 ESC 가 open() 을 부른다 (전투에선 pause_game 켬).
## - 화면 모드(창 / 전체화면)와 창 크기를 고르면 GameSettings 가 바로 적용하고 바로 저장한다
## - 창 크기 목록은 지금 모니터에 들어가는 것만. 전체화면일 때는 창 크기를 못 고른다
## - 닫기 버튼·ESC 로 닫힘. 열려 있는 동안 뒤 화면은 키 입력을 받지 않는다
## 계획 docs/superpowers/plans/2026-11-28-display-settings.md

## 창이 닫힌 뒤
signal closed

## 켜면 창이 떠 있는 동안 게임을 일시정지한다 (전투 화면: 창 뒤에서 적 차례가 진행되지 않게).
## 창 자체는 씬 루트의 process_mode = ALWAYS 라 멈춘 동안에도 입력을 받는다
@export var pause_game := false

## %ModeOption 의 줄 순서 = DisplaySettings.Mode 값 (0 창, 1 전체화면)
const MODE_TEXTS := ["창", "전체화면"]

@onready var _mode_option: OptionButton = %ModeOption
@onready var _size_option: OptionButton = %SizeOption


func _ready() -> void:
	_mode_option.clear()
	for t in MODE_TEXTS:
		_mode_option.add_item(t)
	_mode_option.item_selected.connect(_on_mode_selected)
	_size_option.item_selected.connect(_on_size_selected)
	%CloseButton.pressed.connect(close)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# ESC 는 창을 닫고, 그 밖의 입력도 뒤 화면(타이틀 메뉴·사무소 숫자키)으로 넘기지 않는다
	if event.is_action_pressed("ui_cancel"):
		close()
	get_viewport().set_input_as_handled()


## 저장된 값으로 옵션을 채우고 창을 보인다
func open() -> void:
	_refresh()
	show()
	_mode_option.grab_focus()
	if pause_game:
		get_tree().paused = true


## 창을 숨기고 (pause_game 이면 일시정지를 풀고) closed 를 보낸다
func close() -> void:
	hide()
	if pause_game:
		get_tree().paused = false
	closed.emit()


## 옵션 두 개를 GameSettings 의 지금 값에 맞춘다
func _refresh() -> void:
	var d: DisplaySettings = GameSettings.display
	_mode_option.select(d.mode)
	# 창 크기 목록: 지금 모니터 해상도에 들어가는 것만 (작업 표시줄 포함 전체 기준), 고른 값은 메타데이터(Vector2i)로
	_size_option.clear()
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	for s in DisplaySettings.sizes_fitting(screen):
		_size_option.add_item("%d × %d" % [s.x, s.y])
		_size_option.set_item_metadata(_size_option.item_count - 1, s)
		if s == d.window_size:
			_size_option.select(_size_option.item_count - 1)
	_size_option.disabled = d.mode == DisplaySettings.Mode.FULLSCREEN


func _on_mode_selected(index: int) -> void:
	GameSettings.set_mode(index as DisplaySettings.Mode)
	_size_option.disabled = index == DisplaySettings.Mode.FULLSCREEN


func _on_size_selected(index: int) -> void:
	GameSettings.set_window_size(_size_option.get_item_metadata(index))
