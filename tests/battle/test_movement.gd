extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event

var me: BattleUnit
var battle: Battle
var moved := []

func _setup(extra: Array = [], rows := 3, ally_cols := 4, enemy_cols := 4) -> void:
	me = Fixture.unit(A, Vector2i(0, 0))
	var units: Array[BattleUnit] = [me]
	units.append_array(extra)
	battle = Battle.new(units, 0, rows, ally_cols, enemy_cols)
	moved = []
	battle.events.subscribe(Ev.UNIT_MOVED, func(e): moved.append(e))


func test_move_within_range():
	_setup()
	me.move_left = 2
	assert_true(battle.move_unit(me, Vector2i(1, 1)))
	assert_eq([me.cell, me.move_left], [Vector2i(1, 1), 0])
	assert_eq(moved.size(), 1)
	assert_eq(moved[0].amount, 2)
	assert_same(moved[0].actor, me)

func test_move_split_over_several_moves():
	_setup()
	me.move_left = 3
	assert_true(battle.move_unit(me, Vector2i(1, 0)))
	assert_true(battle.move_unit(me, Vector2i(1, 2)))
	assert_eq([me.cell, me.move_left], [Vector2i(1, 2), 0])

func test_move_too_far():
	_setup()
	me.move_left = 1
	assert_false(battle.move_unit(me, Vector2i(2, 0)))
	assert_eq([me.cell, me.move_left], [Vector2i(0, 0), 1])
	assert_eq(moved, [])

func test_cannot_enter_occupied():
	_setup([Fixture.unit(A, Vector2i(1, 0))])
	me.move_left = 2
	assert_false(battle.move_unit(me, Vector2i(1, 0)))

func test_enemy_on_same_coordinates_does_not_block():
	# 적은 다른 격자에 있으므로 같은 좌표여도 막지 않는다
	_setup([Fixture.unit(E, Vector2i(1, 0))])
	me.move_left = 1
	assert_true(battle.move_unit(me, Vector2i(1, 0)))

func test_must_path_around_units():
	_setup([Fixture.unit(A, Vector2i(1, 0)), Fixture.unit(A, Vector2i(1, 1))])
	me.move_left = 2
	assert_eq(battle.path_length(me, Vector2i(2, 0)), 6)
	assert_false(battle.move_unit(me, Vector2i(2, 0)))

func test_dead_units_do_not_block():
	var corpse := Fixture.unit(A, Vector2i(1, 0))
	corpse.alive = false
	_setup([corpse])
	me.move_left = 1
	assert_true(battle.move_unit(me, Vector2i(1, 0)))

func test_out_of_grid():
	_setup()
	me.move_left = 9
	assert_false(battle.move_unit(me, Vector2i(4, 0)))
	assert_eq(battle.path_length(me, Vector2i(-1, 0)), -1)

func test_grid_size_per_battle_limits_movement():
	_setup([], 2, 3, 4)
	me.move_left = 9
	assert_false(battle.move_unit(me, Vector2i(3, 0)))  # 아군 3열 → 열 3 은 밖
	assert_false(battle.move_unit(me, Vector2i(0, 2)))  # 2행 → 행 2 는 밖
	assert_true(battle.move_unit(me, Vector2i(2, 1)))

func test_no_move_to_own_cell_or_when_dead():
	_setup()
	me.move_left = 2
	assert_false(battle.move_unit(me, Vector2i(0, 0)))
	me.alive = false
	assert_false(battle.move_unit(me, Vector2i(1, 0)))

func test_move_enables_melee():
	var foe := Fixture.unit(E, Vector2i(3, 1))
	_setup([foe])
	me.cell = Vector2i(3, 0)
	var card := CardData.new()
	card.attack_type = "melee"
	me.hand.append(card)
	me.sp = 3
	assert_eq(battle.can_play(me, card), "melee_target")
	me.move_left = 1
	assert_true(battle.move_unit(me, Vector2i(3, 1)))
	assert_eq(battle.can_play(me, card), "")
