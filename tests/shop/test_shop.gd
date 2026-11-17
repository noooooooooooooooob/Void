extends GutTest
# 상점 한 번의 진열과 거래: 구매(카드·아이템), 카드 제거·강화, 조각 부족·가방 가득 참.

var _rng: RandomNumberGenerator

func before_each():
	_rng = RandomNumberGenerator.new()
	_rng.seed = 7

func _card(id: String, deck_id := "d1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.deck_id = deck_id
	return c

func _item(n: String) -> ConsumableData:
	var i := ConsumableData.new()
	i.display_name = n
	return i

func _unit(deck_cards: Array) -> BattleUnit:
	var d := UnitData.new()
	d.deck.assign(deck_cards)
	return BattleUnit.new(d, BattleTypes.Side.ALLY, Vector2i.ZERO)

func _wallet(n: int) -> Wallet:
	var w := Wallet.new()
	w.add(n)
	return w

func _pool(n: int, deck_id := "d1") -> Array[CardData]:
	var out: Array[CardData] = []
	for i in n:
		out.append(_card("%s_%d" % [deck_id, i], deck_id))
	return out

func _items(n: int) -> Array[ConsumableData]:
	var out: Array[ConsumableData] = []
	for i in n:
		out.append(_item("약%d" % i))
	return out

func _shop(party: Array, wallet: Wallet, pool: Array[CardData], items: Array[ConsumableData] = [], bag: Inventory = null) -> Shop:
	var p: Array[BattleUnit] = []
	p.assign(party)
	return Shop.new(ShopData.new(), p, wallet, bag if bag else Inventory.new(), pool, items, _rng)


func test_default_prices():
	var d := ShopData.new()
	assert_eq([d.card_price, d.item_price, d.remove_price, d.upgrade_price, d.card_count, d.item_count], [50, 30, 75, 60, 5, 3])

func test_stock_only_party_cards_no_duplicates():
	var u := _unit([_card("x", "d1")])
	var pool := _pool(7, "d1")
	pool.append_array(_pool(3, "d2"))
	var s := _shop([u], _wallet(0), pool)
	assert_eq(s.cards.size(), 5)
	var seen := {}
	for i in s.cards.size():
		assert_eq(s.cards[i].deck_id, "d1")
		assert_false(seen.has(s.cards[i]))
		seen[s.cards[i]] = true
		assert_eq(s.card_owners[i], u)

func test_stock_smaller_than_count():
	var u := _unit([_card("x", "d1")])
	var s := _shop([u], _wallet(0), _pool(2, "d1"))
	assert_eq(s.cards.size(), 2)
	assert_eq(s.items.size(), 0)

func test_items_no_duplicates():
	var u := _unit([_card("x")])
	var s := _shop([u], _wallet(0), [], _items(5))
	assert_eq(s.items.size(), 3)
	assert_ne(s.items[0], s.items[1])
	assert_ne(s.items[1], s.items[2])
	assert_ne(s.items[0], s.items[2])
	var s2 := _shop([u], _wallet(0), [], _items(2))
	assert_eq(s2.items.size(), 2)

func test_no_party_no_cards():
	var s := _shop([], _wallet(0), _pool(5))
	assert_eq(s.cards.size(), 0)

func test_buy_card_goes_to_owner_run_deck():
	var u := _unit([_card("x")])
	var w := _wallet(50)
	var s := _shop([u], w, _pool(5))
	var card := s.cards[0]
	assert_true(s.buy_card(0))
	assert_eq(w.shards, 0)
	assert_eq(u.run_deck.back(), card)
	assert_null(s.cards[0])
	assert_eq(u.data.deck.size(), 1)
	w.add(50)
	assert_false(s.buy_card(0))
	assert_eq(w.shards, 50)

func test_buy_fails_when_short():
	var u := _unit([_card("x")])
	var w := _wallet(49)
	var s := _shop([u], w, _pool(5))
	assert_false(s.buy_card(0))
	assert_not_null(s.cards[0])
	assert_eq(u.run_deck.size(), 1)
	assert_false(s.buy_card(99))

func test_buy_item_adds_to_bag():
	var u := _unit([_card("x")])
	var w := _wallet(30)
	var bag := Inventory.new()
	var s := _shop([u], w, [], _items(3), bag)
	var item := s.items[1]
	assert_true(s.buy_item(1))
	assert_eq(bag.items, [item])
	assert_null(s.items[1])
	assert_eq(w.shards, 0)

func test_buy_item_blocked_when_bag_full():
	var u := _unit([_card("x")])
	var w := _wallet(100)
	var bag := Inventory.new()
	for i in Inventory.CAPACITY:
		bag.add(_item("가진%d" % i))
	var s := _shop([u], w, [], _items(3), bag)
	assert_false(s.buy_item(0))
	assert_eq(w.shards, 100)
	assert_not_null(s.items[0])

func test_remove_card_only_that_index():
	var a := _card("a")
	var b := _card("b")
	var u := _unit([a, a, b])
	var w := _wallet(100)
	var s := _shop([u], w, [])
	assert_true(s.remove_card(u, 1))
	assert_eq(u.run_deck, [a, b])
	assert_eq(w.shards, 25)
	assert_eq(u.data.deck.size(), 3)
	assert_false(s.remove_card(u, 5))

func test_remove_fails_when_short():
	var u := _unit([_card("a")])
	var w := _wallet(74)
	var s := _shop([u], w, [])
	assert_false(s.remove_card(u, 0))
	assert_eq(u.run_deck.size(), 1)

func _base_with_upgrades(n: int) -> CardData:
	var base := _card("base")
	var ups: Array[CardData] = []
	for i in n:
		ups.append(_card("up%d" % i))
	base.upgrades = ups
	return base

func test_upgrade_choices_max_three():
	var base := _base_with_upgrades(5)
	var u := _unit([base])
	var s := _shop([u], _wallet(0), [base])
	var ch := s.upgrade_choices(u, 0)
	assert_eq(ch.size(), 3)
	for c in ch:
		assert_true(c in base.upgrades)
	assert_ne(ch[0], ch[1])
	assert_ne(ch[1], ch[2])
	assert_ne(ch[0], ch[2])

func test_upgrade_replaces_card():
	var base := _base_with_upgrades(2)
	var up1 := base.upgrades[0]
	var u := _unit([base])
	var w := _wallet(200)
	var s := _shop([u], w, [base])
	assert_true(s.upgrade_card(u, 0, up1))
	assert_eq(u.run_deck[0], up1)
	assert_eq(w.shards, 140)
	assert_false(s.upgrade_card(u, 0, base))
	assert_eq(s.upgrade_choices(u, 0), [base.upgrades[1]])
	assert_true(s.upgrade_card(u, 0, base.upgrades[1]))
	assert_eq(u.run_deck[0], base.upgrades[1])

func test_upgrade_fails_when_short():
	var base := _base_with_upgrades(1)
	var u := _unit([base])
	var w := _wallet(59)
	var s := _shop([u], w, [base])
	assert_false(s.upgrade_card(u, 0, base.upgrades[0]))
	assert_eq(u.run_deck[0], base)

func test_unit_outside_party_rejected():
	var base := _base_with_upgrades(1)
	var inside := _unit([_card("x")])
	var outside := _unit([base])
	var w := _wallet(500)
	var s := _shop([inside], w, [base])
	assert_false(s.remove_card(outside, 0))
	assert_eq(s.upgrade_choices(outside, 0), [])
	assert_false(s.upgrade_card(outside, 0, base.upgrades[0]))
	assert_eq(w.shards, 500)
	assert_eq(outside.run_deck, [base])
