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


const CELL := "res://Scenes/ui/battle_screen/grid_cell.tscn"
var DIAMOND := PackedVector2Array([Vector2(50, 0), Vector2(100, 50), Vector2(50, 100), Vector2(0, 50)])

func test_quad_sets_bounds_and_local_points():
	var c: GridCell = _scene(CELL)
	c.custom_minimum_size = Vector2.ZERO
	c.apply_quad(PackedVector2Array([Vector2(60, 10), Vector2(110, 60), Vector2(60, 110), Vector2(10, 60)]))
	assert_eq(c.position, Vector2(10, 10))
	assert_eq(c.size, Vector2(100, 100))
	assert_eq(c.quad, DIAMOND)

func test_click_only_inside_quad():
	var c: GridCell = _scene(CELL)
	c.custom_minimum_size = Vector2.ZERO
	c.apply_quad(DIAMOND)
	assert_true(c._has_point(Vector2(50, 50)))
	assert_false(c._has_point(Vector2(3, 3)))

func test_no_quad_is_full_rect():
	var c: GridCell = _scene(CELL)
	assert_true(c._has_point(Vector2(3, 3)))
	assert_eq(c.center(), Vector2(60, 60))

func test_center_is_corner_average():
	var c: GridCell = _scene(CELL)
	c.custom_minimum_size = Vector2.ZERO
	c.apply_quad(PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(100, 60), Vector2(0, 60)]))
	assert_eq(c.center(), Vector2(35, 30))

func test_twisted_quad_cannot_fill():
	var c: GridCell = _scene(CELL)
	c.custom_minimum_size = Vector2.ZERO
	c.apply_quad(PackedVector2Array([Vector2(0, 0), Vector2(100, 100), Vector2(100, 0), Vector2(0, 100)]))
	assert_false(c.can_fill())

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

func test_float_number_settles_at_given_scale():
	var f: FloatNumber = load("res://Scenes/ui/battle_screen/float_number.tscn").instantiate()
	add_child_autofree(f)
	f.pop("-30", Color.RED, 1.5)
	assert_gt(f.scale.x, 1.5)  # 처음엔 크게 튀어나옴
	await wait_seconds(0.3)
	assert_almost_eq(f.scale.x, 1.5, 0.01)

func test_float_number_centers_on_point():
	var f: FloatNumber = load("res://Scenes/ui/battle_screen/float_number.tscn").instantiate()
	add_child_autofree(f)
	f.start_jitter = 0.0
	f.global_position = Vector2(200, 100)
	f.pop("123", Color.RED)
	# position = 크기 변화(튀어나옴) 전 상자의 왼쪽 위. 부모가 원점이라 화면 좌표와 같다
	assert_almost_eq(f.position.x + f.size.x * 0.5, 200.0, 0.5)

func test_float_number_paths_vary():
	var ends := []
	for seed in [1, 2]:
		var f: FloatNumber = load("res://Scenes/ui/battle_screen/float_number.tscn").instantiate()
		add_child_autofree(f)
		f.duration = 2.0
		f.rng.seed = seed
		f.position = Vector2(200, 100)
		f.pop("5", Color.RED)
		ends.append(f)
	await wait_seconds(0.4)
	assert_ne(ends[0].position, ends[1].position)


func test_unit_token_card_without_animation_stays_idle():
	# 강화본이 아닌 카드(파일 자체)는 카드 폴더를 뒤지지 않고 그냥 넘어간다
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", PlaceholderTexture2D.new())
	var u := _unit(A)
	u.data.battle_frames = frames
	var t: UnitToken = _scene("res://Scenes/ui/battle_screen/unit_token.tscn")
	t.set_unit(u)
	t.play_card_animation(CardData.new())
	assert_eq(t.sprite().animation, &"idle")
	assert_false(UnitToken.is_embedded_upgrade(CardData.new()))
	assert_true(UnitToken.is_embedded_upgrade(load("res://cards/data/브람/돌주먹.tres").upgrades[0]))


func test_unit_token_plays_upgraded_card_animation_from_base_outside_deck():
	# 상점에서 산 뒤 강화한 카드: 원래 카드가 기본 덱에 없어도 원래 카드의 animation 을 쓴다
	var base: CardData = load("res://cards/data/브람/돌주먹.tres")
	var up: CardData = base.upgrades[0]
	assert_eq(up.animation, &"", "강화본은 animation 칸이 비어 있어야 이 테스트가 의미 있다")
	var frames := SpriteFrames.new()
	frames.add_animation(base.animation)
	frames.add_frame(base.animation, PlaceholderTexture2D.new())
	frames.set_animation_loop(base.animation, false)
	var u := _unit(A)
	u.data.battle_frames = frames
	var t: UnitToken = _scene("res://Scenes/ui/battle_screen/unit_token.tscn")
	t.set_unit(u)
	t.play_card_animation(up)
	assert_eq(t.sprite().animation, base.animation)
