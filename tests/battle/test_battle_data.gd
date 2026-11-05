extends GutTest
# BattleData: 전투 데이터(격자 크기 + 배치) → 전투 유닛 만들기.

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY

func _slot(cell: Vector2i, name := "") -> BattleSlot:
	var s := BattleSlot.new()
	s.unit = UnitData.new()
	s.unit.display_name = name
	s.cell = cell
	return s

func _data() -> BattleData:
	var d := BattleData.new()
	d.allies.assign([_slot(Vector2i(3, 1), "a")])
	d.enemies.assign([_slot(Vector2i(3, 0), "e1"), _slot(Vector2i(2, 2), "e2")])
	return d

func test_make_units_sides_and_cells():
	var units := _data().make_units()
	assert_eq(units.size(), 3)
	assert_eq(units[0].side, A)
	assert_eq(units[0].cell, Vector2i(3, 1))
	assert_eq(units[1].side, E)
	assert_eq(units[1].cell, Vector2i(3, 0))
	assert_eq(units[2].data.display_name, "e2")
	assert_eq(units[2].cell, Vector2i(2, 2))

func test_make_enemy_units_only_enemies():
	var units := _data().make_enemy_units()
	assert_eq(units.size(), 2)
	for u in units:
		assert_eq(u.side, E)

func test_make_units_returns_new_units_each_call():
	var d := _data()
	assert_ne(d.make_units()[0], d.make_units()[0])

func test_default_grid_size():
	var d := BattleData.new()
	assert_eq(d.rows, 3)
	assert_eq(d.ally_cols, 4)
	assert_eq(d.enemy_cols, 4)
