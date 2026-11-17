extends GutTest
# 상점 화면: 조각·진열 표시, 가격 버튼, 구매·제거·강화 흐름, 버리기, 나가기 연결.

const SCENE := "res://Scenes/ui/shop_screen/shop_screen.tscn"

func before_each():
	StageRun.end_run()
	StageRun.start_run(3)
	for n in StageRun.progress.nodes:
		if n.kind == StageNode.Kind.SHOP:
			StageRun.progress.entering = n

func after_each():
	StageRun.end_run()

func _screen(shards := 0) -> ShopScreen:
	StageRun.wallet.add(shards)
	var s: ShopScreen = load(SCENE).instantiate()
	add_child_autofree(s)
	return s


func _buy_buttons(s: ShopScreen, row: String) -> Array[Button]:
	var out: Array[Button] = []
	for c in s.get_node(row).get_children():
		out.append(c.get_node("%Button"))
	return out

# 의뢰 덱에 강화가 있는 카드가 든 살아 있는 파티원과 그 칸
func _upgradable() -> Array:
	for u in StageRun.living_party():
		for i in u.run_deck.size():
			if not u.run_deck[i].upgrades.is_empty():
				return [u, i]
	return []


func test_shows_shards_and_stock():
	var s := _screen(100)
	assert_eq(s.get_node("%ShardLabel").text, "공허 조각 100")
	assert_eq(s.get_node("%CardRow").get_child_count(), 5)
	assert_eq(s.get_node("%ItemRow").get_child_count(), mini(3, StageRun.item_pool().size()))
	assert_false(s.get_node("%DeckPanel").visible)
	assert_false(s.get_node("%UpgradePanel").visible)

func test_buy_buttons_disabled_when_poor():
	var s := _screen(0)   # 가격이 0 이 아니라는 전제 (shop_data.tres 는 에디터에서 바뀔 수 있음)
	if s.shop_data.card_price <= 0:
		pending("카드 가격이 0")
		return
	for b in _buy_buttons(s, "%CardRow"):
		assert_true(b.disabled)
	for b in _buy_buttons(s, "%ItemRow"):
		assert_true(b.disabled)
	assert_true(s.get_node("%RemoveButton").disabled)
	assert_true(s.get_node("%UpgradeButton").disabled)

func test_buy_card_updates_label_and_deck():
	var s := _screen(100)
	var owner: BattleUnit = s.shop.card_owners[0]
	var before := owner.run_deck.size()
	s.click_buy_card(0)
	assert_eq(s.get_node("%ShardLabel").text, "공허 조각 %d" % (100 - s.shop_data.card_price))
	assert_eq(owner.run_deck.size(), before + 1)
	assert_true(_buy_buttons(s, "%CardRow")[0].disabled)

func test_remove_flow():
	var s := _screen(100)
	var u: BattleUnit = StageRun.living_party()[0]
	var before := u.run_deck.size()
	s.open_remove()
	assert_true(s.get_node("%DeckPanel").visible)
	assert_eq(s.get_node("%DeckGrid").get_child_count(), before)
	s.pick_deck_card(u, 0)
	assert_eq(u.run_deck.size(), before - 1)
	assert_false(s.get_node("%DeckPanel").visible)
	assert_eq(s.get_node("%ShardLabel").text, "공허 조각 %d" % (100 - s.shop_data.remove_price))

func test_upgrade_flow():
	var s := _screen(100)
	var found := _upgradable()
	assert_false(found.is_empty(), "강화가 있는 카드가 파티 덱에 있어야 함")
	var u: BattleUnit = found[0]
	var i: int = found[1]
	s.open_upgrade()
	s.select_unit(u)
	s.pick_deck_card(u, i)
	assert_true(s.get_node("%UpgradePanel").visible)
	var first: CardData = s.upgrade_choices[0]
	s.pick_upgrade(first)
	assert_eq(u.run_deck[i], first)
	assert_false(s.get_node("%UpgradePanel").visible)
	assert_false(s.get_node("%DeckPanel").visible)
	assert_eq(s.get_node("%ShardLabel").text, "공허 조각 %d" % (100 - s.shop_data.upgrade_price))

func test_cancel_closes_panels():
	var s := _screen(100)
	s.open_remove()
	s.get_node("%DeckCancel").pressed.emit()
	assert_false(s.get_node("%DeckPanel").visible)

func test_fallen_member_not_in_tabs():
	var fallen: BattleUnit = StageRun.party[0]
	fallen.hp = 0
	var s := _screen(100)
	s.open_remove()
	var shown := 0   # 숨겨 둔 탭 틀(UnitTabTemplate)은 빼고 센다
	for t in s.get_node("%UnitTabs").get_children():
		if t.visible:
			shown += 1
	assert_eq(shown, StageRun.living_party().size())
	for owner in s.shop.card_owners:
		assert_ne(owner, fallen)

func test_discard_from_bag():
	var item := ConsumableData.new()
	item.display_name = "버릴약"
	StageRun.inventory.add(item)
	var s := _screen(0)
	s.get_node("%BagPanel").discard_requested.emit(0)
	assert_eq(StageRun.inventory.items.size(), 0)

func test_leave_button_wired():
	var s := _screen(0)
	assert_true(s.get_node("%LeaveButton").pressed.is_connected(s.leave))

func test_cards_without_upgrades_cannot_be_picked_for_upgrade():
	var s := _screen(100)
	s.open_upgrade()
	for u in StageRun.living_party():
		s.select_unit(u)
		var grid := s.get_node("%DeckGrid")
		for i in u.run_deck.size():
			var b: Button = grid.get_child(i).get_node("%Button")
			assert_eq(b.disabled, u.run_deck[i].upgrades.is_empty(), u.run_deck[i].name_ko)
