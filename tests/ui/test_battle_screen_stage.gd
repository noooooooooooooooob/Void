extends GutTest
# 전투 화면의 의뢰 모드: 전투 노드로 들어오면 의뢰 파티를 쓰고 결과 버튼이 바뀐다.

const SCREEN := "res://Scenes/ui/battle_screen/battle_screen.tscn"

func after_each():
	StageRun.end_run()

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
