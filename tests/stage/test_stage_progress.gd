extends GutTest

const K := StageNode.Kind

func _progress(seed_value := 3) -> StageProgress:
	return StageProgress.new(StageGenerator.new(seed_value).generate())

func test_starts_at_start_node():
	var p := _progress()
	assert_eq(p.current.kind, K.START)
	assert_true(p.current.cleared)
	assert_null(p.entering)
	assert_false(p.is_finished())

func test_choices_are_next_nodes_sorted_by_row():
	var p := _progress()
	var rows := p.choices().map(func(n): return n.row)
	assert_eq(rows, [0, 1, 2])

func test_first_selection_is_middle_row():
	var p := _progress()
	assert_eq(p.selected().row, 1)

func test_move_cursor_clamps():
	var p := _progress()
	p.move_cursor(-1)
	assert_eq(p.selected().row, 0)
	p.move_cursor(-1)
	assert_eq(p.selected().row, 0)
	p.move_cursor(5)
	assert_eq(p.selected().row, 2)

func test_select_only_reachable_nodes():
	var p := _progress()
	var boss: StageNode = p.nodes[-1]
	assert_false(p.select(boss))
	var top: StageNode = p.choices()[0]
	assert_true(p.select(top))
	assert_eq(p.selected(), top)

func test_enter_then_complete_moves_forward():
	var p := _progress()
	var target := p.selected()
	assert_eq(p.enter(), target)
	assert_eq(p.entering, target)
	p.complete()
	assert_eq(p.current, target)
	assert_true(target.cleared)
	assert_null(p.entering)
	assert_eq(p.choices(), StageProgress.sorted_by_row(target.next))

func test_cursor_after_complete_prefers_same_row():
	for s in range(1, 51):
		var p := _progress(s)
		p.enter()
		p.complete()
		var nearest := 99
		for n in p.choices():
			nearest = mini(nearest, absi(n.row - p.current.row))
		assert_eq(absi(p.selected().row - p.current.row), nearest, "seed %d" % s)

func test_walk_to_boss_finishes():
	var p := _progress()
	var kinds := []
	while not p.is_finished():
		kinds.append(p.enter().kind)
		p.complete()
	assert_eq(kinds.size(), 5)
	assert_eq(kinds[0], K.BATTLE)
	assert_eq(kinds[3], K.SHOP)
	assert_eq(kinds[4], K.BOSS)
	assert_true(p.choices().is_empty())
	assert_null(p.selected())
	assert_null(p.enter())

func test_complete_without_enter_does_nothing():
	var p := _progress()
	var start := p.current
	p.complete()
	assert_eq(p.current, start)
