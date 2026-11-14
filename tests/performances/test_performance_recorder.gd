extends GutTest
# 연출 단계 기록: 전투 이벤트를 카드 단계/즉시 단계로 묶고, 단계가 닫힐 때 유닛 상태를 찍어 둔다.

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event
const K := PerformanceStep.Kind

var hero: BattleUnit
var foe: BattleUnit
var battle: Battle
var rec: PerformanceRecorder

func before_each():
	hero = Fixture.unit(A, Vector2i(3, 1), {"attack": 10})
	foe = Fixture.unit(E, Vector2i(3, 1), {"max_hp": 45})
	var units: Array[BattleUnit] = [hero, foe]
	battle = Battle.new(units)
	rec = PerformanceRecorder.new(battle)

func _dmg(amount: int) -> DamageEffect:
	var d := DamageEffect.new()
	d.use_flat = true
	d.flat = amount
	d.can_crit = false
	return d

func _card(effects: Array) -> CardData:
	var c := CardData.new()
	c.attack_type = "melee"
	c.sp = 0
	c.effects.assign(effects)
	hero.hand.append(c)
	return c

func _card_steps(steps: Array) -> Array:
	return steps.filter(func(s): return s.kind == K.CARD)


func test_card_play_becomes_one_card_step():
	var c := _card([_dmg(10)])
	assert_true(battle.play_card(hero, c))
	var cards := _card_steps(rec.take_steps())
	assert_eq(cards.size(), 1)
	var s: PerformanceStep = cards[0]
	assert_eq([s.card, s.actor, s.target], [c, hero, foe])
	assert_eq(s.events.front().type, Ev.BEFORE_CARD_PLAYED)
	assert_eq(s.events.back().type, Ev.AFTER_CARD_PLAYED)

func test_damage_totals_sum_multiple_effects():
	var c := _card([_dmg(10), _dmg(10)])
	battle.play_card(hero, c)
	var s: PerformanceStep = _card_steps(rec.take_steps())[0]
	assert_eq(s.damage_totals()[foe], 20)

func test_hit_targets_include_damaged_units():
	var c := _card([_dmg(10)])
	battle.play_card(hero, c)
	var s: PerformanceStep = _card_steps(rec.take_steps())[0]
	assert_eq(s.hit_targets(), [foe] as Array[BattleUnit])

func test_self_card_hit_targets_is_actor():
	var c := _card([])
	c.attack_type = "self"
	battle.play_card(hero, c)
	var s: PerformanceStep = _card_steps(rec.take_steps())[0]
	assert_eq(s.hit_targets(), [hero] as Array[BattleUnit])

func test_event_outside_card_is_instant():
	battle.apply_damage(null, foe, 5)
	var steps := rec.take_steps()
	# 피해는 DAMAGE_DEALT, DAMAGE_TAKEN 두 이벤트 → 즉시 단계 둘
	assert_eq(steps.map(func(s): return s.kind), [K.INSTANT, K.INSTANT])
	assert_eq(steps.map(func(s): return s.events.size()), [1, 1])
	assert_eq(steps[1].events[0].type, Ev.DAMAGE_TAKEN)
	assert_eq(steps[1].state[foe].hp, 40)

func test_card_step_snapshot_is_per_step():
	var c1 := _card([_dmg(10)])
	var c2 := _card([_dmg(10)])
	battle.play_card(hero, c1)
	battle.play_card(hero, c2)
	var cards := _card_steps(rec.take_steps())
	assert_eq(cards[0].state[foe].hp, 35)
	assert_eq(cards[1].state[foe].hp, 25)
	assert_eq(cards[1].state[foe].cell, Vector2i(3, 1))
	assert_true(cards[1].state[foe].alive)

func test_take_steps_clears():
	battle.apply_damage(null, foe, 5)
	rec.take_steps()
	assert_eq(rec.take_steps().size(), 0)

func test_killed_and_crit_targets():
	hero.data.crit_rate = 100
	var d := _dmg(100)
	d.can_crit = true
	var c := _card([d])
	battle.play_card(hero, c)
	var s: PerformanceStep = _card_steps(rec.take_steps())[0]
	assert_eq(s.killed(), [foe] as Array[BattleUnit])
	assert_eq(s.crit_targets(), [foe] as Array[BattleUnit])

func test_no_kill_no_crit():
	var c := _card([_dmg(5)])
	battle.play_card(hero, c)
	var s: PerformanceStep = _card_steps(rec.take_steps())[0]
	assert_eq(s.killed(), [] as Array[BattleUnit])
	assert_eq(s.crit_targets(), [] as Array[BattleUnit])
