# 스머지 효과 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 시험판 스머지(셰이더 + 드라이버)를 테스트·아틀라스 대응·끌어다 놓는 씬까지 갖춘 정식 기능으로 만든다.

**Architecture:** `SmearDriver`(@tool Node)가 부모 AnimatedSprite2D 의 이동을 재서 꼬리 벡터·짚는 수·지금 프레임 영역을 `smear.gdshader` 에 넣는다. 연출 씬은 `smear.tscn` 인스턴스를 Actor 아래에 둔다.

**Tech Stack:** Godot 4.7.2, GDScript, canvas_item 셰이더, GUT 9.7.1

**Spec:** `docs/superpowers/specs/2026-11-25-smear-effect-design.md`

## Global Constraints
- 기본값: `min_length` 1.0, `average` true, `front_amount` 0.2, `dither` 0, `length_ratio` 0.5, `max_length` 400, `decay_time` 0.12, `min_move` 20
- 위치는 그림 부모(연출 씬 루트) 좌표 — 카메라 이동에 반응하지 않음
- 에디터에서 편집 중인 씬 안에서는 돌지 않음 (material 이 씬에 저장되지 않게)
- 테스트 외 스크립트·셰이더는 한국어 주석 충실히 (CLAUDE.md)
- `.tscn` 손 작성 금지, 에디터 켜진 동안 바깥에서 `res://` `.tscn`/`.tres` 쓰기 금지. 테스트는 프로젝트 복사본에서 (CLAUDE.md "에디터 켜짐 중 작업 규칙")
- 테스트 실행: 복사본에서 `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

## Review Focus
- 아틀라스 그림(홍연 idle 8칸): 꼬리에 옆 프레임 그림이 섞이면 안 됨 → Task 1 `test_atlas_frame_region_sent`
- 부모에 이미 material 이 있는 Actor: 덮어쓰지 않고 경고 → Task 1 `test_keeps_existing_material`
- 좌우 반전(flip_h) Actor: 꼬리가 지나온 쪽으로 → Task 1 `test_flip_mirrors_trail`
- 연출 시작 때 자리 맞추기로 생기는 첫 이동: 꼬리 없음 → Task 1 `test_first_frame_ignored`
- 셰이더 문법 오류(시험판에서 `TEXTURE` 함수 인자): 그릴 때 엔진 에러 없음 → Task 2 `test_shader_compiles_when_drawn`

---

### Task 1: SmearDriver 동작 + 아틀라스 영역

**Files:**
- Modify: `Scripts/performances/smear_driver.gd`
- Test: `tests/performances/test_smear_driver.gd`

**Interfaces:**
- Produces: `SmearDriver.step(delta: float) -> void` (한 프레임 진행, `_process` 가 부름), `SmearDriver.trail() -> Vector2` (지금 꼬리, 부모 좌표 px), 셰이더 uniform 이름 `smear`(vec2, 그림 px), `samples`(int), `pad`(float), `region`(vec4 = 정규화 x, y, w, h)
- `static func frame_region(tex: Texture2D) -> Vector4` — AtlasTexture 면 region / atlas 크기, 아니면 (0, 0, 1, 1)

- [ ] **Step 1: 실패하는 테스트 작성** — 부모 AnimatedSprite2D(scale 0.2, 100×100 프레임)에 SmearDriver 를 붙여 트리에 넣고, position 을 바꾼 뒤 `step(1/60)` 호출:
  - `test_small_move_no_trail`: 19px 이동 → `trail() == Vector2.ZERO`
  - `test_trail_is_move_times_ratio`: (첫 step 뒤) +300px x 이동 → `trail() ≈ Vector2(-150, 0)`, 셰이더 `smear ≈ Vector2(-750, 0)`
  - `test_trail_capped`: +1000px → `trail().length() ≈ 400`
  - `test_trail_gone_after_decay`: 꼬리 생긴 뒤 이동 없이 `step(0.13)` → `Vector2.ZERO`
  - `test_first_frame_ignored`: 붙인 직후 첫 `step` 에서 500px 이동 → 꼬리 없음
  - `test_flip_mirrors_trail`: `flip_h = true`, +300px → 셰이더 `smear.x > 0`
  - `test_keeps_existing_material`: 부모에 CanvasItemMaterial 이 있으면 그대로, `step` 해도 에러 없음
  - `test_atlas_frame_region_sent`: 512×128 아틀라스의 (128,0,128,128) AtlasTexture 프레임 → 셰이더 `region ≈ Vector4(0.25, 0, 0.25, 1)`; 일반 텍스처 → `Vector4(0, 0, 1, 1)`
- [ ] **Step 2: 복사본에서 실행해 실패 확인** (`-gtest=res://tests/performances/test_smear_driver.gd`) — `step`/`trail` 없음으로 FAIL
- [ ] **Step 3: 구현** — `_process` 본문을 `step(delta)` 로 옮기고, 지금 프레임 텍스처(`sprite_frames.get_frame_texture(animation, frame)`)로 `region` 을 매 step 넣음. 부모 material 이 이미 있으면 `push_warning` 후 아무것도 안 함. 기본값은 Global Constraints
- [ ] **Step 4: 실행해 통과 확인**
- [ ] **Step 5: 커밋** — `feat: smear driver tested, atlas frame region`

### Task 2: 셰이더 — 프레임 영역 + 기본값 확정

**Files:**
- Modify: `Scripts/performances/smear.gdshader`
- Test: `tests/performances/test_smear_driver.gd` (같은 파일에 추가)

**Interfaces:**
- Consumes: Task 1 의 uniform `region`

- [ ] **Step 1: 실패하는 테스트** — `test_shader_compiles_when_drawn`: Task 1 셋업으로 그림을 트리에 넣고 `await wait_frames(2)` → GUT 가 엔진 에러 없음으로 통과해야 함. `test_shader_has_region_uniform`: `SmearDriver.SMEAR_SHADER.get_shader_uniform_list()` 이름에 `region` 포함
- [ ] **Step 2: 실패 확인** (`region` 없음)
- [ ] **Step 3: 구현** — `uniform vec4 region = vec4(0, 0, 1, 1)`; `inside(uv)` 를 region 사각형 기준으로. 나머지 기본값은 Global Constraints 그대로 (이미 반영됨, 확인만)
- [ ] **Step 4: 통과 확인 + 전체 테스트** (기존 실패 `test_slowmo_ends_by_itself` 외 새 실패 없음)
- [ ] **Step 5: 커밋** — `feat: smear shader reads only the current frame region`

### Task 3: 끌어다 놓는 씬 + 돌주먹에 연결

**Files:**
- Create: `Scenes/performances/smear.tscn` (루트 `Smear`: Node + `smear_driver.gd`) — 에디터 MCP `scene-create` 로
- Modify: `Scenes/performances/bram_stone_fist.tscn` — 시험판 `Actor/Smear` 노드를 지우고 `smear.tscn` 인스턴스로, Actor `offset` (0, -681) — **사용자가 에디터에서** (MCP 는 한 씬 여러 번 고치면 앞 변경이 되돌아가고, 인스턴스 있는 씬을 망가뜨림)
- Modify: `docs/progress.md` (완료된 기능 표에 한 줄), `CLAUDE.md` 없음
- Test: `tests/performances/test_bram_stone_fist.gd`

- [ ] **Step 1: 실패하는 테스트** — `test_actor_has_smear`: 돌주먹 씬의 `Actor/Smear` 가 `SmearDriver` 이고 `scene_file_path == "res://Scenes/performances/smear.tscn"`
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: `smear.tscn` 만들기 (MCP), 사용자에게 돌주먹 씬 교체·offset 안내 후 저장 확인 (`git diff` 로)**
- [ ] **Step 4: 전체 테스트 + 복사본 캡처로 꼬리 확인** (시험판 `capture_smear.gd` 방식)
- [ ] **Step 5: progress.md 갱신, 커밋** — `feat: smear effect on Bram's stone fist`
