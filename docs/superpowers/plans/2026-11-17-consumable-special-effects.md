# 소비 아이템 특수 효과 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 분노 포션·쉴드 포션·폭탄을 써서 실제 효과가 나게 한다.
**Architecture:** 코드 변경 없음. `ConsumableData.effects`(Godot 담당)에 기존 효과 부품을 넣고, 새 상태 `rage_potion.tres` 하나를 만든다.
**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1
**Spec:** `docs/superpowers/specs/2026-11-17-consumable-special-effects-design.md`

## Global Constraints
- `.tres` 는 에디터를 끈 상태에서 Godot 헤드리스 스크립트(scratchpad)로 저장. 손으로 텍스트 작성 금지
- 테스트는 복사본 `../Void_test` 에서 실행
- 웹 칸(lines·target·area·설명)은 건드리지 않는다

## Review Focus
- 분노 포션을 두 번 마신 뒤 엔드 페이즈 → 수치 2 가 한 번에 모두 사라져야 함 (테스트 있음)
- 다른 유닛의 엔드 페이즈에는 분노가 남아야 함 (테스트 있음)
- 폭탄 범위 안 적에게 방어도가 있으면 방어도부터 깎임 (기존 apply_damage 규칙, 테스트 있음)
- 다시 카드 가져오기 해도 effects 유지 (consumable_importer 기존 테스트가 보장)

---

### Task 1: 세 아이템 데이터 + 분노 상태

**Files:**
- Create: `statuses/data/rage_potion.tres` (StatusData: id `rage_potion`, 이름 "분노", BUFF, uses_stacks; modifier ATTACK PERCENT 10 × StackCountValue("rage_potion"); trigger END_PHASE / OWNER_IS_ACTOR → ModifyStacksEffect(rage_potion, −1, target OWNER, multiplier StackCountValue("rage_potion")))
- Modify: `items/consumables/폭탄.tres` effects = [DamageEffect use_flat, flat 10, can_crit false]
- Modify: `items/consumables/쉴드 포션.tres` effects = [BlockEffect use_flat, flat 10]
- Modify: `items/consumables/분노 포션.tres` effects = [ApplyStatusEffect status rage_potion, stacks 1]
- Test: `tests/battle/test_items.gd`

- [ ] Step 1: 테스트 추가 — `test_bomb_deals_10_to_each_enemy_in_area`, `test_bomb_hits_block_first`, `test_shield_potion_gives_10_block`, `test_rage_potion_raises_attack_10_percent`, `test_rage_stacks_and_clears_all_on_own_end_phase`, `test_rage_survives_other_units_end_phase`
- [ ] Step 2: 복사본에서 실행 → 새 테스트 실패 확인
- [ ] Step 3: 에디터 끈 상태에서 헤드리스 스크립트로 4 파일 저장
- [ ] Step 4: 복사본 동기화 후 전체 테스트 통과 확인
- [ ] Step 5: progress.md 갱신
