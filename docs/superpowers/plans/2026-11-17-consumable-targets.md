# 소비 아이템 대상·범위·음수·가져오기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 소비 아이템에 사용 대상(아군/적/둘 다)·범위·음수 효과를 넣고, 웹 에디터 zip 의 `consumables` 를 Godot 카드 가져오기로 들여온다.

**Architecture:** 웹 에디터(아티팩트 HTML 한 파일)의 `CardModel` 에 `target`·`area` 를 더하고 음수 회복을 허용한다. Godot 는 `ConsumableData` 에 같은 칸, `ConsumableLine` 음수 규칙, `EquipmentImporter` 모양의 `ConsumableImporter`, `Battle.use_item` 의 편·범위·HP 감소(`lose_hp`, 피해 아님)를 더한다. 화면은 카드 광역 표시(`_draw_marks`)를 아이템에도 쓴다.

**Tech Stack:** Godot 4.7.2 GDScript, GUT 9.7.1, 아티팩트 HTML/JS(db·assets·downloads·user), Node(웹 순수 로직 테스트)

**Spec:** `docs/superpowers/specs/2026-11-17-consumable-targets-design.md`

## Global Constraints

- 테스트는 프로젝트 **복사본**에서 실행 (MCP 플러그인·MCPRuntime 끄고 `--log-file`). 에디터가 켜져 있으면 바깥에서 `res://` 의 `.tscn`/`.tres` 를 쓰지 않는다
- 실행: `Godot_v4.7.2-stable_win64_console.exe --headless --path <복사본> --import` 후 `... -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- 모든 비테스트 스크립트에 한국어 주석 (`##` 클래스·export·공개 함수, 단계별 주석)
- enum 값은 맨 뒤에만 추가 (`.tres`·이벤트 숫자 저장)
- 음수 HP 는 **피해가 아니다**: 방어도·`DAMAGE_*` 이벤트·스태미너·치명 없음, 아무도 준 것이 아님
- 대상·범위 없는 예전 데이터 = 아군·단일 (지금 동작 유지)
- 범위는 고른 유닛과 **같은 편** 격자에서만

## Review Focus

- `amount = 0` 줄 → 아무 일도 없어야 함 (지금은 최소 1 로 올림) — Task 2 테스트
- 범위 아이템을 범위 안에 아무도 없는 칸 기준으로 — 고른 유닛은 살아 있으므로 최소 그 유닛만 (offset `(0,0)` 이 없으면 고른 유닛 제외될 수 있음: `area_targets` 는 오프셋 칸만 봄 → 카드와 같은 규칙으로 둔다) — Task 4 테스트로 고정
- 음수 HP 로 마지막 적이 쓰러지면 즉시 승리 — Task 4 테스트
- 음수 HP 로 지금 차례 아군이 쓰러지면 차례가 넘어감 (`_pass_if_dead`) — Task 4 테스트
- 웹 → zip 에 `target`/`area` 없는 예전 아이템 → 아군·단일로 가져옴 — Task 3 테스트

---

### Task 1: 웹 에디터 — 대상·범위·음수

**Files:**
- Work copy: `<scratchpad>/project-void-cards.html` (`Artifact read` 로 받은 전체 HTML, 2656줄 모두 Read 후 사용)
- Test: `<scratchpad>/consumable-targets.test.js` (Node, `module.exports` 의 CardModel)

**Interfaces:**
- Produces (zip `cards.json` → `consumables[]`): `target: "ally"|"enemy"|"both"`, `area: [[x,y],…]` (−2..2, 정렬·중복 제거 = `normalizeArea`)

- [ ] **Step 1: 실패 테스트** — `normalizeConsumable({})` → `target === "ally"`, `area` `[]`; `normalizeConsumable({target:"enemy", area:[[0,0],[1,0],[9,9]]})` → `target "enemy"`, `area [[0,0],[1,0]]`; 모르는 target → `"ally"`; `validateConsumable({name:"폭탄", effects:[{type:"heal_hp",kind:"flat",amount:"-20"}]})` → `[]`; `exportConsumable` 결과에 `target`, `area` 포함; `formatEffect({type:"heal_hp",kind:"flat",amount:-20})` → `"HP 회복 -20"`
- [ ] **Step 2: `node consumable-targets.test.js` → 실패 확인**
- [ ] **Step 3: CardModel 수정** — `ITEM_TARGETS = ["ally","enemy","both"]`, `ITEM_TARGET_LABELS = {ally:"아군", enemy:"적", both:"둘 다"}`, `ITEM_TARGET_BADGES = {ally:"아", enemy:"적", both:"양"}` export; `normalizeConsumable` 에 `target`, `area: normalizeArea(r.area)`; `validateConsumable` 에서 "회복 수치는 0 이상" 검사 삭제; `exportConsumable` 에 `target`, `area`. 가져오기 계획(`list("consumables")` 부분)은 `normalizeConsumable` 을 거치므로 자동 반영 — 확인만
- [ ] **Step 4: Node 테스트 통과**
- [ ] **Step 5: 편집 UI** — `#co-form` 의 효과 칸 위에 `사용 대상` seg(`#c-target`)와 `범위` 격자(`#c-area`, 클래스 `area-edit`, 카드의 `#f-area` 렌더 함수를 아이템 초안용으로 재사용 — `toggleCell`). 설명 `범위 (가운데가 고른 유닛, 아무것도 안 고르면 한 명. 고른 유닛과 같은 편에만)`. `renderConsumable` 의 그림 위에 카드의 `card-side` 처럼 대상 배지 + `miniGrid(area)` (색 변수 `--cat` 을 `var(--consumable)` 로). 효과 수치 입력의 `min` 제거
- [ ] **Step 6: 게시** — `Artifact publish` (url `https://claude.ai/artifact/T2zETQHPfWew1HejtgHKHd`, capabilities 생략=유지). 아티팩트에서 새 아이템을 적·범위·`HP 회복 -20` 으로 저장 → 내보내기 zip 의 `cards.json` 확인

### Task 2: Godot 데이터 — `ConsumableData.target/area`, `ConsumableLine` 음수

**Files:**
- Modify: `Scripts/items/consumable_data.gd`, `Scripts/items/consumable_line.gd`
- Test: `tests/items/test_consumable_data.gd`

**Interfaces:**
- Produces: `enum ConsumableData.Target { ALLY, ENEMY, BOTH }`, `@export var target: Target = Target.ALLY`, `@export var area: Array[Vector2i] = []`, `func allows_side(side: int) -> bool`; `ConsumableLine.amount_for(max_value: int) -> int` (부호 있음)

- [ ] **Step 1: 실패 테스트**
  - `amount_for`: FLAT −20 → −20; PERCENT −20, max 99 → −19 (`floor(99*20/100)=19`, 부호 −); PERCENT 1, max 10 → 1 (최소 1 유지); PERCENT −1, max 10 → −1; amount 0 (FLAT·PERCENT) → 0
  - `describe()`: HEAL_HP FLAT −20 → `"HP 회복 -20"`, HEAL_SP PERCENT −10 → `"SP 회복 -10%"`
  - `allows_side`: ALLY → ALLY true / ENEMY false; ENEMY 반대; BOTH 둘 다 true
  - 새 `ConsumableData` 기본 `target == ALLY`, `area.is_empty()`
- [ ] **Step 2: GUT `-gselect=test_consumable_data` → 실패**
- [ ] **Step 3: 구현** — `amount_for`: 0 이면 0, 그 밖은 크기 = FLAT `|amount|` / PERCENT `floori(max_value * |amount| / 100.0)`, 크기 최소 1, 부호 = `signi(amount)`. `area` 칸 위에 인스펙터 5×5 편집기가 `CardData.area` 용으로 되어 있으면(`addons/` 의 인스펙터 플러그인이 `CardData` 만 보는지 확인) `ConsumableData` 도 받게 한 줄 확장, 아니면 기본 배열 편집기 그대로. 주석: "amount 0 이상" 문구 → "음수면 그만큼 깎는다 (HP 는 피해가 아님)"
- [ ] **Step 4: 통과**
- [ ] **Step 5: Commit** `feat: consumable target side, area, negative amounts`

### Task 3: `ConsumableImporter` + 확인 창

**Files:**
- Create: `addons/card_importer/consumable_importer.gd`
- Modify: `addons/card_importer/plugin.gd` (확인 창 글, apply 순서: 카드 → 장비 → 소비 아이템)
- Test: `tests/cards/test_consumable_importer.gd` (`test_equipment_importer.gd` 와 같은 user:// 임시 폴더 방식)

**Interfaces:**
- Consumes: `CardImporter` 공용 도구 `_text`, `_safe_name`, `_load`, `_save`, `_delete`, `_tres_paths`, `_remove_empty_dirs`; Task 2 의 `target`, `area`
- Produces: `class_name ConsumableImporter`, `_init(root_dir := "res://items/consumables")`, `load_export(data: Dictionary, art := {})`, `preview() -> Dictionary` = `{added: PackedStringArray, updated: PackedStringArray, removed: [{name, has_effects: bool}], dropped: [{name, count: int}]}`, `apply()`

- [ ] **Step 1: 실패 테스트** (각각 하나의 test 함수)
  - `test_new_item_created`: `{id:"c1", name:{ko:"폭탄"}, target:"enemy", area:[[0,0],[0,1]], effects:[{type:"heal_hp",kind:"flat",amount:-20},{type:"heal_sp",kind:"percent",amount:10}], keywords:["k1"]}` → `root/폭탄.tres`: `id "c1"`, `target ENEMY`, `area [Vector2i(0,0),Vector2i(0,1)]`, lines 2개 (HEAL_HP FLAT −20, HEAL_SP PERCENT 10), keywords `["k1"]`
  - `test_buff_lines_dropped_and_previewed`: effects 에 buff 1줄 + heal_hp 1줄 → lines 1개; `preview().dropped == [{name:"힘의 물약", count:1}]`
  - `test_old_item_without_target_area_is_ally_single`: target·area 없음 → `ALLY`, `[]`
  - `test_unknown_target_falls_back_to_ally`, `test_area_out_of_range_and_duplicates_dropped` (`[[3,0],[0,0],[0,0]]` → `[(0,0)]`)
  - `test_reimport_keeps_godot_effects`, `test_rename_moves_file_keeps_uid`, `test_removed_item_deleted_and_previewed` (`has_effects` 표시), `test_file_without_id_untouched` (id 없는 `회복약.tres` 를 미리 저장 → 같은 이름 아이템이 오면 `회복약_<id>.tres`, 원본 그대로), `test_zip_without_consumables_key_changes_nothing`, `test_art_copied_and_unused_removed` (`root/art/`)
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** — `EquipmentImporter` 에서 종류 폴더·착용 확인을 뺀 같은 흐름 (지움 → 비켜 두기 → 옮기기 → 웹 칸 채우기 → 안 쓰인 그림 정리). 경로 `root/<이름>.tres`, 겹치면 `_<id>`. `_fill`: 이름·설명·keywords·art·`target`(`{"ally":ALLY,"enemy":ENEMY,"both":BOTH}`, 그 밖 ALLY)·`area`(−2..2, 중복 제거)·`lines`(`heal_hp`/`heal_sp` 만, 정수 amount). `effects` 는 손대지 않음. `preview()` 의 `dropped` 는 `buff`·모르는 type 줄 수 > 0 인 아이템만
- [ ] **Step 4: 통과**
- [ ] **Step 5: plugin.gd** — `_consumables := ConsumableImporter.new()`, 같은 `get_data()/get_art()`, 확인 창에 `_describe_consumables(p)`:
  ```
  소비 아이템
  추가 N개: …
  덮어쓰기 N개: …
  삭제 N개: …            (has_effects 면 이름 앞 "⚠ ")
  ⚠ 버프 효과는 아직 Godot 에 없어 빼고 가져옴: 힘의 물약(1줄), …   (dropped 있을 때만)
  ```
  `apply()` 는 장비 다음. `@tool` 플러그인이라 헤드리스 테스트 없음 — 에디터에서 실제 zip 으로 확인 (Task 6)
- [ ] **Step 6: Commit** `feat: import consumables from web editor zip`

### Task 4: 전투 규칙 — 편·범위·HP/SP 감소

**Files:**
- Modify: `Scripts/battle/battle_types.gd` (Event 맨 뒤 `HP_LOST`), `Scripts/battle/battle.gd` (`can_use_item`, `use_item`, 새 `lose_hp`, `item_targets_of`), `Scripts/battle/battle_session.gd` (`item_targets` 주석, `use_item`)
- Test: `tests/battle/test_items.gd`

**Interfaces:**
- Produces: `Battle.lose_hp(target: BattleUnit, amount: int, source = null) -> void` (amount > 0 만큼 HP 감소, 0 밑으로 안 감, `HP_LOST` 이벤트 amount = 실제 감소량, 0 이 되면 `_on_unit_died`); `Battle.item_affected(item: ConsumableData, picked: BattleUnit) -> Array[BattleUnit]` = 살아 있는 `area_targets(picked, item.area)`; `Battle.use_item(item, target) -> bool` 시그니처 그대로; `Event.HP_LOST` (actor null, target, amount, source = 아이템); `ITEM_USED` 는 고른 유닛을 target 으로 한 번

- [ ] **Step 1: 실패 테스트**
  - `can_use_item`: ALLY 아이템 → foe false / me true; ENEMY → foe true / me false; BOTH → 둘 다 true; 죽은 유닛 false
  - `test_negative_hp_is_not_damage`: foe `block = 10`, ENEMY 아이템 HEAL_HP FLAT −20 → foe.hp 80, block 10 그대로, `DAMAGE_TAKEN`·`DAMAGE_DEALT` 이벤트 없음, `HP_LOST` amount 20 한 번
  - `test_negative_hp_stops_at_zero_and_kills`: hp 5 에 −20 → hp 0, `UNIT_DIED`, `HP_LOST` amount 5
  - `test_negative_sp_stops_at_zero`: sp 1 에 HEAL_SP −3 → sp 0
  - `test_zero_amount_does_nothing`: HEAL_HP 0 → hp 그대로, `HEALED`/`HP_LOST` 없음
  - `test_area_hits_same_side_only`: 적 2명(같은 열 위아래)·아군 1명, ENEMY 아이템 area `[(0,0),(0,1)]`, −10 → 두 적 −10, 아군 그대로
  - `test_area_offsets_only` (Review Focus): area `[(0,1)]` 이면 고른 유닛은 빠지고 아래 칸 유닛만 (카드 광역과 같은 규칙)
  - `test_effects_run_per_affected_unit`: Godot `effects` 에 기록용 효과 → 범위 2명에게 각각 한 번, 주인 = 그 유닛
  - 세션: `test_killing_last_enemy_with_item_wins` (`finished` 시그널 winner ALLY), `test_item_kills_active_ally_passes_turn` (BOTH 아이템 −999 를 지금 아군에게 → active 바뀜)
  - 기존 테스트 중 "적에게는 못 씀" 을 기대하는 것은 ALLY 아이템 기준이므로 그대로 통과해야 함
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** — `can_use_item`: `item.allows_side(target.side)` 로 교체. `use_item`: `for u in item_affected(item, target)` 마다 줄 적용 — HEAL_HP 양수 `heal`, 음수 `lose_hp(u, -v, item)`; HEAL_SP 양수 지금처럼, 음수 `u.sp = maxi(0, u.sp + v)`; 그다음 `effects` (ctx.owner = u, targets = [u]). 죽은 유닛은 다음 줄에서 건너뜀. 마지막 `ITEM_USED` (target = 고른 유닛). `lose_hp` 는 `_deal_damage` 의 사망 단계만 따라 하고 방어도·트리거 필터용 피해 이벤트는 쓰지 않는다
- [ ] **Step 4: 통과 + 전체 `tests/battle` 통과**
- [ ] **Step 5: Commit** `feat: items can target enemies, hit an area, and lower HP/SP`

### Task 5: 전투 화면 — 적 강조·범위 표시·HP 감소 숫자

**Files:**
- Modify: `Scripts/ui/battle_screen.gd` (`_show_event`, `_draw_marks`, `_update_arrow`)
- Test: `tests/ui/test_battle_screen_items.gd`

**Interfaces:**
- Consumes: Task 4 `Battle.item_affected`, `Event.HP_LOST`

- [ ] **Step 1: 실패 테스트**
  - ENEMY 아이템을 골랐을 때 적 토큰 `set_highlight` 켜짐, 아군 꺼짐 (기존 아군 강조 테스트와 같은 방식)
  - 범위 아이템을 고르고 마우스가 적 위 → 그 적과 범위 안 적의 칸이 `GridCell.Mark.AREA`
  - `HP_LOST` 이벤트 → 기록에 `"%s HP -%d"` (예 `고블린 HP -20`), 숫자는 `damage_color`
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** — `_draw_marks(targets, hover)` 에 아이템 분기: `selected_item >= 0` 이고 hover 가 `session.item_targets(item)` 에 있으면 `battle.item_affected(item, hover)` 칸에 AREA. `_update_arrow` 의 아이템 분기 끝에서 `_draw_marks([], over)` 호출. `_show_event` 에 `E.HP_LOST` 추가. 강조는 기존 `item_targets` 가 편을 따르므로 코드 변경 없음일 수 있음 — 테스트로 확인
- [ ] **Step 4: 통과**
- [ ] **Step 5: Commit** `feat: battle screen shows item area and HP loss`

### Task 6: 실제 확인·문서

**Files:**
- Modify: `CLAUDE.md` (소비 아이템 데이터 줄: 가져오기 있음, 버프만 없음 / 소비 아이템 규칙: 대상 아군·적·둘 다, 범위, 음수 = HP·SP 감소이며 피해 아님), `docs/progress.md`, 이전 설계 `2026-11-17-consumable-items-design.md` 상단에 "대상·음수는 consumable-targets 설계로 대체" 한 줄

- [ ] **Step 1: 전체 GUT 통과** (복사본)
- [ ] **Step 2: 에디터에서 실제 확인** — Task 1 의 zip 을 **카드 가져오기** → 확인 창에 소비 아이템·버프 경고 → `items/consumables/` 에 파일 → F6 전투 화면 `test_items` 에 폭탄 → 적에게 끌어서 범위 표시·HP 감소 숫자·승리 확인
- [ ] **Step 3: 문서 갱신 후 Commit** `docs: consumable targets and import`
