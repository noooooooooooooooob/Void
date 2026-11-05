extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event

var me: BattleUnit
var foe: BattleUnit
var battle: Battle

func _cards(n: int, prefix := "c") -> Array[CardData]:
	var out: Array[CardData] = []
	for i in n:
		var c := CardData.new()
		c.id = "%s%d" % [prefix, i]
		out.append(c)
	return out

func before_each():
	me = Fixture.unit(A, Vector2i(3, 0), {"max_sp": 3, "move": 2})
	me.data.deck = _cards(10)
	foe = Fixture.unit(E, Vector2i(3, 0))
	foe.data.deck = _cards(4, "e")
	var units: Array[BattleUnit] = [me, foe]
	battle = Battle.new(units, 7)


func test_start_battle_copies_and_shuffles_deck():
	battle.start_battle()
	assert_eq(me.deck.size(), 10)
	assert_eq(me.data.deck.size(), 10)  # 원본 데이터는 그대로
	assert_eq([me.hand.size(), me.discard.size(), me.exiled.size()], [0, 0, 0])

func test_begin_turn_refills_and_draws():
	battle.start_battle()
	me.sp = 0
	assert_true(battle.begin_turn(me))
	assert_eq([me.sp, me.move_left, me.hand.size(), me.deck.size()], [3, 2, 5, 5])

func test_begin_turn_event_order():
	var log := []
	for t in [Ev.TURN_START, Ev.CARD_DRAWN, Ev.DRAW_PHASE, Ev.STANDBY_PHASE]:
		battle.events.subscribe(t, func(e): log.append(e.type))
	battle.start_battle()
	battle.begin_turn(foe)
	assert_eq(log, [Ev.TURN_START, Ev.CARD_DRAWN, Ev.DRAW_PHASE, Ev.STANDBY_PHASE])

func test_enemy_draws_one():
	battle.start_battle()
	battle.begin_turn(foe)
	assert_eq(foe.hand.size(), 1)

func test_end_turn_discards_whole_hand():
	var discarded := []
	battle.events.subscribe(Ev.CARD_DISCARDED, func(e): discarded.append(e.card))
	var log := []
	for t in [Ev.END_PHASE, Ev.TURN_END]:
		battle.events.subscribe(t, func(e): log.append(e.type))
	battle.start_battle()
	battle.begin_turn(me)
	battle.end_turn(me)
	assert_eq([me.hand.size(), me.discard.size(), discarded.size()], [0, 5, 5])
	assert_eq(log, [Ev.END_PHASE, Ev.TURN_END])

func test_reshuffle_when_deck_empty():
	battle.start_battle()
	me.deck = _cards(3)
	me.discard = _cards(2, "d")
	battle.draw(me, 5)
	assert_eq([me.hand.size(), me.deck.size(), me.discard.size()], [5, 0, 0])

func test_exiled_cards_never_reshuffled():
	battle.start_battle()
	me.deck = _cards(1)
	me.discard = [] as Array[CardData]
	me.exiled = _cards(3, "x")
	battle.draw(me, 5)
	assert_eq([me.hand.size(), me.exiled.size()], [1, 3])

func test_draw_stops_when_deck_and_discard_empty():
	battle.start_battle()
	me.deck = _cards(2)
	me.discard = [] as Array[CardData]
	battle.draw(me, 5)
	assert_eq(me.hand.size(), 2)

func test_block_reset_at_round_start():
	var resets := []
	battle.events.subscribe(Ev.BLOCK_RESET, func(e): resets.append(e.target))
	battle.start_battle()
	me.block = 10
	battle.start_round()
	assert_eq(me.block, 0)
	assert_eq(resets, [me])

func test_keeps_block_status():
	battle.start_battle()
	var st := Fixture.status("fortress", false)
	st.keeps_block = true
	me.add_status(st, 1, me)
	me.block = 10
	battle.start_round()
	assert_eq(me.block, 10)

func test_same_seed_same_shuffle():
	battle.start_battle()
	var first := me.deck.map(func(c): return c.id)
	var me2 := Fixture.unit(A, Vector2i(3, 0))
	me2.data.deck = me.data.deck
	var foe2 := Fixture.unit(E, Vector2i(3, 0))
	var units2: Array[BattleUnit] = [me2, foe2]
	var b2 := Battle.new(units2, 7)
	b2.start_battle()
	assert_eq(me2.deck.map(func(c): return c.id), first)

func test_draw_effect():
	battle.start_battle()
	var d := DrawEffect.new()
	d.count = 2
	d.target = BattleTypes.Target.SELF
	var ctx := EffectContext.new()
	ctx.battle = battle
	ctx.actor = me
	ctx.owner = me
	d.apply(ctx)
	assert_eq(me.hand.size(), 2)


func test_draw_effect_during_action_does_not_reshuffle():
	# 행동 중 드로우: 덱이 비면 버린 더미를 섞지 않고 못 뽑는다 (사용자 결정)
	battle.start_battle()
	me.deck = [] as Array[CardData]
	me.discard = _cards(3, "d")
	var d := DrawEffect.new()
	d.count = 2
	d.target = BattleTypes.Target.SELF
	var ctx := EffectContext.new()
	ctx.battle = battle
	ctx.actor = me
	ctx.owner = me
	d.apply(ctx)
	assert_eq([me.hand.size(), me.discard.size()], [0, 3])

func test_draw_effect_stops_when_deck_runs_out():
	battle.start_battle()
	me.deck = _cards(1)
	me.discard = _cards(3, "d")
	battle.draw(me, 3, false)
	assert_eq([me.hand.size(), me.deck.size(), me.discard.size()], [1, 0, 3])

func test_draw_phase_still_reshuffles():
	battle.start_battle()
	me.deck = _cards(2)
	me.discard = _cards(5, "d")
	battle.begin_turn(me)
	assert_eq(me.hand.size(), 5)

