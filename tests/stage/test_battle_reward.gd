extends GutTest
# 전투 보상 챙기기: 조각·아이템(가방 가득 참·바꾸기)·카드(주인의 의뢰 덱으로), 두 번 챙기지 않기.

func _item(n: String) -> ConsumableData:
	var i := ConsumableData.new()
	i.display_name = n
	return i

func _card(id: String) -> CardData:
	var c := CardData.new()
	c.id = id
	return c

func _unit() -> BattleUnit:
	var d := UnitData.new()
	d.deck.assign([_card("base")])
	return BattleUnit.new(d, BattleTypes.Side.ALLY, Vector2i.ZERO)

func _full_bag() -> Inventory:
	var b := Inventory.new()
	for i in 5:
		b.add(_item("약%d" % i))
	return b

func _reward(shards := 0, drop: ConsumableData = null, n_cards := 0, owner: BattleUnit = null) -> BattleReward:
	var cards: Array[CardData] = []
	var owners: Array[BattleUnit] = []
	for i in n_cards:
		cards.append(_card("c%d" % i))
		owners.append(owner)
	return BattleReward.new(shards, drop, cards, owners)


func test_claim_shards_adds_once():
	var w := Wallet.new()
	var r := _reward(20)
	assert_true(r.claim_shards(w))
	assert_false(r.claim_shards(w))
	assert_eq(w.shards, 20)
	assert_eq(r.shards, 0)

func test_claim_item_into_bag():
	var bag := Inventory.new()
	var r := _reward(0, _item("포션"))
	assert_true(r.claim_item(bag))
	assert_eq(bag.items.size(), 1)
	assert_null(r.item)
	assert_false(r.claim_item(bag))
	assert_eq(bag.items.size(), 1)

func test_claim_item_full_bag_keeps_it():
	var bag := _full_bag()
	var drop := _item("포션")
	var r := _reward(0, drop)
	assert_false(r.claim_item(bag))
	assert_eq(r.item, drop)
	assert_eq(bag.items.size(), 5)

func test_swap_item_replaces_slot():
	var bag := _full_bag()
	var drop := _item("포션")
	var r := _reward(0, drop)
	assert_true(r.swap_item(bag, 2))
	assert_eq(bag.items[2], drop)
	assert_eq(bag.items.size(), 5)
	assert_null(r.item)
	assert_false(r.swap_item(bag, 3))

func test_claim_card_goes_to_owner_run_deck_once():
	var u := _unit()
	var r := _reward(0, null, 3, u)
	var picked := r.cards[1]
	var before := u.run_deck.size()
	assert_true(r.claim_card(1))
	assert_eq(u.run_deck.size(), before + 1)
	assert_eq(u.run_deck[-1], picked)
	assert_eq(u.data.deck.size(), 1)
	assert_eq(r.cards, [])
	assert_eq(r.card_owners, [])
	assert_false(r.claim_card(0))
	assert_eq(u.run_deck.size(), before + 1)

func test_claim_card_bad_index():
	var u := _unit()
	var r := _reward(0, null, 3, u)
	var before := u.run_deck.size()
	assert_false(r.claim_card(-1))
	assert_false(r.claim_card(3))
	assert_eq(r.cards.size(), 3)
	assert_eq(u.run_deck.size(), before)

func test_is_empty():
	assert_true(_reward().is_empty())
	assert_false(_reward(5).is_empty())
	assert_false(_reward(0, _item("x")).is_empty())
	assert_false(_reward(0, null, 1, _unit()).is_empty())
