extends GutTest
# 카드 후보·원래 카드 찾기 (상점용).

func _card(id: String, deck_id := "", category := "attack") -> CardData:
	var c := CardData.new()
	c.id = id
	c.deck_id = deck_id
	c.category = category
	return c

func _unit_data(cards: Array) -> UnitData:
	var d := UnitData.new()
	d.deck.assign(cards)
	return d

func test_find_base_of_upgrade():
	var up := CardData.new()
	var base := _card("a", "d1")
	base.upgrades.assign([up])
	var pool: Array[CardData] = [base]
	assert_eq(CardPool.find_base(up, pool), base)
	assert_eq(CardPool.find_base(base, pool), base)

func test_upgrade_options_exclude_current():
	var u1 := CardData.new()
	var u2 := CardData.new()
	var base := _card("a", "d1")
	base.upgrades.assign([u1, u2])
	var pool: Array[CardData] = [base]
	assert_eq(CardPool.upgrade_options(base, pool), [u1, u2])
	assert_eq(CardPool.upgrade_options(u1, pool), [u2])

func test_upgrade_options_empty_when_single_upgrade_already_applied():
	var u1 := CardData.new()
	var base := _card("a", "d1")
	base.upgrades.assign([u1])
	var pool: Array[CardData] = [base]
	assert_eq(CardPool.upgrade_options(u1, pool), [])

func test_upgrade_options_empty_without_upgrades():
	var base := _card("a", "d1")
	var pool: Array[CardData] = [base]
	assert_eq(CardPool.upgrade_options(base, pool), [])

func test_deck_ids_of_unit():
	var d := _unit_data([_card("x", "d1"), _card("y", "d1"), _card("z", "")])
	assert_eq(CardPool.deck_ids_of(d), PackedStringArray(["d1"]))

func test_cards_for_filters_by_deck_and_category():
	var mine := _card("m", "d1")
	var pool: Array[CardData] = [mine, _card("e", "d1", "enemy"), _card("o", "d2"), _card("c", "")]
	var d := _unit_data([_card("x", "d1")])
	assert_eq(CardPool.cards_for(d, pool), [mine])

func test_load_all_reads_real_cards():
	assert_gt(CardPool.load_all().size(), 0)
	assert_true(CardPool.load_all("res://no_such_dir").is_empty())

func test_load_all_finds_base_of_real_upgrade():
	# 실제 카드의 강화본도 load_all 결과에서 원래 카드를 찾을 수 있어야 한다 (같은 리소스 객체)
	var pool := CardPool.load_all()
	for c in pool:
		if not c.upgrades.is_empty():
			assert_eq(CardPool.find_base(c.upgrades[0], CardPool.load_all()), c)
			return
	pending("강화가 있는 카드가 없음")
