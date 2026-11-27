extends GutTest
# 전투 화면의 의뢰 모드: 전투 노드로 들어오면 의뢰 파티를 쓰고 결과 버튼이 바뀐다.

const SCREEN := "res://Scenes/ui/battle_screen/battle_screen.tscn"

var _tmp_dir := ""  # 드랍 후보 아이템을 넣어 두는 임시 폴더

func after_each():
	StageRun.end_run()
	if _tmp_dir != "":
		var cards := _tmp_dir.path_join("cards")
		for f in DirAccess.get_files_at(cards):
			DirAccess.remove_absolute(cards.path_join(f))
		DirAccess.remove_absolute(cards)
		for f in DirAccess.get_files_at(_tmp_dir):
			DirAccess.remove_absolute(_tmp_dir.path_join(f))
		DirAccess.remove_absolute(_tmp_dir)
		_tmp_dir = ""

func _screen() -> BattleScreen:
	var s: BattleScreen = load(SCREEN).instantiate()
	s.enemy_delay = 0.0
	add_child_autofree(s)
	return s

func _enter_battle_node() -> void:
	StageRun.start_run(3)
	StageRun.progress.enter()  # 첫 열은 모두 전투

func test_outside_a_run_keeps_restart_button():
	var s := _screen()
	s._on_finished(BattleTypes.Side.ALLY)
	assert_eq(s.get_node("%ResultLabel").text, "승리")
	assert_ne(s.get_node("%RestartButton").text, "계속")

func test_stage_battle_uses_the_run_party():
	_enter_battle_node()
	var s := _screen()
	for u in StageRun.party:
		assert_true(u in s.session.battle.units)

func test_stage_battle_keeps_damage_between_battles():
	_enter_battle_node()
	var hurt: BattleUnit = StageRun.party[0]
	var first := _screen()
	hurt.hp = 7
	first.free()
	var second := _screen()
	assert_true(hurt in second.session.battle.units)
	assert_eq(hurt.hp, 7)

func test_each_stage_battle_rolls_a_new_seed():
	_enter_battle_node()
	var seeds := {}
	for i in 5:
		var s := _screen()
		seeds[s.battle_seed] = true
		s.free()
	assert_gt(seeds.size(), 1)

func test_outside_a_run_keeps_the_fixed_seed():
	var s: BattleScreen = load(SCREEN).instantiate()
	s.battle_seed = 42
	add_child_autofree(s)
	assert_eq(s.battle_seed, 42)

func test_stage_battle_leaves_out_fallen_member():
	_enter_battle_node()
	var fallen: BattleUnit = StageRun.party[0]
	fallen.hp = 0
	fallen.alive = false
	var s := _screen()
	assert_false(fallen in s.session.battle.units)

func test_stage_win_button_continues():
	_enter_battle_node()
	var s := _screen()
	s._on_finished(BattleTypes.Side.ALLY)
	assert_eq(s.get_node("%RestartButton").text, "계속")

func test_stage_loss_button_goes_to_title():
	_enter_battle_node()
	var s := _screen()
	s._on_finished(BattleTypes.Side.ENEMY)
	assert_eq(s.get_node("%RestartButton").text, "처음으로")



# --- 승리 후 보상 목록 (조각·아이템·카드, 클릭해서 챙기기) ---

func _item(n: String) -> ConsumableData:
	var i := ConsumableData.new()
	i.display_name = n
	return i

# 드랍 후보가 "드랍약" 하나뿐인 임시 폴더 + 카드 후보 n_cards 장(파티 첫 캐릭터의 deck_id)인 임시 카드 폴더를 쓰는 화면.
# chance = 드랍 확률. 카드는 _tmp_dir 의 cards/ 하위 폴더 (after_each 가 지운다)
func _screen_with_pool(chance: float, n_cards := 0) -> BattleScreen:
	_tmp_dir = "user://test_drop_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_tmp_dir)
	ResourceSaver.save(_item("드랍약"), _tmp_dir.path_join("drop.tres"))
	var card_dir := _tmp_dir.path_join("cards")
	DirAccess.make_dir_recursive_absolute(card_dir)
	var deck_id := ""
	if StageRun.is_active():
		for u in StageRun.party:   # 공용 카드만 가진 캐릭터는 deck_id 가 없다
			var ids := CardPool.deck_ids_of(u.data)
			if not ids.is_empty():
				deck_id = ids[0]
				break
	for i in n_cards:
		var c := CardData.new()
		c.id = "reward_%d" % i
		c.deck_id = deck_id
		c.name_ko = "보상카드%d" % i
		ResourceSaver.save(c, card_dir.path_join("c%d.tres" % i))
	var s: BattleScreen = load(SCREEN).instantiate()
	s.enemy_delay = 0.0
	s.item_drop_chance = chance
	s.drop_pool_dir = _tmp_dir
	s.card_pool_dir = card_dir
	add_child_autofree(s)
	return s

func _boss_node() -> StageNode:
	for n in StageRun.progress.nodes:
		if n.kind == StageNode.Kind.BOSS:
			return n
	return null

# 결과 창 보상 목록의 보이는 줄 글자들 (템플릿 제외)
func _rows(s: BattleScreen) -> Array:
	var out := []
	for b in s.get_node("%RewardList").get_children():
		if b != s.get_node("%RewardTemplate") and b.visible:
			out.append(b.text)
	return out

func _row(s: BattleScreen, text: String) -> Button:
	for b in s.get_node("%RewardList").get_children():
		if b != s.get_node("%RewardTemplate") and b.text == text:
			return b
	return null

func test_default_drop_chance_and_card_count():
	var s := _screen()
	assert_almost_eq(s.item_drop_chance, 0.4, 0.0001)
	assert_eq(s.card_reward_count, 3)

func test_stage_win_lists_rewards_and_continue_is_visible():
	_enter_battle_node()
	var s := _screen_with_pool(1.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_eq(_rows(s), ["공허 조각 20", "아이템: 드랍약", "카드 추가"])
	assert_eq(StageRun.wallet.shards, 0)   # 누르기 전에는 안 들어감
	assert_eq(s.get_node("%ResultLabel").text, "승리")
	assert_true(s.get_node("%RestartButton").visible)
	assert_eq(s.get_node("%RestartButton").text, "계속")
	assert_false(s.get_node("%DropBox").visible)
	assert_false(s.get_node("%CardPick").visible)

func test_click_shards_adds_once_and_row_goes():
	_enter_battle_node()
	var s := _screen_with_pool(0.0)
	s._on_finished(BattleTypes.Side.ALLY)
	_row(s, "공허 조각 20").pressed.emit()
	assert_eq(StageRun.wallet.shards, 20)
	assert_false("공허 조각 20" in _rows(s))
	s.click_shards()
	assert_eq(StageRun.wallet.shards, 20)

func test_click_item_puts_it_in_bag():
	_enter_battle_node()
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	_row(s, "아이템: 드랍약").pressed.emit()
	assert_eq(StageRun.inventory.items.size(), 1)
	assert_eq(StageRun.inventory.items[0].display_name, "드랍약")
	assert_null(s.reward.item)
	assert_false("아이템: 드랍약" in _rows(s))
	assert_false(s.get_node("%DropBox").visible)

func test_full_bag_click_item_offers_swap():
	_enter_battle_node()
	for i in Inventory.CAPACITY:
		StageRun.inventory.add(_item("헌약%d" % i))
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_false(s.get_node("%DropBox").visible)
	s.click_item()
	assert_true(s.get_node("%DropBox").visible)
	assert_eq(s.get_node("%DropSlots").get_child(2).get_node("%Name").text, "헌약2")
	assert_eq(StageRun.inventory.items.size(), 5)
	s.get_node("%DropSlots").get_child(2).pressed.emit(2)   # 바꿀 칸을 누름
	assert_null(s.reward.item)
	assert_eq(StageRun.inventory.items.size(), 5)
	assert_eq(StageRun.inventory.items[2].display_name, "드랍약")
	assert_eq(StageRun.inventory.items[1].display_name, "헌약1")
	assert_false(s.get_node("%DropBox").visible)
	assert_false("아이템: 드랍약" in _rows(s))

func test_full_bag_cancel_keeps_item_row():
	_enter_battle_node()
	for i in Inventory.CAPACITY:
		StageRun.inventory.add(_item("헌약%d" % i))
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	s.click_item()
	s.get_node("%SkipButton").pressed.emit()
	assert_false(s.get_node("%DropBox").visible)
	assert_not_null(s.reward.item)
	assert_true("아이템: 드랍약" in _rows(s))
	assert_eq(StageRun.inventory.items[0].display_name, "헌약0")

func test_stage_win_offers_three_party_cards():
	_enter_battle_node()
	var s := _screen_with_pool(0.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_eq(s.reward.cards.size(), 3)
	_row(s, "카드 추가").pressed.emit()
	assert_true(s.get_node("%CardPick").visible)
	assert_eq(s.get_node("%CardPickRow").get_child_count(), 3)

func test_pick_card_adds_to_owner_run_deck():
	_enter_battle_node()
	var s := _screen_with_pool(0.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	var owner: BattleUnit = s.reward.card_owners[0]
	var card: CardData = s.reward.cards[0]
	var before := owner.run_deck.size()
	var deck_before := owner.data.deck.size()
	s.open_card_pick()
	s.get_node("%CardPickRow").get_child(0).get_node("%Button").pressed.emit()
	assert_eq(owner.run_deck.size(), before + 1)
	assert_eq(owner.run_deck[-1], card)
	assert_eq(owner.data.deck.size(), deck_before)
	assert_false(s.get_node("%CardPick").visible)
	assert_false("카드 추가" in _rows(s))

func test_card_button_names_owner():
	_enter_battle_node()
	var s := _screen_with_pool(0.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	s.open_card_pick()
	var owner: BattleUnit = s.reward.card_owners[0]
	assert_eq(s.get_node("%CardPickRow").get_child(0).get_node("%Button").text, owner.data.display_name + " 덱에 추가")

func test_skip_card_pick_keeps_same_offer():
	_enter_battle_node()
	var s := _screen_with_pool(0.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	var offer := s.reward.cards.duplicate()
	s.open_card_pick()
	s.get_node("%CardPickSkip").pressed.emit()
	assert_false(s.get_node("%CardPick").visible)
	assert_true("카드 추가" in _rows(s))
	s.open_card_pick()
	assert_eq(s.reward.cards, offer)
	assert_eq(s.get_node("%CardPickRow").get_child_count(), 3)

func test_unclaimed_rewards_change_nothing():
	_enter_battle_node()
	var s := _screen_with_pool(1.0, 4)
	var decks := []
	for u in StageRun.party:
		decks.append(u.run_deck.size())
	s._on_finished(BattleTypes.Side.ALLY)
	assert_eq(StageRun.wallet.shards, 0)
	assert_eq(StageRun.inventory.items.size(), 0)
	for i in StageRun.party.size():
		assert_eq(StageRun.party[i].run_deck.size(), decks[i])

func test_no_party_cards_no_card_row():
	_enter_battle_node()
	var s := _screen_with_pool(0.0, 0)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_eq(s.reward.cards, [])
	assert_false("카드 추가" in _rows(s))

func test_zero_chance_no_item_row():
	_enter_battle_node()
	var s := _screen_with_pool(0.0)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_null(s.reward.item)
	assert_eq(_rows(s), ["공허 조각 20"])

func test_empty_pool_gives_no_drop():
	_enter_battle_node()
	var s := _screen()
	s.item_drop_chance = 1.0
	s.drop_pool_dir = "user://없는_폴더"
	s._on_finished(BattleTypes.Side.ALLY)
	assert_null(s.reward.item)
	assert_true(s.get_node("%RestartButton").visible)

func test_boss_win_shards_only():
	_enter_battle_node()
	StageRun.progress.entering = _boss_node()
	var s := _screen_with_pool(1.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_eq(_rows(s), ["공허 조각 50"])
	s.click_shards()
	assert_eq(StageRun.wallet.shards, 50)

func test_defeat_gives_no_reward():
	_enter_battle_node()
	var s := _screen_with_pool(1.0, 4)
	s._on_finished(BattleTypes.Side.ENEMY)
	assert_null(s.reward)
	assert_eq(_rows(s), [])
	assert_eq(StageRun.wallet.shards, 0)
	assert_eq(s.get_node("%RestartButton").text, "처음으로")
	assert_true(s.get_node("%RestartButton").visible)

func test_test_battle_outside_run_gives_no_reward():
	StageRun.end_run()
	var s := _screen_with_pool(1.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_null(s.reward)
	assert_eq(_rows(s), [])
	assert_eq(StageRun.wallet.shards, 0)
	assert_eq(s.get_node("%ResultLabel").text, "승리")
	assert_true(s.get_node("%RestartButton").visible)

func test_stage_battle_uses_the_run_bag():
	_enter_battle_node()
	StageRun.inventory.add(_item("가진약"))
	var s := _screen()
	assert_same(s.session.inventory, StageRun.inventory)
	assert_eq(s.get_node("%BagButton").text, "가방 1/5")

func test_card_pick_blocks_result_box_and_focuses_first_card():
	_enter_battle_node()
	for i in Inventory.CAPACITY:
		StageRun.inventory.add(_item("헌약%d" % i))
	var s := _screen_with_pool(1.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	s.click_item()   # 바꿀 칸 고르기가 열린 채로 카드 창을 연다
	s.open_card_pick()
	assert_false(s.get_node("%ResultOverlay/Box").visible)   # 계속·다른 줄을 누를 수 없음
	assert_false(s.get_node("%DropBox").visible)
	assert_true(s.get_node("%CardPickRow").get_child(0).get_node("%Button").has_focus())
	s.close_card_pick()
	assert_true(s.get_node("%ResultOverlay/Box").visible)

func test_win_focuses_first_reward_row_not_continue():
	# 스페이스/엔터 한 번에 "계속"이 눌려 보상을 다 잃지 않게 (리뷰 2026-11-19)
	_enter_battle_node()
	var s := _screen_with_pool(1.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_true(_row(s, "공허 조각 20").has_focus())

func test_claim_moves_focus_to_next_row():
	_enter_battle_node()
	var s := _screen_with_pool(1.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	_row(s, "공허 조각 20").pressed.emit()
	assert_true(_row(s, "아이템: 드랍약").has_focus())

func test_closing_card_pick_focuses_a_reward_row():
	_enter_battle_node()
	var s := _screen_with_pool(0.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	s.open_card_pick()
	s.close_card_pick()
	assert_true(_row(s, "공허 조각 20").has_focus())

func test_last_claim_focuses_continue():
	_enter_battle_node()
	var s := _screen_with_pool(0.0)
	s._on_finished(BattleTypes.Side.ALLY)
	var row := _row(s, "공허 조각 20")
	row.grab_focus()   # 키보드로 줄을 골라 누른 상황
	row.pressed.emit()
	assert_true(s.get_node("%RestartButton").has_focus())

func test_defeat_focuses_continue():
	_enter_battle_node()
	var s := _screen_with_pool(1.0, 4)
	s._on_finished(BattleTypes.Side.ENEMY)
	assert_true(s.get_node("%RestartButton").has_focus())

func test_cancel_closes_card_pick_then_swap():
	_enter_battle_node()
	for i in Inventory.CAPACITY:
		StageRun.inventory.add(_item("헌약%d" % i))
	var s := _screen_with_pool(1.0, 4)
	s._on_finished(BattleTypes.Side.ALLY)
	s.open_card_pick()
	s.cancel()   # ESC·우클릭
	assert_false(s.get_node("%CardPick").visible)
	assert_true(s.get_node("%ResultOverlay/Box").visible)
	assert_true("카드 추가" in _rows(s))
	s.click_item()
	s.cancel()
	assert_false(s.get_node("%DropBox").visible)
	assert_not_null(s.reward.item)

func test_swap_label_names_incoming_item():
	_enter_battle_node()
	for i in Inventory.CAPACITY:
		StageRun.inventory.add(_item("헌약%d" % i))
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	s.click_item()
	assert_eq(s.get_node("%DropLabel").text, "가방이 가득 찼어요 — [드랍약] 대신 버릴 칸을 고르세요")
