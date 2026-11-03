# 카드·효과·턴 시스템 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카드·상태(버프/디버프/패시브)·장비가 같은 효과 부품을 조합해 동작하는 전투 로직을, 화면 없이 테스트 가능한 형태로 만든다.

**Architecture:** 전투 로직은 전부 `RefCounted`/`Resource`(씬·오토로드 없음). `Battle`이 유닛·격자·턴 순서·이벤트 관리자(`BattleEvents`)를 소유하고, 카드와 상태는 `.tres`로 조합되는 `CardEffect`/`CardCost`/`ValueSource` 부품을 실행한다. 상태의 트리거는 `BattleEvents`에 구독해서 반응한다.

**Tech Stack:** Godot 4.7.2, GDScript(정적 타입), GUT v9.7.1

**Spec:** `docs/superpowers/specs/2026-11-03-card-effect-system-design.md`

## Global Constraints

- Godot 실행 파일(콘솔): `C:/Users/User/Desktop/Godot_v4.7.2-stable_win64_console.exe` — 아래에서 `$GODOT`
- 테스트 전체 실행 (새 `class_name` 등록을 위해 import 먼저):
  ```bash
  "$GODOT" --headless --path . --import
  "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
  ```
  한 파일만: 두 번째 줄의 `-gdir=... -ginclude_subdirs` 대신 `-gtest=res://tests/<경로>.gd`. 통과 = 종료 코드 0, 요약에 실패 0.
- 파일·폴더 snake_case, `class_name` PascalCase, 시그널 snake_case 과거형 (CLAUDE.md)
- 전투 로직에 오토로드·씬 금지. 모든 난수는 `Battle.rng`(시드 주입)로. `Array.shuffle()`·`randf()` 전역 함수 금지
- 격자 3행 × 4열, 연쇄 깊이 상한 10, 기본 드로우 5장, 치명피해 기본 150(= ×1.5)
- 피해 수치 = `스탯 × % × 배율 × (치명 시 치명피해/100)`를 **전부 곱한 뒤 마지막에** 내림, 최소 1. 배율 ≤ 0이면 0(효과 없음)
- 스탯 = `floori(기본 × (1 + %합/100)) + 고정합`. % 보정은 더한다
- 같은 시점 효과 = 구독 순서. 우선순위 값 없음
- 카드 데이터 필드 이름은 웹 에디터 내보내기 형식에 맞춘다(스펙 4.2)

## Review Focus

1. 광역 카드가 첫 효과로 대상을 죽인 뒤 두 번째 효과가 그 시체에 적용되면 안 된다 → Task 5 `test_dead_targets_are_skipped`
2. 출혈로 자기 차례 드로우 페이즈에 죽은 유닛은 그 차례를 진행하면 안 된다 → Task 8 `test_unit_killed_by_bleed_loses_turn`
3. 덱과 버린 카드 더미가 둘 다 비었을 때 드로우가 오류 없이 멈춰야 한다 → Task 7 `test_draw_stops_when_deck_and_discard_empty`
4. 출혈을 건 유닛이 죽은 뒤에도 출혈 피해는 들어가고, 스태미너 회복은 아무도 받지 않는다 → Task 8 `test_bleed_with_dead_applier`
5. 이미 이번 라운드에 행동한 유닛은 속도가 올라도 다시 행동하지 않는다 → Task 7 `test_acted_unit_not_readded_on_speed_up`

---

## 파일 구조

```
battle/
  battle_types.gd        # 열거형·상수 (Task 1)
  battle_event.gd        # 이벤트 1건 (Task 2)
  battle_events.gd       # 구독·발행 (Task 2)
  unit_data.gd           # 유닛 기본 데이터 Resource (Task 3)
  battle_unit.gd         # 전투 중 유닛 상태 + 스탯 계산 (Task 3)
  status_instance.gd     # 유닛에 붙은 상태 1개 (Task 3)
  effect_context.gd      # 효과 1회 실행 컨텍스트 (스펙의 CardPlay) (Task 3)
  battle.gd              # 격자·피해·상태·카드·턴·이동·적 AI (Task 4~10)
  turn_order.gd          # 속도 순 행동 순서 (Task 7)
cards/
  card_data.gd           # (Task 3)
  card_cost.gd, card_condition.gd, card_effect.gd   # 기반 클래스 (Task 3)
  costs/status_cost.gd                              # (Task 6)
  conditions/has_status_condition.gd                # (Task 6)
  effects/damage_effect.gd, block_effect.gd, heal_effect.gd,
          apply_status_effect.gd, modify_stacks_effect.gd,
          script_effect.gd (Task 5), draw_effect.gd (Task 7)
  values/value_source.gd, fixed_value.gd, stack_count_value.gd,
         consumed_value.gd, event_amount_value.gd, missing_hp_percent_value.gd  # (Task 3)
statuses/
  status_data.gd, status_trigger.gd, stat_modifier.gd   # (Task 3)
  equipment_data.gd                                     # (Task 3)
tests/
  helpers/fixture.gd       # 유닛·카드·상태 생성 도우미 (Task 3에서 시작, 이후 확장)
  helpers/flag_script.gd   # ScriptEffect 테스트용 (Task 5)
  test_smoke.gd, battle/test_*.gd, cards/test_*.gd
```

`battle.gd`는 한 파일이지만 Task마다 섹션 주석(`# --- 격자 ---` 등)으로 나눠 추가한다. 600줄을 넘으면 그 Task에서 분리를 제안한다.

---

### Task 1: 브랜치, GUT 설치, 공통 타입

**Files:**
- Create: `addons/gut/` (GUT v9.7.1), `battle/battle_types.gd`, `tests/test_smoke.gd`
- Commit 포함: 스펙, 이 계획서, `CLAUDE.md`, `addons/godot_mcp_*`, `addons/auto_reload`

**Interfaces:**
- Produces: `class_name BattleTypes` (아래 Step 4의 열거형·상수 전부)

- [ ] **Step 1: 브랜치 생성**

```bash
git checkout -b feat/card-effect-system
```

- [ ] **Step 2: GUT v9.7.1 설치** — `https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.zip`을 스크래치 폴더에 받아 풀고, 그 안의 `addons/gut` 폴더만 프로젝트 `addons/gut`로 복사한다. 실행해서 확인:

Run: `"$GODOT" --headless --path . --import` → 오류 없이 종료.
Godot 4.7.2에서 GUT 로드 오류가 나면 멈추고 보고한다(다른 버전으로 임의 교체 금지).

- [ ] **Step 3: 실패하는 테스트** `tests/test_smoke.gd`

```gdscript
extends GutTest

func test_constants():
	assert_eq(BattleTypes.GRID_ROWS, 3)
	assert_eq(BattleTypes.GRID_COLS, 4)
	assert_eq(BattleTypes.CHAIN_LIMIT, 10)
	assert_eq(BattleTypes.DEFAULT_DRAW, 5)
```

Run: 전체 테스트 → FAIL (`BattleTypes` 없음)

- [ ] **Step 4: `battle/battle_types.gd` 작성** (`class_name BattleTypes extends RefCounted`) — 값은 그대로:

```gdscript
enum Side { ALLY, ENEMY }
enum Stat { HP, SP, ATTACK, DEFENSE, SPEED, MOVE, CRIT_RATE, CRIT_DAMAGE, AGGRO, STAMINA }
enum Event {
	BATTLE_START, BATTLE_END, ROUND_START, ROUND_END,
	TURN_START, DRAW_PHASE, STANDBY_PHASE, END_PHASE, TURN_END,
	BEFORE_CARD_PLAYED, AFTER_CARD_PLAYED, CARD_DRAWN, CARD_DISCARDED,
	DAMAGE_DEALT, DAMAGE_TAKEN, HEALED, BLOCK_GAINED, BLOCK_RESET,
	STATUS_APPLIED, STATUS_REMOVED, UNIT_MOVED, UNIT_DIED, STAMINA_BROKEN,
	TURN_ORDER_CHANGED,
}
enum Target { TARGETS, SELF, OWNER, ALL_ALLIES, ALL_ENEMIES }  # SELF=ctx.actor, OWNER=ctx.owner
enum Who { ACTOR, OWNER }
enum Filter { ANY, OWNER_IS_ACTOR, OWNER_IS_TARGET }
enum StatusTag { BUFF, DEBUFF, PASSIVE }
enum ModKind { PERCENT, FLAT }
const GRID_ROWS := 3
const GRID_COLS := 4
const CHAIN_LIMIT := 10
const DEFAULT_DRAW := 5
```

- [ ] **Step 5: 통과 확인** — Run: 전체 테스트 → PASS

- [ ] **Step 6: Commit**

```bash
git add addons/ battle/ tests/ docs/ CLAUDE.md
git commit -m "chore: add GUT, battle types, card-effect spec and plan"
```

---

### Task 2: 이벤트 관리자

**Files:**
- Create: `battle/battle_event.gd`, `battle/battle_events.gd`
- Test: `tests/battle/test_battle_events.gd`

**Interfaces:**
- Produces:
  - `class_name BattleEvent extends RefCounted` — 필드 `type: int`, `actor`, `target`, `card`, `source`(모두 Variant: 유닛 클래스가 Task 3에 생기므로), `amount: int = 0`; `static func make(type: int, actor = null, target = null, amount: int = 0, source = null, card = null) -> BattleEvent`
  - `class_name BattleEvents extends RefCounted` — `subscribe(type: int, handler: Callable) -> int`, `unsubscribe(id: int) -> void`, `emit(event: BattleEvent) -> void`, `is_subscribed(id: int) -> bool`

- [ ] **Step 1: 실패하는 테스트** — 각 테스트는 `var log := []`에 핸들러가 이름을 append.

```gdscript
func test_handlers_run_in_subscription_order():
	# a, b, c 순서로 TURN_START 구독 → emit → log == ["a","b","c"]
func test_only_matching_type_runs():
	# TURN_START 구독, TURN_END emit → log == []
func test_unsubscribed_during_emit_is_skipped():
	# a의 핸들러가 b를 unsubscribe → emit → log == ["a","c"]
func test_subscribed_during_emit_runs_from_next_emit():
	# a의 핸들러가 (한 번만) d를 subscribe → 1회 emit: ["a","b"], 2회 emit 후 log 끝 3개 == ["a","b","d"]
func test_chain_depth_limit():
	# 핸들러가 같은 이벤트를 다시 emit → 호출 횟수 == BattleTypes.CHAIN_LIMIT (무한 루프 아님)
```

Run: `-gtest=res://tests/battle/test_battle_events.gd` → FAIL

- [ ] **Step 2: 구현** — 구독 목록은 `type → Array[{id, handler}]`. `emit`은 시작 시점 목록의 복사본을 돌되, 각 호출 직전 `is_subscribed(id)`가 false면 건너뛴다. 깊이 카운터가 `CHAIN_LIMIT` 이상이면 `push_warning` 후 return.

- [ ] **Step 3: 통과 확인** → PASS

- [ ] **Step 4: Commit** — `git commit -m "feat: battle event bus with ordered subscriptions and chain limit"`

---

### Task 3: 데이터 모델, 유닛, 스탯, 상태 중첩, 배율

**Files:**
- Create: `battle/unit_data.gd`, `battle/battle_unit.gd`, `battle/status_instance.gd`, `battle/effect_context.gd`, `cards/card_data.gd`, `cards/card_cost.gd`, `cards/card_condition.gd`, `cards/card_effect.gd`, `cards/values/*.gd` (6개), `statuses/status_data.gd`, `statuses/status_trigger.gd`, `statuses/stat_modifier.gd`, `statuses/equipment_data.gd`
- Create: `tests/helpers/fixture.gd`
- Test: `tests/battle/test_battle_unit.gd`, `tests/cards/test_value_sources.gd`

**Interfaces:**
- Produces (Resource는 모두 `@export`):
  - `CardData extends Resource`: `id: String`, `deck_id: String`, `name_ko`, `name_en`, `description_ko`, `description_en: String`, `sp: int = 1`, `cost: int = 0`, `category: String = "attack"`(attack/skill/special/enemy), `attack_type: String = "melee"`(melee/ranged/ally/self), `area: Array[Vector2i]`, `keywords: PackedStringArray`, `art: String`, `upgrades: Array[CardData]`, `costs: Array[CardCost]`, `conditions: Array[CardCondition]`, `effects: Array[CardEffect]`
  - `CardCost extends Resource`: `func can_pay(ctx: EffectContext) -> bool` (기본 true), `func pay(ctx: EffectContext) -> void`
  - `CardCondition extends Resource`: `func check(ctx: EffectContext) -> bool` (기본 true)
  - `CardEffect extends Resource`: `target: int = BattleTypes.Target.TARGETS`, `func apply(ctx: EffectContext) -> void` (기본 없음), `func resolve_targets(ctx: EffectContext) -> Array[BattleUnit]` — TARGETS=ctx.targets, SELF=[ctx.actor], OWNER=[ctx.owner], ALL_ALLIES/ALL_ENEMIES=ctx.battle의 `allies_of/enemies_of(ctx.owner)`; **null과 죽은 유닛은 제외**
  - `ValueSource extends Resource`: `func evaluate(ctx: EffectContext) -> float`
    - `FixedValue(value: float)`, `StackCountValue(status_id: String, of: int = Who.OWNER)`, `ConsumedValue(status_id)` → `ctx.values.get("consumed:" + id, 0)`, `EventAmountValue` → `ctx.event.amount`(없으면 0), `MissingHpPercentValue(of: int = Who.OWNER)` → `(1 - hp / 최대HP) × 100`
  - `StatModifier extends Resource`: `stat: int`, `kind: int = ModKind.PERCENT`, `amount: float`, `scale: ValueSource`(null이면 1) — 기여값 = `amount × scale`
  - `StatusTrigger extends Resource`: `event: int`, `filter: int = Filter.ANY`, `source_status_id: String = ""`, `effects: Array[CardEffect]`
  - `StatusData extends Resource`: `id: String`, `tag: int`, `uses_stacks: bool = true`, `keeps_block: bool = false`, `triggers: Array[StatusTrigger]`, `modifiers: Array[StatModifier]`, `replacements: Dictionary`(CardData → CardData)
  - `EquipmentData extends Resource`: `statuses: Array[StatusData]`
  - `UnitData extends Resource`: `display_name`, `max_hp = 100`, `max_sp = 3`, `attack = 10`, `defense = 10`, `speed = 10`, `move = 2`, `crit_rate = 0`(%), `crit_damage = 150`, `aggro = 0`, `max_stamina = 100`, `draw_count = DEFAULT_DRAW`, `is_boss = false`, `deck: Array[CardData]`, `passives: Array[StatusData]`, `equipment: Array[EquipmentData]`
  - `StatusInstance extends RefCounted`: `data: StatusData`, `owner: BattleUnit`, `applier: BattleUnit`, `stacks: int`, `active: bool = true`, `subscription_ids: Array[int]`
  - `EffectContext extends RefCounted`: `battle`(Variant), `actor: BattleUnit`, `owner: BattleUnit`, `card: CardData`, `source`(Variant), `targets: Array[BattleUnit]`, `values: Dictionary`, `event: BattleEvent`; `func who(w: int) -> BattleUnit`
  - `BattleUnit extends RefCounted`: `_init(data: UnitData, side: int, cell: Vector2i)`; 필드 `data, side, cell, hp, sp, block = 0, stamina, alive = true, statuses: Array[StatusInstance], deck/hand/discard: Array[CardData], move_left = 0, boss_index = 0, initial_index = 0, battle`(Variant); 생성 시 hp=max_hp, stamina=max_stamina
    - `get_stat(stat: int) -> int` — 기본값(UnitData) + 모든 상태의 modifiers, Global Constraints 공식
    - `add_status(status: StatusData, stacks: int, applier: BattleUnit) -> StatusInstance` — 같은 id가 있으면 수치를 더하고 applier 갱신, 같은 인스턴스 반환
    - `get_status(id: String) -> StatusInstance`, `stacks_of(id: String) -> int`
    - `change_stacks(id: String, delta: int) -> bool` — 결과가 ≤0이고 `uses_stacks`면 제거하고 true(제거됨) 반환
    - `remove_status(id: String) -> StatusInstance` — 제거한 인스턴스(`active=false`) 반환
- `tests/helpers/fixture.gd` (`class_name Fixture extends RefCounted`, static): `unit(side: int, cell: Vector2i, stats: Dictionary = {}) -> BattleUnit`(stats 키는 UnitData 필드명), `status(id: String, uses_stacks := true) -> StatusData`, `modifier(stat, kind, amount, scale = null) -> StatModifier`

- [ ] **Step 1: 실패하는 테스트** `tests/battle/test_battle_unit.gd`

```gdscript
func test_stat_percent_then_flat():
	# attack 100, 상태 modifiers: +20%, +10%, +15 고정 → get_stat(ATTACK) == 145
func test_stat_negative_percent():
	# speed 10, -50% → 5
func test_modifier_scaled_by_stacks():
	# 상태 수치 3, modifier ATTACK +10% scale=StackCountValue(그 상태) → attack 100 → 130
func test_status_stacks_merge_and_applier_updates():
	# A가 bleed 3, B가 bleed 2 → statuses.size()==1, stacks_of("bleed")==5, get_status("bleed").applier==B
func test_change_stacks_to_zero_removes():
	# bleed 5, change_stacks(-5) → true, get_status("bleed")==null
func test_passive_without_stacks_is_not_removed():
	# uses_stacks=false, change_stacks(-1) → false, 여전히 존재
```

`tests/cards/test_value_sources.gd`

```gdscript
func test_fixed(): # FixedValue(2).evaluate(ctx) == 2.0
func test_stack_count_of_owner(): # owner bleed 4 → 4.0
func test_consumed(): # ctx.values["consumed:blood"]=5 → 5.0, 없는 id → 0.0
func test_event_amount(): # ctx.event.amount=30 → 30.0, event null → 0.0
func test_missing_hp_percent(): # hp 25 / max 100 → 75.0
```

Run: 두 파일 → FAIL

- [ ] **Step 2: 위 Interfaces대로 파일 작성.** `get_stat`의 modifier 평가용 컨텍스트는 `actor=owner=self`.

- [ ] **Step 3: 통과 확인** → PASS

- [ ] **Step 4: Commit** — `git commit -m "feat: data model, battle unit stats, status stacking, value sources"`

---

### Task 4: Battle 기본 — 격자, 피해, 회복, 방어도, 상태 API

**Files:**
- Create: `battle/battle.gd`
- Test: `tests/battle/test_battle_grid.gd`, `tests/battle/test_battle_damage.gd`

**Interfaces:**
- Consumes: Task 2·3 전부
- Produces: `class_name Battle extends RefCounted`
  - `_init(units: Array[BattleUnit], seed: int = 0)` — `unit.battle = self`, `initial_index` = 배열 순서. 필드 `units`, `events: BattleEvents`, `rng: RandomNumberGenerator`(seed 적용), `stamina_break_status: StatusData = null`
  - 격자: `unit_at(side: int, cell: Vector2i) -> BattleUnit`(살아 있는 유닛만), `living(side: int) -> Array[BattleUnit]`, `allies_of(u) -> Array[BattleUnit]`(자신 포함), `enemies_of(u) -> Array[BattleUnit]`, `melee_target(u: BattleUnit) -> BattleUnit`, `area_targets(origin: BattleUnit, area: Array[Vector2i]) -> Array[BattleUnit]`
  - 좌표: 각 편 격자의 `Vector2i(열, 행)`, 열 0 = 뒤, 열 `GRID_COLS-1` = 맨 앞(양 편 동일). 오프셋 +x = 앞쪽
  - 피해: `apply_damage(actor: BattleUnit, target: BattleUnit, amount: int, source = null) -> void`
  - `heal(target: BattleUnit, amount: int, source = null) -> void`, `add_block(target: BattleUnit, amount: int, source = null) -> void`
  - 상태: `apply_status(target: BattleUnit, status: StatusData, stacks: int, applier: BattleUnit) -> StatusInstance`(STATUS_APPLIED 발행), `change_stacks(target, id: String, delta: int) -> void`(제거되면 STATUS_REMOVED), `remove_status(target, id: String) -> void`
  - 사망: hp ≤ 0 → hp=0, alive=false, UNIT_DIED 발행 (`_on_unit_died(u)` 내부 함수로 둠 — Task 7에서 확장)

`apply_damage` 순서 (amount ≤ 0이면 아무것도 안 함):
1. `blocked = min(target.block, amount)`, block −= blocked, hp −= amount − blocked
2. 대상 스태미너 −= amount(0 미만 금지). 0보다 컸다가 0이 됐을 때만 STAMINA_BROKEN 발행 + `stamina_break_status`가 있으면 `apply_status(target, 그것, 1, actor)`
3. actor가 null이 아니고 살아 있으면 스태미너 += `amount / 2`(정수 나눗셈), 최대치 초과 금지
4. DAMAGE_DEALT, DAMAGE_TAKEN 순서로 발행 (둘 다 actor=actor, target=target, amount=amount, source=source)
5. hp ≤ 0이면 사망 처리

- [ ] **Step 1: 실패하는 테스트** `test_battle_grid.gd`

```gdscript
func test_melee_hits_front_most_enemy_in_same_row():
	# ally (3,1); enemies (1,1), (2,1), (3,0) → melee_target == (2,1)의 적
func test_melee_none_when_row_empty():
	# ally (3,2), 2행에 적 없음 → null
func test_melee_skips_dead():
	# (2,1) 적 alive=false, (1,1) 적 → (1,1)의 적
func test_area_targets_offsets_within_origin_side():
	# 적 (2,1),(3,1),(2,2); origin=(2,1); area [(0,0),(1,0),(0,1),(0,-2)] → 정확히 {(2,1),(3,1),(2,2)} 3명 (격자 밖·빈 칸 무시)
func test_empty_area_is_single_target():
	# area [] → [origin]
```

`test_battle_damage.gd`

```gdscript
func test_block_absorbs_first_and_stamina_counts_full_damage():
	# 대상 block 20, hp 100, stamina 100; 피해 30 → block 0, hp 90, stamina 70
func test_attacker_recovers_half_stamina():
	# 공격자 stamina 50/100, 피해 30 → 65; 피해 31 → 65 (내림)
func test_attacker_stamina_capped():
	# 공격자 stamina 95/100, 피해 30 → 100
func test_damage_events_in_order():
	# 기록: [DAMAGE_DEALT, DAMAGE_TAKEN], 둘 다 amount 30
func test_stamina_broken_once():
	# 대상 stamina 10, 피해 30 → 0, STAMINA_BROKEN 1회; 다시 피해 → 추가 발행 없음
func test_stamina_break_status_applied():
	# battle.stamina_break_status = Fixture.status("exhausted") → 0이 되면 그 상태 보유
func test_death():
	# hp 10, 피해 30 → hp 0, alive false, UNIT_DIED 1회
func test_null_actor_damage():
	# actor null로 피해 → 오류 없음, 대상만 깎임
func test_heal_capped():
	# hp 90/100, heal 30 → 100, HEALED 발행
func test_apply_status_events():
	# apply_status → STATUS_APPLIED; change_stacks로 0 → STATUS_REMOVED
```

Run → FAIL

- [ ] **Step 2: `battle/battle.gd` 구현**
- [ ] **Step 3: 통과 확인** → PASS
- [ ] **Step 4: Commit** — `git commit -m "feat: battle grid, damage pipeline, block, stamina, status API"`

---

### Task 5: 효과 부품

**Files:**
- Create: `cards/effects/damage_effect.gd`, `block_effect.gd`, `heal_effect.gd`, `apply_status_effect.gd`, `modify_stacks_effect.gd`, `script_effect.gd`, `tests/helpers/flag_script.gd`
- Test: `tests/cards/test_effects.gd`

**Interfaces:**
- Consumes: `CardEffect.resolve_targets`, `Battle.apply_damage/heal/add_block/apply_status/change_stacks`, `Battle.rng`
- Produces (모두 `extends CardEffect`, 필드는 `@export`):
  - `DamageEffect`: `percent: float = 100`, `use_flat: bool = false`, `flat: int = 0`, `multiplier: ValueSource`, `can_crit: bool = true`
  - `BlockEffect`: `percent: float = 100`, `use_flat`, `flat`, `multiplier`
  - `HealEffect`: `percent: float = 100`, `multiplier`
  - `ApplyStatusEffect`: `status: StatusData`, `stacks: int = 1`, `multiplier`
  - `ModifyStacksEffect`: `status_id: String`, `delta: int = 1`, `multiplier`
  - `ScriptEffect`: `effect_script: GDScript` — `effect_script.new().apply(ctx)` (`script`는 Object 내장 속성이라 쓰지 않음)
  - 공통: 배율 = `multiplier.evaluate(ctx)` (null이면 1.0). **배율 ≤ 0이면 아무것도 안 함**
  - 스탯 주체 = `ctx.actor`, actor가 null이면 `ctx.owner`. 둘 다 null이고 `use_flat`이 아니면 아무것도 안 함
  - 수치 = `floori(기본 × 배율 [× 치명])`, 최소 1. 기본: Damage/Heal = 공격 × percent/100, Block = 방어 × percent/100, flat 모드면 `flat`
  - 치명: Damage만, 대상마다 `rng.randf() * 100 < 치명확률`이면 × 치명피해/100. actor가 null이면 치명 없음
  - ApplyStatus 수치 = `floori(stacks × 배율)`, applier = ctx.actor; ModifyStacks 변화량 = `floori(delta × 배율)`

- [ ] **Step 1: 실패하는 테스트** (fixture로 Battle과 EffectContext를 직접 구성, 기본 치명확률 0)

```gdscript
func test_damage_percent_with_multiplier():     # 공격 100, 40%, FixedValue(5) → 대상 hp −200
func test_damage_floor_min_one():               # 공격 3, 10% → 1
func test_zero_multiplier_does_nothing():       # FixedValue(0) → 피해·이벤트 없음
func test_crit_floors_after_multiplying():      # 공격 10, 15%, 치명확률 100, 치명피해 150 → 2 (먼저 내림하면 1)
func test_flat_damage_goes_through_block():     # flat 1 × StackCountValue(bleed 4 on owner), 대상 block 3 → block 0, hp −1
func test_dead_targets_are_skipped():           # targets에 죽은 유닛 포함 → 그 유닛 피해 0, DAMAGE 이벤트는 살아 있는 대상분만
func test_kill_then_second_effect_skips_corpse(): # 효과1 피해로 사망 → 효과2 ApplyStatus가 그 대상에 적용 안 됨
func test_block_effect():                       # 방어 50, 80% → block 40; flat 7 → +7
func test_heal_effect():                        # 공격 20, 50%, hp 50/100 → 60
func test_apply_status_effect():                # stacks 2 × FixedValue(2) → 4, applier == actor
func test_modify_stacks_with_event_amount():    # event.amount 30, delta 1, EventAmountValue → +30
func test_script_effect():                      # flag_script.gd가 ctx.values["ran"]=true → true
```

Run → FAIL

- [ ] **Step 2: 구현**
- [ ] **Step 3: 통과 확인** → PASS
- [ ] **Step 4: Commit** — `git commit -m "feat: damage, block, heal, status, stacks, script effects"`

---

### Task 6: 카드 사용 — 조건, 비용, 대상, 대체

**Files:**
- Create: `cards/costs/status_cost.gd`, `cards/conditions/has_status_condition.gd`
- Modify: `battle/battle.gd` (`# --- 카드 ---` 섹션)
- Test: `tests/cards/test_card_play.gd`

**Interfaces:**
- Consumes: Task 3~5
- Produces:
  - `StatusCost extends CardCost`: `status_id: String`, `amount: int = 1`, `consume_all: bool = false`, `min_stacks: int = 1` — 지불한 양을 `ctx.values["consumed:" + status_id]`에 기록, 소모는 `battle.change_stacks`
  - `HasStatusCondition extends CardCondition`: `status_id`, `min_stacks: int = 1` (actor 기준)
  - `Battle.effective_card(u: BattleUnit, card: CardData) -> CardData` — u의 상태 중 `replacements`에 card가 있으면 대체 카드
  - `Battle.can_play(u: BattleUnit, card: CardData, origin: BattleUnit = null) -> String` — "" = 가능, 아니면 이유: `"dead"`, `"not_in_hand"`, `"sp"`, `"melee_target"`, `"origin"`, `"cost"`, `"condition"` (이 순서로 검사)
  - `Battle.play_card(u, card, origin: BattleUnit = null) -> bool`
- 대상 규칙(대체 후 카드 기준): melee = origin 무시, `melee_target(u)`(없으면 `"melee_target"`) / ranged = origin이 살아 있는 적 / ally = origin이 살아 있는 아군(자신 포함) / self = origin = u. 그 외 `"origin"`
- `play_card` 순서: BEFORE_CARD_PLAYED → `u.sp -= 카드.sp` → costs 차례로 pay → `ctx.targets = area_targets(origin, 카드.area)` → effects 차례로 apply → **원본** 카드를 hand에서 discard로 → AFTER_CARD_PLAYED. ctx: actor=owner=u, card=source=대체 후 카드
- SP는 `card.sp`로만 비용 처리(별도 SpCost 클래스 없음, 스펙 4.2)

- [ ] **Step 1: 실패하는 테스트**

```gdscript
func test_insufficient_sp():                    # sp 1, 카드 sp 2 → can_play == "sp"
func test_fixed_status_cost():                  # cost amount 3: 수치 2 → "cost"; 수치 5 → play 성공, 남은 수치 2, values["consumed:x"]==3
func test_consume_all_blood_slash():            # 스펙 예시: 공격 100, 핏방울 5, consume_all, DamageEffect 40% × ConsumedValue → 적 hp −200, 핏방울 상태 제거됨
func test_consume_all_needs_min():              # 수치 0, min_stacks 1 → "cost"
func test_melee_requires_target_in_row():       # 같은 행 적 없음 → "melee_target"; 있으면 맨 앞 적만 피해
func test_ranged_origin_must_be_enemy():        # ranged인데 origin=아군 → "origin"; 적이면 ""
func test_has_status_condition():               # 수치 부족 → "condition"
func test_card_moves_to_discard_and_sp_spent(): # play 후 hand에 없음, discard에 있음, sp −카드.sp
func test_play_events_order():                  # BEFORE_CARD_PLAYED → DAMAGE_DEALT → AFTER_CARD_PLAYED
func test_card_replacement():                   # 상태 replacements {A: B} → A를 내면 B의 효과 실행, discard에는 A
```

Run → FAIL

- [ ] **Step 2: 구현**
- [ ] **Step 3: 통과 확인** → PASS
- [ ] **Step 4: Commit** — `git commit -m "feat: card play with costs, conditions, targeting, replacement"`

---

### Task 7: 덱과 턴 진행

**Files:**
- Create: `battle/turn_order.gd`, `cards/effects/draw_effect.gd`
- Modify: `battle/battle.gd` (`# --- 덱 ---`, `# --- 턴 ---` 섹션, `_on_unit_died` 확장, 상태 변경 후 속도 확인)
- Test: `tests/battle/test_turn_order.gd`, `tests/battle/test_turn_flow.gd`

**Interfaces:**
- Produces:
  - `TurnOrder extends RefCounted`: `start_round(units: Array[BattleUnit]) -> void`, `pop_next() -> BattleUnit`(없으면 null), `resort() -> void`, `remove(u: BattleUnit) -> void`, `remaining() -> Array[BattleUnit]`, `is_round_over() -> bool`. 정렬 키: 속도(`get_stat(SPEED)`) 내림차순 → ALLY 먼저 → `initial_index` 오름차순. 안정 정렬
  - `Battle.turn_order: TurnOrder`, `Battle.current: BattleUnit`
  - `Battle.start_battle() -> void` — 각 유닛 `deck = data.deck` 복사 후 rng로 섞기 → BATTLE_START → `start_round()`
  - `Battle.start_round() -> void` — 방어도 초기화(`keeps_block` 상태가 없는 유닛만, block>0이면 BLOCK_RESET 발행) → ROUND_START → `turn_order.start_round(살아 있는 유닛)`
  - `Battle.next_turn() -> BattleUnit` — 라운드가 끝났으면 ROUND_END → `start_round()`. 다음 유닛을 꺼내 `current`로 두고 반환(begin_turn은 호출하지 않음)
  - `Battle.begin_turn(u) -> bool` — TURN_START → `sp = get_stat(SP)` → `move_left = get_stat(MOVE)` → 드로우(아군 `data.draw_count`, 적 1장; 보스는 Task 10) → DRAW_PHASE → STANDBY_PHASE. 반환 = `u.alive`
  - `Battle.end_turn(u) -> void` — END_PHASE → 손패 전부 discard(장마다 CARD_DISCARDED) → TURN_END
  - `Battle.draw(u, n: int) -> void` — 덱이 비면 discard를 rng로 섞어 덱으로. 둘 다 비면 멈춤. 장마다 CARD_DRAWN
  - `DrawEffect extends CardEffect`: `count: int = 1` — 대상마다 `draw`
  - 속도 즉시 반영: `apply_status`/`change_stacks`/`remove_status` 끝에서 `_refresh_speeds()` — 남은 유닛의 속도를 이전 값(딕셔너리 캐시)과 비교해 하나라도 바뀌면 `turn_order.resort()` + TURN_ORDER_CHANGED
  - `_on_unit_died`: `turn_order.remove(u)` 추가. 그 뒤 `winner()`가 −1이 아니면 BATTLE_END(amount = 이긴 편) 1회 발행
  - `Battle.winner() -> int` — 한쪽 편이 전멸했으면 남은 편(`Side`), 아니면 −1
- 섞기: `rng`를 쓰는 Fisher–Yates를 `Battle._shuffle(arr: Array) -> void`로

- [ ] **Step 1: 실패하는 테스트** `test_turn_order.gd`

```gdscript
func test_sorted_by_speed():                     # 속도 5,9,7 → 9,7,5
func test_tie_ally_first_then_initial_index():   # 같은 속도: 적(idx0), 아군(idx1), 아군(idx2) → 아군1, 아군2, 적0
func test_round_progression():                   # 3명: next_turn 3회 각각 한 번씩, 4번째 호출에서 ROUND_END·ROUND_START 발행 후 첫 유닛
func test_speed_down_resorts_immediately():      # A10(행동함) / 남은 B(적)8, C(아군)6 → B에 속도 −50% 상태 → remaining == [C, B], TURN_ORDER_CHANGED 발행
func test_acted_unit_not_readded_on_speed_up():  # 이미 꺼낸 A에 속도 +100% → remaining에 A 없음
func test_dead_unit_removed():                   # 남은 B 사망 → remaining에 B 없음
func test_battle_end_when_side_wiped():          # 적 1명 사망 → winner() == ALLY, BATTLE_END 1회 (amount == ALLY)
```

`test_turn_flow.gd`

```gdscript
func test_begin_turn_refills_and_draws():        # 아군 max_sp 3, move 2, 덱 10장 → sp 3, move_left 2, hand 5
func test_enemy_draws_one():                     # 적 → hand 1
func test_end_turn_discards_whole_hand():        # hand 5 → end_turn → hand 0, discard 5, CARD_DISCARDED 5회
func test_reshuffle_when_deck_empty():           # deck 3, discard 2, draw 5 → hand 5, deck 0, discard 0
func test_draw_stops_when_deck_and_discard_empty(): # deck 2, discard 0, draw 5 → hand 2, 오류 없음
func test_block_reset_at_round_start():          # block 10 → start_round → 0, BLOCK_RESET
func test_keeps_block_status():                  # keeps_block 상태 보유 → block 유지
func test_same_seed_same_shuffle():              # seed 7로 두 번 start_battle → deck 순서 동일
func test_draw_effect():                         # DrawEffect count 2 → hand +2
```

Run → FAIL

- [ ] **Step 2: 구현**
- [ ] **Step 3: 통과 확인** (Task 1~6 테스트 포함 전체) → PASS
- [ ] **Step 4: Commit** — `git commit -m "feat: turn order with live speed resort, decks, turn flow"`

---

### Task 8: 상태 트리거, 패시브·장비 적용

**Files:**
- Modify: `battle/battle.gd` (`apply_status`에서 구독, `remove_status`/제거 시 해제, `start_battle`에서 패시브·장비 적용)
- Test: `tests/battle/test_status_triggers.gd`

**Interfaces:**
- 새 인스턴스가 생길 때만(중첩 시 아님) 각 `StatusTrigger`를 `events.subscribe(trigger.event, ...)`로 구독하고 id를 `instance.subscription_ids`에 저장. 제거 시 전부 `unsubscribe`, `active=false`
- 트리거 처리: `instance.active`가 false면 무시 → filter(`ANY` / `OWNER_IS_ACTOR`: `e.actor == owner` / `OWNER_IS_TARGET`: `e.target == owner`) → `source_status_id`가 있으면 `e.source is StatusData and e.source.id == source_status_id`일 때만 → EffectContext(`actor` = applier가 살아 있으면 applier 아니면 null, `owner` = 인스턴스 주인, `source` = 상태 데이터, `event` = e, `targets` = e.target이 있으면 [e.target]) → effects 차례로 apply
- `start_battle`: BATTLE_START 전에 각 유닛의 `data.passives`와 `data.equipment[*].statuses`를 `apply_status(u, s, 1, u)`

- [ ] **Step 1: 실패하는 테스트** (테스트 안에서 상태 데이터를 코드로 조합)

```gdscript
# bleed = DRAW_PHASE / OWNER_IS_ACTOR → DamageEffect(use_flat, flat 1, multiplier StackCountValue("bleed"), target OWNER)
func test_bleed_ticks_on_owner_draw_phase():     # A가 B에 bleed 4 → begin_turn(B) → B hp −4, A stamina +2
func test_bleed_with_dead_applier():             # A 사망 후 begin_turn(B) → B hp −4, 오류 없음, 아무도 회복 안 함
func test_unit_killed_by_bleed_loses_turn():     # B hp 3, bleed 4 → begin_turn(B) == false, B는 turn_order에 없음
func test_removed_status_stops_reacting():       # bleed 제거 후 begin_turn(B) → 피해 없음
# blood_armor = TURN_END / OWNER_IS_ACTOR → BlockEffect(use_flat, flat 1, multiplier StackCountValue("blood_armor"), target OWNER)
func test_blood_armor_blocks_on_turn_end():      # 수치 6 → end_turn → block 6
# blood_drop(A의 패시브) = DAMAGE_DEALT / OWNER_IS_ACTOR / source "bleed" → ModifyStacksEffect("blood_drop", 1, EventAmountValue, target OWNER)
func test_blood_drop_counts_only_bleed_damage(): # B 출혈 4 틱 → A blood_drop 4; A의 카드 피해 10 → 그대로 4
func test_equipment_flat_attack_at_battle_start(): # 장비 상태 ATTACK +5 고정, 기본 10 → start_battle 후 get_stat == 15
func test_passive_applied_at_battle_start():     # data.passives의 상태 보유, applier == 자신
```

Run → FAIL

- [ ] **Step 2: 구현**
- [ ] **Step 3: 통과 확인** (전체) → PASS
- [ ] **Step 4: Commit** — `git commit -m "feat: status triggers, passives and equipment"`

---

### Task 9: 이동

**Files:**
- Modify: `battle/battle.gd` (`# --- 이동 ---`)
- Test: `tests/battle/test_movement.gd`

**Interfaces:**
- Produces: `Battle.move_unit(u: BattleUnit, to: Vector2i) -> bool`, `Battle.path_length(u: BattleUnit, to: Vector2i) -> int`(도달 불가 -1)
- 규칙: 자기 편 격자 안, 상하좌우 한 칸 = 1, 다른 살아 있는 유닛 칸은 지나가거나 들어갈 수 없음(BFS). `path_length ≤ move_left`면 이동, `move_left -= 길이`, UNIT_MOVED(actor=u, amount=길이)

- [ ] **Step 1: 실패하는 테스트**

```gdscript
func test_move_within_range():           # move_left 2, (0,0)→(1,1) → true, cell (1,1), move_left 0
func test_move_too_far():                # move_left 1, (0,0)→(2,0) → false, 그대로
func test_cannot_enter_occupied():       # 목적지에 아군 → false
func test_must_path_around_units():      # (1,0),(1,1)에 아군, move_left 2, (0,0)→(2,0) → false (우회 길이 6)
func test_out_of_grid():                 # (0,0)→(4,0) → false
func test_move_enables_melee():          # 1행에 적만 있음, 아군 (3,0) → melee 카드 "melee_target"; (3,1)로 이동 → ""
```

Run → FAIL

- [ ] **Step 2: 구현**
- [ ] **Step 3: 통과 확인** → PASS
- [ ] **Step 4: Commit** — `git commit -m "feat: grid movement"`

---

### Task 10: 적 행동

**Files:**
- Modify: `battle/battle.gd` (`# --- 적 ---`, `begin_turn`의 보스 분기)
- Test: `tests/battle/test_enemy_ai.gd`

**Interfaces:**
- Produces: `Battle.run_enemy_turn(u: BattleUnit) -> void`
- 보스(`data.is_boss`)의 `begin_turn` 드로우: 덱에서 뽑지 않고 `data.deck[boss_index % 크기]`를 손패에 넣고 `boss_index += 1`
- `run_enemy_turn`: `begin_turn(u)`가 false면 return → 손패 첫 카드의 대상: melee=null, ranged=`rng`로 고른 살아 있는 적(아군 편 유닛), ally/self=u → `can_play == ""`면 `play_card` → `end_turn(u)`. 쓸 수 없으면 행동 없이 end_turn

- [ ] **Step 1: 실패하는 테스트**

```gdscript
func test_enemy_plays_drawn_card():          # 적 덱 = 근접 공격 1종, 같은 행에 아군 → 아군 hp 감소, 적 hand 0
func test_enemy_skips_unplayable():          # 같은 행에 아군 없음 → 아무도 피해 없음, 카드 discard, TURN_END 발행
func test_boss_follows_sequence():           # 보스 덱 [A, B] → 3턴 동안 A, B, A 순서로 사용 (AFTER_CARD_PLAYED의 card로 확인)
func test_boss_unplayable_advances():        # 보스 [근접 A(대상 없음), B] → 1턴 행동 없음, 2턴 B
```

Run → FAIL

- [ ] **Step 2: 구현**
- [ ] **Step 3: 전체 테스트** → PASS (Task 1~10 전부)
- [ ] **Step 4: Commit** — `git commit -m "feat: enemy and boss turn behavior"`
