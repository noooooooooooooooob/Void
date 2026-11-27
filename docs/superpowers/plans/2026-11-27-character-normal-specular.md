# 캐릭터 노말맵·스페큘러 (홍연 idle) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 홍연 idle 8프레임이 노말·스페큘러 맵을 가지고 재생되고, 배경의 시험 조명이 캐릭터만 비춘다.

**Architecture:** 시트 3장(색·노말·스페큘러)을 `CanvasTexture` 하나로 묶고, 기존 `hongyeon_frames.tres` 의 AtlasTexture 8개의 atlas 를 그것으로 바꾼다. 캐릭터 그림은 light_mask 2번 층, 조명은 2번 층만 비춘다. 코드 변경 없음.

**Tech Stack:** Godot 4.7.2, GUT 9.7.1, Aseprite MCP(내보내기), Godot AI MCP(에디터 편집)

**Spec:** `docs/superpowers/specs/2026-11-27-character-normal-specular-design.md`

## Global Constraints
- 에디터가 켜져 있으면 `res://` 의 `.tscn`/`.tres` 는 Godot AI MCP 로만 만든다·고친다 (바깥 쓰기 금지)
- 테스트는 프로젝트 복사본에서 실행 (godot_ai 플러그인·`_mcp_game_helper` autoload 끄고, `--log-file` 따로)
- `hongyeon_frames.tres` uid `uid://clsjvjhaikvkc` 유지, AtlasTexture region 8개 그대로 (x = 0,128,…,896, 128×128)
- 그림 파일 이름 snake_case, `Art/characters/hongyeon/` 에

## Review Focus
- 애니메이션이 멈추지 않는다 (포럼에 노말맵 넣으면 멈춘 사례) → Task 3 실행 확인에서 8프레임 재생 확인
- 픽셀이 흐려지지 않는다 (Nearest 필터 유지) → Task 3 스크린샷 확대 확인
- UI·혈갑 이펙트가 빛을 받지 않는다 → Task 3: 조명 세기를 크게 올려 카드·패널 색 그대로인지 확인
- 노말 위아래가 뒤집히지 않는다 → Task 3: 조명을 캐릭터 위에 두면 머리 윗면이 밝아야 함
- 다른 캐릭터(브램 등)는 지금 그대로 보인다 → Task 3 스크린샷

---

### Task 1: 맵 내보내기

**Files:**
- Create: `Art/characters/hongyeon/hongyeon_idle_normal.png`, `Art/characters/hongyeon/hongyeon_idle_specular.png` (각 1024×128, 프레임 n 이 x=(n-1)*128)

- [ ] **Step 1:** Aseprite `hongyeon_idle.aseprite` 에서 `Normal`, `Specular` 레이어만 각각 가로 시트로 내보낸다 (패딩·트림 없음, 1배)
- [ ] **Step 2:** 두 파일이 1024×128 RGBA 인지, 1프레임 영역이 비어 있지 않은지 확인 (`file`, 미리보기)
- [ ] **Step 3:** 에디터가 새 png 를 가져오게 한다 (filesystem 스캔). 가져오기 설정은 `hongyeon_idle.png` 와 같게 (Lossless, 밉맵 없음)

### Task 2: CanvasTexture + SpriteFrames 연결

**Files:**
- Create: `Art/characters/hongyeon/hongyeon_idle_canvas.tres` (CanvasTexture: diffuse_texture = hongyeon_idle.png, normal_texture = _normal.png, specular_texture = _specular.png)
- Modify: `entities/units/hongyeon_frames.tres` (AtlasTexture 8개의 atlas → 위 CanvasTexture)
- Test: `tests/data/test_hongyeon_lit_frames.gd`

**Interfaces:**
- Consumes: Task 1 의 png 두 장
- Produces: 노말·스페큘러가 들어간 `hongyeon_frames.tres` (idle 8프레임)

- [ ] **Step 1: 실패하는 테스트** — `test_idle_frames_use_lit_canvas_texture`: frames 를 load, `idle` 프레임 수 == 8, 각 프레임 텍스처가 `AtlasTexture`, region == `Rect2(i*128, 0, 128, 128)`, atlas 가 `CanvasTexture` 이고 diffuse·normal·specular 가 모두 null 아님, normal 의 경로가 `hongyeon_idle_normal.png` 로 끝남
- [ ] **Step 2:** 복사본에서 GUT 실행 → atlas 가 CanvasTexture 아님으로 FAIL
- [ ] **Step 3:** Godot AI MCP 로 CanvasTexture 리소스를 만들고 frames 의 AtlasTexture atlas 8개를 바꿔 저장
- [ ] **Step 4:** 복사본 다시 동기화 후 GUT 전체 실행 → 새 테스트 PASS, 기존 테스트 회귀 없음
- [ ] **Step 5: Commit** — png 2장(+.import), canvas .tres, frames .tres, 테스트

### Task 3: 캐릭터만 비추는 시험 조명 + 실행 확인

**Files:**
- Modify: `Scenes/ui/battle_screen/unit_token.tscn` — `Sprite` 의 `light_mask` = 1|2 (값 3). EffectBehind/EffectFront 는 1 그대로
- Modify: `Scenes/backgrounds/mountain_shrine.tscn` — `PointLight2D` 노드 `CharacterLight` 추가: `range_item_cull_mask` = 2, 텍스처는 Godot 기본 GradientTexture2D(원형, fill radial), 위치는 아군 격자 위쪽, `height` 는 에디터에서 조정
- Modify: `docs/progress.md`

- [ ] **Step 1:** MCP 로 두 씬 편집·저장
- [ ] **Step 2:** F6 시험 전투(`battles/test_battle.tres` 배경이 mountain_shrine 인지 확인, 아니면 boss/의뢰 전투로) 실행, 스크린샷: 홍연 idle 재생, 조명 쪽 면 밝아짐, 머리 윗면이 위쪽 조명에 밝음(노말 방향), 픽셀 선명, UI·이펙트·다른 유닛 그대로. 노말이 뒤집혀 있으면 Task 1 에서 G 채널 뒤집어 다시 내보내기
- [ ] **Step 3:** 조명 세기·높이·스페큘러 광택을 보면서 맞추고 저장
- [ ] **Step 4:** `docs/progress.md` 에 항목 추가, Commit
