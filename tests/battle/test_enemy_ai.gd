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

func test_enemy_skips_when_extra_card_also_unplayable():
	_setup([_card("할퀴기"), _card("물기")], false, 2)  # 적이 2행 → 근접 카드 둘 다 못 씀
	battle.run_enemy_turn(foe)
	assert_eq(hero.hp, 100)
	assert_eq(played, [])
	assert_eq(foe.discard.size(), 2)  # 처음 카드 + 한 장 더 뽑은 카드 모두 버려짐
	assert_eq(turn_ends, [foe])

func test_enemy_draws_one_more_when_unplayable():
	# 처음 뽑은 근접 카드는 못 씀 → 한 장 더 뽑아서(원거리) 사용 (사용자 결정)
	_setup([_card("할퀴기"), _card("가시", "ranged")], false, 2)
	foe.deck.assign([foe.data.deck[0], foe.data.deck[1]])  # 순서 고정: 근접 → 원거리
	battle.run_enemy_turn(foe)
	assert_eq(played, ["가시"])
	assert_eq(hero.hp, 90)

func test_enemy_extra_draw_does_not_reshuffle():
	# 추가 드로우는 행동 중 드로우 → 덱이 비면 버린 더미를 섞지 않는다
	_setup([_card("할퀴기"), _card("가시", "ranged")], false, 2)
	foe.deck.assign([foe.data.deck[0]])
	foe.discard.assign([foe.data.deck[1]])
	battle.run_enemy_turn(foe)
	assert_eq(played, [])
	assert_eq(hero.hp, 100)

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

func test_boss_unplayable_takes_next_card_now():
	var melee := _card("A", "melee")
	var ranged := _card("B", "ranged")
	_setup([melee, ranged], true, 2)  # 근접 A 는 대상 없음 → 순서상 다음 카드 B 를 바로 꺼내 씀
	battle.run_enemy_turn(foe)
	assert_eq(played, ["B"])
	battle.run_enemy_turn(foe)  # 다시 A(못 씀) → B
	assert_eq(played, ["B", "B"])

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


func _heroes_with_aggro(aggros: Array) -> Array[BattleUnit]:
	var hs: Array[BattleUnit] = []
	for i in aggros.size():
		hs.append(Fixture.unit(A, Vector2i(0, i), {"aggro": aggros[i]}))
	return hs

func _ranged_battle(hs: Array[BattleUnit]) -> void:
	foe = Fixture.unit(E, Vector2i(3, 0))
	var units: Array[BattleUnit] = []
	units.append_array(hs)
	units.append(foe)
	battle = Battle.new(units, 11)

func test_ranged_target_never_zero_aggro_when_others_have_aggro():
	var hs := _heroes_with_aggro([0, 0, 100])
	_ranged_battle(hs)
	for i in 50:
		assert_same(battle.enemy_ai.pick_ranged_target(foe), hs[2])

func test_ranged_target_weighted_by_aggro():
	var hs := _heroes_with_aggro([100, 300])
	_ranged_battle(hs)
	var counts := {hs[0]: 0, hs[1]: 0}
	for i in 2000:
		counts[battle.enemy_ai.pick_ranged_target(foe)] += 1
	var ratio := float(counts[hs[1]]) / 2000.0
	assert_between(ratio, 0.70, 0.80)  # 기대값 0.75

func test_ranged_target_uniform_when_all_aggro_zero():
	var hs := _heroes_with_aggro([0, 0])
	_ranged_battle(hs)
	var seen := {}
	for i in 200:
		seen[battle.enemy_ai.pick_ranged_target(foe)] = true
	assert_eq(seen.size(), 2)

func test_ranged_target_ignores_dead():
	var hs := _heroes_with_aggro([999, 1])
	hs[0].alive = false
	_ranged_battle(hs)
	for i in 20:
		assert_same(battle.enemy_ai.pick_ranged_target(foe), hs[1])

