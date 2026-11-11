extends GutTest
# 격자판 모양 계산: 네 모서리 → 원근 칸 꼭짓점, 핸들 찾기.

var SQ := PackedVector2Array([Vector2(0, 0), Vector2(650, 0), Vector2(650, 650), Vector2(0, 650)])
var TRAP := PackedVector2Array([Vector2(200, 0), Vector2(450, 0), Vector2(650, 300), Vector2(0, 300)])
const EPS := Vector2(0.01, 0.01)

func test_corners_map_exactly():
	assert_almost_eq(BoardShape.point_at(TRAP, Vector2(0, 0)), TRAP[0], EPS)
	assert_almost_eq(BoardShape.point_at(TRAP, Vector2(1, 0)), TRAP[1], EPS)
	assert_almost_eq(BoardShape.point_at(TRAP, Vector2(1, 1)), TRAP[2], EPS)
	assert_almost_eq(BoardShape.point_at(TRAP, Vector2(0, 1)), TRAP[3], EPS)

func test_square_is_linear():
	assert_almost_eq(BoardShape.point_at(SQ, Vector2(0.5, 0.5)), Vector2(325, 325), EPS)

func test_far_rows_are_shorter():
	var far := BoardShape.cell_quad(TRAP, 2, 0, 0.0)
	var near := BoardShape.cell_quad(TRAP, 2, 4, 0.0)
	assert_lt(far[3].y - far[0].y, near[3].y - near[0].y)

func test_cell_quad_gap_is_centered():
	var q := BoardShape.cell_quad(SQ, 0, 0, 10.0 / 130.0)
	assert_almost_eq(q[0], Vector2(5, 5), EPS)
	assert_almost_eq(q[2], Vector2(125, 125), EPS)

func test_collinear_corners_do_not_crash():
	var line := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)])
	var p := BoardShape.point_at(line, Vector2(0.5, 0.5))
	assert_true(is_finite(p.x) and is_finite(p.y))

func test_nearest_handle():
	assert_eq(BoardShape.nearest_handle(SQ, Vector2(648, 3), 10.0), 1)
	assert_eq(BoardShape.nearest_handle(SQ, Vector2(300, 300), 10.0), -1)
