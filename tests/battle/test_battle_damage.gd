extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event

var attacker: BattleUnit
var target: BattleUnit
var battle: Battle
var log := []

func before_each():
	attacker = Fixture.unit(A, Vector2i(3, 1))
	target = Fixture.unit(E, Vector2i(3, 1))
	var units: Array[BattleUnit] = [attacker, target]
	battle = Battle.new(units)
	log = []
	for type in [Ev.DAMAGE_DEALT, Ev.DAMAGE_TAKEN, Ev.STAMINA_BROKEN, Ev.UNIT_DIED, Ev.HEALED, Ev.BLOCK_GAINED, Ev.STATUS_APPLIED, Ev.STATUS_REMOVED]:
		battle.events.subscribe(type, func(e): log.append(e))

func _types() -> Array:
	return log.map(func(e): return e.type)


func test_block_absorbs_first_and_stamina_counts_full_damage():
	target.block = 20
	battle.apply_damage(attacker, target, 30)
	assert_eq([target.block, target.hp, target.stamina], [0, 90, 70])

func test_attacker_recovers_half_stamina():
	attacker.stamina = 50
	battle.apply_damage(attacker, target, 30)
	assert_eq(attacker.stamina, 65)
	attacker.stamina = 50
	battle.apply_damage(attacker, target, 31)
	assert_eq(attacker.stamina, 65)

func test_attacker_stamina_capped():
	attacker.stamina = 95
	battle.apply_damage(attacker, target, 30)
	assert_eq(attacker.stamina, 100)

func test_damage_events_in_order():
	battle.apply_damage(attacker, target, 30, "src")
	assert_eq(_types(), [Ev.DAMAGE_DEALT, Ev.DAMAGE_TAKEN])
	for e in log:
		assert_eq([e.actor, e.target, e.amount, e.source], [attacker, target, 30, "src"])

func test_zero_damage_does_nothing():
	battle.apply_damage(attacker, target, 0)
	assert_eq(log, [])
	assert_eq(target.hp, 100)

func test_stamina_broken_once():
	target.stamina = 10
	battle.apply_damage(attacker, target, 30)
	assert_eq(target.stamina, 0)
	battle.apply_damage(attacker, target, 5)
	assert_eq(_types().count(Ev.STAMINA_BROKEN), 1)

func test_stamina_break_status_applied():
	battle.stamina_break_status = Fixture.status("exhausted")
	target.stamina = 10
	battle.apply_damage(attacker, target, 30)
	assert_not_null(target.get_status("exhausted"))
	assert_same(target.get_status("exhausted").applier, attacker)

func test_death():
	target.hp = 10
	battle.apply_damage(attacker, target, 30)
	assert_eq([target.hp, target.alive], [0, false])
	assert_eq(_types().count(Ev.UNIT_DIED), 1)

func test_dead_target_ignores_further_damage():
	target.hp = 10
	battle.apply_damage(attacker, target, 30)
	log.clear()
	battle.apply_damage(attacker, target, 30)
	assert_eq(log, [])

func test_null_actor_damage():
	battle.apply_damage(null, target, 30)
	assert_eq(target.hp, 70)
	assert_eq(attacker.stamina, 100)

func test_dead_actor_does_not_recover():
	attacker.stamina = 50
	attacker.alive = false
	battle.apply_damage(attacker, target, 30)
	assert_eq(attacker.stamina, 50)

func test_heal_capped():
	target.hp = 90
	battle.heal(target, 30)
	assert_eq(target.hp, 100)
	assert_eq(_types(), [Ev.HEALED])
	assert_eq(log[0].amount, 10)

func test_add_block():
	battle.add_block(target, 12)
	assert_eq(target.block, 12)
	assert_eq(_types(), [Ev.BLOCK_GAINED])

func test_apply_status_events():
	var bleed := Fixture.status("bleed")
	var inst := battle.apply_status(target, bleed, 3, attacker)
	assert_eq(inst.stacks, 3)
	battle.change_stacks(target, "bleed", -3)
	assert_null(target.get_status("bleed"))
	assert_eq(_types(), [Ev.STATUS_APPLIED, Ev.STATUS_REMOVED])

func test_remove_status_event():
	battle.apply_status(target, Fixture.status("bleed"), 3, attacker)
	battle.remove_status(target, "bleed")
	assert_null(target.get_status("bleed"))
	assert_eq(_types(), [Ev.STATUS_APPLIED, Ev.STATUS_REMOVED])
