extends GutTest
# 전투 화면 부품 씬: 격자 칸, 유닛 박스, 행동 순서 초상화, 상태 줄, 떠오르는 숫자.

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY

func _scene(path: String) -> Node:
	return add_child_autofree(load(path).instantiate())

func _unit(side := E, hp := 45) -> BattleUnit:
	var u := Fixture.unit(side, Vector2i(3, 0), {"max_hp": hp})
	u.data.display_name = "시험용 적 A"
	return u


func test_grid_cell_click_emits_side_and_cell():
	var c: GridCell = _scene("res://Scenes/ui/battle_screen/grid_cell.tscn")
	c.setup(E, Vector2i(2, 1))
	watch_signals(c)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	c._gui_input(ev)
	assert_signal_emitted_with_parameters(c, "pressed", [E, Vector2i(2, 1)])

func test_grid_cell_marks():
	var c: GridCell = _scene("res://Scenes/ui/battle_screen/grid_cell.tscn")
	c.set_mark(GridCell.Mark.NONE)
	var none := c.mark_color()
	c.set_mark(GridCell.Mark.MOVE)
	assert_ne(c.mark_color(), none)
	c.set_mark(GridCell.Mark.TARGET)
	assert_ne(c.mark_color(), none)

func test_unit_token_shows_hp_block_and_dims_when_dead():
	var t: UnitToken = _scene("res://Scenes/ui/battle_screen/unit_token.tscn")
	var u := _unit()
	t.set_unit(u)
	assert_eq(t.get_node("%Hp").text, "45/45")
	assert_eq(t.get_node("%Name").text, "시험용 적 A")
	u.block = 6
	t.refresh()
	assert_true(t.get_node("%Block").visible)
	assert_eq(t.get_node("%Block").text, "6")
	u.alive = false
	t.refresh()
	assert_lt(t.modulate.a, 1.0)

func test_unit_token_click_emits_unit():
	var t: UnitToken = _scene("res://Scenes/ui/battle_screen/unit_token.tscn")
	var u := _unit()
	t.set_unit(u)
	watch_signals(t)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	t._gui_input(ev)
	assert_signal_emitted_with_parameters(t, "pressed", [u])

func test_turn_portrait_current_and_speed():
	var p: TurnPortrait = _scene("res://Scenes/ui/battle_screen/turn_portrait.tscn")
	p.set_entry(_unit(), 7, true)
	assert_eq(p.get_node("%Speed").text, "7")
	assert_true(p.is_current)
	p.set_entry(_unit(A), 3, false)
	assert_false(p.is_current)

func test_status_row_shows_hp_and_statuses():
	var r: UnitStatusRow = _scene("res://Scenes/ui/battle_screen/unit_status_row.tscn")
	var u := _unit()
	var st := Fixture.status("bleed")
	st.display_name = "출혈"
	u.add_status(st, 3, u)
	r.set_unit(u)
	assert_eq(r.get_node("%Hp").text, "45/45")
	assert_string_contains(r.get_node("%Statuses").text, "출혈 3")

func test_status_row_hides_empty_passive():
	var r: UnitStatusRow = _scene("res://Scenes/ui/battle_screen/unit_status_row.tscn")
	var u := _unit()
	var st := Fixture.status("blood_drop")
	st.display_name = "핏방울"
	st.tag = BattleTypes.StatusTag.PASSIVE
	u.add_status(st, 0, u)
	r.set_unit(u)
	assert_false(r.get_node("%Statuses").text.contains("핏방울"))

func test_float_number_frees_itself():
	var f: FloatNumber = load("res://Scenes/ui/battle_screen/float_number.tscn").instantiate()
	add_child(f)
	f.duration = 0.05
	f.pop("-9", Color.RED)
	assert_eq(f.text, "-9")
	await wait_seconds(0.2)
	assert_false(is_instance_valid(f))
