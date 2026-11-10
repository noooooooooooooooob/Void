extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event
const T := BattleTypes.Target
const F := BattleTypes.Filter

var a: BattleUnit
var b: BattleUnit
var battle: Battle

func before_each():
	a = Fixture.unit(A, Vector2i(3, 0), {"attack": 100})
	b = Fixture.unit(E, Vector2i(3, 0))
	var units: Array[BattleUnit] = [a, b]
	battle = Battle.new(units, 1)
	battle.start_battle()

func _trigger(event: int, filter: int, effects: Array, source_id := "") -> StatusTrigger:
	var t := StatusTrigger.new()
	t.event = event
	t.filter = filter
	t.source_status_id = source_id
	t.effects.assign(effects)
	return t

# 출혈: 주인의 드로우 페이즈에 수치만큼 고정 피해
func _bleed() -> StatusData:
	var d := DamageEffect.new()
	d.use_flat = true
	d.flat = 1
	d.multiplier = StackCountValue.new("bleed")
	d.target = T.OWNER
	var st := Fixture.status("bleed")
	st.triggers.assign([_trigger(Ev.DRAW_PHASE, F.OWNER_IS_ACTOR, [d])])
	return st

# 혈갑: 주인의 차례 종료 시 수치만큼 방어도
func _blood_armor() -> StatusData:
	var bl := BlockEffect.new()
	bl.use_flat = true
	bl.flat = 1
	bl.multiplier = StackCountValue.new("blood_armor")
	bl.target = T.OWNER
	var st := Fixture.status("blood_armor")
	st.triggers.assign([_trigger(Ev.TURN_END, F.OWNER_IS_ACTOR, [bl])])
	return st

# 핏방울(패시브): 적이 출혈 피해를 받을 때마다(누가 걸었든) 그 피해량만큼 쌓임 (사용자 결정)
func _blood_drop() -> StatusData:
	var m := ModifyStacksEffect.new()
	m.status_id = "blood_drop"
	m.delta = 1
	m.multiplier = EventAmountValue.new()
	m.target = T.OWNER
	var st := Fixture.status("blood_drop", false)
	st.triggers.assign([_trigger(Ev.DAMAGE_TAKEN, F.TARGET_IS_ENEMY_OF_OWNER, [m], "bleed")])
	return st


func test_bleed_ticks_on_owner_draw_phase():
	a.stamina = 50
	b.stamina = 50
	battle.apply_status(b, _bleed(), 4, a)
	battle.begin_turn(b)
	assert_eq(b.hp, 96)
	# 상태로 생긴 피해는 아무도 "준" 것이 아니다 → 건 유닛도, 주인도 스태미너를 회복하지 않는다 (사용자 결정)
	assert_eq(a.stamina, 50)
	assert_eq(b.stamina, 46)  # 맞은 쪽은 피해만큼 깎인다

func test_status_damage_event_has_no_actor_but_remembers_applier():
	var seen := []
	battle.events.subscribe(Ev.DAMAGE_DEALT, func(e): seen.append(e))
	battle.apply_status(b, _bleed(), 4, a)
	battle.begin_turn(b)
	assert_eq(seen.size(), 1)
	assert_null(seen[0].actor)
	assert_same(seen[0].applier, a)
	assert_same(seen[0].target, b)

func test_status_damage_never_crits():
	a.data.crit_rate = 100
	b.data.crit_rate = 100
	battle.apply_status(b, _bleed(), 4, a)
	battle.begin_turn(b)
	assert_eq(b.hp, 96)

func test_bleed_does_not_tick_on_other_units_turn():
	battle.apply_status(b, _bleed(), 4, a)
	battle.begin_turn(a)
	assert_eq(b.hp, 100)

func test_bleed_with_dead_applier():
	battle.apply_status(b, _bleed(), 4, a)
	a.stamina = 50
	a.alive = false
	battle.begin_turn(b)
	assert_eq(b.hp, 96)
	assert_eq(a.stamina, 50)

func test_unit_killed_by_bleed_loses_turn():
	var c := Fixture.unit(E, Vector2i(2, 0))
	battle.units.append(c)
	c.battle = battle
	b.hp = 3
	battle.apply_status(b, _bleed(), 4, a)
	assert_false(battle.begin_turn(b))
	assert_false(b.alive)
	assert_does_not_have(battle.turn_order.remaining_units(), b)

func test_removed_status_stops_reacting():
	battle.apply_status(b, _bleed(), 4, a)
	battle.remove_status(b, "bleed")
	battle.begin_turn(b)
	assert_eq(b.hp, 100)

func test_stacking_does_not_double_subscribe():
	battle.apply_status(b, _bleed(), 2, a)
	battle.apply_status(b, _bleed(), 2, a)
	battle.begin_turn(b)
	assert_eq(b.hp, 96)  # 4 한 번 (구독이 두 번이면 8)

func test_blood_armor_blocks_on_turn_end():
	battle.apply_status(a, _blood_armor(), 6, a)
	battle.begin_turn(a)
	battle.end_turn(a)
	assert_eq(a.block, 6)

func test_blood_drop_counts_only_bleed_damage():
	battle.apply_status(a, _blood_drop(), 0, a)
	battle.apply_status(b, _bleed(), 4, a)
	battle.begin_turn(b)
	assert_eq(a.stacks_of("blood_drop"), 4)
	# A 의 카드 피해(출처가 출혈이 아님)는 쌓이지 않는다
	var card := CardData.new()
	card.attack_type = "melee"
	var d := DamageEffect.new()
	d.percent = 10
	card.effects.assign([d])
	a.hand.append(card)
	a.sp = 3
	assert_true(battle.play_card(a, card))
	assert_eq(a.stacks_of("blood_drop"), 4)

func test_blood_drop_counts_bleed_applied_by_anyone():
	var ally := Fixture.unit(A, Vector2i(2, 0))
	battle.units.append(ally)
	ally.battle = battle
	battle.apply_status(a, _blood_drop(), 0, a)
	battle.apply_status(b, _bleed(), 3, ally)  # 다른 아군이 건 출혈
	battle.begin_turn(b)
	assert_eq(a.stacks_of("blood_drop"), 3)

func test_blood_drop_ignores_bleed_on_allies():
	var ally := Fixture.unit(A, Vector2i(2, 0))
	battle.units.append(ally)
	ally.battle = battle
	battle.apply_status(a, _blood_drop(), 0, a)
	battle.apply_status(ally, _bleed(), 3, b)  # 아군이 받은 출혈은 세지 않음
	battle.begin_turn(ally)
	assert_eq(a.stacks_of("blood_drop"), 0)

func test_owner_is_target_filter():
	# 피격 시 방어도 1: 주인이 피해를 받을 때만
	var bl := BlockEffect.new()
	bl.use_flat = true
	bl.flat = 1
	bl.target = T.OWNER
	var st := Fixture.status("thorns", false)
	st.triggers.assign([_trigger(Ev.DAMAGE_TAKEN, F.OWNER_IS_TARGET, [bl])])
	battle.apply_status(b, st, 0, b)
	battle.apply_damage(a, b, 5)
	assert_eq(b.block, 1)
	battle.apply_damage(b, a, 5)  # b 가 준 피해 → 반응 없음
	assert_eq(b.block, 1)

func _sword_data() -> UnitData:
	var bonus := Fixture.status("sword", false)
	bonus.modifiers.assign([Fixture.modifier(BattleTypes.Stat.ATTACK, BattleTypes.ModKind.FLAT, 5)])
	var eq := EquipmentData.new()
	eq.statuses.assign([bonus])
	var data := UnitData.new()
	data.attack = 10
	data.equipment.assign([eq])
	return data

func test_equipment_always_applies_even_outside_battle():
	# 장비는 착용하고 있으면 항상 적용 (전투 밖에서도) — 사용자 결정
	var u := BattleUnit.new(_sword_data(), A, Vector2i(3, 1))
	assert_eq(u.get_stat(BattleTypes.Stat.ATTACK), 15)

func test_equipment_not_doubled_in_battle():
	var u := BattleUnit.new(_sword_data(), A, Vector2i(3, 1))
	var units: Array[BattleUnit] = [u, Fixture.unit(E, Vector2i(3, 1))]
	var bt := Battle.new(units)
	bt.start_battle()
	assert_eq(u.get_stat(BattleTypes.Stat.ATTACK), 15)

func _stat_gear_unit(mods: Array) -> BattleUnit:
	var eq := EquipmentData.new()
	eq.stats.assign(mods)
	var data := UnitData.new()
	data.attack = 10
	data.max_hp = 100
	data.equipment.assign([eq])
	return BattleUnit.new(data, A, Vector2i(3, 1))

func test_equipment_stats_apply_flat_and_percent():
	# floor(10 × 1.5) + 3 = 18
	var u := _stat_gear_unit([
		Fixture.modifier(BattleTypes.Stat.ATTACK, BattleTypes.ModKind.PERCENT, 50),
		Fixture.modifier(BattleTypes.Stat.ATTACK, BattleTypes.ModKind.FLAT, 3)])
	assert_eq(u.get_stat(BattleTypes.Stat.ATTACK), 18)

func test_equipment_stats_removed_when_unequipped():
	var u := _stat_gear_unit([Fixture.modifier(BattleTypes.Stat.ATTACK, BattleTypes.ModKind.FLAT, 5)])
	u.data.equipment.clear()
	assert_eq(u.get_stat(BattleTypes.Stat.ATTACK), 10)

func test_equipment_hp_bonus_fills_start_hp():
	var u := _stat_gear_unit([Fixture.modifier(BattleTypes.Stat.HP, BattleTypes.ModKind.FLAT, 20)])
	assert_eq(u.hp, 120)

func test_equipment_trigger_works_in_battle():
	# 장비의 트리거도 전투에서 동작: 차례 종료 시 방어도 2
	var bl := BlockEffect.new()
	bl.use_flat = true
	bl.flat = 2
	bl.target = T.OWNER
	var st := Fixture.status("shield_gear", false)
	st.triggers.assign([_trigger(Ev.TURN_END, F.OWNER_IS_ACTOR, [bl])])
	var eq := EquipmentData.new()
	eq.statuses.assign([st])
	var data := UnitData.new()
	data.equipment.assign([eq])
	var u := BattleUnit.new(data, A, Vector2i(3, 1))
	var units: Array[BattleUnit] = [u, Fixture.unit(E, Vector2i(3, 1))]
	var bt := Battle.new(units)
	bt.start_battle()
	bt.begin_turn(u)
	bt.end_turn(u)
	assert_eq(u.block, 2)

func test_passive_applied_at_battle_start():
	var u := Fixture.unit(A, Vector2i(3, 1))
	u.data.passives.assign([_blood_drop()])
	var units: Array[BattleUnit] = [u, Fixture.unit(E, Vector2i(3, 1))]
	var bt := Battle.new(units)
	bt.start_battle()
	var inst := u.get_status("blood_drop")
	assert_not_null(inst)
	assert_same(inst.applier, u)
	assert_eq(inst.stacks, 0)  # 패시브는 수치 0 으로 시작 (쌓는 패시브가 0 부터 세도록)
