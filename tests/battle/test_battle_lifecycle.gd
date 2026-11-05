extends GutTest
# 리뷰 지적 사항 회귀 테스트: 죽은 유닛의 트리거, 전투 사이 유닛 재사용, 쌓는 패시브의 소모.

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event
const T := BattleTypes.Target
const F := BattleTypes.Filter

func _trigger(event: int, filter: int, effects: Array, source_id := "") -> StatusTrigger:
	var t := StatusTrigger.new()
	t.event = event
	t.filter = filter
	t.source_status_id = source_id
	t.effects.assign(effects)
	return t

func _bleed() -> StatusData:
	var d := DamageEffect.new()
	d.use_flat = true
	d.flat = 1
	d.multiplier = StackCountValue.new("bleed")
	d.target = T.OWNER
	var st := Fixture.status("bleed")
	st.triggers.assign([_trigger(Ev.DRAW_PHASE, F.OWNER_IS_ACTOR, [d])])
	return st

# 핏방울: 패시브(태그 PASSIVE), 수치를 쓰는 상태. 적이 받은 출혈 피해만큼 쌓인다.
func _blood_drop() -> StatusData:
	var m := ModifyStacksEffect.new()
	m.status_id = "blood_drop"
	m.delta = 1
	m.multiplier = EventAmountValue.new()
	m.target = T.OWNER
	var st := Fixture.status("blood_drop", true)
	st.tag = BattleTypes.StatusTag.PASSIVE
	st.triggers.assign([_trigger(Ev.DAMAGE_TAKEN, F.TARGET_IS_ENEMY_OF_OWNER, [m], "bleed")])
	return st

func _battle(units: Array) -> Battle:
	var typed: Array[BattleUnit] = []
	typed.assign(units)
	return Battle.new(typed, 2)


func test_dead_unit_triggers_stop():
	# 죽은 유닛의 패시브가 다른 유닛에게 효과를 내면 안 된다: "매 차례 시작 시 적 전체 3 피해" 패시브
	var hit := DamageEffect.new()
	hit.use_flat = true
	hit.flat = 3
	hit.target = T.ALL_ENEMIES
	var aura := Fixture.status("aura", false)
	aura.tag = BattleTypes.StatusTag.PASSIVE
	aura.triggers.assign([_trigger(Ev.TURN_START, F.ANY, [hit])])
	var hero := Fixture.unit(A, Vector2i(3, 0))
	hero.data.passives.assign([aura])
	var foe := Fixture.unit(E, Vector2i(3, 0))
	var other := Fixture.unit(A, Vector2i(2, 0))
	var bt := _battle([hero, other, foe])
	bt.start_battle()
	bt.begin_turn(foe)
	assert_eq(foe.hp, 97)  # 살아 있을 때는 동작
	bt.apply_damage(foe, hero, 999)  # 패시브 주인 사망
	bt.begin_turn(foe)
	assert_eq(foe.hp, 97)  # 죽은 뒤에는 동작하지 않음


func test_passive_counter_survives_being_consumed_and_refills():
	# 핏방울 쌓기 → 피의 참격으로 전부 소모 → 패시브는 남아서(수치 0) 다시 쌓인다
	var hero := Fixture.unit(A, Vector2i(3, 0), {"attack": 100})
	hero.data.passives.assign([_blood_drop()])
	var foe := Fixture.unit(E, Vector2i(3, 0), {"max_hp": 1000})
	var bt := _battle([hero, foe])
	bt.start_battle()
	bt.apply_status(foe, _bleed(), 5, hero)
	bt.begin_turn(foe)
	assert_eq(hero.stacks_of("blood_drop"), 5)
	var slash := CardData.new()
	slash.attack_type = "melee"
	var cost := StatusCost.new()
	cost.status_id = "blood_drop"
	cost.consume_all = true
	slash.costs.assign([cost])
	var d := DamageEffect.new()
	d.percent = 40
	d.multiplier = ConsumedValue.new("blood_drop")
	slash.effects.assign([d])
	hero.hand.append(slash)
	hero.sp = 3
	var hp_before := foe.hp
	assert_true(bt.play_card(hero, slash))
	assert_eq(hp_before - foe.hp, 200)
	assert_not_null(hero.get_status("blood_drop"))
	assert_eq(hero.stacks_of("blood_drop"), 0)
	bt.begin_turn(foe)  # 출혈 5 다시 → 다시 쌓임
	assert_eq(hero.stacks_of("blood_drop"), 5)

func test_non_passive_status_still_removed_at_zero():
	var u := Fixture.unit(A, Vector2i.ZERO)
	u.add_status(Fixture.status("bleed"), 2, u)
	assert_true(u.change_stacks("bleed", -2))
	assert_null(u.get_status("bleed"))


func _gear_unit() -> BattleUnit:
	var bl := BlockEffect.new()
	bl.use_flat = true
	bl.flat = 2
	bl.target = T.OWNER
	var gear := Fixture.status("gear", false)
	gear.triggers.assign([_trigger(Ev.TURN_END, F.OWNER_IS_ACTOR, [bl])])
	var eq := EquipmentData.new()
	eq.statuses.assign([gear])
	var data := UnitData.new()
	data.equipment.assign([eq])
	data.passives.assign([_blood_drop()])
	return BattleUnit.new(data, A, Vector2i(3, 0))

func test_same_unit_in_second_battle_keeps_equipment_and_passive_working():
	var hero := _gear_unit()
	var bt1 := _battle([hero, Fixture.unit(E, Vector2i(3, 0))])
	bt1.start_battle()
	var foe2 := Fixture.unit(E, Vector2i(3, 0))
	var bt2 := _battle([hero, foe2])
	bt2.start_battle()
	# 장비 트리거: 두 번째 전투에서도 차례 종료 시 방어도 2
	bt2.begin_turn(hero)
	bt2.end_turn(hero)
	assert_eq(hero.block, 2)
	# 패시브 트리거: 두 번째 전투에서도 출혈 피해만큼 쌓임
	bt2.apply_status(foe2, _bleed(), 3, hero)
	bt2.begin_turn(foe2)
	assert_eq(hero.stacks_of("blood_drop"), 3)

func test_new_battle_resets_battle_state_but_keeps_hp():
	var hero := _gear_unit()
	var bt1 := _battle([hero, Fixture.unit(E, Vector2i(3, 0))])
	bt1.start_battle()
	hero.hp = 40
	hero.stamina = 10
	hero.block = 7
	bt1.apply_status(hero, _bleed(), 3, hero)
	hero.change_stacks("blood_drop", 4)
	var bt2 := _battle([hero, Fixture.unit(E, Vector2i(3, 0))])
	bt2.start_battle()
	assert_eq(hero.hp, 40)  # 의뢰 안에서 HP 는 이어진다
	assert_eq(hero.stamina, hero.data.max_stamina)  # 스태미너는 전투마다 리셋
	assert_eq(hero.block, 0)
	assert_null(hero.get_status("bleed"))  # 전투 중 상태는 다음 전투로 넘어가지 않음
	assert_not_null(hero.get_status("gear"))  # 장비는 유지
	assert_eq(hero.stacks_of("blood_drop"), 0)  # 패시브는 새로 시작
