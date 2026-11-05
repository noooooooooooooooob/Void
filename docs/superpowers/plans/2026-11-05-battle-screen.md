# 전투 화면 (시험판) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 씬을 열고 F6 → 시험용 홍연으로 타격·사격·방어만 써서 시험용 적 2마리와 한 판을 끝까지(승리/패배 → 다시 하기) 플레이할 수 있는 전투 화면.

**Architecture:** 순수 로직 `BattleSession`(RefCounted)이 `BattleData` 로 전투를 만들고 차례 진행·입력(카드/이동/차례 종료)·적 차례를 담당하고 시그널로 화면에 알린다. 화면(`battle_screen.tscn`)은 노드 배치를 씬에 두고, 스크립트는 세션 상태를 그리고 입력을 세션 호출로 바꾸기만 한다. 규칙 판정은 반드시 `Battle` 의 함수를 쓴다.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, GoPeak MCP(에디터 씬 편집)

**Spec:** `docs/superpowers/specs/2026-11-05-battle-screen-design.md`

## Global Constraints

- 게임 스크립트는 `res://Scripts/<기능>/`, 씬은 `res://ui/<이름>/<이름>.tscn`, 데이터 `.tres` 는 기능 폴더. 씬과 스크립트는 같은 이름(snake_case).
- 노드·UI 배치·스타일은 `.tscn` 노드로. 스크립트에서 `new()`/`add_child()` 로 조립 금지 — 반복 항목만 틀 씬 instantiate.
- 에디터가 켜져 있으면 바깥에서 `res://` 의 `.tscn`/`.tres` 를 쓰지 않는다. 씬은 MCP 로, 리소스 안에 리소스가 필요한 데이터는 에디터를 끈 상태에서 Godot 헤드리스 스크립트가 저장(손으로 텍스트 작성 금지).
- 테스트는 프로젝트 복사본에서: `bash <scratchpad>/run_tests.sh [res://tests/…gd]` (없으면 CLAUDE.md 의 GUT 명령, 복사본에서 MCP 플러그인 끔).
- 테스트 외 모든 스크립트에 한국어 주석(클래스 `##`, export·공개 함수·시그널 `##`, 단계별 주석).
- 열거형에 값을 더할 때는 맨 뒤에.
- 시험 데이터: 카드 `cards/data/common/타격.tres`(근접, DamageEffect percent 100), `사격.tres`(원거리, DamageEffect 100), `방어.tres`(자신, BlockEffect 100, target SELF). 시험용 홍연 덱 = 타격 4·사격 3·방어 3, 패시브·장비 없음, 홍연 숫자 스탯 복사. 시험용 적 2마리: HP 45, 공격 9, 방어 6, 속도 2~8, 덱 = 타격 2·사격 1·방어 1. 격자 3행 × 4열.
- 적 차례 간격 0.7초(화면 타이머). 화면 기준 해상도 1920×1080.

## Review Focus

1. 아군 차례에 SP 가 부족하거나 근접 대상이 없는 카드 → 어둡게 표시되고 골라지지 않아야 한다 (Task 5 `test_unplayable_card_cannot_be_selected`).
2. 적 차례 진행 중(타이머 대기 중) 손패 클릭·차례 종료 버튼 → 무시되어야 한다 (Task 5 `test_input_ignored_during_enemy_turn`).
3. 아군이 자기 차례 시작(드로우 페이즈)에 죽거나, 아군 행동으로 적이 전멸 → 다음 차례로 넘어가지 않고 바로 결과 (Task 3 `test_player_kills_last_enemy_ends_immediately`, `test_dead_at_draw_phase_skips_turn`).
4. "다시 하기" → 이전 전투의 시그널·유닛이 남지 않고 새 전투가 같은 데이터로 시작 (Task 3 `test_restart_creates_fresh_battle`, Task 5 `test_restart_resets_screen`).
5. 라운드 중 속도 재정렬 / 새 라운드 → 행동 순서 줄이 실제 `turn_order` 와 같아야 한다 (Task 3 `test_turn_queue_matches_turn_order`).

---

### Task 1: ROUND_START 를 행동 순서 확정 뒤로

**Files:**
- Modify: `Scripts/battle/battle.gd` (`start_round`, 주석)
- Test: `tests/battle/test_turn_order.gd`

- [ ] **Step 1: 실패하는 테스트**

```gdscript
func test_round_start_emitted_after_order_is_rolled():
	# ROUND_START 를 받는 쪽(화면)이 이번 라운드 순서표를 바로 읽을 수 있어야 한다
	var a := Fixture.unit(A, Vector2i(3, 0))
	var e := Fixture.unit(E, Vector2i(3, 0))
	var bt := _battle([a, e])
	var seen := []
	bt.events.subscribe(Ev.ROUND_START, func(_ev): seen.append(bt.turn_order.remaining().size()))
	bt.start_battle()
	assert_eq(seen, [2])
```
(파일에 이미 있는 헬퍼 이름을 쓴다. 없으면 test_battle_lifecycle.gd 의 `_battle` 과 같은 헬퍼를 둔다.)

- [ ] **Step 2: 실행 → FAIL (`[0]`)**
- [ ] **Step 3: `start_round` 에서 `turn_order.start_round(...)` 를 `ROUND_START` 발행 앞으로 옮기고 함수 주석의 순서 설명을 고친다.** ROUND_START 반응으로 속도가 바뀌면 기존 재정렬(`_refresh_speeds`)이 처리한다.
- [ ] **Step 4: 전체 테스트 PASS (기존 `test_turn_order` 의 ROUND_END→ROUND_START 순서 테스트 포함)**
- [ ] **Step 5: 커밋** `fix: emit ROUND_START after the turn order is rolled`

---

### Task 2: BattleData 리소스 + 시험 데이터

**Files:**
- Create: `Scripts/battle/battle_slot.gd`, `Scripts/battle/battle_data.gd`
- Create (에디터 끈 상태, 헤드리스 스크립트로 저장): `battles/test_battle.tres`, `entities/units/test/test_hongyeon.tres`, `entities/units/test/test_enemy.tres`; Modify: `cards/data/common/타격.tres`·`사격.tres`·`방어.tres` (effects 추가)
- Test: `tests/battle/test_battle_data.gd`, `tests/data/test_sample_data.gd`

**Interfaces:**
- Produces:
  - `class_name BattleSlot extends Resource` — `@export var unit: UnitData`, `@export var cell: Vector2i`
  - `class_name BattleData extends Resource` — `@export var rows: int = BattleTypes.DEFAULT_GRID_ROWS`, `@export var ally_cols: int = BattleTypes.DEFAULT_GRID_COLS`, `@export var enemy_cols: int = BattleTypes.DEFAULT_GRID_COLS`, `@export var allies: Array[BattleSlot]`, `@export var enemies: Array[BattleSlot]`
  - `BattleData.make_units() -> Array[BattleUnit]` — 아군 슬롯 → ALLY, 적 슬롯 → ENEMY 로 새 BattleUnit (순서: 아군, 적)
  - `BattleData.make_enemy_units() -> Array[BattleUnit]`

- [ ] **Step 1: 실패하는 테스트** (`tests/battle/test_battle_data.gd`)
  - `test_make_units_sides_and_cells`: 아군 1·적 2 슬롯 → 3 유닛, side·cell 이 슬롯과 같음, 아군이 먼저.
  - `test_make_units_returns_new_units_each_call`: 두 번 부르면 서로 다른 객체.
- [ ] **Step 2: FAIL 확인**
- [ ] **Step 3: 두 스크립트 구현 (주석 포함)**
- [ ] **Step 4: PASS**
- [ ] **Step 5: 시험 데이터 만들기** — 사용자에게 에디터를 꺼 달라고 요청 → 스크래치 헤드리스 스크립트(`extends SceneTree`)로 위 Global Constraints 의 값대로 리소스를 만들어 `ResourceSaver.save`. 카드 3장은 `load` → `effects` 에 효과 추가 → 같은 경로에 저장(웹 에디터 칸 유지). 시험용 홍연은 `hongyeon.tres` 의 숫자 스탯만 복사, `display_name = "홍연 (시험)"`. 적 표시 이름 "시험용 적 A"/"시험용 적 B" 는 BattleData 에서 같은 UnitData 를 두 번 쓰면 이름이 같아지므로 **적 UnitData 를 A·B 두 파일**(`test_enemy_a.tres`, `test_enemy_b.tres`)로 만든다. 배치: 홍연 (3,1), 적 A (3,0), 적 B (2,2) (열은 전열=3 기준, 기존 Fixture 규칙과 같게).
- [ ] **Step 6: 데이터 테스트** (`tests/data/test_sample_data.gd` 에 추가)
  - `test_basic_cards_have_effects`: 타격·사격 = DamageEffect percent 100, 방어 = BlockEffect percent 100 target SELF.
  - `test_test_battle_data`: `battles/test_battle.tres` 아군 1·적 2, 시험용 홍연 덱 10장(타격 4·사격 3·방어 3), 패시브·장비 비어 있음.
- [ ] **Step 7: 전체 PASS → 커밋** `feat: BattleData resource and test battle data`

---

### Task 3: BattleSession (진행 담당)

**Files:**
- Create: `Scripts/battle/battle_session.gd`
- Modify: `Scripts/cards/card_effect.gd`, `Scripts/cards/effects/damage_effect.gd`, `block_effect.gd`, `heal_effect.gd` (미리보기 수치)
- Test: `tests/battle/test_battle_session.gd`, `tests/cards/test_effects.gd`

**Interfaces:**
- Consumes: `BattleData.make_units()`, `Battle` 공개 함수들
- Produces (`class_name BattleSession extends RefCounted`):
  - `func _init(data: BattleData, allies: Array[BattleUnit] = [], battle_seed: int = 0)` — allies 가 비면 `data.make_units()`, 아니면 allies + `data.make_enemy_units()`
  - `var battle: Battle`, `var active: BattleUnit` (입력을 기다리는 아군, 없으면 null)
  - `signal changed()` — 상태가 바뀔 때마다(카드·이동·차례 시작/끝·적 행동 후)
  - `signal turn_started(unit: BattleUnit)`
  - `signal finished(winner: int)` — 한 번만
  - `func start() -> void` — 전투 시작 후 첫 차례까지 진행
  - `func advance() -> void` — 다음 차례를 연다: 아군이면 `begin_turn`(죽으면 `end_turn` 없이 다음으로) 후 `active` 설정하고 멈춤 / 적이면 멈춰서 `is_enemy_turn()` true (화면이 0.7초 뒤 `step_enemy()` 호출)
  - `func is_enemy_turn() -> bool`, `func pending_enemy() -> BattleUnit`
  - `func step_enemy() -> void` — `run_enemy_turn(pending)` → 승패 확인 → `advance()`
  - `func play(card: CardData, origin: BattleUnit = null) -> bool` — active 일 때만; 성공 후 승패 확인
  - `func move(cell: Vector2i) -> bool`
  - `func end_player_turn() -> void` — `end_turn(active)` → `active = null` → `advance()`
  - `func targets_for(card: CardData) -> Array[BattleUnit]` — 고를 수 있는 기준 유닛(원거리: 상대 살아 있는 유닛, 아군: 자기 편 살아 있는 유닛, 근접: `[melee_target]` 또는 빈 배열, 자신: `[active]`), 각각 `can_play == ""` 인 것만
  - `func reachable_cells() -> Array[Vector2i]` — active 의 빈 칸 중 `path_length <= move_left`
  - `func card_preview(card: CardData) -> int` — 첫 피해/방어도/회복 효과의 미리보기 수치, 없으면 -1
  - `func turn_queue() -> Array` — `[{unit, speed}]`: 현재 차례 유닛(맨 앞) + `turn_order.remaining()`
  - `func restart() -> BattleSession` — 같은 data·seed+1 로 새 세션(아군을 밖에서 받은 경우엔 쓰지 않음; 시험판 전용)
- `CardEffect.preview_amount(ctx: EffectContext) -> int` — 기본 -1. Damage/Block/Heal 은 치명·대상 없이 `final_amount(base × scale_of(ctx, multiplier))`, 배율 ≤ 0 이면 0.

- [ ] **Step 1: 실패하는 테스트** (`test_battle_session.gd`, Fixture 로 만든 BattleData 사용 — 데이터 파일에 의존하지 않음)
  - `test_start_stops_at_first_player_turn_or_enemy_turn`: start 후 `active != null` 또는 `is_enemy_turn()`
  - `test_play_card_spends_sp_and_emits_changed`
  - `test_play_ignored_when_not_active`: active 가 아닐 때 play → false, 손패 그대로
  - `test_end_player_turn_moves_to_next`
  - `test_step_enemy_runs_enemy_and_advances`
  - `test_player_kills_last_enemy_ends_immediately`: 적 HP 1, 타격 → `finished(ALLY)` 한 번, `active == null`, 이후 `advance()` 해도 시그널 추가 없음
  - `test_dead_at_draw_phase_skips_turn`: 아군에게 DRAW_PHASE 치명 출혈 → advance 가 그 아군에서 멈추지 않음
  - `test_targets_for_ranged_lists_living_enemies` / `test_targets_for_melee_is_front_enemy` / `test_targets_for_self_is_active`
  - `test_reachable_cells_respects_move_left`
  - `test_turn_queue_matches_turn_order`: 첫 항목 = 현재 차례 유닛, 나머지 = `turn_order.remaining()` 순서
  - `test_restart_creates_fresh_battle`: `restart()` 의 battle 은 다른 객체, 유닛 HP 가득, 이전 세션 시그널과 무관
  - `test_card_preview_damage_uses_attack`: 공격 20, 타격 100% → 20; 방어 15, 방어 100% → 15; 효과 없는 카드 → -1
  - (`test_effects.gd`) `test_preview_amount_has_no_crit`: 치명 100% 유닛도 미리보기는 기본값
- [ ] **Step 2: FAIL 확인**
- [ ] **Step 3: `preview_amount` 구현 후 `BattleSession` 구현** — `changed` 는 battle 이벤트 버스의 주요 이벤트(DAMAGE_TAKEN, BLOCK_GAINED, HEALED, CARD_PLAYED, UNIT_MOVED, TURN_START, TURN_END, STATUS_APPLIED/REMOVED, TURN_ORDER_CHANGED)에 구독해서 발행해도 되고 공개 함수 끝에서 발행해도 된다. 화면은 이벤트 자체도 직접 구독해 떠오르는 숫자·기록을 만든다(Task 5).
- [ ] **Step 4: PASS (전체)**
- [ ] **Step 5: 커밋** `feat: BattleSession drives turns for the battle screen`

---

### Task 4: 화면 부품 씬 + CardView 계산 수치

**Files:**
- Modify: `ui/card_view/card_view.tscn`(큰 수치 Label `%Amount` 추가, 기본 숨김), `Scripts/ui/card_view.gd`
- Create (MCP 로 에디터에서): `ui/battle_screen/grid_cell.tscn`, `unit_token.tscn`, `turn_portrait.tscn`, `unit_status_row.tscn`, `float_number.tscn` + 같은 이름 스크립트 `Scripts/ui/<이름>.gd`
- Test: `tests/ui/test_card_view.gd`, `tests/ui/test_battle_parts.gd`

**Interfaces:**
- `CardView.show_amount(value: int) -> void` — value < 0 이면 숨김. `CardView.set_dimmed(on: bool) -> void` (modulate 로 어둡게)
- `GridCell` (Control): `var side: int`, `var cell: Vector2i`, `signal pressed(side: int, cell: Vector2i)`, `set_mark(kind: int)` — 0 없음 / 1 이동 가능 / 2 대상 가능 / 3 범위 강조
- `UnitToken` (Control): `set_unit(u: BattleUnit)`, `refresh()` (이름·HP·방어도·사망 흐림), `set_highlight(on: bool)`, `signal pressed(u: BattleUnit)`
- `TurnPortrait`: `set_entry(u: BattleUnit, speed: int, is_current: bool)` (아군/적 색, 속도 숫자)
- `UnitStatusRow`: `set_unit(u: BattleUnit)`, `refresh()` — 이름, HP 바(값/최대), 방어도, 스태미너, 상태 "이름 수치" 목록(PASSIVE 수치 0 은 숨김)
- `FloatNumber`: `pop(text: String, color: Color)` — 위로 떠오르며 사라진 뒤 `queue_free`

- [ ] **Step 1: 실패하는 테스트**
  - `test_card_view.gd`: `test_show_amount_visible_with_value` (`show_amount(9)` → `%Amount` 보임, 텍스트 "9"), `test_show_amount_negative_hides`, `test_gallery_default_has_no_amount` (set_card 만 하면 숨김)
  - `test_battle_parts.gd`: 각 씬 instantiate → `UnitToken.refresh` 후 HP 텍스트가 `"45/45"` 꼴, 사망 시 modulate.a < 1; `UnitStatusRow` 가 상태 수치 표시; `GridCell` 클릭 시 `pressed(side, cell)`; `TurnPortrait` 현재 차례 강조 여부
- [ ] **Step 2: FAIL**
- [ ] **Step 3: 씬은 MCP(`scene-create`, `scene-node-add`, `scene-node-set`, `scene-save`)로 에디터에서 만든다.** 노드 이름 PascalCase, 스크립트에서 쓰는 노드는 고유 이름(%). 크기 기준: 칸 120×120, 유닛 박스 100×100, 초상화 64×80. 스크립트 구현.
- [ ] **Step 4: PASS**
- [ ] **Step 5: 커밋** `feat: battle screen parts and computed amount on cards`

---

### Task 5: 전투 화면

**Files:**
- Create (MCP): `ui/battle_screen/battle_screen.tscn`, `ui/battle_screen/target_arrow.tscn`; Create: `Scripts/ui/battle_screen.gd`, `Scripts/ui/target_arrow.gd`
- Test: `tests/ui/test_battle_screen.gd`

**Interfaces:**
- Consumes: `BattleSession` 전부, Task 4 부품
- `BattleScreen` (Control): `@export var battle_data: BattleData` (기본 `res://battles/test_battle.tres`), `@export var enemy_delay := 0.7`, `@export var battle_seed := 0`; `var session: BattleSession`
  - 테스트용 입력 진입점(마우스 처리도 이 함수들을 부른다): `select_card(index: int) -> bool`, `click_unit(u: BattleUnit) -> bool`, `click_cell(side: int, cell: Vector2i) -> bool`, `cancel() -> void`, `press_end_turn() -> void`, `restart() -> void`
  - `var selected: CardData` (고른 카드, 없으면 null)
- `TargetArrow` (Node2D, `top_level`): `set_points(from: Vector2, to: Vector2)` — 2차 베지어 곡선 `Line2D` 점 갱신 + 끝 화살촉, `set_valid(on: bool)` 색 변경

씬 배치(스펙 3장): 위 가운데 `RoundLabel`·`TurnQueue`(HBox, TurnPortrait 반복), 왼쪽 `AllyPanel`(VBox, UnitStatusRow), 오른쪽 `EnemyPanel`, 가운데 `AllyGrid`·`EnemyGrid`(GridContainer, GridCell 을 데이터 크기만큼 instantiate, 칸 위에 UnitToken), 아래 `Hand`(HBox, CardView), 왼쪽 아래 `SpLabel`·`MoveLabel`·`DeckLabel`, 오른쪽 아래 `DiscardLabel`·`ExileLabel`·`EndTurnButton`, 구석 `Log`(RichTextLabel 또는 VBox Label, 최근 8줄), `FloatLayer`, `TargetArrow`, `ResultOverlay`(`ResultLabel` + `RestartButton`, 기본 숨김). 아군 격자는 전열(열 큰 값)이 가운데를 향하게 좌우 반전 배치.

조작(스펙 4장):
- 카드 클릭: `targets_for(card)` 가 비면 어둡게·무시. 원거리·아군: 화살표 켜기(카드 위 → 마우스), 대상 유닛 위에서 `set_valid(true)` + `area_targets` 칸 강조, 클릭 시 `session.play(card, u)`. 근접: 화살표를 `targets_for` 의 첫 유닛에 고정, 클릭 시 사용. 자신: 같은 카드를 다시 누르거나 손패 위로 끌면 사용.
- 우클릭/ESC → `cancel()`.
- 카드 미선택 시 `reachable_cells()` 에 이동 표시, 칸 클릭 → `session.move`.
- `session.is_enemy_turn()` 이면 `enemy_delay` 초 타이머 후 `step_enemy()`, 그동안 입력 무시.
- 이벤트 구독: DAMAGE_TAKEN → 빨강 "-N", BLOCK_GAINED → 파랑 "+N", HEALED → 초록 "+N" 떠오르는 숫자 + 기록 한 줄; BEFORE_CARD_PLAYED → 기록 "이름: 카드 → 대상".
- `finished` → ResultOverlay("승리"/"패배"), RestartButton → `restart()`(새 세션, 화면 다시 그림).

- [ ] **Step 1: 실패하는 테스트** (`test_battle_screen.gd`, 씬 instantiate + `battle_data` 에 Fixture 데이터, 타이머 대신 `enemy_delay = 0` 과 `session.step_enemy()` 직접 호출 허용)
  - `test_hand_shows_active_unit_cards`: 손패 노드 수 = active.hand.size()
  - `test_turn_queue_shows_session_queue`: 초상화 수·순서 = `session.turn_queue()`
  - `test_ranged_card_then_click_enemy_plays`: 사격 선택 → `click_unit(적)` → 적 HP 감소, 손패 1 감소, `selected == null`
  - `test_melee_card_click_plays_on_front_enemy`
  - `test_self_card_second_click_plays`: 방어 select 두 번 → 방어도 증가
  - `test_unplayable_card_cannot_be_selected`: SP 0 으로 만든 뒤 `select_card` → false, 카드 어둡게
  - `test_input_ignored_during_enemy_turn`: `is_enemy_turn()` 상태에서 `select_card`/`press_end_turn` → 변화 없음
  - `test_click_reachable_cell_moves`
  - `test_cancel_clears_selection_and_arrow`
  - `test_result_overlay_on_win`: 적 HP 1 로 만들고 타격 → ResultOverlay 보임, "승리"
  - `test_restart_resets_screen`: restart 후 오버레이 숨김, 새 session, 적 HP 가득
- [ ] **Step 2: FAIL**
- [ ] **Step 3: 씬은 MCP 로 에디터에서 만들고 스크립트 구현**
- [ ] **Step 4: PASS (전체)**
- [ ] **Step 5: 커밋** `feat: playable battle screen (test build)`

---

### Task 6: 직접 실행 확인 + 문서

**Files:**
- Modify: `docs/progress.md`

- [ ] **Step 1: 에디터에서 `ui/battle_screen/battle_screen.tscn` 열고 F6 (또는 MCP `editor-run`)으로 실행, 스크린샷/디버그 출력으로 확인**: 손패 5장, 사격 화살표, 근접 자동 대상, 방어, 이동, 차례 종료 → 적 행동 0.7초 간격, 결과 화면, 다시 하기. 오류 출력 없음.
- [ ] **Step 2: 발견한 문제는 systematic-debugging 으로 원인 → 테스트 → 수정**
- [ ] **Step 3: `docs/progress.md` 에 "전투 화면 (시험판)" 행, 실행 방법, 남은 것(예상 피해, 적 의도, 그림·연출) 추가**
- [ ] **Step 4: 커밋** `docs: progress — battle screen test build`
