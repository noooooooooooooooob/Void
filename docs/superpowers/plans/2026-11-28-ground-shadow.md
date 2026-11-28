# 바닥 그림자 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 전투 유닛(과 나중에 정지 그림 물체)에 해·달 위치를 따라 자동으로 기우는 바닥 그림자를 붙이고, 진하기·길이 등은 BattleMood 인스펙터에서 조절한다.

**Architecture:** 그림자 부품 `GroundShadow`(Sprite2D)를 대상 그림의 자식으로 두고, 매 프레임 대상의 지금 텍스처를 복사해 Transform2D 로 바닥에 눕혀 기울인다. 값과 해·달 위치는 그룹 `battle_mood` 의 BattleMood 에서 읽는다(없으면 기본값·해 없음). 연출 Actor 에는 연출 큐가 같은 부품을 instantiate 해서 붙인다.

**Tech Stack:** Godot 4.7.2, GDScript, canvas_item 셰이더, GUT 9.7.1

**Spec:** `docs/superpowers/specs/2026-11-28-ground-shadow-design.md`

## Global Constraints

- 스크립트는 `Scripts/backgrounds/`, 씬은 `Scenes/backgrounds/parts/`. 한국어 주석(클래스 `##`, export·공개 함수 `##`, 기획 규칙 한 줄)
- 노드는 씬에. 스크립트에서 `new()`/`add_child()` 로 노드 조립 금지 — 연출 Actor 에 붙이는 그림자는 `ground_shadow.tscn` 을 instantiate (부품 씬이라 허용)
- 에디터가 켜져 있으면 `.tscn` 수정은 Godot AI MCP 로 (`unit_token.tscn`·`battle_mood.tscn`·`ground_shadow.tscn` 생성 포함). 스크립트(.gd)·셰이더·테스트는 파일로 써도 됨
- 테스트는 복사본 `../Void_testcopy` 에 동기화 후 실행 (godot_ai 플러그인·`_mcp_game_helper` 끔, `--log-file` 따로):
  `Godot_v4.7.2-stable_win64_console.exe --headless --path ../Void_testcopy -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- 그림자는 빛을 안 받음 (`light_mask = 0`), 대상 뒤에 그림 (`show_behind_parent = true`)
- 상태 이펙트(EffectBehind/Front)는 그림자에 안 넣음

## Review Focus

1. 대상이 숨겨지면(연출 중 원래 그림) 그림자도 안 보여야 함 — 자식이라 자동이지만, 연출 Actor 에 붙은 그림자가 연출이 끝나면 같이 사라지는지 (Task 3 테스트)
2. 대상의 `sprite_frames` 가 null 이거나 animation 이 없는 프레임(유닛 그림 없음) → 그림자 텍스처 null, 오류 없음 (Task 1 테스트)
3. 전투 화면에 BattleMood 가 없는 배경 → 기본값으로 발밑 짧은 그림자, 오류 없음 (Task 1 테스트)
4. 해·달이 숨겨져 있음(visible=false) → 해 없음으로 취급 (Task 2 테스트)
5. 대상이 flip_h(적 유닛) → 그림자 그림도 뒤집힘 (Task 1 테스트)

---

### Task 1: GroundShadow 부품 (기본값으로 동작)

**Files:**
- Create: `Scripts/backgrounds/ground_shadow.gd`, `Scenes/backgrounds/parts/ground_shadow.gdshader`, `Scenes/backgrounds/parts/ground_shadow.tscn` (MCP: 루트 Sprite2D + 스크립트 + ShaderMaterial, light_mask 0, show_behind_parent true)
- Test: `tests/backgrounds/test_ground_shadow.gd`

**Interfaces:**
- Produces:
  - `class_name GroundShadow extends Sprite2D` (`@tool`), 그룹 `mood_shadow`
  - `const NO_MOOD_COLOR := Color(0, 0, 0, 0.5)`, `const NO_MOOD_LENGTH := 0.2`, `const NO_MOOD_FADE := 0.6`
  - `static func shadow_basis(foot: Vector2, source: Variant, length: float, tilt: float) -> Transform2D` — source 는 해·달 전역 위치(Vector2) 또는 null. d = source 있으면 `(foot - source).normalized()` 후 `d.y *= tilt`, 없으면 `Vector2(0, 1)`. 반환 = `Transform2D(Vector2(1, 0), -length * d, Vector2.ZERO)` (그림 안 높이 h 인 점이 발밑에서 h × length × d 로 감)
  - `func sync_from_target() -> void` — 부모(AnimatedSprite2D 또는 Sprite2D)의 지금 텍스처·`offset`·`centered`·`flip_h`·`flip_v` 를 복사. AnimatedSprite2D 는 `sprite_frames.get_frame_texture(animation, frame)` (sprite_frames null 이거나 animation 없으면 texture = null). Sprite2D 는 `texture`·`region_enabled`·`region_rect`·`hframes`·`vframes`·`frame`
  - 셰이더 uniform `shadow_color: vec4`, `fade: float`(0~1, 끝으로 갈수록 이만큼 옅어짐), instance uniform `foot_y: float`(=0), `top_y: float`(그림 맨 위의 대상 기준 y). 알파 = `shadow_color.a * tex.a * (1 - fade * t)`, t = 발에서 맨 위까지 0→1, rgb = shadow_color.rgb
  - `_process` 에서 매 프레임: `sync_from_target()` → BattleMood 값 읽기(Task 2 전엔 NO_MOOD_*) → `transform = shadow_basis(...)` → 셰이더 값

- [ ] **Step 1: 실패하는 테스트 작성** (`tests/backgrounds/test_ground_shadow.gd`)
  - `test_basis_no_source`: `shadow_basis(Vector2(500, 800), null, 0.2, 0.5)` → `x == Vector2(1,0)`, `y == Vector2(0, -0.2)`
  - `test_basis_sun_behind_right`: foot (500,800), source (1500,300), length 1.0, tilt 0.5 → d0=(-1000,500).normalized()=(-0.894,0.447), d=(-0.894,0.224) → `y ≈ Vector2(0.894, -0.224)` (±0.01). 그림 위쪽 점 `xform(Vector2(0,-100))` 의 x < 0, y > 0 (왼쪽 앞으로)
  - `test_copies_animated_frame`: AnimatedSprite2D(시험 SpriteFrames 2칸, 서로 다른 ImageTexture) 자식으로 부품 instantiate, `frame = 1` 후 `sync_from_target()` → `texture == frames.get_frame_texture(anim, 1)`, `offset`·`flip_h` 같음
  - `test_copies_sprite2d`: Sprite2D 부모 → texture·flip_h 복사
  - `test_null_frames_no_error`: sprite_frames null 인 AnimatedSprite2D → `texture == null`
  - `test_no_mood_defaults`: 트리에 BattleMood 없음, 한 프레임 진행 → `transform.y == Vector2(0, -GroundShadow.NO_MOOD_LENGTH)`, `light_mask == 0`, `show_behind_parent`

- [ ] **Step 2: 복사본에서 실행, 실패 확인** — Expected: `GroundShadow` 없음으로 FAIL
- [ ] **Step 3: 스크립트·셰이더 작성, MCP 로 `ground_shadow.tscn` 생성**
- [ ] **Step 4: 복사본에서 실행, 통과 확인** — Expected: 새 테스트 PASS, 기존 테스트 전부 PASS
- [ ] **Step 5: 커밋** `feat: ground shadow part copies its target and lies on the floor`

### Task 2: BattleMood 그림자 슬라이더 + 해·달 방향

**Files:**
- Modify: `Scripts/backgrounds/battle_mood.gd` (export 그룹 "그림자", 그룹 `battle_mood` 등록, 보이는 해·달 찾기를 공개 함수로)
- Modify: `Scripts/backgrounds/ground_shadow.gd` (BattleMood 값 읽기)
- Test: `tests/backgrounds/test_ground_shadow.gd`, `tests/backgrounds/test_battle_mood.gd`

**Interfaces:**
- Consumes: Task 1 `GroundShadow.shadow_basis`
- Produces (BattleMood):
  - `@export_group("그림자")`: `shadow_color := Color(0, 0, 0, 0.55)`, `@export_range(0, 3, 0.05) shadow_length := 1.2`, `@export_range(0, 1, 0.01) shadow_fade := 0.7`, `@export_range(0.1, 1, 0.01) shadow_tilt := 0.5`, `@export_range(0, 1, 0.01) shadow_no_sun_length := 0.2`
  - `const GROUP := &"battle_mood"` — `_enter_tree` 에서 `add_to_group(GROUP)`
  - `func sky_body() -> SkyBody` — 부모 아래 보이는 해·달 중 트리 순서 첫 번째, 없으면 null. `_apply_rays` 도 이것을 쓰게 바꿈 (동작 그대로)
- GroundShadow: 매 프레임 `get_tree().get_first_node_in_group(BattleMood.GROUP)` (캐시, 무효면 다시 찾음). 있으면 source = `sky_body().global_position` 또는 null(해 없음이면 length = `shadow_no_sun_length`), 색·길이·흐림·기울기 = 위 값. 발밑 = 부모의 `global_position`

- [ ] **Step 1: 실패하는 테스트 작성**
  - `test_battle_mood.gd::test_shadow_defaults_and_group`: battle_mood.tscn instantiate → 그룹 `battle_mood`, 위 기본값 5개
  - `test_battle_mood.gd::test_sky_body_skips_hidden`: 부모 Node2D 아래 BattleMood + sun 둘(첫째 visible=false) → `sky_body()` == 둘째; 둘 다 숨김 → null
  - `test_ground_shadow.gd::test_follows_sun`: 부모 아래 BattleMood + sun(1500,300), 그 옆 AnimatedSprite2D(global_position (500,800), 배율 1) + 자식 그림자 → 한 프레임 뒤 `transform.y ≈ shadow_basis(Vector2(500,800), Vector2(1500,300), 1.2, 0.5).y`, 셰이더 `shadow_color == Color(0,0,0,0.55)`
  - `test_ground_shadow.gd::test_hidden_sun_short_shadow`: 해 visible=false → `transform.y == Vector2(0, -0.2)`
  - `test_ground_shadow.gd::test_mood_values_follow`: `mood.shadow_length = 2.0` 한 프레임 뒤 반영
- [ ] **Step 2: 복사본에서 실행, 실패 확인**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 복사본에서 실행, 전부 통과 확인** (기존 빛줄기 테스트 포함)
- [ ] **Step 5: 커밋** `feat: shadows point away from the sun, tuned from BattleMood`

### Task 3: 유닛·연출 Actor 에 붙이기

**Files:**
- Modify: `Scenes/ui/battle_screen/unit_token.tscn` (MCP: `Sprite` 아래 `Shadow` = ground_shadow.tscn 인스턴스, EffectBehind 보다 앞 순서)
- Modify: `Scripts/ui/performance_queue.gd` (`_start` 에서 `%Actor` 아래 그림자 instantiate·add_child — 연출 씬이 지워질 때 같이 지워짐)
- Test: `tests/ui/test_battle_screen_performance.gd`, `tests/backgrounds/test_ground_shadow.gd`

**Interfaces:**
- Consumes: Task 1 `ground_shadow.tscn`, `GroundShadow`
- Produces: `performance_queue.gd` 에 `const SHADOW_SCENE := preload("res://Scenes/backgrounds/parts/ground_shadow.tscn")`. 연출 씬에 이미 GroundShadow 가 있으면 안 붙임

- [ ] **Step 1: 실패하는 테스트 작성**
  - `test_ground_shadow.gd::test_unit_token_has_shadow`: unit_token.tscn instantiate → `%Sprite` 의 자식 중 GroundShadow 하나
  - `test_battle_screen_performance.gd::test_actor_gets_shadow`: 연출 재생 중 `%Actor` 자식에 GroundShadow 하나 (기존 테스트의 연출 띄우는 방법 그대로)
- [ ] **Step 2: 복사본에서 실행, 실패 확인**
- [ ] **Step 3: MCP 로 unit_token.tscn 에 Shadow 추가·저장, performance_queue.gd 수정**
- [ ] **Step 4: 복사본에서 실행, 전부 통과 확인**
- [ ] **Step 5: 커밋** `feat: units and performance actors cast ground shadows`

### Task 4: 신사 정원에서 맞추기 + 기록

**Files:**
- Modify: `Scenes/backgrounds/shrine_garden.tscn` (MCP: BattleMood 그림자 값만 — 기본값이 맞으면 안 바꿈)
- Modify: `docs/progress.md`, `docs/superpowers/plans/2026-11-27-battle-mood-next-handoff.md` (C 완료 표시)

- [ ] **Step 1: 시험 전투(`battle_screen.tscn`)를 MCP 로 실행·스크린샷** — 확인: 유닛마다 해(오른쪽 뒤) 반대쪽 왼쪽 앞으로 비스듬한 그림자, 발에 붙어 있음, 끝이 옅어짐, idle 에 따라 모양이 바뀜, 적(뒤집힌 그림)도 맞음, 카드 연출(브람 돌주먹) 중 Actor 그림자
- [ ] **Step 2: 레퍼런스 프레임 9 느낌이 되게 BattleMood 그림자 값 조정, 다시 스크린샷** — 사용자에게 화면 보고하고 값 확인받음
- [ ] **Step 3: progress.md 에 한 줄(무엇·값·위치), handoff 의 C 에 완료 표시**
- [ ] **Step 4: 커밋** `tweak: shrine garden shadow values; progress`
