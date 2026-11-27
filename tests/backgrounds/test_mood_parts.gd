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

const SUN := "res://Scenes/backgrounds/parts/sun.tscn"
const MOON := "res://Scenes/backgrounds/parts/moon.tscn"

func test_sky_body_parts():
	for p in [SUN, MOON]:
		var s = load(p).instantiate()
		add_child_autofree(s)
		assert_true(s is SkyBody)
		assert_true(s.is_in_group("mood_sky_body"))
		assert_eq((s.get_node("Disc") as CanvasItem).light_mask, 0)
		assert_eq((s.get_node("Glow") as CanvasItem).light_mask, 0)

func test_sky_body_size_and_color():
	var s = load(SUN).instantiate()
	add_child_autofree(s)
	s.body_size = 200.0
	s.body_color = Color(1, 0, 0)
	var d := s.get_node("Disc") as Sprite2D
	assert_almost_eq(d.texture.get_width() * d.scale.x, 200.0, 0.5)
	assert_eq(d.modulate, Color(1, 0, 0))

func test_sun_and_moon_defaults_differ():
	var sun = load(SUN).instantiate()
	var moon = load(MOON).instantiate()
	add_child_autofree(sun)
	add_child_autofree(moon)
	assert_gt(sun.body_color.r, sun.body_color.b)    # 해는 따뜻한 색
	assert_gt(moon.body_color.b, moon.body_color.r)  # 달은 차가운 색

func test_sky_body_emits_moved():
	var s = load(SUN).instantiate()
	add_child_autofree(s)
	watch_signals(s)
	s.position = Vector2(100, 50)
	await wait_physics_frames(1)
	assert_signal_emitted(s, "moved")
	s.visible = false
	assert_signal_emit_count(s, "moved", 2)

const RAYS := "res://Scenes/backgrounds/parts/light_rays.tscn"

func _beams(r: Node) -> Array:
	return r.get_children().filter(func(c): return c is Polygon2D)

func test_beams_start_at_source_and_land_at_position():
	var r = load(RAYS).instantiate()
	add_child_autofree(r)
	assert_true(r is MoodRays)
	assert_true(r.is_in_group("mood_rays"))
	r.source = Vector2(1700, 100)
	r.has_source = true
	for b in _beams(r):
		var poly: PackedVector2Array = b.polygon
		assert_eq(poly.size(), 4)
		var near_mid: Vector2 = b.to_global((poly[0] + poly[1]) / 2)
		var far_mid: Vector2 = b.to_global((poly[2] + poly[3]) / 2)
		assert_almost_eq(near_mid.distance_to(Vector2(1700, 100)), 0.0, 0.5)
		assert_almost_eq(far_mid.distance_to(b.global_position), 0.0, 0.5)
		assert_almost_eq(poly[0].distance_to(poly[1]), r.width_near, 0.5)
		assert_almost_eq(poly[2].distance_to(poly[3]), r.width_far, 0.5)
		assert_almost_eq(b.vertex_colors[0].a, 1.0, 0.001)
		assert_almost_eq(b.vertex_colors[1].a, 1.0, 0.001)
		assert_almost_eq(b.vertex_colors[2].a, 0.0, 0.001)
		assert_almost_eq(b.vertex_colors[3].a, 0.0, 0.001)

func test_landings_kept_from_old_shape():
	var r = load(RAYS).instantiate()
	add_child_autofree(r)
	assert_eq(r.get_node("Beam1").position, Vector2(1100, 1000))
	assert_eq(r.get_node("Beam2").position, Vector2(840, 1000))
	assert_eq(r.get_node("Beam3").position, Vector2(580, 1000))
	assert_eq(r.get_node("Beam4").position, Vector2(320, 1000))

func test_no_source_points_straight_down():
	var r = load(RAYS).instantiate()
	add_child_autofree(r)
	r.has_source = false
	var b := r.get_node("Beam1") as Polygon2D
	var near_mid: Vector2 = (b.polygon[0] + b.polygon[1]) / 2
	assert_almost_eq(near_mid.x, 0.0, 0.5)
	assert_lt(near_mid.y, -500.0)

func test_zero_length_beam_is_safe():
	var r = load(RAYS).instantiate()
	add_child_autofree(r)
	r.source = (r.get_node("Beam1") as Node2D).global_position
	r.has_source = true
	assert_eq((r.get_node("Beam1") as Polygon2D).polygon.size(), 0)
	r.source = Vector2(1700, 100)
	assert_eq((r.get_node("Beam1") as Polygon2D).polygon.size(), 4)
