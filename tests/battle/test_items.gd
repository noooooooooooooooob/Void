extends GutTest
# 소비 아이템: Battle.use_item (규칙) 과 BattleSession 의 가방·사용 시점.

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event
const HP := ConsumableLine.Type.HEAL_HP
const SP := ConsumableLine.Type.HEAL_SP
const FLAT := ConsumableLine.Kind.FLAT

var me: BattleUnit
var foe: BattleUnit
var battle: Battle

func before_each():
	me = Fixture.unit(A, Vector2i(3, 1), {"max_hp": 100, "max_sp": 3})
	foe = Fixture.unit(E, Vector2i(3, 1), {"max_hp": 100, "max_sp": 3})
	var us: Array[BattleUnit] = [me, foe]
	battle = Battle.new(us, 1)

func _item(type: int, kind: int, amount: int) -> ConsumableData:
	var l := ConsumableLine.new()
	l.type = type
	l.kind = kind
	l.amount = amount
	var item := ConsumableData.new()
	item.display_name = "시험약"
	item.lines.assign([l])
	return item

func _strike() -> CardData:
	var d := DamageEffect.new()
	d.percent = 100
	var c := CardData.new()
	c.name_ko = "타격"
	c.attack_type = "melee"
	c.sp = 1
	c.effects.assign([d])
	return c

func _unit_data(name: String, stats: Dictionary, deck: Array) -> UnitData:
	var d := UnitData.new()
	d.display_name = name
	for k in stats:
		d.set(k, stats[k])
	d.deck.assign(deck)
	return d

func _slot(u: UnitData, cell: Vector2i) -> BattleSlot:
	var s := BattleSlot.new()
	s.unit = u
	s.cell = cell
	return s

# 아군이 먼저 움직이도록 속도 고정: 아군 10, 적 1·2
func _started() -> BattleSession:
	var hero := _unit_data("홍연", {"max_hp": 100, "max_sp": 3, "speed_min": 10, "speed_max": 10},
		[_strike(), _strike(), _strike(), _strike(), _strike()])
	var e1 := _unit_data("적A", {"speed_min": 2, "speed_max": 2}, [_strike()])
	var e2 := _unit_data("적B", {"speed_min": 1, "speed_max": 1}, [_strike()])
	var d := BattleData.new()
	d.allies.assign([_slot(hero, Vector2i(3, 1))])
	d.enemies.assign([_slot(e1, Vector2i(3, 1)), _slot(e2, Vector2i(2, 2))])
	var s := BattleSession.new(d, [], 5)
	s.start()
	return s


func test_hp_item_heals_up_to_max():
	me.hp = 80
	assert_true(battle.use_item(_item(HP, FLAT, 30), me))
	assert_eq(me.hp, 100)

func test_sp_item_can_exceed_max():
	me.sp = 3
	assert_true(battle.use_item(_item(SP, FLAT, 2), me))
	assert_eq(me.sp, 5)

func test_overflowed_sp_returns_to_max_on_next_turn():
	me.sp = 3
	battle.use_item(_item(SP, FLAT, 2), me)
	battle.begin_turn(me)
	assert_eq(me.sp, me.get_stat(BattleTypes.Stat.SP))

func test_item_emits_item_used_with_target_and_source():
	var seen: Array = []
	battle.events.subscribe(Ev.ITEM_USED, func(e): seen.append(e))
	var item := _item(HP, FLAT, 30)
	battle.use_item(item, me)
	assert_eq(seen.size(), 1)
	assert_same(seen[0].target, me)
	assert_same(seen[0].source, item)
	assert_null(seen[0].actor)

func test_item_cannot_target_enemy_or_dead_ally():
	var seen: Array = []
	battle.events.subscribe(Ev.ITEM_USED, func(e): seen.append(e))
	var item := _item(HP, FLAT, 30)
	foe.hp = 50
	assert_false(battle.use_item(item, foe))
	assert_eq(foe.hp, 50)
	me.hp = 50
	me.alive = false
	assert_false(battle.use_item(item, me))
	assert_eq(me.hp, 50)
	assert_false(battle.use_item(null, foe))
	assert_false(battle.use_item(item, null))
	assert_eq(seen.size(), 0)

func test_item_godot_effects_run_on_target():
	var b := BlockEffect.new()
	b.use_flat = true
	b.flat = 7
	b.target = BattleTypes.Target.OWNER
	var item := _item(HP, FLAT, 1)
	item.effects.assign([b])
	battle.use_item(item, me)
	assert_eq(me.block, 7)

func test_session_starts_with_empty_bag():
	assert_eq(_started().inventory.items.size(), 0)

func test_session_use_item_removes_it_from_bag():
	var s := _started()
	s.inventory.add(_item(HP, FLAT, 30))
	s.active.hp = 50
	watch_signals(s)
	assert_true(s.use_item(0, s.active))
	assert_eq(s.inventory.items.size(), 0)
	assert_eq(s.active.hp, 80)
	assert_signal_emitted(s, "changed")

func test_session_item_targets_are_living_allies_on_ally_turn():
	var s := _started()
	assert_eq(s.item_targets(_item(HP, FLAT, 30)), [s.active] as Array[BattleUnit])

func test_session_refuses_item_outside_ally_turn():
	var s := _started()
	var item := _item(HP, FLAT, 30)
	s.inventory.add(item)
	var hero := s.active
	s.end_player_turn()   # 적 차례 대기
	assert_true(s.is_enemy_turn())
	assert_eq(s.item_targets(item).size(), 0)
	assert_false(s.use_item(0, hero))
	assert_eq(s.inventory.items.size(), 1)

func test_session_refuses_bad_index_and_bad_target():
	var s := _started()
	s.inventory.add(_item(HP, FLAT, 30))
	assert_false(s.use_item(3, s.active))
	assert_false(s.use_item(-1, s.active))
	assert_false(s.use_item(0, s.battle.living(E)[0]))
	assert_eq(s.inventory.items.size(), 1)


# --- 대상 편·범위·음수 (2026-11-17 consumable-targets) ---

func _aimed(target: int, type: int, amount: int, area: Array[Vector2i] = []) -> ConsumableData:
	var item := _item(type, FLAT, amount)
	item.target = target
	item.area = area
	return item

func _events(type: int) -> Array:
	var seen: Array = []
	battle.events.subscribe(type, func(e): seen.append(e))
	return seen

func test_enemy_item_targets_enemies_only():
	var item := _aimed(ConsumableData.Target.ENEMY, HP, -10)
	assert_true(battle.can_use_item(item, foe))
	assert_false(battle.can_use_item(item, me))

func test_both_item_targets_either_side():
	var item := _aimed(ConsumableData.Target.BOTH, HP, 10)
	assert_true(battle.can_use_item(item, foe))
	assert_true(battle.can_use_item(item, me))

func test_negative_hp_is_not_damage():
	foe.block = 10
	var dealt := _events(Ev.DAMAGE_DEALT)
	var taken := _events(Ev.DAMAGE_TAKEN)
	var lost := _events(Ev.HP_LOST)
	assert_true(battle.use_item(_aimed(ConsumableData.Target.ENEMY, HP, -20), foe))
	assert_eq(foe.hp, 80)
	assert_eq(foe.block, 10)
	assert_eq(dealt.size(), 0)
	assert_eq(taken.size(), 0)
	assert_eq(lost.size(), 1)
	assert_eq(lost[0].amount, 20)
	assert_same(lost[0].target, foe)
	assert_null(lost[0].actor)

func test_negative_hp_stops_at_zero_and_kills():
	foe.hp = 5
	var lost := _events(Ev.HP_LOST)
	var died := _events(Ev.UNIT_DIED)
	battle.use_item(_aimed(ConsumableData.Target.ENEMY, HP, -20), foe)
	assert_eq(foe.hp, 0)
	assert_false(foe.alive)
	assert_eq(lost[0].amount, 5)
	assert_eq(died.size(), 1)

func test_negative_sp_stops_at_zero():
	foe.sp = 1
	battle.use_item(_aimed(ConsumableData.Target.ENEMY, SP, -3), foe)
	assert_eq(foe.sp, 0)

func test_zero_amount_does_nothing():
	me.hp = 50
	var healed := _events(Ev.HEALED)
	var lost := _events(Ev.HP_LOST)
	battle.use_item(_item(HP, FLAT, 0), me)
	assert_eq(me.hp, 50)
	assert_eq(healed.size(), 0)
	assert_eq(lost.size(), 0)

func _wide_battle() -> Array:
	var a := Fixture.unit(A, Vector2i(3, 1), {"max_hp": 100})
	var e1 := Fixture.unit(E, Vector2i(3, 0), {"max_hp": 100})
	var e2 := Fixture.unit(E, Vector2i(3, 1), {"max_hp": 100})
	var us: Array[BattleUnit] = [a, e1, e2]
	battle = Battle.new(us, 1)
	return [a, e1, e2]

func test_area_hits_same_side_only():
	var u := _wide_battle()
	var area: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	battle.use_item(_aimed(ConsumableData.Target.ENEMY, HP, -10, area), u[1])
	assert_eq(u[1].hp, 90)
	assert_eq(u[2].hp, 90)
	assert_eq(u[0].hp, 100)

func test_area_offsets_only_like_cards():
	var u := _wide_battle()
	var area: Array[Vector2i] = [Vector2i(0, 1)]
	battle.use_item(_aimed(ConsumableData.Target.ENEMY, HP, -10, area), u[1])
	assert_eq(u[1].hp, 100)
	assert_eq(u[2].hp, 90)

func test_item_affected_lists_living_units_in_area():
	var u := _wide_battle()
	var area: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	var item := _aimed(ConsumableData.Target.ENEMY, HP, -10, area)
	assert_eq(battle.item_affected(item, u[1]), [u[1], u[2]] as Array[BattleUnit])
	u[2].alive = false
	assert_eq(battle.item_affected(item, u[1]), [u[1]] as Array[BattleUnit])

func test_effects_run_per_affected_unit():
	var u := _wide_battle()
	var b := BlockEffect.new()
	b.use_flat = true
	b.flat = 7
	b.target = BattleTypes.Target.OWNER
	var area: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	var item := _aimed(ConsumableData.Target.ENEMY, HP, -1, area)
	item.effects.assign([b])
	battle.use_item(item, u[1])
	assert_eq(u[1].block, 7)
	assert_eq(u[2].block, 7)

func test_item_used_event_once_for_picked_unit():
	var u := _wide_battle()
	var used := _events(Ev.ITEM_USED)
	var area: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	battle.use_item(_aimed(ConsumableData.Target.ENEMY, HP, -1, area), u[1])
	assert_eq(used.size(), 1)
	assert_same(used[0].target, u[1])

func test_killing_last_enemies_with_item_wins():
	var s := _started()
	var foes := s.battle.living(E)
	# 적A (3,1) 기준으로 적B (2,2) 는 (-1, 1)
	var area: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 1)]
	s.inventory.add(_aimed(ConsumableData.Target.ENEMY, HP, -999, area))
	watch_signals(s)
	assert_true(s.use_item(0, foes[0]))
	assert_signal_emitted_with_parameters(s, "finished", [A])

func test_session_item_targets_follow_item_side():
	var s := _started()
	var item := _aimed(ConsumableData.Target.ENEMY, HP, -10)
	assert_eq(s.item_targets(item).size(), 2)
	assert_false(s.item_targets(item).has(s.active))

func test_item_killing_only_ally_loses():
	var s := _started()
	s.inventory.add(_aimed(ConsumableData.Target.BOTH, HP, -999))
	watch_signals(s)
	assert_true(s.use_item(0, s.active))
	assert_signal_emitted_with_parameters(s, "finished", [E])

func test_item_with_nobody_in_area_cannot_be_used():
	var u := _wide_battle()
	# 적B (3,1) 아래 칸 (3,2) 은 비어 있다 → 받을 유닛이 없으면 쓸 수 없다 (아이템만 사라지지 않게)
	var area: Array[Vector2i] = [Vector2i(0, 1)]
	var item := _aimed(ConsumableData.Target.ENEMY, HP, -10, area)
	assert_false(battle.can_use_item(item, u[2]))
	assert_false(battle.use_item(item, u[2]))
	assert_true(battle.can_use_item(item, u[1]))


# --- 실제 아이템 데이터 (특수 효과: 2026-11-17-consumable-special-effects-design.md) ---

const BOMB := "res://items/consumables/폭탄.tres"
const SHIELD := "res://items/consumables/쉴드 포션.tres"
const RAGE := "res://items/consumables/분노 포션.tres"

func test_bomb_deals_10_to_each_enemy_in_area():
	var a := Fixture.unit(E, Vector2i(2, 1), {"max_hp": 100})
	var b := Fixture.unit(E, Vector2i(3, 1), {"max_hp": 100})
	var far := Fixture.unit(E, Vector2i(0, 0), {"max_hp": 100})
	var us: Array[BattleUnit] = [me, a, b, far]
	var bt := Battle.new(us, 1)
	assert_true(bt.use_item(load(BOMB), a))
	assert_eq(a.hp, 90)
	assert_eq(b.hp, 90)
	assert_eq(far.hp, 100)

func test_bomb_cannot_target_ally():
	assert_false(battle.can_use_item(load(BOMB), me))

func test_bomb_hits_block_first():
	foe.block = 4
	battle.use_item(load(BOMB), foe)
	assert_eq(foe.block, 0)
	assert_eq(foe.hp, 94)

func test_shield_potion_gives_10_block():
	assert_true(battle.use_item(load(SHIELD), me))
	assert_eq(me.block, 10)

func test_rage_potion_raises_attack_10_percent():
	var hero := Fixture.unit(A, Vector2i(3, 1), {"attack": 100})
	var us: Array[BattleUnit] = [hero, foe]
	var bt := Battle.new(us, 1)
	bt.use_item(load(RAGE), hero)
	assert_eq(hero.get_stat(BattleTypes.Stat.ATTACK), 110)

func test_rage_stacks_and_clears_all_on_own_end_phase():
	var hero := Fixture.unit(A, Vector2i(3, 1), {"attack": 100})
	var us: Array[BattleUnit] = [hero, foe]
	var bt := Battle.new(us, 1)
	bt.use_item(load(RAGE), hero)
	bt.use_item(load(RAGE), hero)
	assert_eq(hero.get_stat(BattleTypes.Stat.ATTACK), 120)
	bt.end_turn(hero)
	assert_eq(hero.stacks_of("rage_potion"), 0)
	assert_null(hero.get_status("rage_potion"))
	assert_eq(hero.get_stat(BattleTypes.Stat.ATTACK), 100)

func test_rage_survives_other_units_end_phase():
	battle.use_item(load(RAGE), me)
	battle.end_turn(foe)
	assert_eq(me.stacks_of("rage_potion"), 1)
