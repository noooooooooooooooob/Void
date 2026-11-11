extends GutTest
# 전투 격자판 (편마다 5×5): 전투 크기만큼 맞닿는 쪽 열·가운데 행의 칸만 켠다.

const BOARD := "res://Scenes/ui/battle_screen/battle_board.tscn"
const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY

func _board(side: int) -> BattleBoard:
	var b: BattleBoard = load(BOARD).instantiate()
	b.side = side
	add_child_autofree(b)
	return b

func test_scene_has_5x5_cells_named_by_position():
	var b := _board(A)
	for col in 5:
		for row in 5:
			assert_true(b.get_node_or_null(BattleBoard.cell_name(col, row)) is GridCell, "%d,%d" % [col, row])

func test_cells_have_no_minimum_and_start_at_120_in_place():
	var b := _board(A)
	for col in 5:
		for row in 5:
			var c: GridCell = b.get_node(BattleBoard.cell_name(col, row))
			assert_eq(c.custom_minimum_size, Vector2.ZERO, "min %d,%d" % [col, row])
			assert_almost_eq(c.size, Vector2(120, 120), Vector2(0.01, 0.01), "size %d,%d" % [col, row])
			assert_almost_eq(c.position, Vector2(col * 130, row * 130), Vector2(0.01, 0.01), "pos %d,%d" % [col, row])

var TRAP := PackedVector2Array([Vector2(200, 0), Vector2(450, 0), Vector2(650, 650), Vector2(0, 650)])
var MINE := PackedVector2Array([Vector2(10, 10), Vector2(50, 10), Vector2(50, 70), Vector2(10, 70)])

func test_board_corners_reshape_cells():
	var b := _board(A)
	b.corners = TRAP
	var far: GridCell = b.get_node(BattleBoard.cell_name(2, 0))
	var near: GridCell = b.get_node(BattleBoard.cell_name(2, 4))
	assert_lt(far.size.y, near.size.y)

func test_custom_corners_win_over_auto():
	var b := _board(A)
	var c: GridCell = b.get_node(BattleBoard.cell_name(1, 1))
	c.custom_corners = MINE
	assert_eq(c.position, Vector2(10, 10))
	assert_eq(c.size, Vector2(40, 60))
	b.corners = TRAP
	assert_eq(c.position, Vector2(10, 10))

func test_wrong_point_count_is_auto():
	var b := _board(A)
	var c: GridCell = b.get_node(BattleBoard.cell_name(1, 1))
	c.custom_corners = PackedVector2Array([Vector2(1, 1), Vector2(2, 2), Vector2(3, 1)])
	assert_almost_eq(c.position, Vector2(130, 130), Vector2(0.01, 0.01))

func test_layout_twice_keeps_shape():
	var b := _board(A)
	var c: GridCell = b.get_node(BattleBoard.cell_name(1, 1))
	c.custom_corners = MINE
	b.layout_cells()
	b.layout_cells()
	assert_eq(c.size, Vector2(40, 60))

func test_wrong_board_corner_count_keeps_layout():
	var b := _board(A)
	var c: GridCell = b.get_node(BattleBoard.cell_name(1, 1))
	var before := c.position
	b.corners = PackedVector2Array([Vector2(0, 0)])
	assert_eq(c.position, before)

func test_ally_front_column_is_on_the_right():
	var b := _board(A)
	# 아군 3열: 전투 열 2(맨 앞) → 판 오른쪽 끝(4), 열 0(뒤) → 판 열 2
	assert_eq(b.board_position(Vector2i(2, 0), 3, 5), Vector2i(4, 0))
	assert_eq(b.board_position(Vector2i(0, 0), 3, 5), Vector2i(2, 0))

func test_enemy_front_column_is_on_the_left():
	var b := _board(E)
	assert_eq(b.board_position(Vector2i(3, 0), 4, 5), Vector2i(0, 0))
	assert_eq(b.board_position(Vector2i(0, 0), 4, 5), Vector2i(3, 0))

func test_rows_are_kept_from_the_middle():
	var b := _board(A)
	# 3행 → 판 1~3행, 5행 → 0~4행
	assert_eq(b.board_position(Vector2i(0, 0), 5, 3).y, 1)
	assert_eq(b.board_position(Vector2i(0, 2), 5, 3).y, 3)
	assert_eq(b.board_position(Vector2i(0, 0), 5, 5).y, 0)

func test_use_cells_shows_only_needed_cells():
	var b := _board(A)
	var used := b.use_cells(3, 3)
	assert_eq(used.size(), 9)
	var visible := 0
	for col in 5:
		for row in 5:
			if b.get_node(BattleBoard.cell_name(col, row)).visible:
				visible += 1
	assert_eq(visible, 9)
	assert_same(used[Vector2i(2, 1)], b.get_node(BattleBoard.cell_name(4, 2)))

func test_use_cells_again_with_smaller_size_hides_the_rest():
	var b := _board(A)
	b.use_cells(5, 5)
	b.use_cells(2, 1)
	assert_false(b.get_node(BattleBoard.cell_name(0, 0)).visible)
	assert_true(b.get_node(BattleBoard.cell_name(4, 2)).visible)

func test_too_big_battle_is_not_supported():
	var b := _board(A)
	assert_true(b.supports(5, 5))
	assert_false(b.supports(6, 3))
	assert_false(b.supports(3, 6))
