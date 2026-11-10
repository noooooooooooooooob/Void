# 장비 에디터 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 웹 카드 에디터에서 장비를 만들고, 같은 zip 으로 Godot 에 가져오기·내보내기 한다. 장비 스탯이 실제 게임 스탯에 반영된다.

**Architecture:** Godot 쪽은 `EquipmentData` 에 웹 담당 칸을 추가하고, 웹 스탯(`stats`)은 `BattleUnit._modified` 가 장비에서 직접 읽어 더한다. 가져오기·내보내기는 카드와 분리된 `EquipmentImporter` / `CardExporter` 확장으로, 같은 zip(`cards.json` 의 `equipment` 키)을 쓴다. 웹은 아티팩트 한 파일(`CardModel` 순수 로직 + UI)에 `equipment` db 컬렉션과 장비 탭을 더한다.

**Tech Stack:** Godot 4.7.2 GDScript, GUT 9.7.1, 아티팩트 HTML/JS (db·assets·downloads), Node(웹 순수 로직 테스트)

**Spec:** `docs/superpowers/specs/2026-11-10-equipment-editor-design.md`

## Global Constraints

- 종류: `weapon` 무기 / `armor` 방어구 / `accessory` 장신구 (고정 3개)
- 등급: `normal` 노말 / `rare` 레어 / `unique` 유니크 / `relic` 유물 (고정 4개, 이 순서)
- 스탯 키 (= `BattleTypes.Stat` 순서): `hp, sp, attack, defense, speed, move, crit_rate, crit_damage, aggro, stamina, actions`; 종류 `flat` | `percent`; 수치 정수, 음수 허용
- 공식 그대로: `floor(기본 × (1 + %합/100)) + 고정합`
- 장비 파일: `res://statuses/equipment/<slot>/<이름>.tres`, 겹치면 `<이름>_<id>.tres`, id 로 찾음. 그림: `res://statuses/equipment/art/`
- id 없는 장비 파일은 가져오기·내보내기 모두 무시. 유닛(`res://entities/units/` 아래)이 착용 중인 장비는 zip 에 없어도 지우지 않음
- `equipment` 키 없는 예전 zip 은 장비를 하나도 바꾸지 않음 (삭제도 안 함)
- 카드·키워드 가져오기 동작은 바뀌지 않음 (기존 `test_card_importer.gd`·`test_card_exporter.gd` 그대로 통과)
- 모든 비테스트 스크립트에 한국어 주석 (CLAUDE.md 주석 원칙)
- GUT 는 **프로젝트 복사본**에서 실행 (에디터 켜짐 규칙). 복사본: `robocopy . ../Void_test /MIR /XD .godot .git` 후 MCP 플러그인 끄고 `--log-file`

## Review Focus

1. `equipment` 키가 없는 예전 zip 을 가져오면 기존 장비 파일이 그대로 남아야 한다 → Task 2 테스트 `test_zip_without_equipment_key_changes_nothing`
2. 장비 이름을 바꾸거나 종류를 바꾸면 파일이 옮겨지되 uid 가 유지되어 유닛 참조가 안 끊겨야 한다 → Task 2 `test_rename_moves_file_keeps_uid`
3. 웹에서 지운 키워드를 장비가 쓰고 있으면 내보낼 때 빠져야 한다 (카드와 같음) → Task 4 Node 테스트 `buildExport drops deleted keyword ids from equipment`
4. 스탯 줄이 비거나 수치가 정수가 아니면 저장 막기 → Task 4 `validateEquipment`
5. 장비 HP 보너스가 전투 시작 HP 에 반영되어야 한다 (HP +20 장비 → 시작 HP = 최대 HP) → Task 1 `test_equipment_hp_bonus_fills_start_hp`

---

### Task 1: EquipmentData 칸 추가 + 스탯 적용

**Files:**
- Modify: `Scripts/statuses/equipment_data.gd`
- Modify: `Scripts/battle/battle_unit.gd:60-72` (`_init`), `:107-123` (`_modified`)
- Test: `tests/battle/test_status_triggers.gd` (장비 테스트 옆에 추가)

**Interfaces:**
- Produces: `EquipmentData` 칸 — `id: String`, `display_name: String`(한국어 이름, 기존 칸 유지), `name_en: String`, `description_ko: String`, `description_en: String`, `slot: String = "weapon"`, `rarity: String = "normal"`, `stats: Array[StatModifier]`, `keywords: PackedStringArray`, `art: String`, `statuses`(기존, Godot 담당). 상수 `SLOTS := ["weapon","armor","accessory"]`, `RARITIES := ["normal","rare","unique","relic"]`

- [ ] **Step 1: 실패하는 테스트**

```gdscript
func test_equipment_stats_apply_flat_and_percent():
	# 기본 공격 10, +50% 와 +3 → floor(10*1.5)+3 = 18
	var eq := EquipmentData.new()
	eq.stats.assign([_mod(BattleTypes.Stat.ATTACK, BattleTypes.ModKind.PERCENT, 50), _mod(BattleTypes.Stat.ATTACK, BattleTypes.ModKind.FLAT, 3)])
	var u := _unit_with([eq])  # attack 10
	assert_eq(u.get_stat(BattleTypes.Stat.ATTACK), 18)

func test_equipment_hp_bonus_fills_start_hp():
	var eq := EquipmentData.new()
	eq.stats.assign([_mod(BattleTypes.Stat.HP, BattleTypes.ModKind.FLAT, 20)])
	var u := _unit_with([eq])  # max_hp 100
	assert_eq(u.hp, 120)
```

- [ ] **Step 2: 복사본에서 GUT 실행 → 두 테스트 FAIL (`stats` 없음)**
- [ ] **Step 3: 구현** — `equipment_data.gd` 에 위 칸·상수(주석 포함). `_modified` 의 상태 보정 루프 뒤에 `data.equipment` 의 `stats` 도 같은 방식으로 더한다. `_init` 끝에서 장비 상태를 붙인 뒤 `hp = get_stat(BattleTypes.Stat.HP)`
- [ ] **Step 4: 전체 GUT PASS** (`test_sample_data` 의 `display_name == "시험용 검"` 포함)
- [ ] **Step 5: 커밋** `feat: equipment web fields and stat bonuses`

### Task 2: EquipmentImporter (zip → 장비 .tres)

**Files:**
- Create: `addons/card_importer/equipment_importer.gd`
- Modify: `addons/card_importer/card_importer.gd` (공개 읽기 함수 2개)
- Test: `tests/cards/test_equipment_importer.gd`

**Interfaces:**
- Consumes: Task 1 `EquipmentData`
- Produces:
  - `CardImporter.get_data() -> Dictionary`, `CardImporter.get_art() -> Dictionary` (read_zip 결과 그대로)
  - `class_name EquipmentImporter`, `_init(root_dir := "res://statuses/equipment", units_dir := "res://entities/units")`
  - `load_export(data: Dictionary, art: Dictionary = {}) -> void`
  - `preview() -> Dictionary` = `{ added: PackedStringArray, updated: PackedStringArray, removed: [{name, has_statuses}], kept: [{name, units: PackedStringArray}] }`
  - `apply() -> void`
- 규칙: 경로·이름 겹침·파일 옮기기(임시 이름 → rename, `take_over_path`)는 `CardImporter._apply_cards` 와 같은 방식. 기존 파일은 불러와서 웹 칸만 덮어써 `statuses` 유지. 스탯 `{stat, kind, amount}` → `StatModifier`(stat = 키의 `BattleTypes.Stat` 순번, kind `percent`→PERCENT). 그림은 `root/art/` 로 복사, 안 쓰는 그림 정리(이 폴더만). `data` 에 `equipment` 키가 없으면 `apply()` 는 아무것도 안 한다

- [ ] **Step 1: 실패하는 테스트** (`test_card_importer.gd` 의 `user://` 임시 폴더 방식 그대로)
  - `test_new_equipment_created_in_slot_folder`: `{id:"e1", name:{ko:"검"}, slot:"weapon", rarity:"rare", stats:[{stat:"attack",kind:"flat",amount:5}], keywords:["k1"]}` → `root/weapon/검.tres` 의 `display_name=="검"`, `rarity=="rare"`, `stats[0].stat==ATTACK`, `stats[0].kind==FLAT`, `stats[0].amount==5.0`, `keywords==["k1"]`
  - `test_reimport_keeps_godot_statuses`: 파일에 `statuses` 하나 넣고 저장 → 이름 바꿔 다시 가져오기 → `statuses.size()==1`
  - `test_rename_moves_file_keeps_uid`: 이름·종류 변경 시 옛 파일 없음, 새 경로 파일의 `ResourceLoader.get_resource_uid` 가 이전과 같음
  - `test_removed_equipment_deleted_and_previewed`
  - `test_equipped_equipment_kept`: `units_dir` 에 장비를 참조하는 UnitData 저장 → zip 에서 빼고 apply → 파일 남음, `preview().kept[0].units == ["<유닛 display_name>"]`
  - `test_file_without_id_untouched`
  - `test_zip_without_equipment_key_changes_nothing`
  - `test_equipment_art_copied_and_unused_removed`
- [ ] **Step 2: GUT 실행 → FAIL (`EquipmentImporter` 없음)**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 전체 GUT PASS (기존 카드 가져오기 테스트 포함)**
- [ ] **Step 5: 커밋** `feat: import equipment from card editor zip`

### Task 3: 내보내기 + 메뉴 미리보기

**Files:**
- Modify: `addons/card_importer/card_exporter.gd`
- Modify: `addons/card_importer/plugin.gd`
- Test: `tests/cards/test_card_exporter.gd`

**Interfaces:**
- Consumes: Task 1·2
- Produces: `CardExporter._init(root_dir := "res://cards", equipment_dir := "res://statuses/equipment")`; `build()` 결과에 `"equipment": [...]` (스펙의 zip 형식, id 있는 파일만, 그림은 기존 `_art_entry` 로 `art/` 에)

- [ ] **Step 1: 실패하는 테스트** — `test_exports_equipment_with_stats_and_art` (장비 저장 → `build().equipment[0]` 의 `slot`, `rarity`, `stats == [{stat:"attack",kind:"flat",amount:5}]`, `art == "art/<파일>"`), `test_equipment_without_id_not_exported`, `test_round_trip_equipment` (build → EquipmentImporter 로 다른 폴더에 apply → 같은 칸)
- [ ] **Step 2: GUT → FAIL**
- [ ] **Step 3: 구현** — exporter 확장. plugin: `_on_file_selected` 에서 `EquipmentImporter` 도 `load_export(_importer.get_data(), _importer.get_art())`, `_describe` 에 장비 구역 추가 (`장비 추가 N개 / 갱신 / 삭제(⚠ = Godot 상태 함께 삭제) / 착용 중이라 남김: 이름(유닛)`), `_on_confirmed` 에서 둘 다 apply
- [ ] **Step 4: GUT PASS**
- [ ] **Step 5: 커밋** `feat: export equipment and show it in import preview`

### Task 4: 웹 — CardModel 장비 로직

**Files:**
- Work copy: `<scratchpad>/card-editor.html` (아티팩트를 `Artifact read` 로 받은 전체 HTML. 이 파일로 다시 게시)
- Test: `<scratchpad>/equipment-model.test.mjs` (HTML 의 첫 `<script>` 를 꺼내 `module.exports` 로 실행, `node:test`)

**Interfaces:**
- Produces (CardModel `api` 에 추가): `SLOTS`, `SLOT_LABELS = {weapon:"무기",armor:"방어구",accessory:"장신구"}`, `RARITIES`, `RARITY_LABELS = {normal:"노말",rare:"레어",unique:"유니크",relic:"유물"}`, `STATS`, `STAT_LABELS = {hp:"HP",sp:"SP",attack:"공격",defense:"방어",speed:"속도",move:"이동속도",crit_rate:"치명확률",crit_damage:"치명피해",aggro:"어그로",stamina:"스태미너",actions:"행동 횟수"}`, `PERCENT_UNIT_STATS = ["crit_rate","crit_damage"]`, `normalizeEquipment(raw)`, `validateEquipment(raw) -> string[]`, `filterEquipment(list, {slot, rarity, query})`, `formatStat({stat,kind,amount}) -> "공격 +5" | "속도 +10%"`
- Modify: `keywordUsage(cards, keywordId, equipment = [])` 장비도 셈; `buildExport({cards,decks,keywords,equipment}, artPath)` 에 `equipment`; `exportAssets` 에 장비 그림; `planImport` 에 `equipment: {add, update}` (삭제 없음, 그림은 카드와 같은 slots 방식)
- 웹 문서 형태: `{ name, nameEn, description, descriptionEn, slot, rarity, stats:[{stat,kind,amount}], keywords:[id], illustration, order? }`

- [ ] **Step 1: 실패하는 테스트** — normalize 기본값(slot weapon, rarity normal, 잘못된 stat 줄 버림), `validateEquipment` (이름 없음, amount `"1.5"`·`""` → 오류), `formatStat` (음수 `"공격 -3"`), `buildExport` 장비 칸·지운 키워드 빠짐, `planImport` 추가/변경/같음, `keywordUsage` 장비 포함
- [ ] **Step 2: `node --test` → FAIL**
- [ ] **Step 3: 구현**
- [ ] **Step 4: `node --test` PASS**

### Task 5: 웹 — 장비 탭 UI + 게시

**Files:** `<scratchpad>/card-editor.html` (UI 스크립트)

- [ ] **Step 1: 구현** — 탭 `장비`; 툴바(종류 칩, 등급 칩, 검색, 정렬 이름순/직접 정렬); 장비 타일(이름, 그림, 종류 배지, 등급 테두리 색 `--normal/--rare/--unique/--relic` 라이트·다크 둘 다, 스탯 줄 목록, 키워드, 설명, 키워드 팝업); "새 장비" 버튼; 편집 시트(이름·영어 이름, 종류·등급 seg, 스탯 줄 추가/삭제 [스탯 select][+/% seg][수치], `PERCENT_UNIT_STATS` 에 % 고르면 안내 "기본값에 곱해요. 기본이 0이면 효과 없음 — 10%p 를 원하면 + 를 고르세요", 그림, 키워드 칩, 설명 한·영, 저장/복제/삭제); db 컬렉션 `equipment` 구독; 그림 삭제 시 카드·장비 둘 다 확인 후 지움; 내보내기·가져오기에 장비 포함, 가져오기 확인 창에 장비 줄
- [ ] **Step 2: 게시** — `Artifact publish` (url `https://claude.ai/artifact/T2zETQHPfWew1HejtgHKHd`, 같은 capabilities)
- [ ] **Step 3: 브라우저 확인** — 장비 만들기 → 스탯 2줄 → 저장 → 타일 표시 → 내보내기 zip 의 `cards.json` 에 `equipment` 확인

### Task 6: 끝까지 확인 + 문서

- [ ] **Step 1:** 내보낸 zip 을 복사본 프로젝트에서 `EquipmentImporter` 로 가져와 `.tres` 생성 확인 (헤드리스 스크립트)
- [ ] **Step 2:** `CLAUDE.md` Tech Stack 의 카드 데이터 줄에 장비 한 줄, `docs/progress.md` 갱신
- [ ] **Step 3: 커밋** `docs: equipment editor flow`
