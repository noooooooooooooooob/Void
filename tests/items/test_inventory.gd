extends GutTest

func _item(n: String) -> ConsumableData:
	var i := ConsumableData.new()
	i.display_name = n
	return i

func test_add_until_full():
	var bag := Inventory.new()
	for i in Inventory.CAPACITY:
		assert_true(bag.add(_item(str(i))))
	assert_true(bag.is_full())
	assert_false(bag.add(_item("넘침")))
	assert_eq(bag.items.size(), 5)

func test_add_null_is_refused():
	assert_false(Inventory.new().add(null))

func test_remove_at_returns_item_and_closes_gap():
	var bag := Inventory.new()
	var a := _item("a")
	var b := _item("b")
	bag.add(a)
	bag.add(b)
	assert_same(bag.remove_at(0), a)
	assert_eq(bag.items, [b] as Array[ConsumableData])
	assert_null(bag.remove_at(3))

func test_replace_swaps_one_slot():
	var bag := Inventory.new()
	bag.add(_item("a"))
	var c := _item("c")
	assert_true(bag.replace(0, c))
	assert_same(bag.items[0], c)
	assert_false(bag.replace(1, c))
	assert_false(bag.replace(0, null))
