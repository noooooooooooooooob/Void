# 소비 아이템 에디터 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 웹 카드 에디터 아티팩트에 소비 아이템 탭(만들기·고치기·내보내기·가져오기)을 추가한다.

**Architecture:** 아티팩트 HTML 한 파일. 순수 로직은 `CardModel` IIFE(Node 에서 `module.exports`)에, 화면은 아래 스크립트에. 장비 탭 코드를 패턴 그대로 따라 db 컬렉션 `consumables` 를 추가한다.

**Tech Stack:** 바닐라 JS, artifact runtime (`claude.use("db"|"assets"|"downloads"|"user")`), Node(테스트)

**Spec:** `docs/superpowers/specs/2026-11-16-consumable-editor-design.md`

## Global Constraints

- 작업 파일: 아티팩트 소스 사본 `<scratchpad>/project-void-cards.html` → 같은 아티팩트 URL 로 republish (capabilities 유지 → 생략)
- 효과 type: `heal_hp`, `heal_sp`, `buff`. kind: `flat` | `percent`. buff 만 `stat`(STATS 중), `turns`(1 이상 정수)
- 회복 amount 0 이상 정수, 버프 amount 음수 허용 정수
- 표시: `HP 회복 +30`, `SP 회복 +20%`, `공격 +5 (3턴)` (값이 % 인 스탯 고정값은 `%p`, formatStat 재사용)
- 등급 없음. 탭 "소비 아이템", 버튼 "새 아이템"
- 기존 카드·장비·키워드 동작 불변, `consumables` 없는 zip 정상

## Review Focus

- `consumables` 키 없는 예전 zip 가져오기 → 소비 아이템 변경 0, 오류 없음 (Task 1 테스트)
- buff 가 아닌 효과에 stat/turns 가 섞여 들어옴 → normalize 가 버림 (Task 1 테스트)
- 소비 아이템과 카드가 같은 그림을 공유한 채 카드 삭제 → 그림 유지 (Task 2, assetInUse 에 포함)
- 키워드 삭제 확인 문구의 사용 수에 소비 아이템 포함 (Task 1 keywordUsage 테스트)
- 입력 중 amount 가 "" 이나 "-" → 저장 시 검증 오류, 미리보기는 0 으로 (Task 1 validate 테스트)

---

### Task 1: CardModel 소비 아이템 로직

**Files:**
- Modify: `<scratchpad>/project-void-cards.html` (CardModel IIFE)
- Test: `<scratchpad>/test/consumable.test.js` (HTML 에서 첫 `<script>` 내용을 잘라 `vm` 으로 실행, `module.exports` 로 api 획득)

**Interfaces — Produces:**
- `EFFECT_TYPES = ["heal_hp","heal_sp","buff"]`, `EFFECT_LABELS = { heal_hp: "HP 회복", heal_sp: "SP 회복", buff: "스탯 버프" }`
- `normalizeEffect(raw) -> {type,kind,amount} | {type:"buff",stat,kind,amount,turns} | null`
- `normalizeConsumable(raw) -> {name,nameEn,description,descriptionEn,effects,keywords,illustration}`
- `validateConsumable(raw) -> string[]`
- `formatEffect(effect) -> string`
- `filterConsumables(list, {query, sort: "name"|"manual"}) -> list`
- `keywordUsage(cards, id, equipment = [], consumables = [])`
- `exportAssets(cards, decks, equipment = [], consumables = [])`
- `buildExport({..., consumables = []}, artPath)` → `consumables: [{id,name:{ko,en},description:{ko,en},effects,keywords,art}]`
- `planImport` → `plan.consumables = {add, update}`, `plan.consumablesSame`

- [ ] **Step 1: 실패 테스트 작성** — 단언:
  - `normalizeEffect({type:"heal_hp",kind:"percent",amount:"20",stat:"attack",turns:3})` → `{type:"heal_hp",kind:"percent",amount:20}`
  - `normalizeEffect({type:"buff",stat:"attack",amount:5,turns:3})` → `{type:"buff",stat:"attack",kind:"flat",amount:5,turns:3}`; 모르는 type → `null`; buff 에 모르는 stat → `null`
  - `validateConsumable({name:"",effects:[]})` 포함 "이름을 입력하세요"; heal amount `"-1"` → 오류; buff turns `"0"` → 오류; buff amount `"-3"` → 오류 없음; amount `""` → 오류
  - `formatEffect` 세 표시 문자열 (Global Constraints) + `{type:"buff",stat:"crit_rate",kind:"flat",amount:10,turns:2}` → `"치명확률 +10%p (2턴)"`
  - `keywordUsage([], "k", [], [{keywords:["k"]}]) === 1`
  - `buildExport` 에 소비 아이템 1개 → `json.consumables[0]` 형식, 그림 경로
  - `planImport({cards:[]}, current)` → `plan.consumables.add.length === 0`; 새 소비 아이템 → add 1; 같은 내용 → `consumablesSame === 1`
- [ ] **Step 2:** `node --test <scratchpad>/test` → 함수 없음으로 FAIL
- [ ] **Step 3:** 위 Interfaces 구현. 장비 함수(normalizeEquipment/validateEquipment/filterEquipment/exportEquipment/planImport 장비 블록) 형태를 그대로 따른다
- [ ] **Step 4:** `node --test` → 기존 동작 포함 전부 PASS

### Task 2: 소비 아이템 탭 화면

**Files:** Modify `<scratchpad>/project-void-cards.html` (CSS, 마크업, 화면 스크립트)

**Interfaces — Consumes:** Task 1 의 모든 함수

- [ ] **Step 1:** CSS 토큰 `--consumable`(라이트 `#3a8f6b`, 다크 `#5cc497`) 3곳, `.equip.consumable { --rar: var(--consumable) }` 로 장비 카드 틀 재사용
- [ ] **Step 2:** 탭 버튼 `data-view="consumables"`, `#view-consumables`(검색 `#co-search`, 정렬 `#co-sort` 이름순/직접 정렬, `#co-grid`), 상단 `#new-consumable` "새 아이템", 편집 시트 `#co-editor` (이름·영어 이름·효과 줄 `#c-effects` + `#c-effect-add`·그림·키워드·설명·영어 설명·오류·미리보기·저장/복제/삭제)
- [ ] **Step 3:** 스크립트: `state.consumables`, `state.coFilter`, `renderConsumable`, `renderConsumableGrid`, 편집기(`coDraft`, 효과 줄 행: type select / buff 일 때 stat select·turns 입력 / kind seg / amount), 저장·복제·삭제(그림 정리), `applyOrder` 에 `consumables`, `render()` 분기, `assetInUse`·덱 삭제 그림 필터·`keywordUsage`/`exportAssets`/`buildExport` 호출에 소비 아이템 전달, 키워드 탭 문구 "카드·장비·아이템"
- [ ] **Step 4:** boot 에 `consumables` onSnapshot, `firstSnap.consumables`, 키워드 스냅샷 시 `coDraft` 갱신, 가져오기 미리보기·적용에 소비 아이템 줄 추가
- [ ] **Step 5:** `node --test` PASS 유지 + HTML 스크립트 구문 검사(`node --check` 로 두 스크립트 추출 검사)

### Task 3: 배포·확인

- [ ] **Step 1:** 같은 아티팩트 URL 로 publish
- [ ] **Step 2:** 진행 기록 `docs/progress.md` 한 줄, CLAUDE.md 카드 데이터 줄에 소비 아이템(웹만, Godot 미구현) 한 줄
