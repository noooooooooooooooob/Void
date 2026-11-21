# 연출 화면 배경 고르기 · 칸 하나씩 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 연출 화면 탭에서 배경을 고르고, 행위자·적 하나와 그 둘의 칸만 보이게 한다.
**Architecture:** `PerformanceStageView` 가 배경 목록(OptionButton)을 갖고, 고르면 배경만 바꾼 BattleData 복제로 무대를 다시 깐다. 보이기(유닛·칸)는 `_update_visible()` 한 곳에서. 저장은 플러그인이 `background_selected` 시그널로.
**Tech Stack:** Godot 4.7.2 GDScript, GUT
**Spec:** `docs/superpowers/specs/2026-11-21-stage-view-background-pick-design.md`

## Global Constraints
- 배경 목록 폴더 `res://Scenes/backgrounds/`, `.tscn`(.remap 뗌)
- 칸 크기·자리는 `battles/test_battle.tres`
- 에디터 켜짐 중 `.tscn` 은 MCP 로 노드 추가, 테스트는 프로젝트 복사본에서

## Review Focus
- 배경 폴더에 판 없는 배경 → 칸 없이 대략 자리에 유닛 (기존 동작 유지)
- 연출 씬이 안 열림 → 행위자 그림은 보임, 다른 아군은 숨김
- 기억한 배경 파일이 지워짐 → 시험 전투 배경으로

---

### Task 1: 유닛·칸 하나씩
**Files:** Modify `addons/performance_stage_view/stage_view.gd`, Test `tests/performances/test_performance_stage_view.gd`
- [ ] 테스트: `test_lays_allies_and_one_enemy` → `test_shows_only_actor_and_enemy` (연출 없음: 보이는 유닛 2개), `test_only_actor_and_enemy_cells_visible` (보이는 GridCell 2개, 행위자 바꿔도 2개이고 행위자 칸이 바뀜)
- [ ] 구현: `_ally_cells`/`_enemy_cell` 기억, `_update_visible()` 를 `set_battle`·`set_actor`·`_rebuild_mirror`·`sync` 에서
- [ ] 테스트 통과

### Task 2: 배경 목록
**Files:** Modify `stage_view.gd`, `stage_view.tscn`(Top 에 `BackgroundLabel`·`%BackgroundList`), `plugin.gd`
- [ ] 테스트: `test_background_list_lists_backgrounds_dir`, `test_set_background_replaces_scene` (`set_background(path)` 후 `%Background` 자식의 scene_file_path)
- [ ] 구현: `static func background_paths(dir) -> PackedStringArray`, `set_background(path: String)`, 시그널 `background_selected(path: String)`; 플러그인은 `EditorSettings.set_project_metadata("performance_stage_view","background",path)` 로 저장·복원
- [ ] 테스트 통과, `docs/progress.md` 갱신, 커밋
