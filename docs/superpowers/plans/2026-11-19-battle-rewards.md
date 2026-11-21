# 전투 보상 목록 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 의뢰 전투 승리 후 결과 창에 보상 목록(공허 조각·소비 아이템·카드 추가)을 띄우고, 줄을 클릭해서 챙기게 한다.

**Architecture:** 보상 보관·챙기기 규칙은 순수 로직 `BattleReward`(RefCounted). 카드 후보 뽑기는 상점과 같은 규칙이라 `CardPool.pick_party_cards` 로 꺼내 Shop 과 함께 쓴다. `BattleScreen` 은 승리 때 `BattleReward` 를 만들고 결과 창에 줄을 그리기만 한다.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1

**Spec:** `docs/superpowers/specs/2026-11-19-battle-rewards-design.md`

## Global Constraints
- 게임 스크립트는 `Scripts/<기능>/`, 테스트는 `tests/<기능>/`. 모든 게임 스크립트에 한국어 주석(클래스 `##`, 공개 함수·변수 `##`)
- 씬 노드는 코드로 조립하지 않는다. 보상 줄은 씬 안 템플릿 버튼을 `duplicate()`, 카드 후보 칸은 `res://Scenes/ui/shop_screen/shop_card_offer.tscn` 을 instantiate
- `.tscn` 은 손으로 쓰지 않는다: 에디터가 켜져 있으면 GoPeak MCP `scene-node-add` (단, `scene-node-set` 금지 — 인스턴스 있는 씬을 망가뜨림), 꺼져 있으면 Godot 헤드리스 스크립트로 PackedScene 을 열어 고치고 `ResourceSaver.save`
- 테스트는 프로젝트 **복사본**에서 실행 (MCP 플러그인·MCPRuntime 끄고 `--log-file` 따로):
  `Godot_v4.7.2-stable_win64_console.exe --headless --path <복사본> --import` 후
  `... --headless --path <복사본> -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- `UnitData.deck` 원본은 절대 안 바꾼다. 카드는 주인의 `BattleUnit.run_deck` 맨 뒤로
- 카드 보상 장수 기본 3 (`BattleScreen.card_reward_count`), 보스 전투는 카드 보상 없음, 시험 전투(F6)·패배는 보상 없음

## Review Focus
- 가방이 가득 찬 상태에서 아이템 줄 클릭 → 바꿀 칸 고르기가 뜨고, 취소하면 아이템 줄이 그대로 남아야 함 (Task 3 테스트)
- 카드 창 "넘어가기" 후 다시 열면 같은 3장 (Task 2·3 테스트)
- 살아 있는 파티원 카드 후보가 3장보다 적으면 있는 만큼, 0장이면 카드 줄 자체가 없음 (Task 1·3 테스트)
- 아무것도 안 챙기고 "계속" → 지갑·덱·가방 그대로, 노드 클리어 (Task 3 테스트)
- 같은 줄 두 번 챙기기(빠른 더블클릭) → 두 번 지급되지 않음 (Task 2 테스트)

---

### Task 1: `CardPool.pick_party_cards` 로 카드 후보 뽑기 공용화

**Files:**
- Modify: `Scripts/cards/card_pool.gd` (함수 추가)
- Modify: `Scripts/shop/shop.gd:110-121` (`_stock_cards` 가 새 함수 사용)
- Test: `tests/cards/test_card_pool.gd`

**Interfaces:**
- Produces: `static func pick_party_cards(party: Array[BattleUnit], pool: Array[CardData], n: int, rng: RandomNumberGenerator) -> Dictionary` — 반환 `{"cards": Array[CardData], "owners": Array[BattleUnit]}` (같은 길이). 규칙은 지금 `Shop._stock_cards` 그대로: 파티원 순서대로 `cards_for` 를 모아 겹치는 카드는 먼저 찾은 주인, 그 중 겹치지 않게 최대 n 장 무작위

- [ ] **Step 1: 실패하는 테스트**
  - `test_pick_party_cards_only_party_cards_with_owner`: 유닛 u(deck_id "d1"), pool = d1 카드 5장 + d2 카드 3장, n=3 → `cards.size()==3`, 모두 deck_id "d1", 겹침 없음, `owners` 전부 u
  - `test_pick_party_cards_fewer_than_n`: d1 카드 2장, n=3 → 2장
  - `test_pick_party_cards_empty_party`: 파티 [] → cards·owners 모두 빈 배열
- [ ] **Step 2: 실행해서 실패 확인** (`-gtest=res://tests/cards/test_card_pool.gd`) — "Invalid call ... pick_party_cards"
- [ ] **Step 3: 구현.** `Shop._stock_cards` 의 루프를 옮기고, `Shop._stock_cards` 는 결과를 `cards`/`card_owners` 에 담기만 한다. `Shop._pick` 은 아이템 진열·강화 후보에서 계속 쓰므로 남긴다
- [ ] **Step 4: `tests/cards/test_card_pool.gd`, `tests/shop/test_shop.gd` 모두 PASS 확인**
- [ ] **Step 5: 커밋** `refactor: share party card picking between shop and rewards`

### Task 2: `BattleReward` 순수 로직

**Files:**
- Create: `Scripts/stage/battle_reward.gd`
- Test: `tests/stage/test_battle_reward.gd`

**Interfaces:**
- Consumes: `Wallet.add(n)`, `Inventory.add(item) -> bool`, `Inventory.replace(index, item) -> bool`, `Inventory.is_full()`
- Produces (`class_name BattleReward extends RefCounted`):
  - `var shards: int` (0 = 없음/챙김), `var item: ConsumableData` (null = 없음/챙김), `var cards: Array[CardData]`, `var card_owners: Array[BattleUnit]` (빈 배열 = 없음/챙김)
  - `func _init(shard_amount: int, drop: ConsumableData, card_offer: Array[CardData], owners: Array[BattleUnit])`
  - `func claim_shards(wallet: Wallet) -> bool` — shards > 0 이면 지갑에 넣고 0 으로
  - `func claim_item(inventory: Inventory) -> bool` — 가방에 빈 칸이 있으면 넣고 item = null. 가득 차면 false, 그대로
  - `func swap_item(inventory: Inventory, index: int) -> bool` — `replace` 성공 시 item = null
  - `func claim_card(index: int) -> bool` — 범위 안이면 `card_owners[index].run_deck.append(cards[index])`, cards·card_owners 비움
  - `func is_empty() -> bool` — 남은 보상이 없음

- [ ] **Step 1: 실패하는 테스트**
  - `test_claim_shards_adds_once`: 20 → claim 두 번, 지갑 20, 두 번째 false
  - `test_claim_item_into_bag`: 빈 가방 → true, 가방에 1개, item null
  - `test_claim_item_full_bag_keeps_it`: 5칸 가득 → false, item 그대로, 가방 5개
  - `test_swap_item_replaces_slot`: 가득 찬 가방 index 2 → true, `inventory.items[2]` 가 보상 아이템, item null, 가방 5개
  - `test_claim_card_goes_to_owner_run_deck_once`: 카드 3장·주인 u → claim_card(1) → u.run_deck 마지막이 cards[1] 이었던 카드, `u.data.deck` 길이 그대로, cards 빈 배열, 다시 claim_card(0) false
  - `test_claim_card_bad_index`: -1, 3 → false, 아무것도 안 바뀜
  - `test_is_empty`: 조각 0·item null·카드 없음 → true; 하나라도 있으면 false
- [ ] **Step 2: 실행해서 실패 확인**
- [ ] **Step 3: 구현** (클래스 `##` 에 규칙과 스펙 경로)
- [ ] **Step 4: PASS 확인**
- [ ] **Step 5: 커밋** `feat: battle reward claim logic`

### Task 3: 결과 창 보상 목록 (씬 + `BattleScreen`)

**Files:**
- Modify: `Scenes/ui/battle_screen/battle_screen.tscn` (ResultOverlay 노드)
- Modify: `Scripts/ui/battle_screen.gd` (드랍 부분 `:108-110`, `:137-139`, `:174-180`, `:360-386`, `:415-416`, `:768-806`)
- Test: `tests/ui/test_battle_screen_stage.gd` (드랍·조각 테스트를 새 동작으로 바꿈)

**씬 변경 (ResultOverlay/Box, ResultLabel 과 DropBox 사이):**
- `RewardList` (VBoxContainer, unique, separation 8) 아래 `RewardTemplate` (Button, unique, 최소 크기 480×64, 글자 26, visible=false)
- `DropBox` 는 "가방이 가득 참 — 바꿀 칸 고르기" 구역으로 계속 쓴다. `TakeButton` 삭제, `SkipButton` 글자 "취소"
- ResultOverlay 아래 `CardPick` (PanelContainer, unique, visible=false, 화면 가운데) → `Margin` → `Box`(VBox) → `CardPickTitle`(Label "카드 1장을 고르세요") / `CardPickRow`(HBoxContainer, unique) / `CardPickSkip`(Button, unique, "넘어가기")

**Interfaces:**
- Consumes: Task 1 `CardPool.pick_party_cards`, Task 2 `BattleReward`, `StageRun.roll_item_drop`, `StageRun.item_pool`, `StageRun.living_party()`, `StageRun.is_boss_battle()`, `CardPool.load_all()`
- Produces (`BattleScreen`):
  - `@export var card_reward_count := 3` (보스·시험 전투는 0 취급)
  - `var card_pool_dir := CardPool.DEFAULT_DIR` (테스트가 임시 폴더로 바꿈, `drop_pool_dir` 와 같은 방식)
  - `var reward: BattleReward` (의뢰 전투 승리 때만, 아니면 null). `pending_drop` 변수와 `take_drop()` 은 없앤다
  - `func click_shards()`, `func click_item()` (가득 차면 DropBox 표시), `func swap_drop(index: int)` (유지), `func skip_drop()` (= 바꿀 칸 고르기 취소, 아이템 줄 남음), `func open_card_pick()`, `func pick_card(index: int)`, `func close_card_pick()`
  - 줄 글자: `"공허 조각 %d"`, `"아이템: " + display_name`, `"카드 추가"`. 카드 칸 버튼 글자: `"<주인 이름> 덱에 추가"` (주인 이름은 `BattleUnit.data` 의 표시 이름 필드)
  - `RestartButton`("계속")은 결과 창에서 항상 보인다. `_show_result` 에서 `StageRun.wallet.add` 자동 지급 제거, 결과 글자에 "+조각" 붙이지 않음

- [ ] **Step 1: 테스트를 새 동작으로 바꾸고 추가**
  - 기존 `pending_drop`/`take_drop` 기준 테스트(113~205행)를 `reward.item`/`click_item` 으로 옮김
  - `test_stage_win_adds_shard_reward` → `test_stage_win_shards_only_after_click`: 승리 직후 지갑 0, `click_shards()` 후 20
  - `test_boss_win_adds_boss_reward` → 보스 승리, `click_shards()` 후 50, `reward.cards` 빈 배열
  - `test_stage_win_offers_three_party_cards`: 임시 카드 폴더(파티 첫 캐릭터 덱의 deck_id 카드 4장 저장) → `reward.cards.size()==3`, `open_card_pick()` 후 `%CardPickRow` 칸 3개
  - `test_pick_card_adds_to_owner_run_deck`: `pick_card(0)` → 주인 `run_deck` 길이 +1, `%CardPick` 숨김, 카드 줄 사라짐
  - `test_skip_card_pick_keeps_same_offer`: open → close → open, 같은 3장, 줄 남음
  - `test_full_bag_cancel_keeps_item_row`: 가득 찬 가방 + 드랍 100% → `click_item()` → DropBox 보임 → `skip_drop()` → `reward.item` 그대로, 가방 그대로
  - `test_continue_visible_with_unclaimed_rewards`: 승리 직후 `%RestartButton.visible == true`
  - `test_continue_without_claiming_changes_nothing`: 승리 → `_on_result_button()` → 지갑 0, 덱 그대로
  - `test_no_party_cards_no_card_row`: 빈 카드 폴더 → `reward.cards` 빈 배열, `%RewardList` 에 카드 줄 없음
  - 패배·시험 전투 → `reward == null`
- [ ] **Step 2: 실행해서 실패 확인**
- [ ] **Step 3: 씬 노드 추가/수정** (Global Constraints 의 방법. 에디터 상태를 먼저 확인)
- [ ] **Step 4: `battle_screen.gd` 구현** — `_show_result` 에서 `BattleReward` 생성(아이템은 기존처럼 화면용 `_fx_rng`), `_draw_rewards()` 가 `RewardList` 의 템플릿 외 자식을 지우고 남은 보상만큼 `duplicate()` 해 그림. 줄을 누를 때마다 `_draw_rewards()`·`_draw_bag()` 다시
- [ ] **Step 5: 전체 테스트 PASS 확인**
- [ ] **Step 6: 직접 실행 확인** — 의뢰 시작 → 전투 승리 → 조각·아이템·카드 줄 클릭, 가방 가득 참, 넘어가기, 계속
- [ ] **Step 7: 커밋** `feat: click-to-claim battle reward list with card reward`

### Task 4: 문서

**Files:**
- Modify: `CLAUDE.md` ("의뢰 스테이지" 보상 줄, "공허 조각·상점"의 자동 지급 표현), `docs/progress.md`

- [ ] **Step 1:** CLAUDE.md 의 "일반 전투 승리 시 확률로 소비 아이템 1개" 문장을 보상 목록 규칙(조각·아이템·카드 3장 중 1장, 클릭해서 챙김, 안 챙긴 건 사라짐, 보스는 조각만)으로 바꾸고 스펙 경로 표기
- [ ] **Step 2:** `docs/progress.md` 에 2026-11-19 항목
- [ ] **Step 3: 커밋** `docs: battle reward list`
