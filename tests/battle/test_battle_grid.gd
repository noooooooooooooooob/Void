extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY

func _battle(units: Array) -> Battle:
	var typed: Array[BattleUnit] = []
	typed.assign(units)
	return Battle.new(typed)


func test_init_links_units_and_order():
	var a := Fixture.unit(A, Vector2i(3, 1))
	var e := Fixture.unit(E, Vector2i(3, 1))
	var b := _battle([a, e])
	assert_same(a.battle, b)
	assert_eq([a.initial_index, e.initial_index], [0, 1])
	assert_not_null(b.events)

func test_melee_hits_front_most_enemy_in_same_row():
	var a := Fixture.unit(A, Vector2i(3, 1))
	var back := Fixture.unit(E, Vector2i(1, 1))
	var front := Fixture.unit(E, Vector2i(2, 1))
	var other_row := Fixture.unit(E, Vector2i(3, 0))
	var b := _battle([a, back, front, other_row])
	assert_same(b.melee_target(a), front)

func test_melee_none_when_row_empty():
	var a := Fixture.unit(A, Vector2i(3, 2))
	var b := _battle([a, Fixture.unit(E, Vector2i(3, 0))])
	assert_null(b.melee_target(a))

func test_melee_skips_dead():
	var a := Fixture.unit(A, Vector2i(3, 1))
	var dead := Fixture.unit(E, Vector2i(2, 1))
	dead.alive = false
	var alive := Fixture.unit(E, Vector2i(1, 1))
	var b := _battle([a, dead, alive])
	assert_same(b.melee_target(a), alive)

func test_area_targets_offsets_within_origin_side():
	var origin := Fixture.unit(E, Vector2i(2, 1))
	var front := Fixture.unit(E, Vector2i(3, 1))
	var below := Fixture.unit(E, Vector2i(2, 2))
	var ally_same_cell := Fixture.unit(A, Vector2i(3, 1))
	var b := _battle([origin, front, below, ally_same_cell])
	var area: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -2)]
	var got := b.area_targets(origin, area)
	assert_eq(got.size(), 3)
	for u in [origin, front, below]:
		assert_has(got, u)
	assert_does_not_have(got, ally_same_cell)

func test_empty_area_is_single_target():
	var origin := Fixture.unit(E, Vector2i(2, 1))
	var b := _battle([origin, Fixture.unit(E, Vector2i(3, 1))])
	assert_eq(b.area_targets(origin, [] as Array[Vector2i]), [origin] as Array[BattleUnit])

func test_living_allies_enemies():
	var a1 := Fixture.unit(A, Vector2i(0, 0))
	var a2 := Fixture.unit(A, Vector2i(1, 0))
	a2.alive = false
	var e1 := Fixture.unit(E, Vector2i(0, 0))
	var b := _battle([a1, a2, e1])
	assert_eq(b.living(A), [a1] as Array[BattleUnit])
	assert_eq(b.allies_of(a1), [a1] as Array[BattleUnit])
	assert_eq(b.enemies_of(a1), [e1] as Array[BattleUnit])
	assert_same(b.unit_at(E, Vector2i(0, 0)), e1)
	assert_null(b.unit_at(A, Vector2i(1, 0)))
