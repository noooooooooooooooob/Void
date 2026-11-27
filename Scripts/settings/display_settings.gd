class_name DisplaySettings
extends RefCounted
## 화면 설정 값 (화면 모드·창 크기). 저장/불러오기와 모니터에 맞추기 규칙만 담은 순수 로직.
## 실제로 창에 적용하고 파일에 쓰는 일은 autoload `GameSettings`(Scripts/settings/game_settings.gd)가 한다.
## 계획 docs/superpowers/plans/2026-11-28-display-settings.md

## 화면 모드. WINDOW = 창, FULLSCREEN = 테두리 없는 전체화면 (모니터 해상도 그대로)
enum Mode { WINDOW, FULLSCREEN }

## 고를 수 있는 창 크기 (작은 것부터). 사용자 결정: 16:9 만, 1920×1080 까지
## (1366×768 은 정확히 16:9 는 아니지만 노트북 표준 해상도라 넣음 — 차이는 expand 가 흡수)
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1440, 810),
	Vector2i(1536, 864), Vector2i(1600, 900), Vector2i(1920, 1080),
]
## 설정 파일이 없거나 값이 이상할 때의 창 크기 (project.godot 의 window override 와 같음)
const DEFAULT_SIZE := Vector2i(1600, 900)

## 설정 파일 안의 섹션 이름
const SECTION := "display"
## 저장 파일의 mode 값 ↔ Mode
const MODE_NAMES := { Mode.WINDOW: "window", Mode.FULLSCREEN: "fullscreen" }

## 지금 화면 모드
var mode: Mode = Mode.WINDOW
## 창 모드일 때의 창 크기 (픽셀). 전체화면에서도 기억했다가 창으로 돌아갈 때 쓴다
var window_size: Vector2i = DEFAULT_SIZE


## 모니터 사용 가능 영역(screen)에 들어가는 창 크기 목록. 하나도 안 들어가면 가장 작은 크기 하나
static func sizes_fitting(screen: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for s in SIZES:
		if s.x <= screen.x and s.y <= screen.y:
			out.append(s)
	if out.is_empty():
		out.append(SIZES[0])
	return out


## window_size 가 screen 에 안 들어가면 들어가는 가장 큰 크기로 줄인다 (예: 큰 모니터에서 저장 → 노트북)
func clamp_to(screen: Vector2i) -> void:
	if window_size.x <= screen.x and window_size.y <= screen.y:
		return
	window_size = sizes_fitting(screen).back()


## 값을 cfg 의 display 섹션에 쓴다 (파일 저장은 부르는 쪽이)
func save_to(cfg: ConfigFile) -> void:
	cfg.set_value(SECTION, "mode", MODE_NAMES[mode])
	cfg.set_value(SECTION, "width", window_size.x)
	cfg.set_value(SECTION, "height", window_size.y)


## cfg 에서 값을 읽어 새 DisplaySettings 로. 없거나 이상한 값은 기본값 (깨진 파일로 멈추지 않게)
static func load_from(cfg: ConfigFile) -> DisplaySettings:
	var d := DisplaySettings.new()
	# 1. 모드: 아는 이름(문자열)만 받는다. 숫자 등 다른 타입은 String 과 비교하면 오류라 먼저 거른다
	var m = cfg.get_value(SECTION, "mode", "")
	if m is String:
		for key in MODE_NAMES:
			if MODE_NAMES[key] == m:
				d.mode = key
	# 2. 크기: 둘 다 양의 정수일 때만 받는다 (목록에 없는 크기도 받아 두고, 적용할 때 clamp_to)
	var w = cfg.get_value(SECTION, "width", 0)
	var h = cfg.get_value(SECTION, "height", 0)
	if w is int and h is int and w > 0 and h > 0:
		d.window_size = Vector2i(w, h)
	return d


## Godot 창 모드 값으로 바꾼다
func window_mode() -> DisplayServer.WindowMode:
	if mode == Mode.FULLSCREEN:
		return DisplayServer.WINDOW_MODE_FULLSCREEN
	return DisplayServer.WINDOW_MODE_WINDOWED
