# 전투 무드 노드 (전투 무드 2단계) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 배경 씬에 넣으면 월드를 어둡게 하고 하늘·캐릭터 보조광·비네트·냉난 대비·빛 번짐·공기원근을 인스펙터 슬라이더로 맞추는 `BattleMood` 노드와, 석등 빛·바닥 안개 부품 씬을 만든다.

**Architecture:** `@tool` Node2D 스크립트가 export 값을 자식 노드(CanvasModulate·TextureRect·DirectionalLight2D·CanvasLayer 1 의 ColorRect 셰이더·WorldEnvironment)와 haze 대상의 공유 ShaderMaterial 에 넣는다. 노드·리소스는 MCP 로 씬에 만든다. 인스턴스마다 값이 달라야 하는 리소스는 `resource_local_to_scene`.

**Tech Stack:** Godot 4.7.2, GUT 9.7.1, Godot AI MCP

**Spec:** `docs/superpowers/specs/2026-11-27-battle-mood-design.md` (2단계)

## Global Constraints
- `.tscn` 은 MCP 로만. 스크립트·셰이더는 `filesystem_manage write_text` 로 (에디터에 등록)
- 스크립트 `Scripts/backgrounds/battle_mood.gd`, 씬·셰이더 `Scenes/backgrounds/parts/`
- 색수차 없음. PostLayer layer = 1, Environment `background_canvas_max_layer` = 1 (UI 층 2~4 는 빛 번짐 안 받음)
- 시작 값 = 시험 "밤 + 캐릭터 보조광": darkness (0.32,0.36,0.55), sky (0.03,0.04,0.1)→(0.15,0.17,0.3), fill (0.75,0.8,1.0) 0.9, vignette 0.6, split 0.6, bloom 0.8, haze (0.35,0.4,0.6) 0.35 blur 1.5. 석등 범위는 시험(texture_scale 9)보다 좁게 6, 안개 알파 0.45 → 0.25
- HDR 2D 는 이번에 켜지 않음 (3단계에서 비교)

## Review Focus
- 배경 둘에 BattleMood 를 넣고 한쪽 값을 바꿔도 다른 쪽이 안 바뀐다 (local_to_scene) → 테스트 `test_two_instances_do_not_share`
- bloom 0 이면 glow 꺼짐 → 테스트
- haze_targets 에 없는 경로·빈 경로가 있어도 에러 없이 건너뜀 → 테스트
- 에디터에서 값 바꾸면 바로 반영 (@tool setter, is_node_ready 전에는 건너뜀) → 실행 확인
- 화면 효과 ColorRect 가 마우스를 막지 않음 (mouse_filter IGNORE) → 테스트

---

### Task 1: BattleMood
**Files:** Create `Scripts/backgrounds/battle_mood.gd`, `Scenes/backgrounds/parts/battle_mood.tscn`, `Scenes/backgrounds/parts/mood_post.gdshader`, `Scenes/backgrounds/parts/mood_haze.gdshader`; Test `tests/ui/test_battle_mood.gd`

**Interfaces — Produces:** `class_name BattleMood extends Node2D`, export: `darkness: Color`, `sky_top: Color`, `sky_bottom: Color`, `fill_color: Color`, `fill_energy: float`, `fill_angle: float`(도), `vignette: float`, `split_tone: float`, `cool: Color`, `warm: Color`, `bloom: float`, `haze_targets: Array[NodePath]`, `haze_color: Color`, `haze_amount: float`, `haze_blur: float`, `haze_material: ShaderMaterial`. 자식: `Sky`(TextureRect), `Darkness`(CanvasModulate), `CharacterFill`(DirectionalLight2D, range_item_cull_mask 2), `PostLayer`(CanvasLayer 1)/`Post`(ColorRect), `Glow`(WorldEnvironment)

- [ ] 실패하는 테스트: 값 반영(darkness→Darkness.color, sky→Sky 그라데이션 색, fill→energy·color·rotation, vignette·split·cool·warm→Post 셰이더 값, bloom→glow_intensity, 0→glow_enabled false, haze→대상 material == haze_material 이고 값), 없는 경로 건너뜀, 두 인스턴스 독립, Post mouse_filter IGNORE, PostLayer.layer 1, background_canvas_max_layer 1
- [ ] RED 확인 → 스크립트·셰이더 작성, MCP 로 씬 조립 → GREEN, 전체 GUT → Commit

### Task 2: 부품 씬 (석등 빛·바닥 안개)
**Files:** Create `Scenes/backgrounds/parts/lantern_light.tscn`(PointLight2D 루트: 색 (1,0.62,0.3), energy 2.2, texture_scale 6, height 25, 원형 GradientTexture2D / 자식 `Halo` Sprite2D: 원형 텍스처, CanvasItemMaterial 더하기·unshaded, modulate (1.4,0.85,0.4,0.6), scale 0.7), `Scenes/backgrounds/parts/ground_fog.tscn`(Sprite2D: NoiseTexture2D seamless, texture_repeat, `ground_fog.gdshader` 가 TIME 으로 가로로 흐름, unshaded, modulate (0.55,0.6,0.8,0.25)); Test 같은 파일에 로드·핵심 값 확인
- [ ] 테스트 → RED → MCP 로 조립 → GREEN → 산중 신사 배경을 복사본 씬이 아닌 에디터 2D 화면에 임시로 넣어 보고 스크린샷(저장 안 함) → `docs/progress.md` → Commit
