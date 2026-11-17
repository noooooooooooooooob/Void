# 소비 아이템 (가방·전투 중 사용·드랍) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 의뢰 동안 유지되는 파티 공용 5칸 가방, 전투 중 HP·SP 회복 아이템 사용, 일반 전투 승리 시 40% 드랍을 넣는다.

**Architecture:** 아이템은 카드와 별개인 리소스(`ConsumableData` + 효과 줄 `ConsumableLine`)이고, 규칙은 순수 로직(`Battle.use_item`, `Inventory`, `BattleSession`)에 둔다. 가방은 `StageRun`(자동 로드)이 의뢰마다 하나 갖고, 전투 화면은 가방 패널 씬과 결과 창의 드랍 구역으로 그것을 보여 주기만 한다.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1

**Spec:** `docs/superpowers/specs/2026-11-17-consumable-items-design.md`

## Global Constraints

- 가방은 파티 공용 하나, **5칸** (`Inventory.CAPACITY = 5`)
- 사용 비용 없음 (SP·행동을 쓰지 않음). 사용 시점은 **아군 차례의 카드 사용 페이즈만** = `BattleSession.active != null` 이고 연출 중이 아닐 때
- 이번 아이템 종류는 **HP 회복·SP 회복만**. 스탯 버프·가져오기는 만들지 않는다
- **SP 회복은 최대 SP 를 넘어도 된다.** HP 는 항상 0 ~ 최대 HP (`BattleUnit.hp` setter 가 맞춤)
- 회복량: 고정값 또는 대상 최대치의 % (내림, 최소 1)
- 대상은 살아 있는 아군만
- **조작은 카드와 같은 드래그** (2026-11-17 사용자 결정): 가방 칸을 누른 채 끌어 아군 위에서 떼면 사용, 그 밖에서 떼면(제자리 클릭 포함) 취소. 화살표는 카드와 같은 `%TargetArrow` 를 같이 쓴다
- 드랍: 의뢰의 **일반 전투** 승리 시에만, 확률 기본 **0.4**, 전투 난수(`Battle.rng`)와 다른 난수. 보스·F6 시험 전투는 드랍 없음
- 프로젝트 규칙 (`CLAUDE.md`): 게임 스크립트는 `Scripts/` 아래, 씬은 `Scenes/` 아래, 데이터는 `.tres`. **`.tscn`/`.tres` 는 손으로 쓰지 않고 Godot 이 저장**한다. 에디터가 켜진 동안 바깥에서 `res://` 의 `.tscn`/`.tres` 를 쓰지 않는다. 테스트는 프로젝트 복사본에서 돌린다. 테스트 코드를 뺀 모든 스크립트에 한국어 주석(클래스 `##`, `@export`·공개 함수 `##`)
- 새 이벤트·enum 값은 맨 뒤에 붙인다 (`.tres` 에 숫자로 저장됨)
- 커밋은 사용자가 요청할 때만 한다. 각 작업의 "커밋" 단계는 사용자 확인 뒤 실행

## 테스트 실행 방법 (모든 작업 공통)

프로젝트를 복사본으로 옮겨 돌린다 (복사본의 `project.godot` 에서 `MCPRuntime` 자동 로드와 MCP 플러그인을 뺀다):

```
<godot_console> --headless --path <복사본> --import
<godot_console> --headless --path <복사본> --log-file <로그> -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
파일 하나만: `-gtest=res://tests/<경로>.gd`. 통과 기준: `Failing Tests` 줄이 없음.

## Review Focus

1. 죽은 아군·적에게 아이템을 쓰려 함 → 아무것도 바뀌지 않고 아이템도 남는다 (Task 3)
2. 연출 중·적 차례·전투가 끝난 뒤 아이템을 누름 → 반응 없음, 가방은 열어 볼 수 있음 (Task 6)
3. 가방이 꽉 찬 상태에서 드랍 → 바꾸거나 넘어갈 수 있고, 아이템이 5개를 넘지 않는다 (Task 2, 7)
4. `items/consumables/` 에 아이템이 하나도 없음 → 드랍 없이 "계속"만 나온다 (Task 4, 7)
5. SP 가 최대를 넘은 캐릭터 → 다음 자기 차례 시작에 최대 SP 로 돌아간다 (Task 3)

---

### Task 1: 아이템 데이터 (`ConsumableLine`, `ConsumableData`)

**Files:**
- Create: `Scripts/items/consumable_line.gd`, `Scripts/items/consumable_data.gd`
- Test: `tests/items/test_consumable_data.gd`

**Interfaces:**
- Produces:
  - `class_name ConsumableLine extends Resource` (`@tool`): `enum Type { HEAL_HP, HEAL_SP }`, `enum Kind { FLAT, PERCENT }`, `@export var type: Type`, `@export var kind: Kind`, `@export var amount: int`
    - `func amount_for(max_value: int) -> int` — FLAT 이면 `amount`, PERCENT 면 `floor(max_value × amount / 100)`, 둘 다 최소 1
    - `func describe() -> String` — `"HP 회복 +30"`, `"SP 회복 +20%"`
  - `class_name ConsumableData extends Resource` (`@tool`): `@export var id: String`, `display_name`, `name_en`, `description_ko`, `description_en` (multiline), `keywords: PackedStringArray`, `art: String`, `lines: Array[ConsumableLine]`, `effects: Array[CardEffect]` (그룹 "Godot")
    - `func describe_lines() -> String` — 줄마다 `describe()` 를 줄바꿈으로 이은 글

- [ ] **Step 1: 실패하는 테스트 작성** (`tests/items/test_consumable_data.gd`)

```gdscript
extends GutTest

func _line(type: int, kind: int, amount: int) -> ConsumableLine:
	var l := ConsumableLine.new()
	l.type = type
	l.kind = kind
	l.amount = amount
	return l

func test_flat_amount_ignores_max():
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.FLAT, 30).amount_for(100), 30)

func test_percent_amount_is_floored_share_of_max():
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.PERCENT, 25).amount_for(90), 22)

func test_amount_is_at_least_one():
	assert_eq(_line(ConsumableLine.Type.HEAL_SP, ConsumableLine.Kind.PERCENT, 10).amount_for(3), 1)
	assert_eq(_line(ConsumableLine.Type.HEAL_SP, ConsumableLine.Kind.FLAT, 0).amount_for(3), 1)

func test_describe():
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.FLAT, 30).describe(), "HP 회복 +30")
	assert_eq(_line(ConsumableLine.Type.HEAL_SP, ConsumableLine.Kind.PERCENT, 20).describe(), "SP 회복 +20%")

func test_item_describes_all_lines():
	var item := ConsumableData.new()
	item.lines.assign([
		_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.FLAT, 30),
		_line(ConsumableLine.Type.HEAL_SP, ConsumableLine.Kind.FLAT, 2)])
	assert_eq(item.describe_lines(), "HP 회복 +30\nSP 회복 +2")
```

- [ ] **Step 2: 실패 확인** — `-gtest=res://tests/items/test_consumable_data.gd`, 기대: `ConsumableLine` 을 찾지 못해 스크립트 오류
- [ ] **Step 3: 두 스크립트 구현** (위 Interfaces 그대로. `EquipmentData`·`StatModifier` 의 주석·`@export` 방식 따름)
- [ ] **Step 4: 통과 확인** — 같은 명령, 5개 통과
- [ ] **Step 5: 커밋** — `feat: consumable item data`

---

### Task 2: 가방 (`Inventory`)

**Files:**
- Create: `Scripts/items/inventory.gd`
- Test: `tests/items/test_inventory.gd`

**Interfaces:**
- Produces: `class_name Inventory extends RefCounted`
  - `const CAPACITY := 5`, `var items: Array[ConsumableData] = []`
  - `func is_full() -> bool`
  - `func add(item: ConsumableData) -> bool` — 꽉 찼거나 `item == null` 이면 false, 아니면 맨 뒤에 넣고 true
  - `func remove_at(index: int) -> ConsumableData` — 범위 밖이면 null
  - `func replace(index: int, item: ConsumableData) -> bool` — 범위 밖이거나 `item == null` 이면 false

- [ ] **Step 1: 실패하는 테스트 작성**

```gdscript
extends GutTest

func _item(n: String) -> ConsumableData:
	var i := ConsumableData.new()
	i.display_name = n
	return i

func test_add_until_full():
	var bag := Inventory.new()
	for i in Inventory.CAPACITY:
		assert_true(bag.add(_item(str(i))))
	assert_true(bag.is_full())
	assert_false(bag.add(_item("넘침")))
	assert_eq(bag.items.size(), 5)

func test_add_null_is_refused():
	assert_false(Inventory.new().add(null))

func test_remove_at_returns_item_and_closes_gap():
	var bag := Inventory.new()
	var a := _item("a")
	var b := _item("b")
	bag.add(a)
	bag.add(b)
	assert_same(bag.remove_at(0), a)
	assert_eq(bag.items, [b] as Array[ConsumableData])
	assert_null(bag.remove_at(3))

func test_replace_swaps_one_slot():
	var bag := Inventory.new()
	bag.add(_item("a"))
	var c := _item("c")
	assert_true(bag.replace(0, c))
	assert_same(bag.items[0], c)
	assert_false(bag.replace(1, c))
	assert_false(bag.replace(0, null))
```

- [ ] **Step 2: 실패 확인** — `Inventory` 없음
- [ ] **Step 3: `Scripts/items/inventory.gd` 구현**
- [ ] **Step 4: 통과 확인** — 4개 통과
- [ ] **Step 5: 커밋** — `feat: party inventory (5 slots)`

---

### Task 3: 전투 규칙 (`Battle.use_item`, `ITEM_USED`, 세션)

**Files:**
- Modify: `Scripts/battle/battle_types.gd` (`Event` enum 맨 뒤에 `ITEM_USED`), `Scripts/battle/battle.gd`, `Scripts/battle/battle_session.gd`
- Test: `tests/battle/test_items.gd`

**Interfaces:**
- Consumes: Task 1 `ConsumableData`·`ConsumableLine.amount_for`, Task 2 `Inventory`
- Produces:
  - `BattleTypes.Event.ITEM_USED` — `target` = 대상 유닛, `source` = `ConsumableData`
  - `Battle.can_use_item(item: ConsumableData, target: BattleUnit) -> bool` — `item`·`target` 이 있고 대상이 살아 있는 **아군**(`Side.ALLY`)일 때 true
  - `Battle.use_item(item: ConsumableData, target: BattleUnit) -> bool` — 못 쓰면 아무것도 안 바꾸고 false. 줄 순서대로: HEAL_HP → `heal(target, line.amount_for(최대 HP), item)`, HEAL_SP → `target.sp += line.amount_for(최대 SP)` (상한 없음). 그다음 `item.effects` 를 `EffectContext`(actor = null, owner = target, targets = [target], source = item)로 실행, 마지막에 `ITEM_USED` 발행
  - `BattleSession.inventory: Inventory` (생성자 뒤에 넣는 공개 변수, 기본은 빈 `Inventory`)
  - `BattleSession.item_targets(item: ConsumableData) -> Array[BattleUnit]` — `active == null` 이거나 끝났으면 빈 배열, 아니면 `can_use_item` 을 통과하는 살아 있는 유닛들
  - `BattleSession.use_item(index: int, target: BattleUnit) -> bool` — `active` 가 있고 끝나지 않았을 때만. 성공하면 가방에서 그 칸을 빼고 `changed`, `_check_end()`

- [ ] **Step 1: 실패하는 테스트 작성** (`tests/battle/test_items.gd`. 세션용 데이터는 `tests/battle/test_battle_session.gd` 의 `_data()`·`_started()` 와 같은 방식으로 이 파일 안에 만든다 — 아군 "홍연" 속도 10·`max_sp` 3·`max_hp` 100, 적 둘)

```gdscript
func _item(type: int, kind: int, amount: int) -> ConsumableData  # 줄 하나짜리 아이템

func test_hp_item_heals_up_to_max():
	me.hp = 80
	assert_true(battle.use_item(_item(HP, FLAT, 30), me))
	assert_eq(me.hp, 100)

func test_sp_item_can_exceed_max():
	me.sp = 3
	assert_true(battle.use_item(_item(SP, FLAT, 2), me))
	assert_eq(me.sp, 5)

func test_overflowed_sp_returns_to_max_on_next_turn():
	me.sp = 5
	battle.begin_turn(me)
	assert_eq(me.sp, me.get_stat(BattleTypes.Stat.SP))

func test_item_emits_item_used_with_target_and_source():
	# ITEM_USED 구독 → e.target == me, e.source == item

func test_item_cannot_target_enemy_or_dead_ally():
	assert_false(battle.use_item(item, foe))
	me.alive = false
	assert_false(battle.use_item(item, me))
	# 둘 다 HP·SP 변화 없음, ITEM_USED 없음

func test_item_godot_effects_run_on_target():
	# item.effects = [BlockEffect(use_flat, flat 7, target OWNER)] → me.block == 7

func test_session_use_item_removes_it_from_bag():
	var s := _started()
	s.inventory.add(hp_item)
	s.active.hp = 50
	assert_true(s.use_item(0, s.active))
	assert_eq(s.inventory.items.size(), 0)
	assert_eq(s.active.hp, 80)

func test_session_refuses_item_outside_ally_turn():
	var s := _started()
	s.inventory.add(hp_item)
	s.end_player_turn()   # 적 차례 대기
	assert_eq(s.item_targets(hp_item).size(), 0)
	assert_false(s.use_item(0, s.battle.living(BattleTypes.Side.ALLY)[0]))
	assert_eq(s.inventory.items.size(), 1)

func test_session_refuses_bad_index_and_bad_target():
	# use_item(3, active) == false, use_item(0, 적) == false, 가방 그대로
```

- [ ] **Step 2: 실패 확인** — `use_item` 없음
- [ ] **Step 3: 구현** — `battle.gd` 에 "# --- 아이템 ---" 구역을 "피해·회복·방어도" 구역 뒤에 추가. `battle_session.gd` 에 `inventory`, `item_targets`, `use_item`
- [ ] **Step 4: 통과 확인** — `-gdir=res://tests/battle` 전체 통과 (기존 테스트 포함)
- [ ] **Step 5: 커밋** — `feat: use consumable items in battle`

---

### Task 4: 의뢰의 가방과 드랍 (`StageRun`)

**Files:**
- Modify: `Scripts/stage/stage_run.gd`
- Test: `tests/stage/test_stage_run.gd` (추가)

**Interfaces:**
- Consumes: Task 1, Task 2
- Produces:
  - `StageRun.inventory: Inventory` — `start_run` 에서 새로, `end_run` 에서 새 빈 가방으로
  - `const ITEM_DIR := "res://items/consumables"`
  - `func item_pool(dir: String = ITEM_DIR) -> Array[ConsumableData]` — 폴더(하위 폴더 제외)의 `.tres` 중 `ConsumableData` 인 것. 내보낸 게임의 `.remap` 접미사는 떼고 읽는다 (`KeywordData._scan` 과 같은 방식). 폴더가 없으면 빈 배열
  - `func is_boss_battle() -> bool` — 들어가 있는 노드가 `Kind.BOSS`
  - `func roll_item_drop(chance: float, pool: Array[ConsumableData], rng: RandomNumberGenerator) -> ConsumableData` — `pool` 이 비었거나 `rng.randf() >= chance` 면 null, 아니면 `pool[rng.randi_range(0, pool.size() - 1)]`

- [ ] **Step 1: 실패하는 테스트 추가**

```gdscript
func test_run_starts_with_empty_bag_and_end_clears_it():
	var r := _run()
	assert_eq(r.inventory.items.size(), 0)
	r.inventory.add(ConsumableData.new())
	r.end_run()
	assert_eq(r.inventory.items.size(), 0)

func test_drop_never_at_zero_always_at_one():
	var r := _run()
	var pool: Array[ConsumableData] = [ConsumableData.new()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 50:
		assert_null(r.roll_item_drop(0.0, pool, rng))
		assert_same(r.roll_item_drop(1.0, pool, rng), pool[0])

func test_drop_from_empty_pool_is_null():
	var r := _run()
	var none: Array[ConsumableData] = []
	assert_null(r.roll_item_drop(1.0, none, RandomNumberGenerator.new()))

func test_item_pool_reads_folder_and_missing_folder_is_empty():
	# user://test_items_<시각>/ 에 ConsumableData 2개와 StatusData 1개를 ResourceSaver 로 저장
	# → item_pool(그 폴더).size() == 2 ; item_pool("user://없는_폴더").size() == 0 ; after 에서 폴더 삭제

func test_is_boss_battle_only_on_boss_node():
	var r := _run()
	r.progress.enter()
	assert_false(r.is_boss_battle())
	r.progress.entering = _node_of(r, K.BOSS)
	assert_true(r.is_boss_battle())
```

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — `-gdir=res://tests/stage`
- [ ] **Step 5: 커밋** — `feat: run inventory and item drop roll`

---

### Task 5: 씬·시험 아이템·입력 액션 (Godot 이 저장)

**이 작업은 `.tscn`/`.tres`/`project.godot` 를 바꾼다. Godot 에디터를 끈 뒤 헤드리스 스크립트로 저장하거나, 사용자가 에디터에서 직접 만든다. 시작 전에 사용자에게 에디터를 꺼 달라고 요청한다.**

**Files:**
- Create: `Scripts/ui/item_slot.gd`, `Scripts/ui/bag_panel.gd`, `Scenes/ui/battle_screen/item_slot.tscn`, `Scenes/ui/battle_screen/bag_panel.tscn`, `items/consumables/hp_potion.tres`, `items/consumables/sp_potion.tres`
- Modify: `Scenes/ui/battle_screen/battle_screen.tscn`, `project.godot` (입력 액션 `toggle_bag` = Tab 키)
- Test: `tests/ui/test_bag_panel.gd`, `tests/data/test_sample_data.gd` (추가)

**Interfaces:**
- Produces:
  - `class_name ItemSlot extends PanelContainer` — 칸 하나. `signal pressed(index: int)` (왼쪽 버튼을 누름), `signal released(index: int)` (누른 뒤 뗌 — 누른 칸이 떼는 입력도 받는다), `var index: int`, `func set_item(item: ConsumableData) -> void` (null = 빈 칸: 이름 비움), `func set_dimmed(on: bool) -> void`, `func set_selected(on: bool) -> void`. 씬 노드: `%Name`(Label), `%Lines`(Label, 효과 줄). `tooltip_text` = 이름 + 설명 + 효과 줄. 빈 칸은 눌러도 `pressed`·`released` 를 내지 않는다
  - `class_name BagPanel extends PanelContainer` — `signal item_pressed(index: int)`, `signal item_released(index: int)`, `func show_items(items: Array[ConsumableData], usable: bool, selected: int) -> void` (칸 5개를 채우고 `%Title` 을 `"가방 (n/5)"` 로), `func slots() -> Array[ItemSlot]`. 씬 노드: `%Title`(Label), `%Slots`(HBoxContainer, `ItemSlot` 인스턴스 5개 `Slot0`~`Slot4`)
  - `battle_screen.tscn` 에 추가되는 노드 (모두 고유 이름):
    - `BottomRight/BagButton` (Button, `EndTurnButton` 바로 위, 글자 `"가방 0/5"`)
    - 루트의 `test_items` = [`hp_potion.tres`, `sp_potion.tres`] (F6 시험 전투에서 바로 써 볼 수 있게)
    - `BagPanel` (`bag_panel.tscn` 인스턴스, 처음엔 숨김, `BottomRight` 위쪽에 배치, `ResultOverlay` 보다 앞 순서)
    - `ResultOverlay/Box` 안, `ResultLabel` 과 `RestartButton` 사이: `DropBox`(VBoxContainer, 처음엔 숨김) → `DropLabel`(Label), `DropSlots`(HBoxContainer, `ItemSlot` 5개), `DropButtons`(HBoxContainer) → `TakeButton`("받기"), `SkipButton`("넘어가기")
  - 시험 아이템: `hp_potion.tres` (`display_name` "회복약", 줄 HEAL_HP·FLAT·30), `sp_potion.tres` ("기력약", 줄 HEAL_SP·FLAT·2). `id` 는 빈 값

- [ ] **Step 1: 실패하는 테스트 작성**

```gdscript
# tests/ui/test_bag_panel.gd
func test_panel_fills_five_slots_and_title():
	var p: BagPanel = load("res://Scenes/ui/battle_screen/bag_panel.tscn").instantiate()
	add_child_autofree(p)
	var items: Array[ConsumableData] = [_item("회복약"), _item("기력약")]
	p.show_items(items, true, -1)
	assert_eq(p.slots().size(), 5)
	assert_eq(p.get_node("%Title").text, "가방 (2/5)")
	assert_eq(p.slots()[0].get_node("%Name").text, "회복약")
	assert_eq(p.slots()[2].get_node("%Name").text, "")

func test_pressing_filled_slot_reports_index_and_empty_slot_does_not():
	# watch_signals(p); p.slots()[1].pressed.emit(1) 대신 실제 입력: 슬롯에 왼쪽 버튼 InputEventMouseButton 을 _gui_input 으로 넣음
	# → item_pressed(1) 한 번 ; 같은 칸에 버튼 뗌 입력 → item_released(1) 한 번
	# 빈 칸(3)에 누름·뗌 입력 → 추가 발행 없음

# tests/data/test_sample_data.gd 에 추가
func test_sample_potions_exist():
	var hp: ConsumableData = load("res://items/consumables/hp_potion.tres")
	var sp: ConsumableData = load("res://items/consumables/sp_potion.tres")
	assert_eq(hp.display_name, "회복약")
	assert_eq(hp.lines[0].amount_for(100), 30)
	assert_eq(sp.lines[0].type, ConsumableLine.Type.HEAL_SP)
	assert_eq(sp.lines[0].amount_for(3), 2)
```

- [ ] **Step 2: 실패 확인** — 씬·파일 없음
- [ ] **Step 3: `item_slot.gd`, `bag_panel.gd` 작성** (`unit_token.gd` 의 `_gui_input` → `pressed` 방식, `card_view.gd` 의 `set_dimmed` 색 `Color(0.45, 0.45, 0.45)` 를 따름)
- [ ] **Step 4: Godot 이 씬·리소스를 저장** — 에디터가 꺼진 상태에서 헤드리스 스크립트(스크래치 폴더에 두고 `--script` 로 실행)로 `item_slot.tscn`, `bag_panel.tscn`, 시험 아이템 2개를 만들고, `battle_screen.tscn` 을 불러와 위 노드를 추가해 다시 저장한다 (추가한 노드의 `owner` = 씬 루트, 인스턴스 노드는 `PackedScene.instantiate()` 한 것을 `add_child`). 저장 뒤 `battle_screen.tscn` 의 기존 노드·`unique_id` 가 그대로인지 `git diff` 로 확인
- [ ] **Step 5: 입력 액션 추가** — 에디터가 꺼진 상태에서 `project.godot` 의 `[input]` 에 `toggle_bag`(Tab, physical keycode 4194306)을 헤드리스 스크립트의 `ProjectSettings.set_setting("input/toggle_bag", …)` + `ProjectSettings.save()` 로 넣는다. 저장 뒤 `git diff project.godot` 에서 `[input]` 의 다른 액션(`map_up`, `map_down`)이 그대로인지 확인
- [ ] **Step 6: 통과 확인** — `-gdir=res://tests/ui`, `-gtest=res://tests/data/test_sample_data.gd`
- [ ] **Step 7: 커밋** — `feat: bag panel scenes and sample potions`

---

### Task 6: 전투 화면 — 가방 열기, 아이템 고르기·쓰기

**Files:**
- Modify: `Scripts/ui/battle_screen.gd`
- Test: `tests/ui/test_battle_screen_items.gd`

**Interfaces:**
- Consumes: Task 3 세션 함수, Task 4 `StageRun.inventory`, Task 5 노드 (`%BagButton`, `%BagPanel`)
- Produces (`BattleScreen`):
  - `@export var test_items: Array[ConsumableData]` — 의뢰 모드가 아닐 때 가방에 넣는 시험 아이템 ("다시 하기" 때도 다시 채움)
  - `var selected_item := -1` — 고른 아이템의 가방 칸 번호
  - `func toggle_bag() -> void`, `func is_bag_open() -> bool`
  - `func select_item(index: int) -> bool` — `_input_ok()` 이고 그 칸에 아이템이 있고 `item_targets` 가 비어 있지 않을 때만 true. 고른 카드는 내려놓는다
  - `var _dragging_item := false` — 가방 칸을 누른 채 끌고 있는지 (카드의 `_dragging` 과 같은 역할)
  - `%BagPanel.item_pressed(i)` → `_dragging_item = select_item(i)` ; `%BagPanel.item_released(i)` → `_release_item_drag(get_global_mouse_position())`. `_unhandled_input` 의 왼쪽 버튼 뗌도 `_dragging_item` 이면 같은 함수로 (카드와 같은 안전망)
  - `func _release_item_drag(mouse: Vector2) -> void` — 손을 뗌: `_unit_under(mouse)` 가 대상 아군이면 사용, 그 밖에는(제자리 클릭 포함) `selected_item = -1` 로 취소. 카드의 `_release_drag` 와 같은 규칙
  - `_update_arrow` 확장: 아이템을 고른 상태면 그 가방 칸의 위쪽 가운데 → 마우스로 화살표, `set_valid(마우스 아래 유닛이 item_targets 에 있음)`. `_process` 는 `selected` 또는 `selected_item >= 0` 일 때 화살표를 갱신
  - `click_unit(u)` 확장: 아이템을 고른 상태면 그 유닛에게 사용 (대상이 아니면 false). 사용 뒤 `selected_item = -1`, 가방은 열린 채
  - `select_card` 확장: 카드를 고르면 `selected_item = -1`
  - `cancel()` 확장: 고른 아이템이 있으면 그것만 취소, 없고 가방이 열려 있으면 가방 닫기, 그 밖엔 지금 동작
  - `_show_event` 확장: `ITEM_USED` → 전투 기록 `"아이템: <아이템 이름> → <대상 이름>"`
  - `refresh()` 확장: `%BagButton.text = "가방 n/5"`, 가방 패널 다시 그림 (`usable = _input_ok()`), 고른 아이템이 있으면 대상 아군 강조(`set_highlight`)
  - 세션 만들 때: 의뢰 모드면 `session.inventory = StageRun.inventory`, 아니면 `test_items` 로 채운 새 `Inventory`

- [ ] **Step 1: 실패하는 테스트 작성** (화면 만들기는 `tests/ui/test_battle_screen.gd` 의 `_screen()` 방식. `s.test_items` 에 회복약(HP +30)·기력약(SP +2)을 넣고 `add_child_autofree`)

```gdscript
func test_bag_button_shows_count_and_toggles_panel():
	assert_eq(s.get_node("%BagButton").text, "가방 2/5")
	assert_false(s.is_bag_open())
	s.toggle_bag()
	assert_true(s.get_node("%BagPanel").visible)

func test_toggle_bag_action_opens_bag():
	# InputEventAction("toggle_bag", pressed) 를 s._unhandled_input 에 넣음 → is_bag_open()

func test_use_hp_item_on_ally():
	var hero := s.session.active
	hero.hp = 50
	assert_true(s.select_item(0))
	assert_true(s.click_unit(hero))
	assert_eq(hero.hp, 80)
	assert_eq(s.session.inventory.items.size(), 1)
	assert_eq(s.selected_item, -1)
	assert_string_contains(s.get_node("%Log").text, "아이템: 회복약 → 홍연")

func test_drag_item_released_on_ally_uses_it():
	var hero := s.session.active
	hero.hp = 50
	s.toggle_bag()
	s._dragging_item = s.select_item(0)
	s._release_item_drag(_token_center(s, hero))   # 아군 박스 위에서 뗌
	assert_eq(hero.hp, 80)
	assert_eq(s.session.inventory.items.size(), 1)
	assert_eq(s.selected_item, -1)
	assert_false(s._dragging_item)

func test_drag_item_released_off_target_keeps_it():
	s.toggle_bag()
	s._dragging_item = s.select_item(0)
	s._release_item_drag(Vector2(5, 5))            # 아무 유닛도 없는 곳
	assert_eq(s.selected_item, -1)
	assert_eq(s.session.inventory.items.size(), 2)

func test_drag_item_released_on_enemy_keeps_it():
	s.toggle_bag()
	s._dragging_item = s.select_item(0)
	s._release_item_drag(_token_center(s, _unit(s, "적A")))
	assert_eq(s.selected_item, -1)
	assert_eq(s.session.inventory.items.size(), 2)

func test_arrow_shows_while_item_is_selected_and_hides_after():
	s.toggle_bag()
	s.select_item(0)
	s._update_arrow()
	assert_true(s.get_node("%TargetArrow").visible)
	s.cancel()
	s._update_arrow()
	assert_false(s.get_node("%TargetArrow").visible)

func test_using_item_keeps_bag_open():
	s.toggle_bag()
	s.select_item(0)
	s.click_unit(s.session.active)
	assert_true(s.is_bag_open())

func test_item_cannot_be_used_on_enemy():
	s.select_item(0)
	assert_false(s.click_unit(_unit(s, "적A")))
	assert_eq(s.session.inventory.items.size(), 2)

func test_selecting_item_drops_selected_card_and_back():
	s.select_card(0)
	s.select_item(0)
	assert_null(s.selected)
	s.select_card(0)
	assert_eq(s.selected_item, -1)

func test_item_refused_on_enemy_turn_but_bag_still_opens():
	s.press_end_turn()            # enemy_delay 0 → 적 차례 대기
	assert_false(s.select_item(0))
	s.toggle_bag()
	assert_true(s.is_bag_open())

func test_item_refused_during_performance():
	# tests/ui/test_battle_screen_performance.gd 의 _data()/_use 방식으로 연출 카드를 쓴 직후
	assert_false(s.select_item(0))

func test_cancel_drops_item_first_then_closes_bag():
	s.toggle_bag()
	s.select_item(0)
	s.cancel()
	assert_eq(s.selected_item, -1)
	assert_true(s.is_bag_open())
	s.cancel()
	assert_false(s.is_bag_open())

func test_restart_refills_test_bag():
	s.select_item(0)
	s.click_unit(s.session.active)
	s.restart()
	assert_eq(s.session.inventory.items.size(), 2)
```

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** — `%BagButton.pressed` → `toggle_bag`, `%BagPanel.item_pressed`/`item_released` → 드래그 시작/끝, `_unhandled_input` 에 `toggle_bag` 액션과 아이템 드래그의 버튼 뗌. 화살표는 `_update_arrow` 에 아이템 갈래만 더하고, 손패 그리기·카드 드래그 흐름(`_on_card_input`, `_release_drag`)은 건드리지 않는다
- [ ] **Step 4: 통과 확인** — `-gdir=res://tests/ui` 전체 (기존 화면·연출 테스트 포함)
- [ ] **Step 5: 커밋** — `feat: bag and item use on the battle screen`

---

### Task 7: 결과 창의 드랍

**Files:**
- Modify: `Scripts/ui/battle_screen.gd`
- Test: `tests/ui/test_battle_screen_stage.gd` (추가)

**Interfaces:**
- Consumes: Task 4 (`StageRun.roll_item_drop`, `item_pool`, `is_boss_battle`, `inventory`), Task 5 노드 (`%DropBox`, `%DropLabel`, `%DropSlots`, `%TakeButton`, `%SkipButton`)
- Produces (`BattleScreen`):
  - `@export_range(0.0, 1.0) var item_drop_chance := 0.4`
  - `var drop_pool_dir := StageRun.ITEM_DIR` — 드랍 후보 폴더 (테스트에서 바꿈)
  - `var pending_drop: ConsumableData` — 결과 창에서 아직 정하지 않은 드랍 (없으면 null)
  - `func take_drop() -> void` — 빈 칸이 있을 때만: 가방에 넣고 `pending_drop = null`
  - `func swap_drop(index: int) -> void` — 그 칸을 드랍으로 바꾸고 `pending_drop = null`
  - `func skip_drop() -> void` — 받지 않고 `pending_drop = null`
  - `_show_result` 확장: 의뢰 모드 + 승리 + 보스 아님일 때만 `_fx_rng` 로 `StageRun.roll_item_drop(item_drop_chance, StageRun.item_pool(drop_pool_dir), _fx_rng)`. 드랍이 있으면 `%DropBox` 를 보이고 `%RestartButton`("계속")을 숨긴다 → 정하면 `%DropBox` 를 숨기고 "계속"을 보인다
    - 빈 칸 있음: `%DropLabel` = `"아이템 획득: <이름>"`, `%TakeButton`·`%SkipButton` 보임, `%DropSlots` 숨김
    - 가득 참: `%DropLabel` = `"아이템 획득: <이름> (가방이 가득 참)"`, `%DropSlots` 에 가방 5칸(누르면 `swap_drop`), `%SkipButton` 만 보임

- [ ] **Step 1: 실패하는 테스트 추가** (드랍 후보는 `user://` 임시 폴더에 `ConsumableData` 하나를 저장해 `s.drop_pool_dir` 로 지정, `after_each` 에서 삭제)

```gdscript
func test_stage_win_with_full_chance_offers_item_and_take_adds_it():
	_enter_battle_node()
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_not_null(s.pending_drop)
	assert_true(s.get_node("%DropBox").visible)
	assert_false(s.get_node("%RestartButton").visible)
	s.take_drop()
	assert_eq(StageRun.inventory.items.size(), 1)
	assert_false(s.get_node("%DropBox").visible)
	assert_true(s.get_node("%RestartButton").visible)

func test_skip_drop_adds_nothing():
	# 위와 같이 연 뒤 s.skip_drop() → 가방 0개, "계속" 보임

func test_zero_chance_goes_straight_to_continue():
	# _screen_with_pool(0.0) → pending_drop == null, DropBox 숨김, RestartButton 보임

func test_full_bag_offers_swap_and_never_exceeds_five():
	# StageRun.inventory 를 5개로 채움 → 승리 → TakeButton 숨김, DropSlots 보임
	# s.take_drop() 은 아무것도 안 함(여전히 5개, pending_drop 그대로) → s.swap_drop(2) → items[2] 가 드랍, 5개

func test_empty_pool_gives_no_drop():
	# drop_pool_dir = "user://없는_폴더", 확률 1.0 → pending_drop == null

func test_boss_win_and_defeat_give_no_drop():
	# progress.entering = 보스 노드 → 승리 → pending_drop == null
	# 일반 노드에서 s._on_finished(BattleTypes.Side.ENEMY) → pending_drop == null

func test_test_battle_outside_run_gives_no_drop():
	# 의뢰 밖(StageRun 비활성)에서 확률 1.0, 승리 → pending_drop == null, "다시 하기" 버튼 그대로
```

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** — `%TakeButton`/`%SkipButton`/`%DropSlots` 의 칸 `pressed` 연결
- [ ] **Step 4: 통과 확인** — 전체 테스트 (`-gdir=res://tests -ginclude_subdirs`), 2번 돌려 둘 다 전부 통과
- [ ] **Step 5: 커밋** — `feat: item drop on stage battle victory`

---

### Task 8: 문서와 직접 실행 확인

**Files:**
- Modify: `CLAUDE.md`, `docs/progress.md`

- [ ] **Step 1: `CLAUDE.md`** — "전투 승리마다 아이템 1개" → "일반 전투 승리 시 확률(기본 40%, `BattleScreen.item_drop_chance`)로 소비 아이템 1개. 보스는 드랍 없음". "확정된 게임 규칙"에 가방(파티 공용 5칸, 의뢰 동안 유지)·사용(아군 차례의 카드 사용 페이즈, 비용 없음, 살아 있는 아군 대상, SP 는 최대를 넘을 수 있고 다음 차례 시작에 최대로)·TAB 조작 추가. "소비 아이템 데이터" 줄에 Godot 쪽 리소스(`Scripts/items/`, `items/consumables/`)가 생겼고 가져오기·버프는 아직 없음을 적는다. Project Structure 에 `items/` 추가
- [ ] **Step 2: `docs/progress.md`** — 완료된 기능 표에 "소비 아이템 (시험판, 2026-11-17)" 줄, "나중에 할 일"에 가져오기·스탯 버프·상점 구매·사무소 인벤토리
- [ ] **Step 3: 직접 실행 확인** — 사용자에게 요청: F5 → 지도 → 전투에서 TAB 으로 가방 열기, 아이템을 끌어 아군에게 놓기·빈 곳에 놓아 취소하기, (시험 전투 F6 에서는 `test_items` 에 회복약·기력약을 넣어) 아이템 사용, 승리 뒤 드랍 창. 확인 결과를 받아 기록
- [ ] **Step 4: 커밋** — `docs: consumable item rules`
