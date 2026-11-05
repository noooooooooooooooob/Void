extends GutTest

const S := BattleTypes.Stat
const K := BattleTypes.ModKind

func _with_mods(stats: Dictionary, mods: Array) -> BattleUnit:
	var u := Fixture.unit(BattleTypes.Side.ALLY, Vector2i.ZERO, stats)
	var st := Fixture.status("buff", false)
	st.modifiers.assign(mods)
	u.add_status(st, 1, u)
	return u


func test_stat_percent_then_flat():
	var u := _with_mods({"attack": 100}, [
		Fixture.modifier(S.ATTACK, K.PERCENT, 20),
		Fixture.modifier(S.ATTACK, K.PERCENT, 10),
		Fixture.modifier(S.ATTACK, K.FLAT, 15),
	])
	assert_eq(u.get_stat(S.ATTACK), 145)

func test_speed_modifier_applies_to_rolled_speed():
	var u := _with_mods({}, [Fixture.modifier(S.SPEED, K.PERCENT, -50)])
	assert_eq(u.modified_speed(10), 5)

func test_roll_speeds_one_per_action_within_range():
	var u := Fixture.unit(BattleTypes.Side.ALLY, Vector2i.ZERO, {"speed_min": 3, "speed_max": 7, "actions_per_round": 2})
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	u.roll_speeds(rng)
	assert_eq(u.speed_rolls.size(), 2)
	for v in u.speed_rolls:
		assert_between(v, 3, 7)

func test_roll_speeds_same_seed_same_result():
	var a := Fixture.unit(BattleTypes.Side.ALLY, Vector2i.ZERO, {"speed_min": 1, "speed_max": 10, "actions_per_round": 3})
	var b := Fixture.unit(BattleTypes.Side.ALLY, Vector2i.ZERO, {"speed_min": 1, "speed_max": 10, "actions_per_round": 3})
	var r1 := RandomNumberGenerator.new()
	r1.seed = 42
	var r2 := RandomNumberGenerator.new()
	r2.seed = 42
	a.roll_speeds(r1)
	b.roll_speeds(r2)
	assert_eq(a.speed_rolls, b.speed_rolls)

func test_action_speed_uses_modifiers():
	var u := _with_mods({"speed_min": 8, "speed_max": 8}, [Fixture.modifier(S.SPEED, K.FLAT, -3)])
	u.roll_speeds(RandomNumberGenerator.new())
	assert_eq(u.action_speed(0), 5)

func test_actions_per_round_is_a_modifiable_stat():
	var u := _with_mods({"actions_per_round": 1}, [Fixture.modifier(S.ACTIONS, K.FLAT, 1)])
	assert_eq(u.get_stat(S.ACTIONS), 2)

func test_stat_without_modifiers_is_base():
	var u := Fixture.unit(BattleTypes.Side.ALLY, Vector2i.ZERO, {"defense": 7, "move": 3})
	assert_eq(u.get_stat(S.DEFENSE), 7)
	assert_eq(u.get_stat(S.MOVE), 3)

func test_modifier_scaled_by_stacks():
	var u := Fixture.unit(BattleTypes.Side.ALLY, Vector2i.ZERO, {"attack": 100})
	var st := Fixture.status("armor")
	var sc := StackCountValue.new("armor")
	st.modifiers.assign([Fixture.modifier(S.ATTACK, K.PERCENT, 10, sc)])
	u.add_status(st, 3, u)
	assert_eq(u.get_stat(S.ATTACK), 130)

func test_status_stacks_merge_and_applier_updates():
	var u := Fixture.unit(BattleTypes.Side.ENEMY, Vector2i.ZERO)
	var a := Fixture.unit(BattleTypes.Side.ALLY, Vector2i.ZERO)
	var b := Fixture.unit(BattleTypes.Side.ALLY, Vector2i(1, 0))
	var bleed := Fixture.status("bleed")
	var first := u.add_status(bleed, 3, a)
	var second := u.add_status(bleed, 2, b)
	assert_eq(u.statuses.size(), 1)
	assert_same(first, second)
	assert_eq(u.stacks_of("bleed"), 5)
	assert_same(u.get_status("bleed").applier, b)
	assert_same(u.get_status("bleed").owner, u)

func test_change_stacks_to_zero_removes():
	var u := Fixture.unit(BattleTypes.Side.ENEMY, Vector2i.ZERO)
	var inst := u.add_status(Fixture.status("bleed"), 5, u)
	assert_true(u.change_stacks("bleed", -5))
	assert_null(u.get_status("bleed"))
	assert_false(inst.active)
	assert_eq(u.stacks_of("bleed"), 0)

func test_passive_without_stacks_is_not_removed():
	var u := Fixture.unit(BattleTypes.Side.ALLY, Vector2i.ZERO)
	u.add_status(Fixture.status("passive", false), 1, u)
	assert_false(u.change_stacks("passive", -1))
	assert_not_null(u.get_status("passive"))

func test_new_unit_starts_full():
	var u := Fixture.unit(BattleTypes.Side.ALLY, Vector2i(2, 1), {"max_hp": 80, "max_stamina": 50})
	assert_eq([u.hp, u.stamina, u.block, u.alive, u.cell], [80, 50, 0, true, Vector2i(2, 1)])
