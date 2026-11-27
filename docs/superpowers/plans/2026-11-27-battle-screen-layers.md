# 전투 화면 층 나누기 (전투 무드 1단계) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 전투 화면을 CanvasLayer 로 나눈다. 월드(0층)만 나중에 어둠·조명·화면 효과를 받고, UI 는 받지 않게 한다. 보이는 모습과 동작은 지금과 똑같아야 한다.

**Architecture:** `battle_screen.tscn` 루트 아래에 CanvasLayer 세 개(UiLayer 2, FrontLayer 3, OverlayLayer 4)를 만든다. 지금 그리기 순서 그대로 노드를 옮긴다. 노드 이름과 `%` 고유 이름은 유지하고, `$`로 잡던 경로 하나만 `%`로 바꾼다. 연출 미리보기 씬의 Panel 은 CanvasLayer 10 으로 올린다.

**Tech Stack:** Godot 4.7.2, GUT 9.7.1, Godot AI MCP

**Spec:** `docs/superpowers/specs/2026-11-27-battle-mood-design.md` (1단계)

## Global Constraints
- 에디터가 켜져 있으면 `.tscn` 은 Godot AI MCP 로만 고친다 (바깥 쓰기 금지)
- 테스트는 복사본 `Void_testcopy` 에서 실행한다 (godot_ai 플러그인·`_mcp_game_helper` 끄고, `--log-file` 따로)
- 그리기 순서 유지: World < (1층 비움) < UiLayer < FrontLayer < OverlayLayer
- 노드 이름·`unique_name_in_owner`·uid 유지
- 스크립트를 고치면 한국어 주석 유지·추가

## Review Focus
- 마우스 입력: 카드 드래그, 버튼, 가방 드래그, 유닛 클릭이 지금처럼 된다 → 기존 GUT 전체 통과 + 실행 확인
- 조준 화살표가 카드에서 유닛으로 정확히 이어진다 (TargetArrow 는 `top_level`, 4층) → 실행 스크린샷
- 연출 카메라 확대·복귀 (`%World`·`%WorldFront` 변환) → 기존 `test_battle_screen_performance` 통과
- 결과 창·보상 목록·← 사무소로 버튼이 맨 위에 보이고 눌린다 → 기존 `test_battle_screen_stage` 통과 (경로는 `%ResultOverlay/Box` 로 바꿈)
- 연출 미리보기 씬의 Panel 이 전투 화면 위에 보인다 → 실행 스크린샷

---

### Task 1: 전투 화면 층 나누기

**Files:**
- Modify: `Scenes/ui/battle_screen/battle_screen.tscn`
- Modify: `Scripts/ui/battle_screen.gd:157` (`$ResultOverlay/Box` → `%ResultOverlay/Box`)
- Modify: `tests/ui/test_battle_screen_stage.gd:340,344,392` (`"ResultOverlay/Box"` → `"%ResultOverlay/Box"`)
- Test: `tests/ui/test_battle_screen_layers.gd` (새로)

**Interfaces:**
- Produces: CanvasLayer 노드 `UiLayer`(layer 2), `FrontLayer`(layer 3), `OverlayLayer`(layer 4). 0층에는 `World` 가 있다. 1층은 2단계 `BattleMood` 의 PostLayer 용으로 비워 둔다

노드 배치 (각 층 안의 순서는 지금 순서대로):
- 루트에 남는 것: World, EnemyTimer, PerformanceQueue, HitSound
- UiLayer: RoundLabel, TurnQueue, TurnBanner, AllyPanel, EnemyPanel, Log, Hand, BottomLeft, BottomRight
- FrontLayer: WorldFront
- OverlayLayer: BagPanel, TargetArrow, ResultOverlay, BackButton

- [ ] **Step 1: 실패하는 테스트** — `test_battle_screen_layers.gd`: 씬을 instantiate 하고 `add_child_autofree` 한다

```gdscript
func _layer(s: Node, path: String) -> int:
	var l := (s.get_node(path) as CanvasItem).get_canvas_layer_node()
	return l.layer if l else 0

func test_world_stays_on_base_canvas():
	assert_eq(_layer(s, "%World"), 0)
func test_ui_on_layer_2():
	for p in ["%RoundLabel", "%TurnQueue", "%TurnBanner", "%AllyPanel", "%EnemyPanel", "%Log", "%Hand", "UiLayer/BottomLeft", "UiLayer/BottomRight"]:
		assert_eq(_layer(s, p), 2, p)
func test_front_on_layer_3():
	assert_eq(_layer(s, "%WorldFront"), 3)
	assert_eq(_layer(s, "%FloatLayer"), 3)
func test_overlay_on_layer_4():
	for p in ["%BagPanel", "%TargetArrow", "%ResultOverlay", "%BackButton"]:
		assert_eq(_layer(s, p), 4, p)
```

- [ ] **Step 2:** 복사본에서 GUT 를 실행한다 → 새 테스트 FAIL (층 0)
- [ ] **Step 3:** MCP 로 CanvasLayer 3개를 만들고 노드를 옮긴 뒤 저장한다. 스크립트 157줄과 테스트 경로 3곳을 고친다
- [ ] **Step 4:** 복사본을 다시 동기화하고 GUT 전체를 실행한다 → 새 테스트 PASS, 기존 테스트 회귀 없음
- [ ] **Step 5:** Commit

### Task 2: 연출 미리보기 Panel 올리기 + 실행 확인

**Files:**
- Modify: `Scenes/performances/performance_preview.tscn` — `PanelLayer`(CanvasLayer, layer 10) 를 만들고 `Panel` 을 그 아래로 옮긴다
- Modify: `Scripts/performances/performance_preview.gd` — `$Panel/...` 경로가 있으면 `PanelLayer/Panel/...` 로 바꾼다
- Modify: `docs/progress.md`

- [ ] **Step 1:** MCP 로 편집하고 저장한다
- [ ] **Step 2:** GUT 전체를 실행한다 → 통과
- [ ] **Step 3:** 실행 확인한다. F6 시험 전투 스크린샷: 화면이 이전과 같다(손패·패널·버튼·배경). 카드를 드래그하면 화살표가 맞고, 연출이 확대되고, 피해 숫자가 보인다. 연출 미리보기 씬(F6)에서 Panel 이 보인다
- [ ] **Step 4:** `docs/progress.md` 에 한 줄 추가하고 Commit
