# 연출 화면 창 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 에디터 하단 "연출 화면" 탭에서, 연출 씬의 지금 프레임을 실제 전투 화면(배경·격자·아군·적 하나·늘린 위치·카메라 구도)으로 보여 준다.

**Architecture:** 배치·카메라 식을 공용 정적 함수(`PerformanceSpace`, `CameraMath`, `@tool`)로 빼서 실제 게임(`PerformanceQueue`, `BattleScreen`)과 창(`StageView`)이 같이 쓴다. 창은 `@tool` Control 로 SubViewport 에 무대를 깔고, 편집 중인 연출 씬을 복제해 매 에디터 프레임 상태를 옮긴 뒤 같은 식으로 배치한다. 에디터 플러그인은 하단 패널에 창을 붙이고 편집 씬을 넘기기만 한다.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1

**Spec:** `docs/superpowers/specs/2026-11-19-performance-stage-view-design.md`

## Global Constraints
- 플러그인 파일은 `addons/performance_stage_view/` (plugin.cfg, plugin.gd, stage_view.gd, stage_view.tscn). 공용 계산은 `Scripts/performances/`. 한국어 주석 규칙 동일
- 씬은 손으로 쓰지 않는다: **에디터를 끈 상태에서** 헤드리스(`--headless --editor`, 원래 PackedScene 에 pack) 스크립트로. **쓰기 직전에 `tasklist | grep -i godot` 을 따로 실행하고, 결과가 있으면 멈추고 사용자에게 에디터를 꺼 달라고 요청**
- 반복 생성(유닛 그림)은 씬 안 숨긴 틀 `%UnitTemplate` 을 `duplicate()`
- 테스트는 복사본(`.superpowers/sdd/2026-11-19-performance-timeline/t.sh`)
- 창에 까는 것: 시험 전투 아군 전원 + **첫 적 하나**(대상). 대상 고르기 없음
- 커밋 안 함 (사용자 요청 시만)

## Review Focus
- 연출 씬이 아닌 씬을 열었을 때 창이 아무것도 안 하고 에러 없음 (Task 2 테스트)
- 편집 씬에 노드를 추가/삭제한 뒤에도 복제가 다시 맞춰짐 (Task 2 테스트)
- 카메라 트랙이 없는 연출 → World 단위 변환 (Task 2 테스트)
- 행위자 = 대상이 같은 경우는 없음(아군·적) — 대신 Target 노드가 없는 연출 → Home 기준 그대로 (Task 2 테스트)
- 실제 게임과 창의 배치가 같은 식 — 리팩터 후 기존 연출 테스트 전부 통과 (Task 1)

---

### Task 1: 공용 배치·카메라 식

**Files:** Modify `Scripts/performances/performance_space.gd`, `Scripts/performances/camera_math.gd` (둘 다 `@tool` 추가), `Scripts/ui/performance_queue.gd`, `Scripts/ui/battle_screen.gd`; Test `tests/performances/test_performance_space.gd`, `tests/performances/test_camera_math.gd`

**Interfaces (Produces):**
- `PerformanceSpace.root_scale(sprite_scale: Vector2, actor_scale: Vector2) -> Vector2` — 성분별 나눗셈, actor_scale 0 성분은 1
- `PerformanceSpace.root_position(sprite_pos: Vector2, home: Vector2, root_scale: Vector2) -> Vector2` = `sprite_pos - home * root_scale`
- `CameraMath.world_xform(t: Transform2D, cam0: Transform2D, cam: Transform2D) -> Transform2D` = `t * view(cam0, cam) * t.affine_inverse()`

- [ ] 테스트: `root_scale(Vector2(0.2,0.2), Vector2(0.2,0.2)) == Vector2.ONE`, `root_scale(Vector2(0.2,0.2), Vector2.ZERO) == Vector2(0.2,0.2)`, `root_position(Vector2(100,50), Vector2(10,0), Vector2(2,2)) == Vector2(80,50)`, `world_xform(T(이동 (100,0)), k, k)` 단위, `world_xform(T, k0, zoom2)` 의 배율 2·카메라 점 고정
- [ ] FAIL 확인 → 구현 → PASS
- [ ] `PerformanceQueue._start`·`BattleScreen._update_camera` 가 이 함수들을 쓰도록 바꿈 (동작 같음) → 전체 PASS

### Task 2: 창 `StageView` (+ 씬)

**Files:** Create `addons/performance_stage_view/stage_view.gd` (`@tool`, `class_name PerformanceStageView extends Control`), `addons/performance_stage_view/stage_view.tscn`; Test `tests/performances/test_performance_stage_view.gd`

씬 노드: 루트 `PerformanceStageView`(VBox 처럼 위 줄 + 화면) → `Top`(HBox: Label "행위자", `%ActorList` OptionButton, `%Hint` Label) / `Screen`(SubViewportContainer, stretch, 세로 확장) → `Viewport`(SubViewport 1920×1080, transparent_bg 끔) → `%World`(Control 전체 크기) → `%Background`(Control), `%Units`(Control, 자식 `%UnitTemplate` AnimatedSprite2D 숨김, scale 0.2·offset (0,-200)), `%PerfLayer`(Node2D)

**Interfaces (Produces):**
- `set_battle(data: BattleData) -> void` — 배경·칸·유닛 그림 (아군 전원 + 첫 적). 행위자 목록 채움
- `set_source(perf: Node) -> void` — 편집 중 연출 루트(없거나 CardPerformance 가 아니면 비우고 `%Hint` 에 안내). 복제본 만들고 AnimationPlayer 삭제
- `sync() -> void` — 상태 옮기기 → 배치(`root_scale`·`root_position`·`map_point`) → 행위자 그림·Target 자식 숨김 → 카메라(`world_xform`)
- `set_actor(index: int) -> void`
- `static func default_actor(data: BattleData, perf_path: String, cards_dir: String) -> int`
- `static func camera_pose_at(anim: Animation, cam: Node2D, time: float) -> Transform2D` — `Camera:` 트랙들(position, position:x/y, zoom, zoom:x/y, rotation; value·bezier)을 time 으로 계산, 없는 건 노드 값
- 읽기용: `unit_sprite(index_in_battle: int) -> Node2D` 대신 `ally_sprite(i: int)`, `enemy_sprite() -> Node2D`, `mirror() -> Node2D`, `world() -> Control`

- [ ] 테스트 (헤드리스, 에디터 없이; `_view()` = 씬 instantiate + add_child_autofree + `set_battle(load(test_battle))`):
  - `test_lays_allies_and_one_enemy`: `%Units` 보이는 자식 수 == 아군 수 + 1
  - `test_default_actor_is_card_owner`: 돌주먹 씬이면 브람 index
  - `test_actor_on_home_sits_on_actor_sprite`: 돌주먹 씬 instance 를 source 로, `sync()` 후 `mirror()` 의 Actor global_position ≈ 행위자 그림 global_position, 행위자 그림 숨김
  - `test_actor_on_target_sits_on_enemy`: source Actor.position = Target.position → sync → ≈ `enemy_sprite()` 위치
  - `test_target_preview_hidden_in_mirror`
  - `test_camera_zoom_moves_world`: source Camera.zoom = (2,2) (0초 값은 1) → sync → `world().scale` ≈ 2, 카메라 점 고정
  - `test_no_camera_world_identity`: Camera 없는 조립 연출(`PerfBuild.build`) → World 단위
  - `test_non_performance_source_shows_hint`: `set_source(Node2D.new())` → 에러 없이 `%Hint` 보임, 복제 없음
  - `test_rebuilds_mirror_when_source_changes`: source 에 Sprite2D 자식 추가 → sync → mirror 에도 같은 이름 노드
  - `test_camera_pose_at_zero_reads_track`: 돌주먹 perform 의 0초 zoom == 1
- [ ] FAIL → 씬 만들기(에디터 꺼짐 확인 후 헤드리스) → 구현 → PASS → 전체 PASS

### Task 3: 플러그인 + 문서

**Files:** Create `addons/performance_stage_view/plugin.cfg`, `plugin.gd`; Modify `project.godot` 의 `editor_plugins/enabled`(에디터 꺼진 상태에서 헤드리스로 `ProjectSettings` 저장 — 손으로 쓰지 않음), `docs/progress.md`, `CLAUDE.md` 의 MCP/플러그인 줄 없음(손대지 않음), 설계 상태
- `plugin.gd`: `_enter_tree` 에 `add_control_to_bottom_panel(view, "연출 화면")`, `scene_changed` → `view.set_source(root)`, `_process` 에서 패널이 보일 때만 `view.sync()`, `_exit_tree` 정리. 처음 한 번 `view.set_battle(load("res://battles/test_battle.tres"))`
- [ ] 수동 확인: 사용자에게 에디터를 켜서 돌주먹 씬 → 하단 "연출 화면" 탭 → 막대 끌기 요청
- [ ] progress.md 줄 추가, 설계 상태 "구현됨"
