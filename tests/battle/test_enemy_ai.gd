extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event

var hero: BattleUnit
var foe: BattleUnit
var battle: Battle
var played := []
var turn_ends := []

func _card(name: String, attack_type := "melee", percent := 10.0) -> CardData:
	var c := CardData.new()
	c.name_ko = name
	c.attack_type = attack_type
	c.sp = 1
	var d := DamageEffect.new()
	d.percent = percent
	c.effects.assign([d])
	return c

func _setup(foe_deck: Array, boss := false, foe_row := 0) -> void:
	hero = Fixture.unit(A, Vector2i(3, 0))
	foe = Fixture.unit(E, Vector2i(3, foe_row), {"attack": 100, "is_boss": boss})
	foe.data.deck.assign(foe_deck)
	var units: Array[BattleUnit] = [hero, foe]
	battle = Battle.new(units, 5)
	played = []
	turn_ends = []
	battle.events.subscribe(Ev.AFTER_CARD_PLAYED, func(e): played.append(e.card.name_ko))
	battle.events.subscribe(Ev.TURN_END, func(e): turn_ends.append(e.actor))
	battle.start_battle()


func test_enemy_plays_drawn_card():
	_setup([_card("할퀴기")])
	battle.run_enemy_turn(foe)
	assert_eq(hero.hp, 90)
	assert_eq(foe.hand.size(), 0)
	assert_eq(played, ["할퀴기"])
	assert_eq(turn_ends, [foe])

func test_enemy_skips_unplayable():
	_setup([_card("할퀴기")], false, 2)  # 적이 2행 → 같은 행에 아군 없음
	battle.run_enemy_turn(foe)
	assert_eq(hero.hp, 100)
	assert_eq(played, [])
	assert_eq(foe.discard.size(), 1)
	assert_eq(turn_ends, [foe])

func test_enemy_ranged_targets_a_living_hero():
	_setup([_card("가시", "ranged")], false, 2)
	battle.run_enemy_turn(foe)
	assert_eq(hero.hp, 90)

func test_enemy_self_card_targets_itself():
	var c := CardData.new()
	c.name_ko = "웅크리기"
	c.attack_type = "self"
	var b := BlockEffect.new()
	b.use_flat = true
	b.flat = 5
	c.effects.assign([b])
	_setup([c])
	battle.run_enemy_turn(foe)
	assert_eq(foe.block, 5)

func test_boss_follows_sequence():
	_setup([_card("A"), _card("B")], true)
	for i in 3:
		battle.run_enemy_turn(foe)
	assert_eq(played, ["A", "B", "A"])

func test_boss_unplayable_advances():
	var melee := _card("A", "melee")
	var ranged := _card("B", "ranged")
	_setup([melee, ranged], true, 2)  # 근접 A 는 대상 없음
	battle.run_enemy_turn(foe)
	assert_eq(played, [])
	battle.run_enemy_turn(foe)
	assert_eq(played, ["B"])

func test_boss_deck_not_shuffled_or_drawn():
	_setup([_card("A"), _card("B"), _card("C")], true)
	battle.begin_turn(foe)
	assert_eq(foe.hand.map(func(c): return c.name_ko), ["A"])

func test_enemy_killed_by_bleed_does_nothing():
	_setup([_card("할퀴기")])
	foe.hp = 2
	var d := DamageEffect.new()
	d.use_flat = true
	d.flat = 1
	d.multiplier = StackCountValue.new("bleed")
	d.target = BattleTypes.Target.OWNER
	var t := StatusTrigger.new()
	t.event = Ev.DRAW_PHASE
	t.filter = BattleTypes.Filter.OWNER_IS_ACTOR
	t.effects.assign([d])
	var bleed := Fixture.status("bleed")
	bleed.triggers.assign([t])
	battle.apply_status(foe, bleed, 5, hero)
	battle.run_enemy_turn(foe)
	assert_false(foe.alive)
	assert_eq(hero.hp, 100)
	assert_eq(played, [])
