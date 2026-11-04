---
paths:
  - "**/*.tscn"
  - "**/*.tres"
  - "**/*.uid"
---

# 씬·리소스 파일 규칙 (Godot)

> 출처: donchitos/claude-code-game-studios `.claude/rules/scene-files.md` (MIT) — Void 에 맞게 고침.

이 파일들은 Godot 에디터가 쓴다. 손으로 잘못 고치면 씬이 안 열리거나, 오류 없이 참조가 끊긴다.

## 먼저 (Void 규칙 — CLAUDE.md 와 같음)
- 에디터에서 만들 수 있는 건 에디터로 만든다. 에디터가 켜져 있으면 GoPeak MCP 로, 안 되면 에디터를 끄고 Godot 이 직접 저장하게 한다.
- **에디터가 켜져 있으면 바깥에서 `res://` 의 `.tscn`/`.tres`/폴더를 쓰거나 옮기거나 지우지 않는다.** (2026-11-04 크래시 2회 원인)
- `cards/data/` 의 `.tres` 는 카드 가져오기(`addons/card_importer`)가 만든다. 웹 에디터 칸은 손으로 고치지 말고 웹 에디터 → 다시 가져오기.

## 그래도 손으로 고쳐야 할 때 (에디터 꺼진 상태에서만)
- `[gd_scene]` / `[gd_resource]` 헤더의 `format=` 값은 바꾸지 않는다.
- `id` 를 재사용하지 않는다. `[ext_resource]`·`[sub_resource]` 의 id 는 파일 안에서 유일하다.
- 노드 블록을 복사할 때 `unique_id=` 는 빼고 복사한다 (Godot 4.6+).
- `uid://` 값을 지어내지 않는다. 새 참조엔 `uid=` 를 빼고, 에디터나 `--import` 가 채우게 한다.
- TileMapLayer / GridMap 셀 데이터는 인코딩돼 있으니 에디터에서만 고친다.
- `.uid` 파일은 고치거나 지우지 않고, 스크립트·셰이더와 함께 커밋한다. 에디터 밖에서 스크립트를 옮기면 `.uid` 도 같이 옮긴다 (원칙은 FileSystem 독에서 옮기기).
- 고친 뒤엔 **프로젝트 복사본에서** `--headless --import` 를 돌리고 씬을 한 번 열거나 실행해 오류가 없는지 확인한다.
