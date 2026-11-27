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
	assert_eq(mood.fog_color, Color(0.7, 0.5, 0.45))
	assert_almost_eq(mood.fog_density, 0.25, 0.001)
	assert_eq(bg.get_node("GroundFog").modulate, Color(0.7, 0.5, 0.45, 0.25))

func test_sun_drives_rays():
	var sun := bg.get_node("Sun") as SkyBody
	assert_gt(sun.get_index(), bg.get_node("FarLayer").get_index())   # 먼 산 그림이 화면 전체를 덮어서 그 앞
	assert_lt(sun.get_index(), bg.get_node("NearLayer").get_index())
	var rays := bg.get_node("LightRays") as MoodRays
	assert_true(rays.has_source)
	assert_eq(rays.source, sun.global_position)
