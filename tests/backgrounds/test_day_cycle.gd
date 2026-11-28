extends GutTest
# 하루 순환: 시간대 프리셋 보간, 시간 흐름, 해·달 궤도 (설계 2026-11-28-day-cycle-design.md)

const MOOD := "res://Scenes/backgrounds/parts/battle_mood.tscn"


func _preset(hour: float, dark: Color, length: float) -> TimeOfDayPreset:
	var p := TimeOfDayPreset.new()
	p.hour = hour
	p.darkness = dark
	p.shadow_length = length
	return p


func _arr(list: Array) -> Array[TimeOfDayPreset]:
	var out: Array[TimeOfDayPreset] = []
	out.assign(list)
	return out


func test_blend_between():
	var d := BattleMood.blend_presets(_arr([_preset(6, Color.WHITE, 0.5), _preset(18, Color.BLACK, 1.5)]), 12.0)
	assert_almost_eq(d[&"darkness"].r, 0.5, 0.001)
	assert_almost_eq(float(d[&"shadow_length"]), 1.0, 0.001)


func test_blend_wraps_midnight():
	var ps := _arr([_preset(20, Color.WHITE, 1.0), _preset(4, Color.WHITE, 2.0)])
	assert_almost_eq(float(BattleMood.blend_presets(ps, 0.0)[&"shadow_length"]), 1.5, 0.001)
	assert_almost_eq(float(BattleMood.blend_presets(ps, 22.0)[&"shadow_length"]), 1.25, 0.001)


func test_single_preset():
	var d := BattleMood.blend_presets(_arr([_preset(6, Color.RED, 0.7)]), 15.0)
	assert_eq(d[&"darkness"], Color.RED)
	assert_almost_eq(float(d[&"shadow_length"]), 0.7, 0.001)


func test_no_presets_empty():
	assert_eq(BattleMood.blend_presets(_arr([]), 3.0), {})


func test_mood_takes_blend():
	var m = load(MOOD).instantiate()
	add_child_autofree(m)
	m.presets = _arr([_preset(6, Color.WHITE, 0.5), _preset(18, Color.BLACK, 1.5)])
	m.time_of_day = 12.0
	assert_almost_eq(m.darkness.r, 0.5, 0.001)
	assert_almost_eq((m.get_node("Darkness") as CanvasModulate).color.r, 0.5, 0.001)
	assert_almost_eq(m.shadow_length, 1.0, 0.001)


func test_no_presets_keeps_inspector_values():
	var m = load(MOOD).instantiate()
	add_child_autofree(m)
	m.darkness = Color(0.1, 0.2, 0.3)
	m.time_of_day = 3.0
	assert_eq(m.darkness, Color(0.1, 0.2, 0.3))


# 해·달 궤도: 화면 위 가장자리, 원반 1/3 만 보임 (y = -지름/6)
func test_body_position_sun():
	var s := Vector2(1920, 1080)
	assert_eq(BattleMood.body_position(9.0, false, s, 120.0), Vector2(450, -20))
	assert_eq(BattleMood.body_position(12.0, false, s, 120.0), Vector2(960, -20))
	assert_null(BattleMood.body_position(0.0, false, s, 120.0))
	# 궤도 양 끝(원반이 화면 밖에 완전히 나간 자리)은 하늘에 없는 것으로 (2026-11-28 리뷰: 6·18시 뒤집힘)
	assert_null(BattleMood.body_position(6.0, false, s, 120.0))
	assert_null(BattleMood.body_position(18.0, false, s, 120.0))


func test_body_position_moon():
	var s := Vector2(1920, 1080)
	assert_eq(BattleMood.body_position(0.0, true, s, 120.0), Vector2(960, -20))
	assert_null(BattleMood.body_position(12.0, true, s, 120.0))


func test_time_flows():
	var m = load(MOOD).instantiate()
	m.day_length_sec = 24.0
	m.time_flows = true
	m.time_of_day = 10.0
	add_child_autofree(m)
	await wait_seconds(1.0)
	assert_almost_eq(m.time_of_day, 11.0, 0.2)


func test_zero_length_no_flow():
	var m = load(MOOD).instantiate()
	m.day_length_sec = 0.0
	m.time_of_day = 10.0
	add_child_autofree(m)
	await wait_seconds(0.3)
	assert_eq(m.time_of_day, 10.0)


## 1920×1080 Control 아래 무드(흐름 끔) + 해 + 달. [무드, 해, 달]
func _sky_scene() -> Array:
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	add_child_autofree(root)
	var m = load(MOOD).instantiate()
	m.time_flows = false
	root.add_child(m)
	var sun = load("res://Scenes/backgrounds/parts/sun.tscn").instantiate()
	root.add_child(sun)
	var moon = load("res://Scenes/backgrounds/parts/moon.tscn").instantiate()
	root.add_child(moon)
	m.presets = _arr([_preset(6, Color.WHITE, 0.5), _preset(18, Color.BLACK, 1.5)])
	return [m, sun, moon]


func test_bodies_follow_time():
	var p := _sky_scene()
	assert_true(p[2].is_moon)
	p[0].time_of_day = 12.0
	assert_true(p[1].visible)
	assert_almost_eq(p[1].position.x, 960.0, 0.5)
	assert_false(p[2].visible)
	assert_eq(p[0].sky_body(), p[1])
	p[0].time_of_day = 0.0
	assert_false(p[1].visible)
	assert_true(p[2].visible)
	assert_eq(p[0].sky_body(), p[2])


func test_no_body_on_screen():
	var p := _sky_scene()
	p[2].free()
	p[0].time_of_day = 0.0
	assert_null(p[0].sky_body())


# 6·18시 경계: 끝으로 갈수록 해·달 세기가 0 으로 → 그림자가 짧아졌다가 반대쪽에서 다시 길어진다 (한 프레임에 뒤집히지 않게)
func test_sky_factor_fades_at_edges():
	var p := _sky_scene()
	p[0].time_of_day = 12.0
	assert_almost_eq(p[0].sky_factor(), 1.0, 0.001)
	p[0].time_of_day = 17.94
	assert_lt(p[0].sky_factor(), 0.1)
	p[0].time_of_day = 18.0
	assert_null(p[0].sky_body())


func test_shadow_shrinks_near_edge():
	var p := _sky_scene()
	var a := AnimatedSprite2D.new()
	a.position = Vector2(500, 800)
	p[0].get_parent().add_child(a)
	var sh: GroundShadow = load("res://Scenes/backgrounds/parts/ground_shadow.tscn").instantiate()
	a.add_child(sh)
	p[0].time_of_day = 17.99
	await wait_process_frames(2)
	# 거의 끝 → 길이 ≈ 해 없을 때 길이(0.2)
	assert_lt(sh.transform.y.length(), 0.3)


# 인스펙터에서 빈 칸만 있는 프리셋 목록 → 오류 없이 인스펙터 값 그대로
func test_null_only_presets_ignored():
	var m = load(MOOD).instantiate()
	add_child_autofree(m)
	m.darkness = Color(0.1, 0.2, 0.3)
	var arr: Array[TimeOfDayPreset] = [null]
	m.presets = arr
	m.time_of_day = 5.0
	assert_eq(m.darkness, Color(0.1, 0.2, 0.3))
