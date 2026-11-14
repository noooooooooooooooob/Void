# 카드 사용 연출 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카드를 쓰면 카드마다의 연출 씬(AnimationPlayer 타임라인)이 이동·동작·피격 반응·결과 표시를 보여 주고, 연출이 끝나야 다음 행동이 진행된다. 피격 반응에 타격감 기법을 차례로 더한다.

**Architecture:** 전투 계산은 지금처럼 즉시 끝난다. `PerformanceRecorder` 가 이벤트를 카드 단계/즉시 단계(`PerformanceStep`, 단계 끝의 유닛 상태 스냅샷 포함)로 묶고, 전투 화면의 `PerformanceQueue` 노드가 단계를 하나씩 재생한다. 연출 씬 루트 `CardPerformance` 는 타임라인 Call Method 키(`move`/`hit`/`show_results`/`zoom`)를 시그널로 바꿔 큐에 알린다.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1

**Spec:** `docs/superpowers/specs/2026-11-14-card-performance-design.md`

## Global Constraints

- 작업 브랜치: `feat/card-performance`, **`feat/bram-sprites` 에서 분기** (`UnitData.battle_frames`, `UnitToken` 의 `%Sprite`, `CardData.animation` 사용)
- 전투 계산 규칙(`Battle`, `BattleCardPlay`, 효과) 변경 금지. 예외: Task 7 의 치명 여부 전달(값 계산은 그대로)
- 기존 테스트 전부 통과. 연출 씬 없는 카드만 쓰면 지금과 같은 프레임에 결과가 보여야 함
- 에디터가 켜져 있으면 바깥에서 `res://` 의 `.tscn`/`.tres` 쓰기 금지. 씬 노드는 GoPeak MCP 로 추가(단 `scene-node-set` 은 인스턴스 있는 씬을 망가뜨리므로 금지), 안 되면 에디터를 끄고 Godot 헤드리스 스크립트로 저장. 브랜치 전환도 에디터를 끈 상태에서
- 테스트는 **프로젝트 복사본**에서 (MCP 플러그인·MCPRuntime 끄고 `--log-file` 따로):
  `Godot_v4.7.2-stable_win64_console.exe --headless --path <복사본> --import` 후
  `... --headless --path <복사본> -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- 게임 스크립트는 `Scripts/<기능>/`, 씬은 `Scenes/<기능>/`. 테스트 외 모든 스크립트에 한국어 주석(클래스 `##`, export·공개 함수·시그널 `##`)
- 흔들림·음높이 난수는 전투 `rng` 와 별개의 `RandomNumberGenerator`
- 모든 타격감 수치는 `BattleScreen` 의 `@export` 공통값. 카드별 변경 가능한 항목은 `CardPerformance` 루트의 같은 이름 `@export` (이펙트·효과음 null, 숫자 < 0 이면 공통값)

## Review Focus

1. 적 차례 한 번에 카드 2장 → 첫 카드의 `show_results` 때 두 번째 카드 결과(HP)가 미리 보이면 안 됨 → 스냅샷으로 표시 (Task 1 `test_card_step_snapshot_is_per_step`, Task 3 `test_two_enemy_cards_show_their_own_hp`)
2. 연출 중 마지막 적이 쓰러져 전투 종료 → 결과 창은 연출이 끝난 뒤 (Task 3 `test_result_waits_for_queue`)
3. 연출 씬에 `show_results` 키가 없음 → 끝날 때 결과 표시 (Task 2·3 `test_no_show_results_key_shows_at_end`)
4. 연출 중 클릭·차례 끝내기 → 무시 (Task 3 `test_input_ignored_while_playing`)
5. `move` 했는데 연출 끝까지 복귀 키 없음 → 자동 복귀하고 Sprite 가 다시 보임 (Task 3 `test_auto_return_after_move`)

---

### Task 0: 브랜치 준비

- [ ] **Step 1:** 에디터가 꺼졌는지 사용자에게 확인 (`Get-Process Godot*` 가 비어야 함)
- [ ] **Step 2:** `git stash -u` (main 의 `grid_cell.tscn` uid 변경, 새 문서 보관) → `git switch feat/bram-sprites` → `git switch -c feat/card-performance` → `git stash pop`. 충돌이 나면 멈추고 사용자에게 알림
- [ ] **Step 3:** 설계 문서와 이 계획을 커밋 (`docs: card performance design and plan`)

### Task 1: 연출 단계 기록 (순수 로직)

**Files:**
- Create: `Scripts/performances/performance_step.gd`, `Scripts/performances/performance_recorder.gd`
- Modify: `Scripts/battle/battle_card_play.gd` (BEFORE 이벤트의 `source` 는 이미 eff — 변경 없음, 확인만)
- Test: `tests/performances/test_performance_recorder.gd`

**Interfaces:**
- Produces:
  - `class_name PerformanceStep extends RefCounted`
    - `enum Kind { CARD, INSTANT }`, `var kind: int`, `var actor: BattleUnit`, `var card: CardData`(실제로 쓴 카드, INSTANT 면 null), `var target: BattleUnit`(기준 대상), `var events: Array[BattleEvent]`
    - `var state: Dictionary` — BattleUnit → `{"hp": int, "block": int, "alive": bool, "cell": Vector2i}` (단계가 닫힐 때 전투의 모든 유닛)
    - `func damage_totals() -> Dictionary` — DAMAGE_TAKEN 의 target 별 amount 합 (BattleUnit → int)
    - `func hit_targets() -> Array[BattleUnit]` — 기준 대상 + DAMAGE_TAKEN 대상 (중복 없음, 처음 나온 순서). 자신 카드면 빈 배열이 아니라 [actor]
  - `class_name PerformanceRecorder extends RefCounted`
    - `func _init(battle: Battle)` — `battle.events` 의 모든 `BattleTypes.Event` 를 구독
    - `func take_steps() -> Array[PerformanceStep]` — 쌓인 단계를 돌려주고 비움
    - 규칙: BEFORE_CARD_PLAYED 에서 깊이 0 이면 CARD 단계 열기, 깊이 +1. AFTER_CARD_PLAYED 에서 깊이 −1, 0 이 되면 상태 스냅샷 후 닫기. 깊이 > 0 인 동안의 이벤트는 열린 단계에. 깊이 0 의 다른 이벤트는 각각 INSTANT 단계(이벤트 직후 스냅샷)
    - `ROUND_START`, `TURN_ORDER_CHANGED` 도 INSTANT 로 기록한다 (화면 라운드 카운트가 쓰므로)

- [ ] **Step 1: 실패하는 테스트** — `tests/battle/` 의 기존 헬퍼 패턴(유닛·카드 직접 생성)으로 전투를 만든다.
  - `test_card_play_becomes_one_card_step`: 아군이 근접 피해 카드 사용 → `take_steps()` 중 kind CARD 가 1개, `card` == 쓴 카드, `actor`·`target` 일치, `events` 첫 원소 BEFORE, 마지막 AFTER
  - `test_damage_totals_sum_multiple_effects`: 피해 효과 2개(각 10) 카드 → `damage_totals()[적] == 20`
  - `test_event_outside_card_is_instant`: `battle.apply_damage(null, 적, 5)` → INSTANT 단계 1개, events.size()==1
  - `test_card_step_snapshot_is_per_step`: 카드 A(피해 10) 후 카드 B(피해 10), 적 HP 45 → steps[0].state[적].hp == 35, steps[1].state[적].hp == 25
  - `test_take_steps_clears`: 두 번째 `take_steps()` 는 빈 배열
- [ ] **Step 2:** 복사본에서 GUT 실행 → FAIL (`PerformanceRecorder` 없음)
- [ ] **Step 3:** 두 스크립트 구현
- [ ] **Step 4:** GUT 실행 → 새 테스트 PASS, 기존 전부 PASS
- [ ] **Step 5:** 커밋 `feat: record battle events into performance steps`

### Task 2: 연출 씬 루트 `CardPerformance` + `CardData.performance`

**Files:**
- Create: `Scripts/performances/card_performance.gd`
- Modify: `Scripts/cards/card_data.gd` (칸 추가)
- Test: `tests/performances/test_card_performance.gd`

**Interfaces:**
- Produces:
  - `CardData`: `@export var performance: PackedScene` (`animation` 아래). 주석: 비우면 연출 없음, 카드 가져오기가 덮어쓰지 않음
  - `class_name CardPerformance extends Node2D`
    - 자식 규약: `%Actor`(AnimatedSprite2D), `%AnimationPlayer`, 애니메이션 이름 `&"perform"`
    - 시그널: `move_requested(offset: Vector2, time: float)`, `hit_reached()`, `results_requested()`, `zoom_requested(strength: float, time: float)`, `done()`
    - 타임라인용 함수(Call Method 키): `move(x: float, y: float, time: float)`, `hit()`, `show_results()`, `zoom(strength: float, time: float)` — 각각 시그널만 낸다
    - `func play(frames: SpriteFrames) -> void` — frames 가 null 이 아니면 `%Actor.sprite_frames = frames`, `perform` 재생, 끝나면 `done`. `perform` 이 없으면 바로 `done` (call_deferred)
    - `func set_paused(on: bool) -> void` — AnimationPlayer·씬 안 모든 AnimatedSprite2D 의 `speed_scale` 0/1 (히트스톱용)
    - export(카드별 변경, 기본 = 공통값 사용): `return_time := -1.0`, `hit_effect: PackedScene`, `hit_sound: AudioStream`, `hit_shake := -1.0`, `hitstop_time := -1.0`, `knockback := -1.0`

- [ ] **Step 1: 실패하는 테스트** — 테스트 안에서 CardPerformance + Actor + AnimationPlayer 를 코드로 만들고, Animation 에 Call Method 트랙(루트 경로 `.`)으로 0.0초 `move(-80,0,0.1)`, 0.05초 `hit()`, 0.05초 `hit()`, 0.1초 `show_results()` 를 넣는다 (길이 0.2초).
  - `test_keys_emit_signals_in_order`: `play(null)` 후 `await wait_for_signal(p.done, 1.0)`. 기록된 시그널 순서 == `["move", "hit", "hit", "results", "done"]`, move offset == `Vector2(-80, 0)`
  - `test_missing_perform_finishes_immediately`: 애니메이션 없는 씬 → `play(null)` 후 한 프레임 안에 `done`
  - `test_play_sets_actor_frames`: `play(frames)` 후 `%Actor.sprite_frames == frames`
  - `test_card_data_has_performance`: `CardData.new().performance == null`
- [ ] **Step 2:** GUT → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** GUT → PASS
- [ ] **Step 5:** 커밋 `feat: CardPerformance scene root and CardData.performance`

### Task 3: 연출 대기열과 전투 화면 연결

**Files:**
- Create: `Scripts/ui/performance_queue.gd`
- Modify: `Scripts/ui/battle_screen.gd`, `Scripts/ui/unit_token.gd`, `Scenes/ui/battle_screen/battle_screen.tscn` (노드 추가: FloatLayer 바로 아래 형제 `PerformanceLayer`(Control, mouse_filter ignore, 전체 크기, unique), 루트 자식 `PerformanceQueue`(Node, 스크립트 performance_queue.gd, unique))
- Test: `tests/ui/test_battle_screen_performance.gd`

**Interfaces:**
- Consumes: Task 1 `PerformanceRecorder`/`PerformanceStep`, Task 2 `CardPerformance`
- Produces:
  - `class_name PerformanceQueue extends Node`
    - `signal step_results(step: PerformanceStep)` — 그 단계의 결과를 지금 보여 줄 때 (화면이 숫자·로그·박스 갱신)
    - `signal hit(step: PerformanceStep, perf: CardPerformance)` — `hit()` 키마다 (Task 4~ 가 피격 반응을 여기 붙임)
    - `signal drained()` — 비었을 때
    - `func push(steps: Array[PerformanceStep]) -> void` — 쌓고, 놀고 있으면 바로 처리 시작
    - `func is_busy() -> bool`
    - `var layer: Control`, `var token_of: Callable` (BattleUnit → UnitToken) — 화면이 `_ready` 에서 넣음
    - `@export var default_return_time := 0.2`
    - 처리 규칙: INSTANT 단계·연출 씬 없는 CARD 단계는 **같은 호출 안에서** `step_results` 를 내고 다음으로 (bram 의 `play_card_animation(card)` 을 CARD 단계면 부름). 연출 씬 있는 CARD 단계는 설계 6 의 순서: 씬 생성 → 행위자 토큰 Sprite 의 global 위치·scale 에 맞춰 `layer` 에 추가 → Sprite 숨김 → `play(actor.data.battle_frames)` → `move_requested` 는 대상 토큰 칸 중심(화면에 보이는 토큰의 global rect center)+offset 으로 tween → `results_requested` 첫 번째만 `step_results` → `done` 에서 결과 미표시면 표시 → 움직였으면 `return_time`(씬 값 ≥ 0, 아니면 기본) 동안 원래 위치로 tween → 씬 free, Sprite 보임 → 다음
  - `UnitToken.show_state(s: Dictionary) -> void` — `{"hp","block","alive"}` 로 HP·방어도 라벨과 흐림만 갱신 (실제 unit 값 대신)
  - `UnitToken.sprite() -> AnimatedSprite2D`, `UnitToken.ui_box() -> Control` (%Box)
  - `BattleScreen`:
    - `_subscribe_events` 의 즉시 그리기 람다들을 `_show_event(e: BattleEvent)` 하나로 옮김. 구독은 `PerformanceRecorder` 하나로 대체하고, 세션 `changed` 마다 `queue.push(recorder.take_steps())`
    - `step_results` 처리: CARD 단계면 피해는 `damage_totals()` 대상별 숫자 하나로 띄우고 나머지 이벤트(방어도·회복·로그 등)는 `_show_event` 그대로, INSTANT 면 `_show_event`. 이어서 `step.state` 로 각 토큰 `show_state`, `cell` 이 바뀐 토큰은 그 칸으로 옮김, ROUND_START 카운트도 여기서
    - `_on_changed`: 큐가 바쁘면 refresh·적 타이머를 미루고 `drained` 때 실행. `_on_finished` 도 바쁘면 결과 창을 `drained` 때
    - `_input_ok()` 에 `not _queue.is_busy()` 추가

- [ ] **Step 1: 실패하는 테스트** — `tests/ui/test_battle_screen.gd` 의 `_data()`/`_screen()` 헬퍼를 복사해 쓰고, 연출 씬은 Task 2 테스트처럼 코드로 만든 노드를 `PackedScene.pack()` 해서 카드의 `performance` 에 넣는다 (길이 0.3초, 0.1초 `hit`, 0.2초 `show_results`).
  - `test_card_without_performance_is_immediate`: 연출 없는 카드 사용 직후(await 없이) 적 토큰 HP 라벨이 깎인 값 — 기존 동작
  - `test_hp_waits_for_show_results`: 연출 카드 사용 직후 적 토큰 HP 라벨은 이전 값, `await wait_for_signal(queue.drained, 2.0)` 후 깎인 값
  - `test_input_ignored_while_playing`: 연출 중 `press_end_turn()` → 세션 active 그대로, `select_card(0)` → false
  - `test_result_waits_for_queue`: 적 HP 를 1 로 만든 데이터 + 연출 카드로 처치 → 직후 결과 오버레이 숨김, drained 후 보임
  - `test_two_enemy_cards_show_their_own_hp`: 적 손패를 연출 카드 2장으로 하고 `enemy_delay = 0` 상태에서 `session.step_enemy()` → 첫 `step_results` 시점의 아군 토큰 HP 라벨 == 첫 카드 후 값
  - `test_no_show_results_key_shows_at_end`: `show_results` 키 없는 연출 → drained 후 HP 깎임
  - `test_auto_return_after_move`: `move(-80,0,0.05)` 만 있는 연출 → drained 후 행위자 토큰 Sprite visible, PerformanceLayer 자식 0개
- [ ] **Step 2:** GUT → FAIL
- [ ] **Step 3:** 에디터에서 `battle_screen.tscn` 에 두 노드 추가 (MCP `scene-node-add` 또는 에디터 끈 상태 헤드리스 저장)
- [ ] **Step 4:** 스크립트 구현
- [ ] **Step 5:** GUT → 새 테스트 PASS, 기존 `tests/ui/` 전부 PASS
- [ ] **Step 6:** 커밋 `feat: performance queue plays card performances before showing results`

### Task 4: 기본 피격 반응 (흔들림 ×3 · 피격 이펙트 · 효과음 + 음높이 무작위)

설계 "hit() 한 번에 일어나는 것" 1~5 + 타격감 4번.

**Files:**
- Create: `Scripts/ui/shaker.gd`
- Modify: `Scripts/ui/battle_screen.gd`, `Scenes/ui/battle_screen/battle_screen.tscn` (자식 `HitSound`: AudioStreamPlayer, unique)
- Test: `tests/ui/test_shaker.gd`, `tests/ui/test_battle_screen_performance.gd`

**Interfaces:**
- Produces:
  - `class_name Shaker extends RefCounted` — `static func shake(node: CanvasItem, strength: float, time: float, rng: RandomNumberGenerator) -> void`: node 의 지금 `position` 을 기준으로, 매 프레임 세기 × 남은 비율 안의 무작위 오프셋, `time` 뒤 정확히 원래 위치. 같은 노드에 겹쳐 부르면 원래 위치를 잃지 않음 (노드 meta 에 기준 위치 저장)
  - `BattleScreen` export: `hit_effect: PackedScene`, `hit_sound: AudioStream`, `hit_shake := 6.0`(화면), `hit_unit_shake := 4.0`(캐릭터 그림·UI), `shake_time := 0.2`, `pitch_jitter := 0.08`
  - `queue.hit` 처리: 대상(`step.hit_targets()`)마다 토큰 Sprite·`ui_box()` 흔들기, 화면(루트 자신) 흔들기(카드값 ≥ 0 이면 그 값), 대상 토큰 중심에 이펙트 인스턴스(PerformanceLayer), `HitSound` 에 스트림 넣고 `pitch_scale = 1 ± pitch_jitter` 무작위 후 재생. null 이면 그 항목 건너뜀
- [ ] **Step 1: 실패하는 테스트**
  - `test_shake_returns_to_origin`: Node2D position (10,10), `shake(n, 5, 0.1, rng)` → 한 프레임 뒤 position != (10,10) 이고 거리 ≤ 5, 0.2초 뒤 == (10,10)
  - `test_overlapping_shakes_keep_origin`: 0.05초 간격으로 두 번 → 끝나면 (10,10)
  - `test_hit_shakes_target_ui`(performance 테스트): `queue.hit` 직후 대상 토큰 `ui_box().position` 이 원래와 다름
- [ ] **Step 2:** GUT → FAIL
- [ ] **Step 3:** `HitSound` 노드 추가(에디터), 구현
- [ ] **Step 4:** GUT → PASS
- [ ] **Step 5:** 커밋 `feat: hit reaction — random decaying shake, hit effect, pitched hit sound`

### Task 5: 히트스톱 (타격감 1)

**Files:** Modify `Scripts/ui/battle_screen.gd`, `Scripts/ui/performance_queue.gd`; Test `tests/ui/test_battle_screen_performance.gd`

- `BattleScreen` export `hitstop_time := 0.07`. `hit` 때 연출 씬 `set_paused(true)` + 대상 토큰 Sprite `speed_scale = 0`, `get_tree().create_timer(t)` 뒤 되돌림. 연출 씬 tween(이동)도 그동안 멈춤 → 큐가 만든 tween 을 `pause()/play()`
- [ ] **Step 1:** 테스트 `test_hitstop_pauses_performance`: hit 직후 연출 씬 AnimationPlayer `speed_scale == 0`, 0.15초 뒤 1
- [ ] **Step 2:** FAIL 확인 → **Step 3:** 구현 → **Step 4:** PASS
- [ ] **Step 5:** 커밋 `feat: hitstop on hit`

### Task 6: 피격 번쩍임 + 넉백 (타격감 2·3)

**Files:** Modify `Scripts/ui/battle_screen.gd`; Test `tests/ui/test_battle_screen_performance.gd`

- 번쩍임: 대상 Sprite `modulate` 를 `Color(3,3,3)`(HDR 흰빛, 셰이더 없이) 로 했다가 `flash_time := 0.08` 동안 흰색으로. *(셰이더가 필요해 보이면 그때)*
- 넉백: export `knockback := 12.0`(픽셀, 카드값 우선). 대상 Sprite 를 행위자 반대 방향(x 부호 = 대상 x − 행위자 x)으로 즉시 밀고 `knockback_return := 0.25` 동안 ease-out 으로 복귀. 흔들림과 겹쳐도 원래 위치로 돌아와야 함 (Shaker 와 같은 meta 기준 위치 사용)
- [ ] **Step 1:** 테스트 `test_hit_flashes_target` (직후 modulate.r > 1), `test_knockback_returns` (0.4초 뒤 Sprite position == 원래)
- [ ] **Step 2~4:** FAIL → 구현 → PASS
- [ ] **Step 5:** 커밋 `feat: hit flash and knockback`

### Task 7: 숫자 강조 · 처치 강조 · 치명타 강조 (타격감 5·6·7)

**Files:**
- Modify: `Scripts/battle/battle_event.gd` (`var crit := false`), `Scripts/battle/battle.gd` (`apply_damage(..., crit := false)` 마지막 인자 추가 → DEALT/TAKEN 이벤트에 실음), `Scripts/cards/effects/damage_effect.gd` (판정 결과 전달), `Scripts/performances/performance_step.gd` (`func crit_targets() -> Array[BattleUnit]`, `func killed() -> Array[BattleUnit]`), `Scripts/ui/float_number.gd` (`pop(value, color, scale := 1.0)` 튀어나왔다 줄어드는 스케일), `Scripts/ui/battle_screen.gd`
- Test: `tests/battle/test_battle_damage.gd`, `tests/performances/test_performance_recorder.gd`, `tests/ui/test_battle_screen_performance.gd`

- 숫자 크기: `1.0 + clamp(피해 / 대상 최대HP, 0, 1) × big_number_boost(0.6)`. 치명이면 색 `crit_color := Color("ffd23f")`, 크기 × `crit_number_scale := 1.3`
- 처치 강조: 그 단계에 `killed()` 가 있으면 `show_results` 순간에 화면 흔들림·히트스톱을 한 번 더, 세기·시간 × `kill_boost := 1.8`. *(제 판단: 어느 hit 가 마지막인지 미리 알 수 없어서, 결과가 보이는 순간에 강조)*
- 치명 강조: 치명 대상이 있으면 `show_results` 때 화면 흔들림 추가 1회(× 1.3)
- [ ] **Step 1: 실패하는 테스트**
  - `test_crit_flag_on_damage_event` (battle): 치명확률 100 → DAMAGE_TAKEN `crit == true`, 0 → false. 피해 수치는 기존 테스트 그대로
  - `test_killed_and_crit_targets` (recorder)
  - `test_bigger_damage_bigger_number` (ui): 적 최대HP 대비 큰 피해의 FloatNumber scale > 작은 피해
- [ ] **Step 2~4:** FAIL → 구현 → 전체 GUT PASS
- [ ] **Step 5:** 커밋 `feat: emphasize big, killing and critical hits`

### Task 8: 줌 펀치 키 (타격감 8)

**Files:** Modify `Scripts/ui/performance_queue.gd`, `Scripts/ui/battle_screen.gd`; Test `tests/ui/test_battle_screen_performance.gd`

- `zoom_requested(strength, time)` → 화면 루트 `pivot_offset` 을 대상 토큰 중심으로, `scale` 을 `1 + strength` 로 즉시 → `time` 동안 1 로. 끝나면 `pivot_offset` 원래대로
- [ ] **Step 1:** 테스트 `test_zoom_returns_to_one` (0.05초 뒤 scale.x > 1, time+0.1초 뒤 == 1)
- [ ] **Step 2~4:** FAIL → 구현 → PASS
- [ ] **Step 5:** 커밋 `feat: zoom punch performance key`

### Task 9: 브람 시험 연출 + 진행 기록

**Files:**
- Create (에디터에서): `Scenes/performances/bram_stone_fist.tscn` — 루트 Node2D + `card_performance.gd`, `%Actor`(bram_frames 미리보기, Texture Filter 는 그림 종류에 맞게), `%AnimationPlayer` 의 `perform`: 0.0 Actor `idle` → `move(-120, 0, 0.15)` → 0.2 Actor `punch` → 0.3 `hit()` → 0.3 `show_results()` → 0.6 Actor `idle` (길이 0.7). 수치는 화면 보고 조정
- Modify (인스펙터): `cards/data/브람/돌주먹.tres` 의 `performance`
- Modify: `docs/progress.md` (전투 연출 줄 추가, 마지막 갱신 날짜), 설계 문서 상태 → "구현됨"

- [ ] **Step 1:** 에디터에서 씬 만들고 카드에 연결 (MCP 또는 인스펙터 안내)
- [ ] **Step 2:** 게임 실행 → 시험 전투에서 돌주먹 사용: 이동 → 펀치 → 흔들림·히트스톱·번쩍임·넉백·숫자 → 복귀, 연출 중 입력 막힘, 적 차례는 연출 뒤 진행 확인. 사용자에게 화면 확인 요청
- [ ] **Step 3:** 전체 GUT PASS
- [ ] **Step 4:** 커밋 `feat: Bram stone fist performance` / `docs: progress — card performance`
