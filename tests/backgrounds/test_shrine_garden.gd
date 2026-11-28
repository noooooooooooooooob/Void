extends GutTest
# 신사 정원 배경: 무드(밤)가 맨 뒤, 먼 산에 공기원근, 석등 둘·바닥 안개, 아군·적 격자판.

const SCENE := "res://Scenes/backgrounds/shrine_garden.tscn"

var bg: Control

func before_each():
	bg = load(SCENE).instantiate()
	add_child_autofree(bg)

func test_mood_is_first_and_hazes_far_layer():
	var mood := bg.get_child(0) as BattleMood
	assert_not_null(mood)
	var far := bg.get_node("FarLayer") as CanvasItem
	assert_eq(far.material, mood.haze_material)
	assert_eq(far.light_mask, 0)   # 먼 산은 석등 빛을 안 받음

func test_layers_use_shrine_garden_art():
	assert_true((bg.get_node("FarLayer") as TextureRect).texture.resource_path.ends_with("shrine_garden_far.png"))
	assert_true((bg.get_node("NearLayer") as TextureRect).texture.resource_path.ends_with("shrine_garden_near.png"))
	assert_lt(bg.get_node("FarLayer").get_index(), bg.get_node("NearLayer").get_index())

func test_two_lanterns_and_fog():
	assert_true(bg.get_node("LanternL") is PointLight2D)
	assert_true(bg.get_node("LanternR") is PointLight2D)
	assert_true(bg.get_node("GroundFog") is Sprite2D)

func test_has_ally_and_enemy_boards():
	var sides := []
	for c in bg.get_children():
		if c is BattleBoard:
			sides.append(c.side)
	sides.sort()
	assert_eq(sides, [BattleTypes.Side.ALLY, BattleTypes.Side.ENEMY])

# 노을 무드 (2026-11-27 사용자 결정: 시험 mood_grid 오른쪽 아래 느낌)
func test_dusk_mood_and_rays():
	var mood := bg.get_child(0) as BattleMood
	assert_gt(mood.sky_bottom.r, mood.sky_bottom.b)   # 하늘 아래가 주황
	assert_gt(mood.darkness.r, 0.8)                     # 밤처럼 어둡지 않음
	assert_true(bg.get_node("LightRays") is Node2D)

# 무드 슬라이더 (2026-11-27 A): 석등·안개 값은 무드가 쥐고, 빛줄기는 해에서 뻗는다
func test_mood_owns_part_values():
	var mood := bg.get_child(0) as BattleMood
	assert_almost_eq((bg.get_node("LanternL") as MoodLight).brightness, 1.0, 0.001)
	assert_almost_eq((bg.get_node("LanternR") as MoodLight).brightness, 1.0, 0.001)
	# 안개 값은 하루 순환(2026-11-28)으로 시각마다 섞이므로 고정 숫자 대신 무드 → 안개로 그대로 가는지만
	var fog: Color = bg.get_node("GroundFog").modulate
	assert_eq(fog, Color(mood.fog_color.r, mood.fog_color.g, mood.fog_color.b, mood.fog_density))

# 하루 순환 (2026-11-28): 프리셋 4개, 신사 정원 전용 노을, 시작 17.5시, 달 있음
func test_day_cycle_setup():
	var mood := bg.get_child(0) as BattleMood
	assert_eq(mood.presets.size(), 4)
	assert_eq(mood.presets[1].resource_path, "res://moods/time_of_day/shrine_garden/dusk.tres")
	assert_almost_eq(mood.time_of_day, 17.5, 0.001)
	assert_true((bg.get_node("Moon") as SkyBody).is_moon)
	assert_eq((load("res://battles/boss_battle.tres") as BattleData).background.resource_path, "res://Scenes/backgrounds/shrine_garden.tscn")

func test_sun_drives_rays():
	var sun := bg.get_node("Sun") as SkyBody
	# 해는 제일 뒤 (무드의 하늘 바로 앞, 먼 산 뒤 — 먼 산 그림의 하늘은 투명). 2026-11-27 사용자 결정
	assert_eq(sun.get_index(), 1)
	assert_lt(sun.get_index(), bg.get_node("FarLayer").get_index())
	var rays := bg.get_node("LightRays") as MoodRays
	assert_true(rays.has_source)
	assert_eq(rays.source, sun.global_position)

# 리뷰 Important 2: 안개 재질 사본이 배경 씬에 저장되지 않음 (부품 원본 조정이 그대로 전해짐)
func test_fog_uses_part_material():
	var part: Sprite2D = load("res://Scenes/backgrounds/parts/ground_fog.tscn").instantiate()
	autofree(part)
	assert_eq(bg.get_node("GroundFog").material, part.material)
