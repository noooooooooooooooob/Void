extends Node
## 게임 설정 autoload (`GameSettings`). 지금은 화면 설정(DisplaySettings)만 다룬다.
## - 시작할 때 `user://settings.cfg` 를 읽어 창에 적용한다. 파일이 없으면 아무것도 적용하지 않는다 (프로젝트 설정 그대로)
## - 설정 창(SettingsPanel)이 set_mode / set_window_size 를 부르면 바로 적용하고 바로 저장한다
## 계획 docs/superpowers/plans/2026-11-28-display-settings.md

## 화면 설정이 바뀌고 적용된 뒤
signal display_changed

## 설정 파일 경로 (테스트가 다른 경로로 바꿔 쓴다)
var save_path := "user://settings.cfg"
## 지금 화면 설정 값
var display := DisplaySettings.new()


func _ready() -> void:
	if load_settings():
		apply()


## save_path 에서 설정을 읽는다. 파일이 있어서 읽었으면 true (없거나 못 읽으면 기본값 그대로 false)
func load_settings() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return false
	display = DisplaySettings.load_from(cfg)
	return true


## 지금 값을 save_path 에 쓴다 (같은 파일의 다른 섹션은 남긴다)
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)  # 없으면 빈 파일로 시작
	display.save_to(cfg)
	var err := cfg.save(save_path)
	if err != OK:
		push_warning("GameSettings: 설정을 저장하지 못했어요 (%s)" % error_string(err))


## 지금 값을 창에 적용한다. 에디터 안에 끼워진 게임·헤드리스에서는 창을 건드리지 않는다 (값만 유지)
func apply() -> void:
	if Engine.is_embedded_in_editor() or DisplayServer.get_name() == "headless":
		return
	# 1. 저장된 창 크기가 지금 모니터 해상도보다 크면 들어가는 가장 큰 크기로
	#    (사용자 결정: 작업 표시줄 뺀 영역이 아니라 모니터 전체 기준 — 1080p 모니터에서도 1920×1080 창)
	var screen := DisplayServer.window_get_current_screen()
	display.clamp_to(DisplayServer.screen_get_size(screen))
	# 2. 모드 적용. 창이면 크기를 바꾸고, 제목 표시줄까지 합쳐 사용 영역 가운데로 (넘치면 맨 위)
	DisplayServer.window_set_mode(display.window_mode())
	if display.mode == DisplaySettings.Mode.WINDOW:
		DisplayServer.window_set_size(display.window_size)
		var title_h := DisplayServer.window_get_size_with_decorations().y - DisplayServer.window_get_size().y
		var area := DisplayServer.screen_get_usable_rect(screen)
		DisplayServer.window_set_position(DisplaySettings.window_position(area, display.window_size, title_h))


## 화면 모드를 바꾼다 → 적용 → 저장 → display_changed
func set_mode(mode: DisplaySettings.Mode) -> void:
	display.mode = mode
	_commit()


## 창 크기를 바꾼다 (전체화면 중이면 기억만 했다가 창으로 돌아갈 때 쓴다) → 적용 → 저장 → display_changed
func set_window_size(size: Vector2i) -> void:
	display.window_size = size
	_commit()


func _commit() -> void:
	apply()
	save_settings()
	display_changed.emit()
