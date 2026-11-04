extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event
const S := BattleTypes.Stat
const K := BattleTypes.ModKind

func _u(side: int, speed: int, actions := 1, col := 0) -> BattleUnit:
	return Fixture.unit(side, Vector2i(col, 0), {"speed_min": speed, "speed_max": speed, "actions_per_round": actions})

func _battle(units: Array) -> Battle:
	var typed: Array[BattleUnit] = []
	typed.assign(units)
	return Battle.new(typed, 3)

func _speed_mod(percent: float) -> StatusData:
	var st := Fixture.status("speed_mod", false)
	st.modifiers.assign([Fixture.modifier(S.SPEED, K.PERCENT, percent)])
	return st


func test_sorted_by_speed():
	var a := _u(A, 5)
	var b := _u(A, 9, 1, 1)
	var c := _u(E, 7)
	var bt := _battle([a, b, c])
	bt.start_battle()
	assert_eq(bt.turn_order.remaining_units(), [b, c, a] as Array[BattleUnit])

func test_tie_ally_first_then_initial_index():
	var e0 := _u(E, 5)
	var a1 := _u(A, 5)
	var a2 := _u(A, 5, 1, 1)
	var bt := _battle([e0, a1, a2])
	bt.start_battle()
	assert_eq(bt.turn_order.remaining_units(), [a1, a2, e0] as Array[BattleUnit])

func test_multiple_actions_each_with_own_speed():
	var a := _u(A, 5, 2)
	var b := _u(E, 5)
	var bt := _battle([a, b])
	bt.start_battle()
	a.speed_rolls.assign([8, 2])
	bt.turn_order.resort()
	assert_eq(bt.turn_order.remaining_units(), [a, b, a] as Array[BattleUnit])

func test_speeds_rerolled_each_round():
	var a := Fixture.unit(A, Vector2i.ZERO, {"speed_min": 1, "speed_max": 1000, "actions_per_round": 2})
	var bt := _battle([a, _u(E, 1)])
	bt.start_battle()
	var first := a.speed_rolls.duplicate()
	for v in first:
		assert_between(v, 1, 1000)
	bt.start_round()
	assert_eq(a.speed_rolls.size(), 2)
	assert_ne(a.speed_rolls, first)

func test_round_progression():
	var a := _u(A, 9)
	var b := _u(E, 7)
	var c := _u(A, 5, 1, 1)
	var bt := _battle([a, b, c])
	var log := []
	for t in [Ev.ROUND_END, Ev.ROUND_START]:
		bt.events.subscribe(t, func(e): log.append(e.type))
	bt.start_battle()
	log.clear()
	assert_eq([bt.next_turn(), bt.next_turn(), bt.next_turn()], [a, b, c])
	assert_eq(log, [])
	assert_same(bt.next_turn(), a)
	assert_eq(log, [Ev.ROUND_END, Ev.ROUND_START])
	assert_same(bt.current, a)

func test_unit_with_two_actions_gets_two_turns():
	var a := _u(A, 9, 2)
	var b := _u(E, 5)
	var bt := _battle([a, b])
	bt.start_battle()
	assert_eq([bt.next_turn(), bt.next_turn(), bt.next_turn()], [a, a, b])

func test_speed_down_resorts_immediately():
	var a := _u(A, 10)
	var b := _u(E, 8)
	var c := _u(A, 6, 1, 1)
	var bt := _battle([a, b, c])
	var changed := []
	bt.events.subscribe(Ev.TURN_ORDER_CHANGED, func(e): changed.append(e))
	bt.start_battle()
	bt.next_turn()
	bt.apply_status(b, _speed_mod(-50), 1, a)  # B 속도 8 → 4
	assert_eq(bt.turn_order.remaining_units(), [c, b] as Array[BattleUnit])
	assert_eq(changed.size(), 1)

func test_no_order_event_when_speed_unchanged():
	var a := _u(A, 10)
	var b := _u(E, 8)
	var bt := _battle([a, b])
	var changed := []
	bt.events.subscribe(Ev.TURN_ORDER_CHANGED, func(e): changed.append(e))
	bt.start_battle()
	bt.apply_status(b, Fixture.status("bleed"), 2, a)
	assert_eq(changed, [])

func test_used_action_not_readded_on_speed_up():
	var a := _u(A, 10)
	var b := _u(E, 8)
	var bt := _battle([a, b])
	bt.start_battle()
	bt.next_turn()
	bt.apply_status(a, _speed_mod(100), 1, a)
	assert_eq(bt.turn_order.remaining_units(), [b] as Array[BattleUnit])
	# 행동 2회 유닛: 첫 행동 뒤에도 남은 1회는 유지
	var x := _u(A, 10, 2)
	var y := _u(E, 8)
	var bt2 := _battle([x, y])
	bt2.start_battle()
	bt2.next_turn()
	bt2.apply_status(x, _speed_mod(100), 1, x)
	assert_eq(bt2.turn_order.remaining_units(), [x, y] as Array[BattleUnit])

func test_dead_unit_removed():
	var a := _u(A, 10)
	var b := _u(E, 8, 2)
	var c := _u(E, 6, 1, 1)
	var bt := _battle([a, b, c])
	bt.start_battle()
	bt.next_turn()
	bt.apply_damage(a, b, 999)
	assert_eq(bt.turn_order.remaining_units(), [c] as Array[BattleUnit])

func test_battle_end_when_side_wiped():
	var a := _u(A, 10)
	var e := _u(E, 8)
	var bt := _battle([a, e])
	var ends := []
	bt.events.subscribe(Ev.BATTLE_END, func(ev): ends.append(ev.amount))
	bt.start_battle()
	assert_eq(bt.winner(), -1)
	bt.apply_damage(a, e, 999)
	assert_eq(bt.winner(), A)
	assert_eq(ends, [A])

func test_next_turn_null_when_nobody_left():
	var a := _u(A, 10)
	var e := _u(E, 8)
	var bt := _battle([a, e])
	bt.start_battle()
	a.alive = false
	e.alive = false
	bt.turn_order.remove(a)
	bt.turn_order.remove(e)
	assert_null(bt.next_turn())
