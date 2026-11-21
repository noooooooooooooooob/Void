# 연출 타임라인 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 연출 씬을 에디터 ▶ 로 그대로 미리 볼 수 있게(위치·동작·카메라·이펙트·소리) 구조를 바꾸고, 실제 전투에서 칸 위치에 맞춰 늘려 재생하며 카메라로 월드를 움직이고, F6 한 번으로 진짜 전투 연출을 반복 재생하는 미리보기 씬을 만든다.

**Architecture:** 자리 맞추기·카메라 변환은 순수 계산(`PerformanceSpace`, `CameraMath`, RefCounted). `CardPerformance` 가 AnimationPlayer 를 수동으로 진행시키며(`advance`) 매 프레임 "애니메이션이 쓴 원래 위치 → 실제 칸 기준 위치" 로 바꿔 놓는다. `PerformanceQueue` 는 Home/Target 을 실제 그림 자리에 맞추고, `BattleScreen` 은 연출의 카메라 변환을 새 `%World` 묶음에만 적용한다. `move()` 키는 없앤다.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1

**Spec:** `docs/superpowers/specs/2026-11-19-performance-timeline-design.md` (이전 설계 `2026-11-14-card-performance-design.md` 의 hit/show_results/zoom 규칙은 그대로)

## Global Constraints
- 게임 스크립트는 `Scripts/<기능>/`, 테스트는 `tests/<기능>/`. 모든 게임 스크립트에 한국어 주석(클래스 `##`, 공개 함수·변수·시그널 `##`)
- `.tscn` 은 손으로 쓰지 않는다: 에디터가 켜져 있으면 GoPeak MCP `scene-node-add` (`scene-node-set` 금지), 노드 옮기기·애니메이션 트랙 만들기처럼 MCP 로 안 되는 것은 **에디터를 끈 상태에서** Godot 헤드리스 스크립트(scratchpad 에 둠)로 PackedScene 을 열어 고치고 `ResourceSaver.save`. 에디터가 켜져 있으면 사용자에게 꺼 달라고 요청
- 테스트는 프로젝트 **복사본**에서 실행 (MCP 플러그인·MCPRuntime 끄고 `--log-file` 따로):
  `Godot_v4.7.2-stable_win64_console.exe --headless --path <복사본> --import` 후
  `... --headless --path <복사본> -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- 전투 계산(`Scripts/battle/`, 카드 효과)은 건드리지 않는다. 연출 없는 카드는 지금과 똑같이
- 적이라고 좌우 반전하지 않는다
- 연출 씬 노드 이름 규약: `Home`(Marker2D), `Target`(Marker2D, 자식은 미리보기 그림), `Actor`(AnimatedSprite2D, `%Actor`), `Camera`(Camera2D, `enabled = false`), `AnimationPlayer`(`%AnimationPlayer`), 애니메이션 이름 `perform`
- 커밋은 사용자가 요청할 때만 (작업 트리에 다른 미커밋 작업이 있음 — 커밋 단계에서는 이 계획의 파일만 `git add`)

## Review Focus
- Home 과 Target 이 같은 자리(`d = 0`, 자신 카드 등) → 0 나누기 없이 w = 0 (Task 1 테스트)
- 위치 트랙이 없는 노드(이펙트가 제자리)는 매 프레임 바꿔도 **밀려 나가지 않아야** 함 (Task 2 테스트)
- 히트스톱(`set_paused(true)`) 동안 수동 진행도 멈춰야 함 — 안 그러면 히트스톱이 사라짐 (Task 2 테스트)
- Camera 노드가 없는 연출(기존 방식 카드, 테스트용 조립 연출) → `%World` 변환이 항상 단위 행렬 (Task 4 테스트)
- 연출 중 손패·버튼(UI)은 카메라에 따라 움직이지 않아야 함 (Task 4 테스트)

---

### Task 1: 순수 계산 — 자리 맞추기·카메라 변환

**Files:**
- Create: `Scripts/performances/performance_space.gd`, `Scripts/performances/camera_math.gd`
- Test: `tests/performances/test_performance_space.gd`, `tests/performances/test_camera_math.gd`

**Interfaces:**
- Produces:
  - `class_name PerformanceSpace extends RefCounted` — `static func map_point(p: Vector2, home: Vector2, target: Vector2, real_home: Vector2, real_target: Vector2) -> Vector2`
  - `class_name CameraMath extends RefCounted` — `static func camera_xform(pos: Vector2, rot: float, zoom: Vector2) -> Transform2D` (= 이동·회전·`1/zoom` 크기), `static func view(cam0: Transform2D, cam: Transform2D) -> Transform2D` (= `cam0 * cam.affine_inverse()`, 시작 카메라 기준으로 월드를 움직일 변환)

- [ ] **Step 1: 실패하는 테스트**

```gdscript
# test_performance_space.gd
func test_home_maps_to_real_home():
	assert_eq(PerformanceSpace.map_point(Vector2(0,0), Vector2(0,0), Vector2(100,0), Vector2(0,0), Vector2(300,0)), Vector2(0,0))
func test_target_maps_to_real_target():
	assert_eq(PerformanceSpace.map_point(Vector2(100,0), Vector2(0,0), Vector2(100,0), Vector2(0,0), Vector2(300,0)), Vector2(300,0))
func test_midway_stretches():
	assert_eq(PerformanceSpace.map_point(Vector2(50,0), Vector2(0,0), Vector2(100,0), Vector2(0,0), Vector2(300,0)), Vector2(150,0))
func test_height_off_line_kept():
	assert_eq(PerformanceSpace.map_point(Vector2(50,-40), Vector2(0,0), Vector2(100,0), Vector2(0,0), Vector2(300,0)), Vector2(150,-40))
func test_beyond_target_follows_target():
	assert_eq(PerformanceSpace.map_point(Vector2(130,0), Vector2(0,0), Vector2(100,0), Vector2(0,0), Vector2(300,0)), Vector2(330,0))
func test_behind_home_follows_home():
	assert_eq(PerformanceSpace.map_point(Vector2(-20,0), Vector2(0,0), Vector2(100,0), Vector2(10,0), Vector2(300,0)), Vector2(-10,0))
func test_same_home_and_target_no_nan():
	var r := PerformanceSpace.map_point(Vector2(5,5), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2(50,0))
	assert_eq(r, Vector2(5,5))

# test_camera_math.gd
func test_view_identity_when_camera_unchanged():
	var k := CameraMath.camera_xform(Vector2(100,50), 0.0, Vector2.ONE)
	assert_true(CameraMath.view(k, k).is_equal_approx(Transform2D.IDENTITY))
func test_zoom_two_scales_world_about_camera_point():
	var k0 := CameraMath.camera_xform(Vector2(100,50), 0.0, Vector2.ONE)
	var v := CameraMath.view(k0, CameraMath.camera_xform(Vector2(100,50), 0.0, Vector2(2,2)))
	assert_almost_eq(v.get_scale(), Vector2(2,2), Vector2(0.001,0.001))
	assert_almost_eq(v * Vector2(100,50), Vector2(100,50), Vector2(0.001,0.001))  # 카메라 중심은 제자리
func test_pan_moves_world_opposite():
	var k0 := CameraMath.camera_xform(Vector2.ZERO, 0.0, Vector2.ONE)
	var v := CameraMath.view(k0, CameraMath.camera_xform(Vector2(40,0), 0.0, Vector2.ONE))
	assert_almost_eq(v * Vector2(40,0), Vector2.ZERO, Vector2(0.001,0.001))
```

- [ ] **Step 2: 복사본에서 실행 → 클래스 없음으로 FAIL 확인**
- [ ] **Step 3: 구현.** `map_point` 알고리즘 (설계 2장):

```
d = target - home; L = d.length_squared()
w = 0 if L == 0 else clamp((p - home).dot(d) / L, 0, 1)
return p + (1 - w) * (real_home - home) + w * (real_target - target)
```

- [ ] **Step 4: 실행 → PASS**
- [ ] **Step 5: 커밋** `feat: PerformanceSpace / CameraMath for performance timeline`

---

### Task 2: CardPerformance 새 규약 (수동 진행 + 자리 맞추기 + 카메라 값)

**Files:**
- Modify: `Scripts/performances/card_performance.gd`
- Modify: `tests/performances/test_card_performance.gd` (조립 도우미 `build` 확장, move 관련 테스트 삭제)

**Interfaces:**
- Consumes: `PerformanceSpace.map_point`, `CameraMath.camera_xform`
- Produces (`CardPerformance`):
  - 삭제: `signal move_requested`, `func move(...)`
  - `func set_stage(real_home: Vector2, real_target: Vector2) -> void` — 루트 로컬 좌표. 부르지 않으면 Home/Target 그대로(에디터와 같음)
  - `func play(frames: SpriteFrames) -> void` — 기존 + `Target` 의 자식 그림 숨김, `Actor.play()` 시작, AnimationPlayer `callback_mode_process = ANIMATION_CALLBACK_MODE_PROCESS_MANUAL`
  - `func has_camera() -> bool`
  - `func camera_xform() -> Transform2D` — 바뀐(맵핑된) Camera 의 루트 로컬 `CameraMath.camera_xform`. Camera 없으면 `Transform2D.IDENTITY`
  - `func home_position() -> Vector2` — Home 로컬 위치 (Home 없으면 `Vector2.ZERO`)
  - `func actor_offset_from_home() -> Vector2` — 지금 화면상 Actor 위치 − 실제 Home
  - 기존 `set_paused`, `hit`, `show_results`, `zoom`, 시그널(hit_reached, results_requested, zoom_requested, done), `@export` 들 유지
- 테스트 도우미: `static func build(keys: Array, length := 0.2, actor_x_keys: Array = [], anim_keys: Array = [], cam_zoom_keys: Array = []) -> CardPerformance` — `Home`(0,0)·`Target`(200,0, 자식 Sprite2D 하나) Marker2D 를 넣고, `actor_x_keys = [[시각, x], ...]` 면 `Actor:position:x` 값 트랙, `anim_keys = [[시각, 이름], ...]` 면 `Actor:animation` 값 트랙(UPDATE_DISCRETE), `cam_zoom_keys = [[시각, Vector2], ...]` 면 `Camera`(Camera2D, enabled false, (100,0)) + `Camera:zoom` 값 트랙 추가 (Task 4 가 씀)

- [ ] **Step 1: 실패하는 테스트** (test_card_performance.gd 에 추가, 기존 `test_keys_emit_signals_in_order` 에서 move 키 제거)

```gdscript
func test_actor_stretches_to_real_target():
	var p := build([], 0.4, [[0.0, 0.0], [0.1, 200.0]])
	add_child_autofree(p)
	p.set_stage(Vector2.ZERO, Vector2(500, 0))
	p.play(null)
	await wait_seconds(0.25)
	assert_almost_eq(p.get_node("%Actor").position.x, 500.0, 1.0)

func test_node_without_track_does_not_drift():
	var p := build([], 0.3)
	add_child_autofree(p)
	p.set_stage(Vector2.ZERO, Vector2(500, 0))
	p.get_node("%Actor").position = Vector2(200, 0)  # Target 위, 트랙 없음
	p.play(null)
	await wait_seconds(0.2)
	assert_almost_eq(p.get_node("%Actor").position.x, 500.0, 1.0)  # 한 번만 맞춰지고 계속 밀리지 않음

func test_target_preview_hidden_on_play():
	var p := build([], 0.1)
	add_child_autofree(p)
	p.play(null)
	assert_false(p.get_node("Target").get_child(0).visible)

func test_paused_stops_manual_advance():
	var p := build([], 0.4, [[0.0, 0.0], [0.4, 200.0]])
	add_child_autofree(p)
	p.play(null)
	p.set_paused(true)
	await wait_seconds(0.15)
	assert_almost_eq(p.get_node("%Actor").position.x, 0.0, 1.0)

func test_no_camera_is_identity():
	var p := build([], 0.1)
	add_child_autofree(p)
	assert_false(p.has_camera())
	assert_eq(p.camera_xform(), Transform2D.IDENTITY)

func test_actor_animation_track_keeps_playing():
	# Actor:animation 속성 트랙으로 "punch" 로 바꿔도 AnimatedSprite2D 가 재생 상태 유지
	var p := build([], 0.2, [], [[0.0, &"idle"], [0.05, &"punch"]])
	add_child_autofree(p)
	p.play(load("res://entities/units/bram_frames.tres"))
	await wait_seconds(0.1)
	assert_eq(p.get_node("%Actor").animation, &"punch")
	assert_true(p.get_node("%Actor").is_playing())
```

- [ ] **Step 2: 실행 → FAIL 확인**
- [ ] **Step 3: 구현.** 매 `_process(delta)` 순서 (설계 2장 "원래 값과 화면 위치 분리"):
  1. 맵핑 대상 노드(루트의 직계 Node2D 자식 중 `Home`·`Target` 제외)의 위치를 **지난번에 기억한 원래 값**으로 되돌림 (처음엔 지금 값을 원래 값으로 기억)
  2. 재생 중이면 `_player.advance(delta)` (`speed_scale` 0 이면 진행 안 됨을 테스트로 확인; 안 되면 `delta * _player.speed_scale` 로 직접)
  3. 각 노드의 지금 위치를 원래 값으로 기억 → `PerformanceSpace.map_point(원래, home, target, real_home, real_target)` 를 위치로
  - 에디터(`Engine.is_editor_hint()`)에서는 아무것도 하지 않음 (스크립트가 `@tool` 이 아니므로 자연히)
  - perform 이 끝나도 `_process` 는 계속 맵핑(복귀 전까지 자리가 유지되게)
- [ ] **Step 4: 실행 → PASS, `tests/performances/` 전체 PASS** (`test_bram_stone_fist` 는 Task 5 전까지 실패해도 됨 — 기록만)
- [ ] **Step 5: 커밋** `feat: CardPerformance manual advance with stage mapping, drop move()`

---

### Task 3: PerformanceQueue — Home/Target 을 실제 그림 자리에

**Files:**
- Modify: `Scripts/ui/performance_queue.gd`, `Scripts/ui/battle_screen.gd` (`_hitstop` 의 `move_tween` 참조 → `return_tween`)
- Modify: `tests/ui/test_battle_screen_performance.gd` (`test_auto_return_after_move`, `test_move_goes_near_target_cell` 을 위치 트랙 기반으로 교체)

**Interfaces:**
- Consumes: `CardPerformance.set_stage`, `home_position`, `actor_offset_from_home`, `PerfBuild.build(keys, length, actor_x_keys)`
- Produces: `PerformanceQueue.return_tween: Tween` (이름 변경, 히트스톱이 멈춤), `_on_move` 삭제

- [ ] **Step 1: 실패하는 테스트**

```gdscript
func test_actor_reaches_target_sprite():
	# 위치 트랙: 0→0.05초에 Home(0)→Target(200). 실제로는 대상 그림 자리까지 가야 함
	var s := _screen(_data(45, null, _perf_x([[0.0, 0.0], [0.05, 200.0]], 0.3)))
	s.select_card(_index_of(s, "연출타격")); s.click_unit(_unit(s, "적A"))
	await wait_seconds(0.15)
	var actor: Node2D = s.get_node("%PerformanceLayer").get_child(0).get_node("%Actor")
	var target_sprite: Node2D = s._tokens[_unit(s, "적A")].sprite()
	assert_almost_eq(actor.global_position.x, target_sprite.global_position.x, 2.0)

func test_actor_returns_home_after_perform():
	var s := _screen(_data(45, null, _perf_x([[0.0, 0.0], [0.05, 200.0]], 0.15)))
	s.select_card(_index_of(s, "연출타격")); s.click_unit(_unit(s, "적A"))
	assert_eq(s.get_node("%PerformanceLayer").get_child_count(), 1)
	await wait_for_signal(_queue(s).drained, 2.0)
	assert_eq(s.get_node("%PerformanceLayer").get_child_count(), 0)
```
(`_perf_x(x_keys, length)` = `PerfBuild.build([[length*0.5,"hit",[]]], length, x_keys)` 을 PackedScene 으로)

- [ ] **Step 2: 실행 → FAIL**
- [ ] **Step 3: 구현** (`_start`):
  - 루트 `global_scale` = 행위자 그림 global_scale, `global_position` = 행위자 그림 global_position − `home_position()` × scale (→ Home 이 그림 자리에 옴)
  - 기준 대상 그림이 있으면 `set_stage(home_position(), perf.to_local(대상 그림 global_position))`, 없으면 `set_stage` 안 부름
  - `_on_done`: `actor_offset_from_home()` 길이가 0.5 미만이면 바로 `_finish`, 아니면 `return_time` 동안 Actor 원래 값이 Home 으로 가게 tween(`return_tween`) 후 `_finish` *(맵핑 상태에서 원래 값이 Home 이면 화면도 실제 Home)*
- [ ] **Step 4: 실행 → `tests/ui/` 전체 PASS** (히트스톱·넉백·줌 기존 테스트 포함)
- [ ] **Step 5: 커밋** `feat: performance queue places Home/Target on real sprites`

---

### Task 4: 전투 화면 월드 묶음 + 카메라 적용

**Files:**
- Modify: `Scenes/ui/battle_screen/battle_screen.tscn` — 새 Control `World`(`%World`, 전체 화면 앵커, `mouse_filter = IGNORE`)를 루트 첫 자식으로 만들고 `Background`, `AllyGrid`, `EnemyGrid`, `PerformanceLayer`, `FloatLayer` 를 그 안으로 (순서 유지). 나머지(UI)는 그대로. **에디터 끈 상태에서 헤드리스 스크립트로**
- Modify: `Scripts/ui/battle_screen.gd`
- Test: `tests/ui/test_battle_screen_performance.gd`

**Interfaces:**
- Consumes: `CardPerformance.has_camera`, `camera_xform`, `CameraMath.view`, `PerformanceQueue.current_performance`, `drained`
- Produces: `BattleScreen` `@onready var _world: Control = %World`; 연출 중 `_world` 의 position/rotation/scale = `CameraMath.view(시작 카메라, 지금 카메라)` 를 World 로컬로 옮긴 값; 연출이 끝나면 `default_return_time`(또는 연출의 `return_time`) 동안 단위로 tween

- [ ] **Step 1: 실패하는 테스트** (`_perf_cam(zoom_keys, length)` = `PerfBuild.build([[length*0.5,"hit",[]]], length, [], [], zoom_keys)` 를 PackedScene 으로)

```gdscript
func test_camera_zoom_scales_world_not_ui():
	var s := _screen(_data(45, null, _perf_cam([[0.0, Vector2.ONE], [0.1, Vector2(2,2)]], 0.4)))
	s.select_card(_index_of(s, "연출타격")); s.click_unit(_unit(s, "적A"))
	await wait_seconds(0.2)
	assert_almost_eq(s.get_node("%World").scale, Vector2(2,2), Vector2(0.05,0.05))
	assert_eq(s.get_node("%Hand").get_global_transform().get_scale(), Vector2.ONE)

func test_world_returns_after_performance():
	var s := _screen(_data(45, null, _perf_cam([[0.0, Vector2.ONE], [0.1, Vector2(2,2)]], 0.2)))
	s.select_card(_index_of(s, "연출타격")); s.click_unit(_unit(s, "적A"))
	await wait_for_signal(_queue(s).drained, 2.0)
	await wait_seconds(0.4)
	assert_almost_eq(s.get_node("%World").scale, Vector2.ONE, Vector2(0.01,0.01))

func test_no_camera_world_untouched():
	var s := _screen()
	s.select_card(_index_of(s, "연출타격")); s.click_unit(_unit(s, "적A"))
	await wait_seconds(0.15)
	assert_eq(s.get_node("%World").scale, Vector2.ONE)
	assert_eq(s.get_node("%World").position, Vector2.ZERO)
```

- [ ] **Step 2: 실행 → FAIL**
- [ ] **Step 3: 씬 구조 변경 (헤드리스 스크립트)** → 기존 `tests/ui/` 전체 다시 PASS 확인 (모든 노드가 `%이름` 으로 찾아서 경로 영향 없어야 함; `$ResultOverlay/Box` 는 UI 라 그대로)
- [ ] **Step 4: 구현.** `_process`: 지금 연출이 있고 `has_camera()` 면 첫 프레임 값을 `cam0` 으로 기억, `view` 를 연출 루트 → World 로컬 좌표로 바꿔(`perf 루트의 World 기준 변환 T`: `T * view * T⁻¹`) `_world` 에 position/rotation/scale 로 풀어 넣음 (`pivot_offset = 0`). 끝나면 단위로 tween. 줌 펀치·화면 흔들림은 루트(`self`)에 그대로
- [ ] **Step 5: 실행 → `tests/` 전체 PASS**
- [ ] **Step 6: 커밋** `feat: performance camera moves battle world`

---

### Task 5: 브람 돌주먹을 새 규약으로

**Files:**
- Modify: `Scenes/performances/bram_stone_fist.tscn` (**에디터 끈 상태에서 헤드리스 스크립트로** 다시 저장)
- Modify: `tests/performances/test_bram_stone_fist.gd`

**Interfaces:**
- Consumes: Task 2 규약

씬 내용 (설계 6장, 지금 타이밍 유지):
- `Home`(0,0), `Target`(Marker2D, (360,0)) + 자식 Sprite2D 미리보기 그림 (`bram_idle.png` 을 좌우 반전·반투명, offset (0,-200) — 적 그림이 생기면 교체), `Actor`(기존 그대로, `bram_frames.tres`, offset (0,-200)), `Camera`(Camera2D, enabled false, Home·Target 중간)
- `perform` 길이 0.7: `Actor:position:x` Bezier — 0.0 에 0, 0.15 에 Target.x − 120 (이전 `move(-120,0,0.15)` 과 같은 자리); `Actor:animation` 값 트랙 — 0 idle, 0.2 punch, 0.6 idle; `Camera:zoom` Bezier — 0 에 1, 0.3 에 1.15, 0.7 에 1; Call Method `.` — 0.3 `hit`, 0.3 `show_results`(별도 트랙)

- [ ] **Step 1: 테스트 교체**

```gdscript
func test_scene_follows_timeline_contract():
	var p: CardPerformance = load(SCENE).instantiate()
	add_child_autofree(p)
	for n in ["Home", "Target", "Actor", "Camera", "AnimationPlayer"]:
		assert_not_null(p.get_node_or_null(n), n)
	var anim: Animation = p.get_node("%AnimationPlayer").get_animation(&"perform")
	assert_ne(anim.find_track(NodePath("Actor:animation"), Animation.TYPE_VALUE), -1)
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_METHOD:
			for k in anim.track_get_key_count(t):
				assert_ne(anim.method_track_get_name(t, k), &"move")

func test_plays_hit_results_done_in_order():
	# 기존 테스트에서 "move" 제거 → ["hit", "results", "done"]
```
- [ ] **Step 2: 실행 → FAIL**
- [ ] **Step 3: 헤드리스 스크립트로 씬 다시 저장** (uid 유지: 기존 PackedScene 을 열어 노드 추가·애니메이션 교체 후 같은 경로로 `ResourceSaver.save`)
- [ ] **Step 4: 실행 → PASS.** 사용자에게 에디터에서 씬 열고 ▶ 로 이동·동작·카메라 범위가 보이는지 확인 요청
- [ ] **Step 5: 커밋** `feat: bram stone fist on timeline contract`

---

### Task 6: 연출 미리보기 씬

**Files:**
- Create: `Scripts/performances/performance_preview.gd`, `Scenes/performances/performance_preview.tscn` (루트 Control `PerformancePreview`; 자식 `BattleScreen` 인스턴스(`battle_data = battles/test_battle.tres`), 개발용 패널 `Panel`: OptionButton `%CardList`·`%ActorList`·`%TargetList`, Button `%PlayButton`, CheckBox `%LoopCheck`, OptionButton `%SpeedList`(0.25/0.5/1))
- Test: `tests/performances/test_performance_preview.gd`

**Interfaces:**
- Consumes: `BattleScreen.battle_data`, `restart()`, `session`, `select_card`, `click_unit`, `PerformanceQueue.drained`
- Produces (`PerformancePreview`):
  - `@export var card: CardData` — 정해 두면 F6 즉시 재생
  - `@export var cards_dir := "res://cards/data/"`
  - `static func performance_cards(dir: String) -> Array[CardData]` — 하위 폴더까지 `performance` 가 있는 카드 (이름순)
  - `func play_once() -> void` — 시험 전투 데이터를 복제해 행위자 유닛의 덱을 `[card]` 만으로, SP 충분·속도 최대로 바꾼 BattleData 로 `restart()`, 행위자 차례가 되면 `select_card(0)` + `click_unit(대상)`. `UnitData` 원본은 `duplicate()` 해서 바꿈 (원본 .tres 불변)
  - `signal preview_finished()` — 대기열이 비면. 반복이 켜져 있으면 다시 `play_once()`
  - `func set_speed(s: float) -> void` — 속도: `Engine.time_scale` 로 (개발용 씬이므로 허용 *(설계 5장 속도 — 이 씬에서만)*), 씬을 나갈 때 1 로 복구

- [ ] **Step 1: 실패하는 테스트**

```gdscript
func test_lists_only_cards_with_performance():
	var cs := PerformancePreview.performance_cards("res://cards/data/")
	assert_true(cs.any(func(c): return c.name_ko == "돌주먹"))
	assert_true(cs.all(func(c): return c.performance != null))

func test_play_once_runs_performance_and_finishes():
	var p: PerformancePreview = load("res://Scenes/performances/performance_preview.tscn").instantiate()
	p.card = load("res://cards/data/브람/돌주먹.tres")
	add_child_autofree(p)
	p.play_once()
	await wait_for_signal(p.preview_finished, 5.0)
	assert_signal_emitted(p, "preview_finished")

func test_source_unit_data_untouched():
	var bram: UnitData = load("res://entities/units/bram_welburn.tres")
	var deck_before := bram.deck.size()
	var p: PerformancePreview = load("res://Scenes/performances/performance_preview.tscn").instantiate()
	p.card = load("res://cards/data/브람/돌주먹.tres")
	add_child_autofree(p)
	p.play_once()
	assert_eq(bram.deck.size(), deck_before)

func test_time_scale_restored_on_exit():
	var p: PerformancePreview = load("res://Scenes/performances/performance_preview.tscn").instantiate()
	add_child(p)
	p.set_speed(0.25)
	p.free()
	assert_eq(Engine.time_scale, 1.0)
```
- [ ] **Step 2: 실행 → FAIL**
- [ ] **Step 3: 씬 만들기** (에디터 켜짐: MCP `scene-create`/`scene-node-add`, 인스턴스 추가는 헤드리스로) + 스크립트 구현 (`set_speed(s: float)` 공개)
- [ ] **Step 4: 실행 → `tests/` 전체 PASS.** 실제 F6 으로 돌주먹 반복 재생·속도 확인 (스크린샷/사용자 확인)
- [ ] **Step 5: 커밋** `feat: performance preview scene`

---

### Task 7: 문서

**Files:** `docs/progress.md`, `docs/superpowers/specs/2026-11-14-card-performance-design.md`(맨 위에 "5·6장은 2026-11-19 타임라인 설계로 대체" 한 줄), `docs/superpowers/specs/2026-11-19-performance-timeline-design.md`(상태: 구현됨)

- [ ] **Step 1:** progress.md 에 "연출 타임라인 (2026-11-19)" 줄: 새 규약 노드, 자리 맞추기, 카메라, 미리보기 씬 사용법(`performance_preview.tscn` 에서 F6, `card` 지정), 에디터 ▶ 로 안 보이는 것(hit·show_results·zoom 반응) 명시
- [ ] **Step 2: 커밋** `docs: performance timeline progress`
