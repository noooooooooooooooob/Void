# 전투 무드 슬라이더 모으기 (A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 빛나는 물품·해/달·빛줄기·안개·빛 번짐 문턱을 BattleMood 인스펙터에서 조절하고, 빛줄기가 해(밤엔 달) 위치에서 뻗게 한다.

**Architecture:** 부품마다 작은 `@tool` 스크립트(MoodLight·SkyBody·MoodRays)가 자기 모양을 그리고, BattleMood 가 자기 부모(배경 씬) 안에서 그룹으로 부품을 찾아 장면 전체 값(배율·색·세기)을 넣는다. 해/달이 움직이면 시그널로 빛줄기를 다시 맞춘다.

**Tech Stack:** Godot 4.7.2 GDScript, GUT 9.7.1, Godot AI MCP (씬 편집)

**Spec:** `docs/superpowers/specs/2026-11-27-battle-mood-sliders-design.md`

## Global Constraints
- 게임 스크립트는 `Scripts/backgrounds/`, 부품 씬은 `Scenes/backgrounds/parts/`. 씬·노드는 에디터(MCP)로, 손으로 .tscn 텍스트 쓰기 금지. 스크립트로 노드 `new()` 금지 (테스트 제외)
- 모든 스크립트에 한국어 주석 (클래스 `##`, export·공개 함수·시그널 `##`)
- 에디터 켜져 있으면 바깥에서 res:// .tscn/.tres 쓰지 않음. 테스트는 복사본 `../Void_testcopy` 에 동기화 후 실행 (godot_ai 플러그인·`_mcp_game_helper` 끔, `--log-file` 따로)
- 테스트 실행: `Godot_v4.7.2-stable_win64_console.exe --headless --path <copy> -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- 그룹 이름: `mood_light`, `mood_sky_body`, `mood_rays`, `mood_fog`

## Review Focus
- 배경 씬 밖(다른 씬·전투 화면의 다른 노드)에 같은 그룹 부품이 있어도 BattleMood 가 건드리지 않아야 함 → Task 5 `test_parts_outside_background_untouched`
- 해와 달이 둘 다 있고 해만 숨김 → 빛줄기는 달을 따라야 함 → Task 5 `test_rays_follow_first_visible_sky_body`
- 해/달이 하나도 없음 → 빛줄기가 에러 없이 똑바로 아래로 → Task 3 `test_no_source_points_straight_down`
- 해가 빔 닿는 곳과 같은 점 (길이 0) → 0 나누기 없이 빔이 그냥 안 보임 → Task 3 `test_zero_length_beam_is_safe`
- 안개 두 개 인스턴스가 재질을 공유하면 한쪽 속도 바꿀 때 다른 쪽도 바뀜 → Task 4 `test_fog_material_not_shared`

---

### Task 1: 빛나는 물품 `MoodLight`

**Files:**
- Create: `Scripts/backgrounds/mood_light.gd`
- Modify: `Scenes/backgrounds/parts/lantern_light.tscn` (루트에 스크립트, 그룹 `mood_light`, 값 이전)
- Test: `tests/backgrounds/test_mood_parts.gd` (새 파일)

**Interfaces:**
- Produces: `class_name MoodLight extends PointLight2D` (@tool). export `light_color: Color = Color(1, 0.62, 0.3)`, `brightness: float = 2.2` (0..5), `halo_strength: float = 0.85` (0..3), `halo_size: float = 0.7` (0..3). 공개 변수 `mood_brightness_scale: float = 1.0`, `mood_halo_scale: float = 1.0` (setter 로 다시 그림). 자식 `Halo`(Sprite2D)

- [ ] **Step 1: 실패 테스트**
```gdscript
func test_mood_light_values():
	var l := load(LANTERN).instantiate() as MoodLight
	add_child_autofree(l)
	assert_true(l.is_in_group("mood_light"))
	l.light_color = Color(0.2, 0.4, 1.0)
	l.brightness = 2.0
	l.mood_brightness_scale = 0.5
	l.halo_strength = 1.0
	l.mood_halo_scale = 2.0
	l.halo_size = 1.2
	assert_eq(l.color, Color(0.2, 0.4, 1.0))
	assert_almost_eq(l.energy, 1.0, 0.001)
	var h := l.get_node("Halo") as Sprite2D
	assert_eq(h.modulate, Color(0.4, 0.8, 2.0, 1.0))
	assert_eq(h.scale, Vector2(1.2, 1.2))
	l.mood_brightness_scale = 0.0
	assert_false(l.enabled)
func test_mood_light_defaults_match_old_look():
	var l := load(LANTERN).instantiate() as MoodLight
	add_child_autofree(l)
	assert_almost_eq(l.energy, 2.2, 0.001)
	assert_almost_eq(l.texture_scale, 6.0, 0.001)
```
기존 `test_battle_mood.gd::test_lantern_part` 는 그대로 통과해야 함.
- [ ] **Step 2: 실행 → FAIL (MoodLight 없음)**
- [ ] **Step 3: `mood_light.gd` 작성**, `_apply()` 는 is_node_ready 가드 + `_ready` 에서 호출. MCP 로 lantern_light 루트에 스크립트 붙이고 그룹 추가, Halo modulate 는 스크립트가 덮으므로 기본 값으로 둠
- [ ] **Step 4: 실행 → PASS**
- [ ] **Step 5: 커밋** `feat: MoodLight part for glowing props`

### Task 2: 해·달 `SkyBody`

**Files:**
- Create: `Scripts/backgrounds/sky_body.gd`, `Scenes/backgrounds/parts/sun.tscn`, `Scenes/backgrounds/parts/moon.tscn`
- Test: `tests/backgrounds/test_mood_parts.gd`

**Interfaces:**
- Produces: `class_name SkyBody extends Node2D` (@tool), 그룹 `mood_sky_body`. export `body_color: Color`, `body_size: float`(원반 지름 px), `glow_strength: float`(헤일로 modulate 배율). `signal moved` — `NOTIFICATION_TRANSFORM_CHANGED`(ready 에서 `set_notify_transform(true)`) 와 visible 바뀔 때(`NOTIFICATION_VISIBILITY_CHANGED`) 냄. 자식 `Disc`(Sprite2D, 원형 GradientTexture2D 가장자리 단단히), `Glow`(Sprite2D 더하기 헤일로). 둘 다 light_mask 0, CanvasItemMaterial unshaded
- 해 기본: 색 (1, 0.75, 0.45), 크기 120, 헤일로 1.5. 달 기본: 색 (0.8, 0.88, 1.0), 크기 80, 헤일로 0.8

- [ ] **Step 1: 실패 테스트**
```gdscript
func test_sky_body_parts():
	for p in [SUN, MOON]:
		var s := load(p).instantiate() as SkyBody
		add_child_autofree(s)
		assert_true(s.is_in_group("mood_sky_body"))
		assert_eq((s.get_node("Disc") as CanvasItem).light_mask, 0)
func test_sky_body_size_and_color():
	var s := load(SUN).instantiate() as SkyBody
	add_child_autofree(s)
	s.body_size = 200.0
	s.body_color = Color(1, 0, 0)
	var d := s.get_node("Disc") as Sprite2D
	assert_almost_eq(d.texture.get_width() * d.scale.x, 200.0, 0.5)
	assert_eq(d.modulate, Color(1, 0, 0))
func test_sky_body_emits_moved():
	var s := load(SUN).instantiate() as SkyBody
	add_child_autofree(s)
	watch_signals(s)
	s.position = Vector2(100, 50)
	await wait_physics_frames(1)
	assert_signal_emitted(s, "moved")
```
- [ ] **Step 2: 실행 → FAIL**
- [ ] **Step 3: 스크립트 작성, MCP 로 sun.tscn 만들고 moon.tscn 은 sun 복제 후 값만 바꿈**
- [ ] **Step 4: 실행 → PASS**
- [ ] **Step 5: 커밋** `feat: sun and moon sky body parts`

### Task 3: 빛줄기 `MoodRays`

**Files:**
- Create: `Scripts/backgrounds/mood_rays.gd`
- Modify: `Scenes/backgrounds/parts/light_rays.tscn` (루트 스크립트, 그룹 `mood_rays`, Beam1~4 position = 닿는 곳, polygon 은 스크립트가 채움)
- Test: `tests/backgrounds/test_mood_parts.gd`

**Interfaces:**
- Produces: `class_name MoodRays extends Node2D` (@tool). export `width_near: float = 110.0`, `width_far: float = 250.0`. 공개 `source: Vector2` (전역 좌표, setter 로 다시 그림), `has_source: bool = false` (false 면 각 빔 위 1000px 에서 똑바로 아래). 빔 = 자식 Polygon2D 전부
- 빔 polygon (빔 로컬): 해 쪽 두 점 = `to_local(source)` ± 수직×width_near/2, 닿는 곳 두 점 = (0,0) ± 수직×width_far/2. vertex_colors = 흰색, 해 쪽 알파 1, 닿는 곳 알파 0. 길이 < 1px 이면 polygon 비움
- 닿는 곳: Beam1 (1100,1000), Beam2 (840,1000), Beam3 (580,1000), Beam4 (320,1000)

- [ ] **Step 1: 실패 테스트**
```gdscript
func test_beams_start_at_source_and_land_at_position():
	var r := load(RAYS).instantiate() as MoodRays
	add_child_autofree(r)
	assert_true(r.is_in_group("mood_rays"))
	r.source = Vector2(1700, 100)
	r.has_source = true
	for b in r.get_children().filter(func(c): return c is Polygon2D):
		var poly: PackedVector2Array = b.polygon
		var near_mid: Vector2 = b.to_global((poly[0] + poly[1]) / 2)
		var far_mid: Vector2 = b.to_global((poly[2] + poly[3]) / 2)
		assert_almost_eq(near_mid.distance_to(Vector2(1700, 100)), 0.0, 0.5)
		assert_almost_eq(far_mid.distance_to(b.global_position), 0.0, 0.5)
		assert_almost_eq(b.vertex_colors[0].a, 1.0, 0.001)
		assert_almost_eq(b.vertex_colors[2].a, 0.0, 0.001)
func test_landings_kept_from_old_shape():
	var r := load(RAYS).instantiate() as MoodRays
	add_child_autofree(r)
	assert_eq(r.get_node("Beam1").position, Vector2(1100, 1000))
	assert_eq(r.get_node("Beam4").position, Vector2(320, 1000))
func test_no_source_points_straight_down():
	var r := load(RAYS).instantiate() as MoodRays
	add_child_autofree(r)
	r.has_source = false
	var b := r.get_node("Beam1") as Polygon2D
	var near_mid: Vector2 = (b.polygon[0] + b.polygon[1]) / 2
	assert_almost_eq(near_mid.x, 0.0, 0.5)
	assert_lt(near_mid.y, -500.0)
func test_zero_length_beam_is_safe():
	var r := load(RAYS).instantiate() as MoodRays
	add_child_autofree(r)
	r.source = (r.get_node("Beam1") as Node2D).global_position
	r.has_source = true
	assert_eq((r.get_node("Beam1") as Polygon2D).polygon.size(), 0)
```
기존 `test_light_rays_part` (더하기·unshaded·빔 3개 이상·use_parent_material) 유지.
- [ ] **Step 2: 실행 → FAIL**
- [ ] **Step 3: 스크립트 작성, MCP 로 빔 position 설정·스크립트·그룹**
- [ ] **Step 4: 실행 → PASS**
- [ ] **Step 5: 커밋** `feat: light rays radiate from a source point`

### Task 4: 안개 부품

**Files:**
- Modify: `Scenes/backgrounds/parts/ground_fog.tscn` (그룹 `mood_fog`, 재질 `resource_local_to_scene = true`)
- Test: `tests/backgrounds/test_mood_parts.gd`

- [ ] **Step 1: 실패 테스트**
```gdscript
func test_fog_group_and_material_not_shared():
	var root := Node.new()
	add_child_autofree(root)
	var scene := PackedScene.new()
	var holder := Node2D.new()
	var f1 := load(FOG).instantiate(); var f2 := load(FOG).instantiate()
	holder.add_child(f1); holder.add_child(f2)
	f1.owner = holder; f2.owner = holder
	scene.pack(holder); holder.free()
	var inst := scene.instantiate()
	root.add_child(inst)
	assert_true(inst.get_child(0).is_in_group("mood_fog"))
	assert_ne(inst.get_child(0).material, inst.get_child(1).material)
```
- [ ] **Step 2: FAIL → Step 3: MCP 로 그룹·local_to_scene → Step 4: PASS → Step 5: 커밋** `feat: ground fog joins mood group`

### Task 5: BattleMood 가 부품에 값 넣기

**Files:**
- Modify: `Scripts/backgrounds/battle_mood.gd`
- Test: `tests/backgrounds/test_battle_mood.gd`

**Interfaces:**
- Consumes: MoodLight.mood_brightness_scale/mood_halo_scale, SkyBody.moved, MoodRays.source/has_source
- Produces: export 그룹 "빛나는 물품": `light_scale` 1.0 (0..3), `halo_scale` 1.0 (0..3). "빛줄기": `rays_color` (1, 0.8, 0.55), `rays_strength` 0.4 (0..3) → MoodRays.modulate = Color(rays_color.rgb, rays_strength). "안개": `fog_color` (0.55, 0.6, 0.8), `fog_density` 0.25 (0..1) → modulate, `fog_speed` 0.01 (-0.1..0.1) → 셰이더 `speed`. "화면": `bloom_threshold` 0.9 (0..2) → `glow_hdr_threshold`
- 범위: `get_parent()` 아래만 (`get_parent().is_ancestor_of(n)`). 부모 없으면 아무것도 안 함
- 해/달: 그룹 `mood_sky_body` 중 `is_visible_in_tree()` 인 것, 트리 순서 첫 번째 → 빛줄기 `source = global_position`, `has_source = true`. 없으면 `has_source = false`. 범위 안 SkyBody 의 `moved` 를 연결(중복 연결 금지)
- 나중에 추가된 부품: `get_tree().node_added` 연결 → 그룹 부품이면 `_apply_parts.call_deferred()` (exit_tree 에서 끊음)

- [ ] **Step 1: 실패 테스트** (before_each 의 root 아래에 부품을 넣는다)
```gdscript
func test_light_and_halo_scale_reach_mood_lights():
	var l := load(LANTERN).instantiate(); root.add_child(l)
	m.light_scale = 0.5; m.halo_scale = 2.0
	assert_almost_eq(l.mood_brightness_scale, 0.5, 0.001)
	assert_almost_eq(l.mood_halo_scale, 2.0, 0.001)
func test_parts_added_later_get_values():
	m.light_scale = 0.3
	var l := load(LANTERN).instantiate(); root.add_child(l)
	await wait_physics_frames(1)
	assert_almost_eq(l.mood_brightness_scale, 0.3, 0.001)
func test_parts_outside_background_untouched():
	var other := Node.new(); add_child_autofree(other)
	var l := load(LANTERN).instantiate(); other.add_child(l)
	m.light_scale = 0.3
	assert_almost_eq(l.mood_brightness_scale, 1.0, 0.001)
func test_rays_color_strength_and_fog():
	var r := load(RAYS).instantiate(); root.add_child(r)
	var f := load(FOG).instantiate(); root.add_child(f)
	m.rays_color = Color(0.5, 0.6, 1.0); m.rays_strength = 1.5
	m.fog_color = Color(0.1, 0.2, 0.3); m.fog_density = 0.4; m.fog_speed = -0.02
	assert_eq(r.modulate, Color(0.5, 0.6, 1.0, 1.5))
	assert_eq(f.modulate, Color(0.1, 0.2, 0.3, 0.4))
	assert_almost_eq(f.material.get_shader_parameter("speed"), -0.02, 0.0001)
func test_rays_follow_first_visible_sky_body():
	var r := load(RAYS).instantiate(); root.add_child(r)
	var sun := load(SUN).instantiate(); root.add_child(sun); sun.position = Vector2(1700, 100)
	var moon := load(MOON).instantiate(); root.add_child(moon); moon.position = Vector2(300, 150)
	await wait_physics_frames(1)
	assert_true(r.has_source); assert_eq(r.source, Vector2(1700, 100))
	sun.visible = false
	await wait_physics_frames(1)
	assert_eq(r.source, Vector2(300, 150))
	moon.position = Vector2(400, 120)
	await wait_physics_frames(1)
	assert_eq(r.source, Vector2(400, 120))
	moon.visible = false
	await wait_physics_frames(1)
	assert_false(r.has_source)
func test_bloom_threshold():
	m.bloom_threshold = 1.2
	assert_almost_eq((m.get_node("Glow") as WorldEnvironment).environment.glow_hdr_threshold, 1.2, 0.001)
```
- [ ] **Step 2: FAIL → Step 3: 구현 → Step 4: 전체 테스트 PASS → Step 5: 커밋** `feat: BattleMood drives lights, sky body rays, fog, bloom threshold`

### Task 6: 신사 정원 옮기기 + 화면 확인

**Files:**
- Modify: `Scenes/backgrounds/shrine_garden.tscn` (MCP)
- Test: `tests/backgrounds/test_shrine_garden.gd`
- Modify: `docs/progress.md`, `docs/superpowers/plans/2026-11-27-battle-mood-next-handoff.md` (A 완료 표시)

- [ ] **Step 1: 실패 테스트**
```gdscript
func test_mood_owns_part_values():
	var mood := bg.get_child(0) as BattleMood
	assert_almost_eq((bg.get_node("LanternL") as MoodLight).brightness, 1.0, 0.001)
	assert_eq(mood.fog_color, Color(0.7, 0.5, 0.45))
	assert_almost_eq(mood.fog_density, 0.25, 0.001)
	assert_eq(bg.get_node("GroundFog").modulate, Color(0.7, 0.5, 0.45, 0.25))
	var sun := bg.get_node("Sun") as SkyBody
	assert_lt(sun.get_index(), bg.get_node("FarLayer").get_index())
	assert_true((bg.get_node("LightRays") as MoodRays).has_source)
```
- [ ] **Step 2: FAIL → Step 3: MCP 로 석등 `energy` override 지우고 `brightness = 1.0`, 안개 modulate override 지우고 BattleMood fog 값, `Sun` 인스턴스(BattleMood 바로 뒤, 위치 (1650, 260)) 추가, 저장 → Step 4: PASS**
- [ ] **Step 5: 화면 확인**: 복사본에서 SceneTree 스크립트로 시험 전투 찍기 (HDR: RGBA8 변환 후 `linear_to_srgb()`). A 전 커밋 화면과 비교 — 석등·안개 같아야 하고, 빛줄기는 해에서 뻗음. 빛줄기 세기 0.4 가 너무 세면 낮추고 사용자에게 보고
- [ ] **Step 6: progress.md·이어받기 메모 갱신, 커밋** `feat: shrine garden uses mood sliders and a sun`
