extends GutTest
# 무드 부품: 빛나는 물품(MoodLight)·해/달(SkyBody)·빛줄기(MoodRays)·안개가 자기 값대로 그려지는지.

const LANTERN := "res://Scenes/backgrounds/parts/lantern_light.tscn"

func test_mood_light_values():
	var l = load(LANTERN).instantiate()
	add_child_autofree(l)
	assert_true(l is MoodLight)
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
	assert_true(l.enabled)
	l.mood_brightness_scale = 0.0
	assert_false(l.enabled)

func test_mood_light_defaults_match_old_look():
	var l = load(LANTERN).instantiate()
	add_child_autofree(l)
	assert_almost_eq(l.energy, 2.2, 0.001)
	assert_almost_eq(l.texture_scale, 6.0, 0.001)
	assert_eq(l.color, Color(1, 0.62, 0.3))
	assert_eq((l.get_node("Halo") as Sprite2D).scale, Vector2(0.7, 0.7))
