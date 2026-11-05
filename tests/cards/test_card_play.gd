extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event

var me: BattleUnit
var buddy: BattleUnit
var foe: BattleUnit
var battle: Battle
var log := []

func before_each():
	me = Fixture.unit(A, Vector2i(3, 1), {"attack": 100})
	buddy = Fixture.unit(A, Vector2i(3, 0))
	foe = Fixture.unit(E, Vector2i(3, 1), {"max_hp": 1000})
	var units: Array[BattleUnit] = [me, buddy, foe]
	battle = Battle.new(units)
	me.sp = 3
	log = []
	for t in [Ev.BEFORE_CARD_PLAYED, Ev.DAMAGE_DEALT, Ev.AFTER_CARD_PLAYED, Ev.CARD_EXILED]:
		battle.events.subscribe(t, func(e): log.append(e.type))

func _card(attack_type := "melee", sp := 1, percent := 100.0) -> CardData:
	var c := CardData.new()
	c.name_ko = "테스트"
	c.attack_type = attack_type
	c.sp = sp
	var d := DamageEffect.new()
	d.percent = percent
	c.effects.assign([d])
	return c

func _in_hand(c: CardData) -> CardData:
	me.hand.append(c)
	return c

func _status_cost(id: String, amount := 1, all := false, min_stacks := 1) -> StatusCost:
	var s := StatusCost.new()
	s.status_id = id
	s.amount = amount
	s.consume_all = all
	s.min_stacks = min_stacks
	return s


func test_insufficient_sp():
	var c := _in_hand(_card("melee", 4))
	assert_eq(battle.can_play(me, c), "sp")

func test_not_in_hand():
	assert_eq(battle.can_play(me, _card()), "not_in_hand")

func test_dead_user():
	var c := _in_hand(_card())
	me.alive = false
	assert_eq(battle.can_play(me, c), "dead")

func test_fixed_status_cost():
	var c := _in_hand(_card())
	c.costs.assign([_status_cost("x", 3)])
	me.add_status(Fixture.status("x"), 2, me)
	assert_eq(battle.can_play(me, c), "cost")
	me.add_status(Fixture.status("x"), 3, me)
	assert_true(battle.play_card(me, c))
	assert_eq(me.stacks_of("x"), 2)

func test_consumed_value_recorded_for_effects():
	var c := _in_hand(_card())
	c.costs.assign([_status_cost("x", 3)])
	var d := DamageEffect.new()
	d.percent = 10
	d.multiplier = ConsumedValue.new("x")
	c.effects.assign([d])
	me.add_status(Fixture.status("x"), 5, me)
	battle.play_card(me, c)
	assert_eq(foe.hp, 1000 - 30)  # 100 × 10% × 소모 3

func test_consume_all_blood_slash():
	# 스펙 예시: 공격 100, 핏방울 5, consume_all, 40% × 소모량 → 200
	var c := _in_hand(_card("melee", 1, 40))
	c.costs.assign([_status_cost("blood_drop", 1, true, 1)])
	c.effects[0].multiplier = ConsumedValue.new("blood_drop")
	me.add_status(Fixture.status("blood_drop"), 5, me)
	assert_true(battle.play_card(me, c))
	assert_eq(foe.hp, 800)
	assert_null(me.get_status("blood_drop"))

func test_consume_all_needs_min():
	var c := _in_hand(_card())
	c.costs.assign([_status_cost("blood_drop", 1, true, 1)])
	assert_eq(battle.can_play(me, c), "cost")

func test_melee_requires_target_in_row():
	var c := _in_hand(_card("melee"))
	foe.cell = Vector2i(3, 2)
	assert_eq(battle.can_play(me, c), "melee_target")
	foe.cell = Vector2i(3, 1)
	var back := Fixture.unit(E, Vector2i(1, 1))
	battle.units.append(back)
	back.battle = battle
	assert_true(battle.play_card(me, c))
	assert_eq(foe.hp, 900)
	assert_eq(back.hp, 100)

func test_ranged_origin_must_be_enemy():
	var c := _in_hand(_card("ranged"))
	assert_eq(battle.can_play(me, c, buddy), "origin")
	assert_eq(battle.can_play(me, c, null), "origin")
	assert_eq(battle.can_play(me, c, foe), "")

func test_ally_origin_must_be_ally():
	var c := _in_hand(_card("ally"))
	assert_eq(battle.can_play(me, c, foe), "origin")
	assert_eq(battle.can_play(me, c, buddy), "")
	assert_eq(battle.can_play(me, c, me), "")

func test_self_card_targets_user():
	var c := _in_hand(_card("self"))
	var b := BlockEffect.new()
	b.use_flat = true
	b.flat = 5
	c.effects.assign([b])
	assert_true(battle.play_card(me, c, foe))
	assert_eq(me.block, 5)

func test_has_status_condition():
	var c := _in_hand(_card())
	var cond := HasStatusCondition.new()
	cond.status_id = "rage"
	cond.min_stacks = 2
	c.conditions.assign([cond])
	me.add_status(Fixture.status("rage"), 1, me)
	assert_eq(battle.can_play(me, c), "condition")
	me.add_status(Fixture.status("rage"), 1, me)
	assert_eq(battle.can_play(me, c), "")
	battle.play_card(me, c)
	assert_eq(me.stacks_of("rage"), 2)  # 조건은 소모하지 않음

func test_card_moves_to_discard_and_sp_spent():
	var c := _in_hand(_card("melee", 2))
	assert_true(battle.play_card(me, c))
	assert_false(me.hand.has(c))
	assert_true(me.discard.has(c))
	assert_eq(me.sp, 1)

func test_failed_play_changes_nothing():
	var c := _in_hand(_card("melee", 5))
	assert_false(battle.play_card(me, c))
	assert_true(me.hand.has(c))
	assert_eq(me.sp, 3)
	assert_eq(log, [])

func test_play_events_order():
	battle.play_card(me, _in_hand(_card()))
	assert_eq(log, [Ev.BEFORE_CARD_PLAYED, Ev.DAMAGE_DEALT, Ev.AFTER_CARD_PLAYED])

func test_card_replacement():
	var orig := _in_hand(_card("melee", 1, 10))
	var repl := _card("melee", 1, 50)
	var st := Fixture.status("stance", false)
	st.replacements = {orig: repl}
	me.add_status(st, 1, me)
	assert_true(battle.play_card(me, orig))
	assert_eq(foe.hp, 950)           # 대체 카드(50%)로 사용됨
	assert_true(me.discard.has(orig))  # 버린 더미에는 원래 카드
	assert_false(me.discard.has(repl))

func test_replacement_only_while_status_held():
	var orig := _in_hand(_card())
	var repl := _card()
	var st := Fixture.status("stance", false)
	st.replacements = {orig: repl}
	me.add_status(st, 1, me)
	assert_same(battle.effective_card(me, orig), repl)
	battle.remove_status(me, "stance")
	assert_same(battle.effective_card(me, orig), orig)

func test_exile_keyword_sends_card_to_exile():
	var kw := KeywordData.new()
	kw.id = "k_exile"
	kw.rules.assign([ExileAfterUseRule.new()])
	battle.keyword_cache["k_exile"] = kw
	var c := _in_hand(_card())
	c.keywords = PackedStringArray(["k_exile"])
	assert_true(battle.play_card(me, c))
	assert_true(me.exiled.has(c))
	assert_false(me.discard.has(c))
	assert_eq(log, [Ev.BEFORE_CARD_PLAYED, Ev.DAMAGE_DEALT, Ev.CARD_EXILED, Ev.AFTER_CARD_PLAYED])

func test_replaced_card_with_exile_returns_original_to_exile():
	var kw := KeywordData.new()
	kw.id = "k_exile"
	kw.rules.assign([ExileAfterUseRule.new()])
	battle.keyword_cache["k_exile"] = kw
	var orig := _in_hand(_card())
	var repl := _card()
	repl.keywords = PackedStringArray(["k_exile"])
	var st := Fixture.status("stance", false)
	st.replacements = {orig: repl}
	me.add_status(st, 1, me)
	battle.play_card(me, orig)
	assert_true(me.exiled.has(orig))
	assert_false(me.exiled.has(repl))

func test_keyword_without_exile_rule_goes_to_discard():
	var kw := KeywordData.new()
	kw.id = "k_plain"
	battle.keyword_cache["k_plain"] = kw
	var c := _in_hand(_card())
	c.keywords = PackedStringArray(["k_plain"])
	battle.play_card(me, c)
	assert_true(me.discard.has(c))

func test_area_around_ranged_origin():
	var c := _in_hand(_card("ranged"))
	c.area.assign([Vector2i(0, 0), Vector2i(0, 1)])
	var below := Fixture.unit(E, Vector2i(3, 2))
	battle.units.append(below)
	below.battle = battle
	battle.play_card(me, c, foe)
	assert_eq([foe.hp, below.hp], [900, 0])
