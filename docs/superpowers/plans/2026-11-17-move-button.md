# 이동 버튼 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 이동 버튼을 눌렀을 때만 이동 칸 표시·이동
**Spec:** `docs/superpowers/specs/2026-11-17-move-button-design.md`
**Global Constraints:** 버튼은 씬 노드(에디터 MCP 또는 에디터 끈 상태 헤드리스). 테스트는 `../Void_test` 복사본.

### Task 1: 이동 모드
**Files:** `Scripts/ui/battle_screen.gd`, `Scenes/ui/battle_screen/battle_screen.tscn` (BottomRight/MoveButton, BagButton 앞), `tests/ui/test_battle_screen.gd`
**Produces:** `BattleScreen.toggle_move() -> void`, `BattleScreen.is_move_mode() -> bool`

- [ ] 테스트: `test_click_cell_without_move_mode_does_nothing`, `test_click_reachable_cell_moves`(toggle_move 후, 이동 뒤 모드 꺼짐), `test_move_cells_shown_only_in_move_mode`, `test_selecting_card_ends_move_mode`, `test_cancel_ends_move_mode`, `test_move_button_disabled_without_move_left`
- [ ] 실패 확인 → 씬에 버튼 추가 → 구현 → 전체 통과 → progress.md
