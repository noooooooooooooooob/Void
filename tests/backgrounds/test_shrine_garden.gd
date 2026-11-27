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
