extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event

var bram: BattleUnit
var ally: BattleUnit
var foe: BattleUnit
var foe2: BattleUnit
var battle: Battle
var log := []

func before_each():
	bram = Fixture.unit(A, Vector2i(2, 1), {"attack": 100, "defense": 50})
	ally = Fixture.unit(A, Vector2i(2, 0), {"aggro": 100})
	foe = Fixture.unit(E, Vector2i(1, 1))
	foe2 = Fixture.unit(E, Vector2i(3, 0))
	var units: Array[BattleUnit] = [bram, ally, foe, foe2]
	battle = Battle.new(units, 7)
	log = []

func _ctx(targets: Array) -> EffectContext:
	var c := EffectContext.new()
	c.battle = battle
	c.actor = bram
	c.owner = bram
	c.source = "test"
	c.targets.assign(targets)
	return c

func _card_in_hand(attack_type: String, effects: Array[CardEffect], costs: Array[CardCost] = []) -> CardData:
	var c := CardData.new()
	c.attack_type = attack_type
	c.sp = 0
	c.effects = effects
	c.costs = costs
	bram.hand.append(c)
	return c

func _taunt() -> StatusData:
	var s := Fixture.status("taunt")
	s.taunts = true
	return s

func _guard(reduction: float = 0.0) -> StatusData:
	var s := Fixture.status("guarded")
	s.guarded_by_applier = true
	s.guard_reduction = reduction
	return s


# --- 쉴드 전부 소모 → 소모량 비례 피해 (돌 던지기, 내려찍기) ---

func test_block_cost_blocks_play_without_block():
	var card := _card_in_hand("self", [], [BlockCost.new()])
	assert_eq(battle.can_play(bram, card), "cost")

func test_block_cost_consumes_all_block_and_scales_damage():
	bram.block = 40
	var value := ConsumedValue.new("block")
	value.percent = 150.0
	var dmg := DamageEffect.new()
	dmg.use_flat = true
	dmg.flat = 1
	dmg.multiplier = value
	var card := _card_in_hand("ranged", [dmg], [BlockCost.new()])
	assert_true(battle.play_card(bram, card, foe))
	assert_eq(bram.block, 0)
	assert_eq(foe.hp, 40)

func test_consumed_value_default_percent_is_unchanged():
	var c := _ctx([])
	c.values["consumed:block"] = 7
	assert_eq(ConsumedValue.new("block").evaluate(c), 7.0)


# --- 현재 쉴드 비례 (굳은살) ---

func test_current_block_value_is_percent_of_actor_block():
	bram.block = 30
	var v := CurrentBlockValue.new()
	v.percent = 50.0
	assert_eq(v.evaluate(_ctx([])), 15.0)

func test_block_effect_adds_half_of_current_block():
	bram.block = 30
	var v := CurrentBlockValue.new()
	v.percent = 50.0
	var b := BlockEffect.new()
	b.use_flat = true
	b.flat = 1
	b.multiplier = v
	b.apply(_ctx([bram]))
	assert_eq(bram.block, 45)

func test_block_effect_does_nothing_without_block():
	var v := CurrentBlockValue.new()
	v.percent = 50.0
	var b := BlockEffect.new()
	b.use_flat = true
	b.flat = 1
	b.multiplier = v
	b.apply(_ctx([bram]))
	assert_eq(bram.block, 0)


# --- 대상 쉴드 제거 (갈라치기) ---

func test_remove_block_clears_target_and_emits_event():
	foe.block = 30
	battle.events.subscribe(Ev.BLOCK_RESET, func(e): log.append(e))
	RemoveBlockEffect.new().apply(_ctx([foe]))
	assert_eq(foe.block, 0)
	assert_eq(log.size(), 1)
	assert_eq(log[0].target, foe)

func test_remove_block_without_block_emits_nothing():
	battle.events.subscribe(Ev.BLOCK_RESET, func(e): log.append(e))
	RemoveBlockEffect.new().apply(_ctx([foe]))
	assert_eq(log, [])


# --- 끌어오기 (갈고리 걸기) ---

func test_pull_moves_target_to_front_in_actors_row():
	foe.move_left = 2
	PullEffect.new().apply(_ctx([foe]))
	assert_eq(foe.cell, Vector2i(3, 1))
	assert_eq(foe.move_left, 2)

func test_pull_emits_unit_moved():
	battle.events.subscribe(Ev.UNIT_MOVED, func(e): log.append(e))
	PullEffect.new().apply(_ctx([foe]))
	assert_eq(log.size(), 1)

func test_pull_stays_when_destination_is_occupied():
	foe2.cell = Vector2i(3, 1)
	PullEffect.new().apply(_ctx([foe]))
	assert_eq(foe.cell, Vector2i(1, 1))

func test_pull_already_in_place_emits_nothing():
	foe.cell = Vector2i(3, 1)
	battle.events.subscribe(Ev.UNIT_MOVED, func(e): log.append(e))
	PullEffect.new().apply(_ctx([foe]))
	assert_eq(log, [])


# --- 도발 ---

func test_taunt_forces_enemy_ranged_target():
	battle.apply_status(bram, _taunt(), 1, bram)
	for i in 30:
		assert_eq(battle.enemy_ai.pick_ranged_target(foe), bram)

func test_taunt_forces_melee_target_from_another_row():
	battle.apply_status(bram, _taunt(), 1, bram)
	assert_eq(battle.melee_target(foe2), bram)

func test_melee_target_is_normal_without_taunt():
	assert_eq(battle.melee_target(foe2), ally)

func test_dead_taunter_no_longer_forces_target():
	battle.apply_status(bram, _taunt(), 1, bram)
	battle.apply_damage(foe, bram, 1000)
	assert_eq(battle.melee_target(foe2), ally)

func test_taunting_enemy_must_be_the_ranged_origin():
	battle.apply_status(foe, _taunt(), 1, foe)
	var card := _card_in_hand("ranged", [])
	assert_eq(battle.can_play(bram, card, foe2), "origin")
	assert_eq(battle.can_play(bram, card, foe), "")


# --- 대신 맞기 ---

func test_guard_redirects_card_damage_to_applier():
	battle.apply_status(ally, _guard(), 1, bram)
	battle.apply_damage(foe, ally, 30)
	assert_eq([ally.hp, bram.hp], [100, 70])

func test_guard_reduction_lowers_redirected_damage():
	battle.apply_status(ally, _guard(30.0), 1, bram)
	battle.apply_damage(foe, ally, 30)
	assert_eq([ally.hp, bram.hp], [100, 79])

func test_guard_redirected_damage_hits_appliers_block_first():
	bram.block = 10
	battle.apply_status(ally, _guard(), 1, bram)
	battle.apply_damage(foe, ally, 30)
	assert_eq([bram.block, bram.hp], [0, 80])

func test_guard_events_name_the_applier_as_target():
	battle.apply_status(ally, _guard(), 1, bram)
	battle.events.subscribe(Ev.DAMAGE_TAKEN, func(e): log.append(e))
	battle.apply_damage(foe, ally, 30)
	assert_eq(log[0].target, bram)

func test_guard_ignores_status_damage():
	battle.apply_status(ally, _guard(), 1, bram)
	battle.apply_damage(null, ally, 30)
	assert_eq([ally.hp, bram.hp], [70, 100])

func test_guard_stops_when_applier_is_dead():
	battle.apply_status(ally, _guard(), 1, bram)
	battle.apply_damage(foe, bram, 1000)
	battle.apply_damage(foe, ally, 30)
	assert_eq(ally.hp, 70)

func test_guard_on_self_changes_nothing():
	battle.apply_status(bram, _guard(30.0), 1, bram)
	battle.apply_damage(foe, bram, 30)
	assert_eq(bram.hp, 70)


# --- 새 트리거 필터: 상태를 건 유닛의 차례에만 (대신 맞기 지속 시간) ---

func _fades_on_applier_turn(s: StatusData) -> StatusData:
	var down := ModifyStacksEffect.new()
	down.status_id = s.id
	down.delta = -1
	down.target = BattleTypes.Target.OWNER
	var t := StatusTrigger.new()
	t.event = Ev.TURN_START
	t.filter = BattleTypes.Filter.APPLIER_IS_ACTOR
	t.effects = [down]
	s.triggers = [t]
	return s

func test_applier_filter_fires_on_appliers_turn():
	battle.apply_status(ally, _fades_on_applier_turn(_guard()), 1, bram)
	battle.events.emit(BattleEvent.make(Ev.TURN_START, bram))
	assert_null(ally.get_status("guarded"))

func test_applier_filter_ignores_other_units_turns():
	battle.apply_status(ally, _fades_on_applier_turn(_guard()), 1, bram)
	battle.events.emit(BattleEvent.make(Ev.TURN_START, ally))
	assert_not_null(ally.get_status("guarded"))
