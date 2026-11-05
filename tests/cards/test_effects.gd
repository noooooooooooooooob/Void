extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event

var me: BattleUnit
var foe: BattleUnit
var foe2: BattleUnit
var battle: Battle
var log := []

func before_each():
	me = Fixture.unit(A, Vector2i(3, 1), {"attack": 100, "defense": 50})
	foe = Fixture.unit(E, Vector2i(3, 1))
	foe2 = Fixture.unit(E, Vector2i(3, 2))
	var units: Array[BattleUnit] = [me, foe, foe2]
	battle = Battle.new(units, 7)
	log = []
	battle.events.subscribe(Ev.DAMAGE_TAKEN, func(e): log.append(e))

func _ctx(targets: Array) -> EffectContext:
	var c := EffectContext.new()
	c.battle = battle
	c.actor = me
	c.owner = me
	c.source = "test"
	c.targets.assign(targets)
	return c

func _damage(percent: float, mult: ValueSource = null) -> DamageEffect:
	var d := DamageEffect.new()
	d.percent = percent
	d.multiplier = mult
	return d


func test_damage_percent_with_multiplier():
	_damage(40, FixedValue.new(5)).apply(_ctx([foe]))
	assert_eq(foe.hp, 0)  # 200 피해 → HP 100 은 0 (사망)
	assert_eq(log[0].amount, 200)

func test_damage_floor_min_one():
	me.data.attack = 3
	_damage(10).apply(_ctx([foe]))
	assert_eq(log[0].amount, 1)

func test_zero_multiplier_does_nothing():
	_damage(100, FixedValue.new(0)).apply(_ctx([foe]))
	assert_eq(log, [])
	assert_eq(foe.hp, 100)

func test_crit_floors_after_multiplying():
	me.data.attack = 10
	me.data.crit_rate = 100
	me.data.crit_damage = 150
	_damage(15).apply(_ctx([foe]))
	assert_eq(log[0].amount, 2)  # 10 × 0.15 × 1.5 = 2.25 → 2 (먼저 내림하면 1)

func test_flat_damage_goes_through_block():
	me.add_status(Fixture.status("bleed"), 4, me)
	foe.block = 3
	var d := DamageEffect.new()
	d.use_flat = true
	d.flat = 1
	d.multiplier = StackCountValue.new("bleed")
	d.apply(_ctx([foe]))
	assert_eq([foe.block, foe.hp], [0, 99])

func test_flat_damage_without_actor_uses_owner_stats_none_needed():
	var d := DamageEffect.new()
	d.use_flat = true
	d.flat = 5
	var c := _ctx([foe])
	c.actor = null
	d.apply(c)
	assert_eq(foe.hp, 95)

func test_percent_damage_without_actor_uses_owner():
	var c := _ctx([foe])
	c.actor = null
	_damage(10).apply(c)
	assert_eq(foe.hp, 90)  # owner(me) 공격 100 × 10%

func test_damage_events_carry_source():
	_damage(10).apply(_ctx([foe]))
	assert_eq(log[0].source, "test")
	assert_same(log[0].actor, me)

func test_dead_targets_are_skipped():
	foe2.alive = false
	_damage(10).apply(_ctx([foe, foe2]))
	assert_eq(log.size(), 1)
	assert_eq(foe2.hp, 100)

func test_kill_then_second_effect_skips_corpse():
	foe.hp = 5
	var poison := ApplyStatusEffect.new()
	poison.status = Fixture.status("bleed")
	poison.stacks = 2
	var c := _ctx([foe, foe2])
	_damage(10).apply(c)
	poison.apply(c)
	assert_false(foe.alive)
	assert_null(foe.get_status("bleed"))
	assert_eq(foe2.stacks_of("bleed"), 2)

func test_damage_each_target_in_area():
	_damage(10).apply(_ctx([foe, foe2]))
	assert_eq([foe.hp, foe2.hp], [90, 90])

func test_block_effect():
	var b := BlockEffect.new()
	b.percent = 80
	b.target = BattleTypes.Target.SELF
	b.apply(_ctx([]))
	assert_eq(me.block, 40)
	var f := BlockEffect.new()
	f.use_flat = true
	f.flat = 7
	f.target = BattleTypes.Target.SELF
	f.apply(_ctx([]))
	assert_eq(me.block, 47)

func test_heal_effect():
	me.data.attack = 20
	foe.hp = 50
	var h := HealEffect.new()
	h.percent = 50
	h.apply(_ctx([foe]))
	assert_eq(foe.hp, 60)

func test_apply_status_effect():
	var a := ApplyStatusEffect.new()
	a.status = Fixture.status("bleed")
	a.stacks = 2
	a.multiplier = FixedValue.new(2)
	a.apply(_ctx([foe]))
	assert_eq(foe.stacks_of("bleed"), 4)
	assert_same(foe.get_status("bleed").applier, me)

func test_modify_stacks_with_event_amount():
	me.add_status(Fixture.status("blood_drop", false), 0, me)
	var m := ModifyStacksEffect.new()
	m.status_id = "blood_drop"
	m.delta = 1
	m.multiplier = EventAmountValue.new()
	m.target = BattleTypes.Target.OWNER
	var c := _ctx([])
	c.event = BattleEvent.make(Ev.DAMAGE_DEALT, me, foe, 30)
	m.apply(c)
	assert_eq(me.stacks_of("blood_drop"), 30)

func test_modify_stacks_negative_decay():
	foe.add_status(Fixture.status("bleed"), 3, me)
	var m := ModifyStacksEffect.new()
	m.status_id = "bleed"
	m.delta = -1
	m.apply(_ctx([foe]))
	assert_eq(foe.stacks_of("bleed"), 2)

func test_script_effect():
	var s := ScriptEffect.new()
	s.effect_script = preload("res://tests/helpers/flag_script.gd")
	var c := _ctx([])
	s.apply(c)
	assert_true(c.values.get("ran", false))

func test_preview_amount_damage_block_heal():
	var ctx := _ctx([])
	assert_eq(_damage(40, FixedValue.new(5)).preview_amount(ctx), 200)
	var b := BlockEffect.new()
	b.percent = 50
	assert_eq(b.preview_amount(ctx), 25)
	var h := HealEffect.new()
	h.percent = 10
	assert_eq(h.preview_amount(ctx), 10)
	assert_eq(CardEffect.new().preview_amount(ctx), -1)

func test_preview_amount_has_no_crit():
	me.data.crit_rate = 100
	assert_eq(_damage(100).preview_amount(_ctx([])), 100)

func test_preview_amount_zero_multiplier_is_zero():
	assert_eq(_damage(100, FixedValue.new(0)).preview_amount(_ctx([])), 0)
