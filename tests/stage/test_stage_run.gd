extends GutTest

var site: VoidSiteData

func before_each():
	StageRun.navigate = false
	StageRun.cleared_sites.clear()
	site = load("res://voids/crystal_flame_cave.tres")

func after_each():
	StageRun.end_run()
	StageRun.cleared_sites.clear()
	StageRun.navigate = true

func _walk_to_boss() -> void:
	while not StageRun.progress.is_finished():
		StageRun.progress.enter()
		StageRun.progress.complete()

func test_start_run_remembers_site():
	StageRun.start_run(site, 3)
	assert_true(StageRun.is_active())
	assert_eq(StageRun.site, site)

func test_party_comes_from_roster():
	StageRun.start_run(site, 3)
	var roster: RosterData = load("res://entities/roster.tres")
	assert_gt(StageRun.party.size(), 0)
	var unit: UnitData = roster.playable_units()[0]
	assert_eq(StageRun.party[0].data, unit)
	assert_eq(StageRun.party[0].side, BattleTypes.Side.ALLY)
	assert_eq(StageRun.party[0].hp, unit.max_hp)

func test_battle_background_is_site_background():
	StageRun.start_run(site, 3)
	assert_eq(StageRun.battle_background(), site.background)

func test_battle_background_falls_back_without_site():
	StageRun.start_run(null, 3)
	assert_eq(StageRun.battle_background(), StageRun.battle_data().background)

func test_complete_middle_node_goes_to_stage_map():
	StageRun.start_run(site, 3)
	StageRun.progress.enter()
	StageRun.complete_node()
	assert_eq(StageRun.last_screen, Router.Screen.STAGE_MAP)

func test_boss_clear_then_finish_marks_site_and_goes_to_void_map():
	StageRun.start_run(site, 3)
	_walk_to_boss()
	assert_eq(StageRun.room(), StageRun.Room.CLEAR)
	StageRun.finish_run()
	assert_true(StageRun.is_cleared(site.id))
	assert_false(StageRun.is_active())
	assert_eq(StageRun.last_screen, Router.Screen.VOID_MAP)

func test_fail_goes_to_void_map_without_clear():
	StageRun.start_run(site, 3)
	StageRun.fail_run()
	assert_false(StageRun.is_cleared(site.id))
	assert_false(StageRun.is_active())
	assert_eq(StageRun.last_screen, Router.Screen.VOID_MAP)
