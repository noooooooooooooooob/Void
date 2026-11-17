extends GutTest
# 전투 화면의 의뢰 모드: 전투 노드로 들어오면 의뢰 파티를 쓰고 결과 버튼이 바뀐다.

const SCREEN := "res://Scenes/ui/battle_screen/battle_screen.tscn"

var _tmp_dir := ""  # 드랍 후보 아이템을 넣어 두는 임시 폴더

func after_each():
	StageRun.end_run()
	if _tmp_dir != "":
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


# --- 승리 후 아이템 드랍 ---

func _item(n: String) -> ConsumableData:
	var i := ConsumableData.new()
	i.display_name = n
	return i

# 드랍 후보가 "드랍약" 하나뿐인 임시 폴더를 쓰는 화면. chance = 드랍 확률
func _screen_with_pool(chance: float) -> BattleScreen:
	_tmp_dir = "user://test_drop_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_tmp_dir)
	ResourceSaver.save(_item("드랍약"), _tmp_dir.path_join("drop.tres"))
	var s: BattleScreen = load(SCREEN).instantiate()
	s.enemy_delay = 0.0
	s.item_drop_chance = chance
	s.drop_pool_dir = _tmp_dir
	add_child_autofree(s)
	return s

func _boss_node() -> StageNode:
	for n in StageRun.progress.nodes:
		if n.kind == StageNode.Kind.BOSS:
			return n
	return null

func test_default_drop_chance_is_forty_percent():
	var s := _screen()
	assert_almost_eq(s.item_drop_chance, 0.4, 0.0001)

func test_stage_win_with_full_chance_offers_item_and_take_adds_it():
	_enter_battle_node()
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_not_null(s.pending_drop)
	assert_true(s.get_node("%DropBox").visible)
	assert_eq(s.get_node("%DropLabel").text, "아이템 획득: 드랍약")
	assert_true(s.get_node("%TakeButton").visible)
	assert_false(s.get_node("%DropSlots").visible)
	assert_false(s.get_node("%RestartButton").visible)
	s.take_drop()
	assert_null(s.pending_drop)
	assert_eq(StageRun.inventory.items.size(), 1)
	assert_eq(StageRun.inventory.items[0].display_name, "드랍약")
	assert_false(s.get_node("%DropBox").visible)
	assert_true(s.get_node("%RestartButton").visible)
	assert_eq(s.get_node("%RestartButton").text, "계속")

func test_take_and_skip_buttons_are_wired():
	_enter_battle_node()
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	s.get_node("%TakeButton").pressed.emit()
	assert_eq(StageRun.inventory.items.size(), 1)

func test_skip_drop_adds_nothing():
	_enter_battle_node()
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	s.get_node("%SkipButton").pressed.emit()
	assert_null(s.pending_drop)
	assert_eq(StageRun.inventory.items.size(), 0)
	assert_false(s.get_node("%DropBox").visible)
	assert_true(s.get_node("%RestartButton").visible)

func test_zero_chance_goes_straight_to_continue():
	_enter_battle_node()
	var s := _screen_with_pool(0.0)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_null(s.pending_drop)
	assert_false(s.get_node("%DropBox").visible)
	assert_true(s.get_node("%RestartButton").visible)

func test_full_bag_offers_swap_and_never_exceeds_five():
	_enter_battle_node()
	for i in Inventory.CAPACITY:
		StageRun.inventory.add(_item("헌약%d" % i))
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_eq(s.get_node("%DropLabel").text, "아이템 획득: 드랍약 (가방이 가득 참)")
	assert_false(s.get_node("%TakeButton").visible)
	assert_true(s.get_node("%SkipButton").visible)
	assert_true(s.get_node("%DropSlots").visible)
	assert_eq(s.get_node("%DropSlots").get_child(2).get_node("%Name").text, "헌약2")
	s.take_drop()   # 가득 차 있으면 받기는 아무것도 하지 않는다
	assert_eq(StageRun.inventory.items.size(), 5)
	assert_not_null(s.pending_drop)
	s.get_node("%DropSlots").get_child(2).pressed.emit(2)   # 바꿀 칸을 누름
	assert_null(s.pending_drop)
	assert_eq(StageRun.inventory.items.size(), 5)
	assert_eq(StageRun.inventory.items[2].display_name, "드랍약")
	assert_eq(StageRun.inventory.items[1].display_name, "헌약1")
	assert_true(s.get_node("%RestartButton").visible)

func test_empty_pool_gives_no_drop():
	_enter_battle_node()
	var s := _screen()
	s.item_drop_chance = 1.0
	s.drop_pool_dir = "user://없는_폴더"
	s._on_finished(BattleTypes.Side.ALLY)
	assert_null(s.pending_drop)
	assert_true(s.get_node("%RestartButton").visible)

func test_boss_win_gives_no_drop():
	_enter_battle_node()
	StageRun.progress.entering = _boss_node()
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_null(s.pending_drop)
	assert_false(s.get_node("%DropBox").visible)

func test_defeat_gives_no_drop():
	_enter_battle_node()
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ENEMY)
	assert_null(s.pending_drop)
	assert_eq(s.get_node("%RestartButton").text, "처음으로")
	assert_true(s.get_node("%RestartButton").visible)

func test_test_battle_outside_run_gives_no_drop():
	var s := _screen_with_pool(1.0)
	s._on_finished(BattleTypes.Side.ALLY)
	assert_null(s.pending_drop)
	assert_false(s.get_node("%DropBox").visible)
	assert_true(s.get_node("%RestartButton").visible)

func test_stage_battle_uses_the_run_bag():
	_enter_battle_node()
	StageRun.inventory.add(_item("가진약"))
	var s := _screen()
	assert_same(s.session.inventory, StageRun.inventory)
	assert_eq(s.get_node("%BagButton").text, "가방 1/5")
