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

func test_room_has_no_shop_kind():
	# 상점은 ShopScreen 이 맡아서 방 화면에는 오지 않는다 (2026-11-17)
	assert_false(StageRun.Room.has("SHOP"))

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

# --- 공허 조각 / 보스 전투 데이터 ---

func test_wallet_resets_on_new_run():
	var r := _run()
	r.wallet.add(40)
	r.end_run()
	assert_eq(r.wallet.shards, 0)
	r.start_run(2)
	assert_eq(r.wallet.shards, 0)

func test_boss_node_uses_boss_battle():
	var r := _run()
	r.progress.entering = _node_of(r, K.BOSS)
	assert_eq(r.battle_data(), r.BOSS_BATTLE)
	r.progress.entering = _node_of(r, K.BATTLE)
	assert_eq(r.battle_data(), r.DEFAULT_BATTLE)

func test_shard_rewards_default_and_boss():
	assert_eq(StageRunScript.DEFAULT_BATTLE.shard_reward, 20)
	assert_eq(StageRunScript.BOSS_BATTLE.shard_reward, 50)

func test_scene_for_each_node_kind():
	var r := _run()
	assert_eq(r.scene_for(_node_of(r, K.BATTLE)), r.BATTLE_SCENE)
	assert_eq(r.scene_for(_node_of(r, K.BOSS)), r.BATTLE_SCENE)
	assert_eq(r.scene_for(_node_of(r, K.EVENT)), r.ROOM_SCENE)
	assert_eq(r.scene_for(_node_of(r, K.SHOP)), r.SHOP_SCENE)

func test_run_end_returns_to_office():
	# 의뢰가 끝나면(성공·실패) 시작 화면이 아니라 사무소로 (2026-11-21)
	assert_eq(StageRun.OFFICE_SCENE, "res://Scenes/ui/office_screen/office_screen.tscn")
	assert_true(ResourceLoader.exists(StageRun.OFFICE_SCENE), "사무소 씬이 있어야 함")
