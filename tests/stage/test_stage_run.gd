extends GutTest
# 의뢰 한 판의 상태: 파티 체력 유지, HP 0 제외, 어떤 방을 보여줄지.

const K := StageNode.Kind
const StageRunScript := preload("res://Scripts/stage/stage_run.gd")

func _run() -> Node:
	var r: Node = StageRunScript.new()
	autofree(r)
	r.start_run(3)
	return r

func _node_of(r: Node, kind: StageNode.Kind) -> StageNode:
	for n in r.progress.nodes:
		if n.kind == kind:
			return n
	return null

func test_not_active_until_started():
	var r: Node = StageRunScript.new()
	autofree(r)
	assert_false(r.is_active())
	assert_false(r.in_battle())

func test_start_run_makes_full_hp_ally_party():
	var r := _run()
	assert_true(r.is_active())
	assert_gt(r.party.size(), 0)
	for u in r.party:
		assert_eq(u.side, BattleTypes.Side.ALLY)
		assert_eq(u.hp, u.get_stat(BattleTypes.Stat.HP))

func test_living_party_excludes_zero_hp():
	var r := _run()
	var fallen: BattleUnit = r.party[0]
	fallen.hp = 0
	assert_false(fallen in r.living_party())
	assert_eq(r.living_party().size(), r.party.size() - 1)

func test_in_battle_only_while_entering_battle_node():
	var r := _run()
	assert_false(r.in_battle())
	r.progress.entering = _node_of(r, K.BATTLE)
	assert_true(r.in_battle())
	r.progress.entering = _node_of(r, K.EVENT)
	assert_false(r.in_battle())
	r.progress.entering = _node_of(r, K.BOSS)
	assert_true(r.in_battle())

func test_room_follows_entering_node():
	var r := _run()
	r.progress.entering = _node_of(r, K.EVENT)
	assert_eq(r.room(), r.Room.EVENT)
	r.progress.entering = _node_of(r, K.SHOP)
	assert_eq(r.room(), r.Room.SHOP)

func test_room_is_clear_after_boss():
	var r := _run()
	r.progress.current = _node_of(r, K.BOSS)
	assert_eq(r.room(), r.Room.CLEAR)

func test_end_run_clears_state_and_new_run_heals():
	var r := _run()
	r.party[0].hp = 1
	r.end_run()
	assert_false(r.is_active())
	assert_eq(r.party.size(), 0)
	r.start_run(3)
	assert_eq(r.party[0].hp, r.party[0].get_stat(BattleTypes.Stat.HP))

# --- 가방과 아이템 드랍 ---

var _tmp_dir := ""

func after_each():
	if _tmp_dir != "":
		for f in DirAccess.get_files_at(_tmp_dir):
			DirAccess.remove_absolute(_tmp_dir.path_join(f))
		DirAccess.remove_absolute(_tmp_dir)
		_tmp_dir = ""

func test_run_starts_with_empty_bag_and_end_clears_it():
	var r := _run()
	assert_eq(r.inventory.items.size(), 0)
	r.inventory.add(ConsumableData.new())
	r.end_run()
	assert_eq(r.inventory.items.size(), 0)

func test_new_run_gets_a_new_empty_bag():
	var r := _run()
	r.inventory.add(ConsumableData.new())
	r.start_run(4)
	assert_eq(r.inventory.items.size(), 0)

func test_drop_never_at_zero_always_at_one():
	var r := _run()
	var pool: Array[ConsumableData] = [ConsumableData.new()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 50:
		assert_null(r.roll_item_drop(0.0, pool, rng))
		assert_same(r.roll_item_drop(1.0, pool, rng), pool[0])

func test_drop_from_empty_pool_is_null():
	var r := _run()
	var none: Array[ConsumableData] = []
	assert_null(r.roll_item_drop(1.0, none, RandomNumberGenerator.new()))

func test_item_pool_reads_folder_and_missing_folder_is_empty():
	var r := _run()
	_tmp_dir = "user://test_items_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_tmp_dir)
	for n in ["a", "b"]:
		var item := ConsumableData.new()
		item.display_name = n
		ResourceSaver.save(item, _tmp_dir.path_join(n + ".tres"))
	ResourceSaver.save(StatusData.new(), _tmp_dir.path_join("status.tres"))
	assert_eq(r.item_pool(_tmp_dir).size(), 2)
	assert_eq(r.item_pool("user://없는_폴더").size(), 0)

func test_is_boss_battle_only_on_boss_node():
	var r := _run()
	assert_false(r.is_boss_battle())
	r.progress.enter()
	assert_false(r.is_boss_battle())
	r.progress.entering = _node_of(r, K.BOSS)
	assert_true(r.is_boss_battle())
