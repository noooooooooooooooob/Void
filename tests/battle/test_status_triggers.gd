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

# 핏방울(패시브): 주인이 출혈 피해를 줄 때마다 그 피해량만큼 쌓임
func _blood_drop() -> StatusData:
	var m := ModifyStacksEffect.new()
	m.status_id = "blood_drop"
	m.delta = 1
	m.multiplier = EventAmountValue.new()
	m.target = T.OWNER
	var st := Fixture.status("blood_drop", false)
	st.triggers.assign([_trigger(Ev.DAMAGE_DEALT, F.OWNER_IS_ACTOR, [m], "bleed")])
	return st


func test_bleed_ticks_on_owner_draw_phase():
	a.stamina = 50
	battle.apply_status(b, _bleed(), 4, a)
	battle.begin_turn(b)
	assert_eq(b.hp, 96)
	assert_eq(a.stamina, 52)  # 출혈 피해를 "준 쪽" = 출혈을 건 A

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

func test_equipment_flat_attack_at_battle_start():
	var u := Fixture.unit(A, Vector2i(3, 1), {"attack": 10})
	var bonus := Fixture.status("sword", false)
	bonus.modifiers.assign([Fixture.modifier(BattleTypes.Stat.ATTACK, BattleTypes.ModKind.FLAT, 5)])
	var eq := EquipmentData.new()
	eq.statuses.assign([bonus])
	u.data.equipment.assign([eq])
	var units: Array[BattleUnit] = [u, Fixture.unit(E, Vector2i(3, 1))]
	var bt := Battle.new(units)
	bt.start_battle()
	assert_eq(u.get_stat(BattleTypes.Stat.ATTACK), 15)

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
