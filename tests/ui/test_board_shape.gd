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

# --- 판 늘리기 (2026-11-25) ---

const TRAPEZOID := [Vector2(184, 333), Vector2(757, 333), Vector2(716, 674), Vector2(-86, 674)]

func _pts(a: Array) -> PackedVector2Array:
	return PackedVector2Array(a)

func test_stretch_by_one_keeps_corners():
	var out := BoardShape.stretch(_pts(TRAPEZOID), 1.0, 1.0)
	for i in 4:
		assert_almost_eq(out[i], TRAPEZOID[i], Vector2(0.001, 0.001))

func test_stretch_rows_on_square_doubles_height_around_center():
	var sq := _pts([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	var out := BoardShape.stretch(sq, 1.0, 2.0)
	assert_almost_eq(out[0], Vector2(0, -50), Vector2(0.001, 0.001))
	assert_almost_eq(out[2], Vector2(100, 150), Vector2(0.001, 0.001))

func test_stretch_keeps_center_and_side_lines():
	var c := _pts(TRAPEZOID)
	var out := BoardShape.stretch(c, 1.0, 1.6)
	# 판 가운데 점은 그대로
	assert_almost_eq(BoardShape.point_at(out, Vector2(0.5, 0.5)), BoardShape.point_at(c, Vector2(0.5, 0.5)), Vector2(0.01, 0.01))
	# 새 왼쪽 위 모서리는 원래 왼쪽 변의 연장선 위 (원근 유지)
	var d1: Vector2 = c[3] - c[0]
	var d2: Vector2 = out[0] - c[0]
	assert_almost_eq(d1.cross(d2), 0.0, 0.5)

func test_stretch_rows_makes_middle_rows_taller():
	var c := _pts(TRAPEZOID)
	var out := BoardShape.stretch(c, 1.0, 1.6)
	var before := BoardShape.cell_quad(c, 2, 2, 0.0)
	var after := BoardShape.cell_quad(out, 2, 2, 0.0)
	assert_gt(after[3].y - after[0].y, (before[3].y - before[0].y) * 1.4)

func test_stretch_then_inverse_returns():
	var c := _pts(TRAPEZOID)
	var back := BoardShape.stretch(BoardShape.stretch(c, 1.0, 1.5), 1.0, 1.0 / 1.5)
	for i in 4:
		assert_almost_eq(back[i], c[i], Vector2(0.01, 0.01))
