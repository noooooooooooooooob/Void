extends GutTest
# 스테이지 지도 화면: 연결선, 현재 위치·커서 표시, 키보드·클릭으로 다음 노드 고르기.

const SCENE := "res://Scenes/ui/stage_map/stage_map.tscn"

func before_each():
	StageRun.end_run()
	StageRun.start_run(3)

func after_each():
	StageRun.end_run()

func _map() -> StageMap:
	var m: StageMap = load(SCENE).instantiate()
	add_child_autofree(m)
	return m

func _view_of(m: StageMap, node: StageNode) -> StageNodeView:
	for v in m.views:
		if v.node == node:
			return v
	return null

func _action(name: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e

func test_makes_a_view_per_node():
	var m := _map()
	assert_eq(m.views.size(), StageRun.progress.nodes.size())

func test_draws_a_visible_line_per_link():
	var m := _map()
	var links := 0
	for n in StageRun.progress.nodes:
		links += n.next.size()
	var lines := m.get_node("%Links").get_children().filter(func(c): return c is Line2D and c.visible)
	assert_gt(links, 0)
	assert_eq(lines.size(), links)

func test_start_node_shows_here_mark():
	var m := _map()
	var v := _view_of(m, StageRun.progress.current)
	assert_eq(v.state, StageNodeView.State.CURRENT)
	assert_true(v.get_node("%HereMark").visible)

func test_only_selected_node_shows_ring():
	var m := _map()
	var selected := StageRun.progress.selected()
	for v in m.views:
		assert_eq(v.get_node("%Ring").visible, v.node == selected)

func test_map_down_moves_the_ring():
	var m := _map()
	StageRun.progress.cursor = 0
	m.refresh()
	var before := StageRun.progress.selected()
	m._unhandled_input(_action("map_down"))
	var after := StageRun.progress.selected()
	assert_ne(after, before)
	assert_false(_view_of(m, before).get_node("%Ring").visible)
	assert_true(_view_of(m, after).get_node("%Ring").visible)

func test_map_up_and_down_actions_exist():
	assert_true(InputMap.has_action("map_up"))
	assert_true(InputMap.has_action("map_down"))

func test_clicking_another_choice_only_moves_the_cursor():
	var m := _map()
	StageRun.progress.cursor = 0
	m.refresh()
	var other: StageNode = StageRun.progress.choices()[1]
	m._on_view_clicked(_view_of(m, other))
	assert_eq(StageRun.progress.selected(), other)
	assert_null(StageRun.progress.entering)

func test_clicking_a_locked_node_does_nothing():
	var m := _map()
	var before := StageRun.progress.selected()
	m._on_view_clicked(_view_of(m, StageRun.progress.nodes[-1]))
	assert_eq(StageRun.progress.selected(), before)
	assert_null(StageRun.progress.entering)

func test_coming_back_shows_progress():
	StageRun.progress.enter()
	StageRun.progress.complete()
	var m := _map()
	assert_eq(_view_of(m, StageRun.progress.nodes[0]).state, StageNodeView.State.CLEARED)
	assert_eq(_view_of(m, StageRun.progress.current).state, StageNodeView.State.CURRENT)
