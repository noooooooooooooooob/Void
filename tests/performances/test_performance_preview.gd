extends GutTest
# 연출 미리보기 씬: 연출 있는 카드를 실제 전투 화면에서 바로 써서 반복 재생한다.

const SCENE := "res://Scenes/performances/performance_preview.tscn"
const STONE_FIST := "res://cards/data/브람/돌주먹.tres"

func _preview(card_path := STONE_FIST) -> PerformancePreview:
	var p: PerformancePreview = load(SCENE).instantiate()
	p.card = load(card_path) if card_path != "" else null
	p.autoplay = false
	add_child_autofree(p)
	return p

func after_each():
	Engine.time_scale = 1.0

func test_lists_only_cards_with_performance():
	var cs := PerformancePreview.performance_cards("res://cards/data/")
	assert_true(cs.any(func(c): return c.name_ko == "돌주먹"))
	assert_true(cs.all(func(c): return c.performance != null))

func test_card_list_filled():
	var p := _preview()
	var list: OptionButton = p.get_node("%CardList")
	assert_gt(list.item_count, 0)
	assert_eq(list.get_item_text(list.selected), "돌주먹")

func test_play_once_runs_performance_and_finishes():
	var p := _preview()
	await wait_process_frames(2)
	watch_signals(p)
	p.play_once()
	var q: PerformanceQueue = p.get_node("BattleScreen").get_node("%PerformanceQueue")
	assert_true(q.is_busy())
	await wait_for_signal(p.preview_finished, 5.0)
	assert_signal_emitted(p, "preview_finished")

func test_actor_is_card_owner():
	var p := _preview()
	assert_eq(p.actor_unit().display_name, "브람 웰번")

func test_source_unit_data_untouched():
	var bram: UnitData = load("res://entities/units/bram_welburn.tres")
	var before := [bram.deck.size(), bram.speed_max, bram.max_sp]
	var p := _preview()
	await wait_process_frames(2)
	p.play_once()
	assert_eq([bram.deck.size(), bram.speed_max, bram.max_sp], before)

func test_loop_replays():
	var p := _preview()
	p.get_node("%LoopCheck").button_pressed = true
	await wait_process_frames(2)
	watch_signals(p)
	p.play_once()
	await wait_for_signal(p.preview_finished, 5.0)
	await wait_process_frames(3)
	assert_true(p.get_node("BattleScreen").get_node("%PerformanceQueue").is_busy())

func test_set_speed_and_restore_on_exit():
	var p: PerformancePreview = load(SCENE).instantiate()
	p.autoplay = false
	add_child(p)
	p.set_speed(0.25)
	assert_eq(Engine.time_scale, 0.25)
	p.free()
	assert_eq(Engine.time_scale, 1.0)

func test_actor_lands_on_target_row_even_right_after_start():
	# 씬이 뜨자마자 재생해도(격자 배치 전) 대상 그림 자리로 가야 한다
	var p := _preview()
	p.play_once()
	await wait_seconds(0.25)
	var s: BattleScreen = p.get_node("BattleScreen")
	var perf: CardPerformance = s.get_node("%PerformanceLayer").get_child(0)
	var foe: BattleUnit = null
	for u in s.session.battle.units:
		if u.data.display_name == "금 간 수호 석상":  # 시험 전투의 첫 적 (2026-11-25)
			foe = u
	assert_almost_eq(perf.get_node("%Actor").global_position.y, s._tokens[foe].sprite().global_position.y, 10.0)

func test_scene_nodes_have_names():
	var p: Node = load(SCENE).instantiate()
	var bad := []
	for n in p.find_children("*", "", true, false):
		if n.owner == p and String(n.name).begins_with("@"):
			bad.append(n.name)
	p.free()
	assert_eq(bad, [])
