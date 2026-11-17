# 근접 카드 끌어 올려 쓰기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 근접 카드를 위로 `drag_play_height` 넘게 끌어 올려 놓으면 자동 대상에게 쓰이게 한다.

**Architecture:** `BattleScreen._release_drag` 의 자신 카드 높이 조건에 근접 카드를 더한다. `_play(null)` 은 근접 카드면 이미 자동 대상(`targets_for(card)[0]`)을 쓰는지 확인 후 사용. 화살표는 근접 카드일 때 이미 자동 대상에 붙어 "쓸 수 있음" 색이므로 변경 없음.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1

**Spec:** `docs/superpowers/specs/2026-11-17-melee-drag-play-design.md`

## Global Constraints
- 원거리·아군 카드, 소비 아이템 동작은 바뀌지 않는다
- 기준 높이에 못 미치게 끌고 유닛 없는 곳에서 놓으면 지금처럼 취소(손패 복귀)
- 테스트는 프로젝트 복사본에서 실행 (CLAUDE.md 에디터 켜짐 규칙)

## Review Focus
- 근접 카드 높이 미달 + 유닛 없는 곳에서 놓기 → 취소 (테스트 추가)
- 근접 카드를 높이 넘겨 놓되 다른 적(자동 대상 아님) 위에서 놓기 → `click_unit` 이 false 면 높이 규칙으로 자동 대상에 사용
- 원거리 카드를 높이 넘겨 빈 곳에 놓기 → 여전히 취소 (기존 `test_..._returns_card` 가 지킴)

---

### Task 1: 근접 카드 높이 기준 사용

**Files:**
- Modify: `Scripts/ui/battle_screen.gd:963-975` (`_release_drag` 와 그 위 `##` 주석)
- Test: `tests/ui/test_battle_screen.gd`

- [ ] **Step 1: 실패하는 테스트 작성** — 기존 `test_short_click_release_returns_card` 아래에

```gdscript
func test_melee_card_drag_up_plays_on_front_enemy():
	var s := _screen()
	var front := _enemy(s, "적A")
	s.select_card(_index_of(s, "타격"))
	s._dragging = true
	s._press_pos = Vector2(900, 1000)
	s._release_drag(Vector2(900, 1000 - s.drag_play_height - 10))  # 유닛 없는 곳, 기준 높이 위
	assert_eq(front.hp, 35)
	assert_null(s.selected)

func test_melee_card_short_drag_returns_card():
	var s := _screen()
	var front := _enemy(s, "적A")
	s.select_card(_index_of(s, "타격"))
	s._dragging = true
	s._press_pos = Vector2(900, 1000)
	s._release_drag(Vector2(900, 1000 - s.drag_play_height + 10))
	assert_eq(front.hp, 40)
	assert_null(s.selected)
	assert_eq(s.session.active.hand.size(), 5)
```
(빈 곳 좌표가 유닛 위가 아닌지 실행 시 확인; 겹치면 x 를 바꾼다. 적A 시작 HP 는 `_data()` 의 `enemy_hp` 기준으로 맞춘다.)

- [ ] **Step 2: 실행해 첫 테스트 실패 확인** — 복사본에서 `-gtest=res://tests/ui/test_battle_screen.gd -gunit_test_name=melee_card`

- [ ] **Step 3: 구현** — `_release_drag` 조건을 `_attack_type(selected) in ["self", "melee"]` 로, 주석을 "자신·근접 카드(대상 고를 필요 없음)를 충분히 끌어 올렸으면 사용 (2026-11-17)" 으로

- [ ] **Step 4: 전체 테스트 통과 확인** — `-gdir=res://tests -ginclude_subdirs -gexit`

- [ ] **Step 5: CLAUDE.md 카드 조작 규칙·`docs/progress.md` 갱신 후 커밋** (현재 브랜치에 다른 미커밋 작업이 많으므로 이 기능 파일만 add)
