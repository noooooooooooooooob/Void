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
