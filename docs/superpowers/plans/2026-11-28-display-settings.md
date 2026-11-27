# 화면 설정(해상도) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 타이틀·사무소의 "설정" 버튼으로 설정 창을 열어 화면 모드(창/전체화면)와 창 크기를 고르고, 고른 값이 저장돼 다음 실행에도 유지되게 한다.

**Architecture:** 순수 로직 `DisplaySettings`(RefCounted: 값·크기 목록·ConfigFile 읽기/쓰기) + autoload `GameSettings`(Node: 시작 때 불러와 적용, 바꾸면 적용·저장) + 화면 `SettingsPanel`(씬, 두 화면에 인스턴스). 배치 기준 1920×1080 · `canvas_items` + `expand` 는 그대로 — 창 크기만 바뀌고 화면은 늘어나거나 줄어든다.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, Godot AI MCP(씬·autoload 편집)

**Spec:** 별도 스펙 없음 — 2026-11-28 대화에서 정함 (아래 Global Constraints 가 그 내용)

## Global Constraints

- 화면 모드는 둘: **창** / **전체화면** (`DisplayServer.WINDOW_MODE_FULLSCREEN` = 테두리 없는 전체화면, 모니터 해상도 그대로). 처음 말한 "테두리 없는 창"은 Godot 4 의 전체화면이 이미 테두리 없는 방식이라 뺐다 (내 결정)
- 창 크기 목록: `1280×720, 1600×900, 1920×1080` (사용자 결정: 1920×1080 까지) 중 **모니터 사용 가능 영역(`screen_get_usable_rect`) 안에 들어가는 것만**. 하나도 안 들어가면 1280×720 하나
- 기본값(설정 파일 없음): 창, 1600×900 (지금 `window_width_override` 와 같음). 파일이 없으면 **아무것도 적용하지 않는다** (프로젝트 설정 그대로)
- 저장: `user://settings.cfg`, 섹션 `display`, 키 `mode`("window"/"fullscreen"), `width`, `height`. 이상한 값은 기본값
- 바꾸면 **바로 적용 + 바로 저장** (확인/되돌리기 카운트다운 없음). 창 크기를 바꾸면 창을 화면 가운데로
- 전체화면일 때 창 크기 고르기는 비활성 (고른 값은 기억했다가 창으로 돌아갈 때 씀)
- 에디터 안에 끼워진 게임(`Engine.is_embedded_in_editor()`)이나 헤드리스(`DisplayServer.get_name() == "headless"`)에서는 창을 건드리지 않는다 (값 저장은 함)
- 설정 창은 닫기 버튼·ESC 로 닫힘. 열려 있는 동안 뒤 화면(타이틀 메뉴·사무소 숫자키)이 키 입력을 받지 않는다
- 프로젝트 규칙: 스크립트 `Scripts/<기능>/`, 씬 `Scenes/<기능>/`, 한국어 주석(클래스 `##`, export·공개 함수·시그널 `##`), 노드는 씬에(스크립트에서 `new()`/`add_child()` 금지), 에디터 켜진 동안 씬·autoload 는 Godot AI MCP 로, 테스트는 복사본 `../Void_testcopy` 에서 (godot_ai 플러그인·`_mcp_game_helper` 끔, `--log-file` 따로)
- 테스트 실행: `Godot_v4.7.2-stable_win64_console.exe --headless --path ../Void_testcopy -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

## Review Focus

- 저장된 창 크기가 지금 모니터보다 큼 (1440p 에서 1920×1080 저장 → 1080p 노트북) → 들어가는 가장 큰 크기로 줄여서 적용 — Task 1 `test_clamp_to_smaller_screen`
- 설정 파일이 깨졌거나 값이 이상함 (`mode="abc"`, `width=-5`) → 기본값, 오류로 멈추지 않음 — Task 1 `test_load_bad_values_fall_back`
- 설정 창이 열린 채 ESC → 창만 닫히고 타이틀이 TITLE 상태로 돌아가지 않음 — Task 4 `test_esc_closes_panel_only`
- 전체화면 → 창으로 돌아올 때 예전에 고른 창 크기를 씀 — Task 2 `test_window_size_kept_through_fullscreen`
- 사용자가 전체화면에서 Alt+Enter 등 바깥에서 모드를 바꿈 → 이번 범위 밖 (설정 창을 열면 저장값 기준으로 보여 줌)

---

### Task 1: DisplaySettings (순수 로직)

**Files:**
- Create: `Scripts/settings/display_settings.gd`
- Test: `tests/settings/test_display_settings.gd`

**Interfaces:**
- Produces:
  - `class_name DisplaySettings extends RefCounted`
  - `enum Mode { WINDOW, FULLSCREEN }`
  - `const SIZES: Array[Vector2i]` (위 3개, 작은 것부터)
  - `const DEFAULT_SIZE := Vector2i(1600, 900)`
  - `var mode: Mode = Mode.WINDOW`, `var window_size: Vector2i = DEFAULT_SIZE`
  - `static func sizes_fitting(screen: Vector2i) -> Array[Vector2i]`
  - `func clamp_to(screen: Vector2i) -> void` — `window_size` 가 안 들어가면 들어가는 가장 큰 것으로
  - `func save_to(cfg: ConfigFile) -> void`, `static func load_from(cfg: ConfigFile) -> DisplaySettings`
  - `func window_mode() -> DisplayServer.WindowMode`

- [ ] **Step 1: 실패하는 테스트 쓰기**

```gdscript
extends GutTest
# 화면 설정 값: 크기 목록 거르기, 모니터에 맞추기, 저장/불러오기

func test_sizes_fitting_1080p_screen():
	# 작업 표시줄 때문에 사용 가능 영역은 1920×1040 같은 값
	assert_eq(DisplaySettings.sizes_fitting(Vector2i(1920, 1040)),
		[Vector2i(1280, 720), Vector2i(1600, 900)] as Array[Vector2i])

func test_sizes_fitting_big_screen_has_all_three():
	assert_eq(DisplaySettings.sizes_fitting(Vector2i(3840, 2160)),
		[Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)] as Array[Vector2i])

func test_sizes_fitting_tiny_screen_keeps_smallest():
	assert_eq(DisplaySettings.sizes_fitting(Vector2i(1024, 600)),
		[Vector2i(1280, 720)] as Array[Vector2i])

func test_clamp_to_smaller_screen():
	var d := DisplaySettings.new()
	d.window_size = Vector2i(1920, 1080)
	d.clamp_to(Vector2i(1920, 1040))
	assert_eq(d.window_size, Vector2i(1600, 900))

func test_clamp_keeps_fitting_size():
	var d := DisplaySettings.new()
	d.window_size = Vector2i(1280, 720)
	d.clamp_to(Vector2i(3840, 2160))
	assert_eq(d.window_size, Vector2i(1280, 720))

func test_save_load_roundtrip():
	var d := DisplaySettings.new()
	d.mode = DisplaySettings.Mode.FULLSCREEN
	d.window_size = Vector2i(1920, 1080)
	var cfg := ConfigFile.new()
	d.save_to(cfg)
	assert_eq(cfg.get_value("display", "mode"), "fullscreen")
	var e := DisplaySettings.load_from(cfg)
	assert_eq(e.mode, DisplaySettings.Mode.FULLSCREEN)
	assert_eq(e.window_size, Vector2i(1920, 1080))

func test_load_bad_values_fall_back():
	var cfg := ConfigFile.new()
	cfg.set_value("display", "mode", "abc")
	cfg.set_value("display", "width", -5)
	cfg.set_value("display", "height", "x")
	var e := DisplaySettings.load_from(cfg)
	assert_eq(e.mode, DisplaySettings.Mode.WINDOW)
	assert_eq(e.window_size, DisplaySettings.DEFAULT_SIZE)

func test_window_mode_maps_to_display_server():
	var d := DisplaySettings.new()
	assert_eq(d.window_mode(), DisplayServer.WINDOW_MODE_WINDOWED)
	d.mode = DisplaySettings.Mode.FULLSCREEN
	assert_eq(d.window_mode(), DisplayServer.WINDOW_MODE_FULLSCREEN)
```

- [ ] **Step 2: 복사본에 동기화 후 실행 → 실패 확인** (`DisplaySettings` 없음으로 파싱 실패). `-gdir=res://tests/settings`
- [ ] **Step 3: `Scripts/settings/display_settings.gd` 구현** — 이상한 값 판정: `width`/`height` 가 int 가 아니거나 0 이하면 기본 크기. 크기는 SIZES 에 없어도 양수면 받아 둔다 (clamp 는 적용 때)
- [ ] **Step 4: 실행 → 통과**
- [ ] **Step 5: 커밋** `feat: DisplaySettings value + config load/save`

### Task 2: GameSettings autoload

**Files:**
- Create: `Scripts/settings/game_settings.gd`
- Modify: `project.godot` — autoload `GameSettings="*res://Scripts/settings/game_settings.gd"` (MCP `autoload_manage` add, `StageRun` 다음)
- Test: `tests/settings/test_game_settings.gd`

**Interfaces:**
- Consumes: `DisplaySettings` (Task 1)
- Produces (autoload 이름 `GameSettings`, 스크립트에 `class_name` 없음 — autoload 이름과 겹치지 않게):
  - `signal display_changed` — 값이 바뀌고 적용된 뒤
  - `var save_path := "user://settings.cfg"` (테스트가 바꿔 씀)
  - `var display: DisplaySettings`
  - `func load_settings() -> bool` — 파일이 있어서 읽었으면 true
  - `func save_settings() -> void`
  - `func apply() -> void` — 창 크기를 `clamp_to(사용 가능 영역)` 후 모드 적용, 창이면 크기 바꾸고 가운데로. 끼워진 게임·헤드리스면 창은 건드리지 않음
  - `func set_mode(mode: DisplaySettings.Mode) -> void`, `func set_window_size(size: Vector2i) -> void` — 값 바꾸기 → apply → save → `display_changed`
- `_ready`: `display = DisplaySettings.new()`; `if load_settings(): apply()`

- [ ] **Step 1: 실패하는 테스트** — 테스트용 노드를 `load("res://Scripts/settings/game_settings.gd").new()` 로 만들고 `save_path = "user://test_settings.cfg"` (after_each 에서 지움)

```gdscript
func test_set_window_size_saves_file()        # 저장 후 ConfigFile 로 읽으면 width=1280,height=720
func test_load_settings_false_without_file()  # 파일 없으면 false, display 는 기본값
func test_load_settings_reads_saved_file()    # 다른 인스턴스가 저장한 fullscreen 을 읽음
func test_window_size_kept_through_fullscreen() # set_window_size(1280x720) → set_mode(FULLSCREEN) → set_mode(WINDOW) → window_size 1280x720
func test_display_changed_emitted()           # watch_signals → set_mode 후 assert_signal_emitted
```

- [ ] **Step 2: 실행 → 실패 확인**
- [ ] **Step 3: 구현** + MCP 로 autoload 등록 (복사본 `project.godot` 에도 들어가게 동기화)
- [ ] **Step 4: 실행 → 통과** (헤드리스라 apply 는 창을 건드리지 않음)
- [ ] **Step 5: 커밋** `feat: GameSettings autoload applies and saves display settings`

### Task 3: SettingsPanel 씬

**Files:**
- Create: `Scenes/ui/settings_panel/settings_panel.tscn` (MCP 로 노드 만들기), `Scripts/ui/settings_panel.gd`
- Test: `tests/ui/test_settings_panel.gd`

**Interfaces:**
- Consumes: `GameSettings` autoload, `DisplaySettings`
- Produces:
  - `class_name SettingsPanel extends Control`
  - `signal closed`
  - `func open() -> void` — 저장값으로 옵션을 채우고 보이기, 첫 옵션에 포커스
  - `func close() -> void` — 숨기고 `closed`
  - 노드(unique): `%ModeOption`(OptionButton: 0 창 / 1 전체화면), `%SizeOption`(OptionButton: `sizes_fitting` 목록, 글 `"1600 × 900"`), `%CloseButton`(Button, theme variation `GhostButton`, 글 "닫기  ESC")
- 씬 구조: 루트 Control 전체 화면(앵커 15, mouse_filter STOP, 처음 `visible = false`) → `Dim` ColorRect(검정 a 0.6, 전체) → 가운데 `PanelContainer`(약 640×360) → VBox: 제목 Label "설정"(variation `PanelTitle`), Grid 2열(Label "화면 모드" + %ModeOption, Label "창 크기" + %SizeOption), 오른쪽 아래 %CloseButton. 꾸밈은 테마 기본값으로, 나중에 Figma 시안이 나오면 바꿈
- 입력: 보일 때 `_unhandled_input` 에서 `ui_cancel` → `close()`, 그 밖의 키 입력도 `set_input_as_handled()` 로 막음 (OptionButton 조작은 GUI 입력이라 그 전에 처리됨)
- %SizeOption 은 전체화면일 때 `disabled`

- [ ] **Step 1: 실패하는 테스트** (각 테스트 전 `GameSettings.save_path` 를 테스트 파일로, `GameSettings.display = DisplaySettings.new()`)

```gdscript
func test_starts_hidden()
func test_open_shows_saved_mode()             # display.mode=FULLSCREEN → open → %ModeOption.selected == 1, %SizeOption.disabled
func test_pick_fullscreen_calls_settings()    # %ModeOption.item_selected.emit(1) → GameSettings.display.mode == FULLSCREEN
func test_pick_size_calls_settings()          # 목록 0번(1280×720) 고르기 → window_size == 1280x720
func test_esc_closes_and_emits()              # ui_cancel 액션 이벤트 → visible false, closed 발생
func test_close_button_closes()
```

- [ ] **Step 2: 실행 → 실패 확인**
- [ ] **Step 3: 씬(MCP)·스크립트 구현**
- [ ] **Step 4: 실행 → 통과**
- [ ] **Step 5: 커밋** `feat: settings panel with window mode and size`

### Task 4: 타이틀·사무소에 연결

**Files:**
- Modify: `Scenes/ui/title_screen/title_screen.tscn`, `Scenes/ui/office_screen/office_screen.tscn` — 맨 마지막 자식으로 `SettingsPanel` 인스턴스(unique `%SettingsPanel`) (MCP)
- Modify: `Scripts/ui/title_screen.gd:122-124` — `Item.SETTINGS` → `%SettingsPanel.open()` (CREDITS 는 "준비 중" 유지), 클래스 주석 갱신
- Modify: `Scripts/ui/office_screen.gd:46` — `%SettingsButton` → `%SettingsPanel.open()`, 클래스 주석 갱신
- Modify: `tests/ui/test_title_screen.gd:95-108` — 설정 대신 제작진으로 "준비 중" 확인하도록 바꾸고 새 테스트 추가
- Test: `tests/ui/test_title_screen.gd`, `tests/ui/test_office_screen.gd`

- [ ] **Step 1: 테스트 고치기/추가**

```gdscript
# test_title_screen.gd
func test_settings_opens_panel()      # show_menu → activate(Item.SETTINGS) → %SettingsPanel.visible
func test_esc_closes_panel_only()     # 패널 연 채 get_viewport().push_input(ESC 키) (직접 호출 말고 실제 전달 순서로) → 패널 닫힘, t.state 는 여전히 MENU
# 기존 E/Enter 테스트: move_cursor 로 제작진까지 가서 "준비 중입니다" 확인
# test_office_screen.gd
func test_settings_button_opens_panel() # %SettingsButton.pressed.emit() → %SettingsPanel.visible
```

- [ ] **Step 2: 실행 → 실패 확인**
- [ ] **Step 3: 씬 인스턴스(MCP) + 스크립트 수정**
- [ ] **Step 4: 전체 테스트 실행 → 통과** (`-gdir=res://tests -ginclude_subdirs`)
- [ ] **Step 5: 직접 확인** — 에디터에서 F5 (끼워진 게임이면 창 모드가 안 바뀌니 별도 창 실행 설정 확인) → 설정 → 전체화면/창, 크기 바꾸기 → 껐다 켜서 유지되는지
- [ ] **Step 6: 문서** — `docs/progress.md` 에 한 줄, `CLAUDE.md` 의 확정 규칙에 "화면 설정" 짧은 절(위 Global Constraints 요약)
- [ ] **Step 7: 커밋** `feat: settings button opens display settings on title and office`
