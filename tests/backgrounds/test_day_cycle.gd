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
