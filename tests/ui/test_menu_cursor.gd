extends GutTest
# 메뉴 커서: 위/아래로 움직이고 끝에서 반대쪽으로 돌아가며, 비활성 줄은 건너뛴다.

func test_first_skips_disabled():
	var c := MenuCursor.new([false, false, true, true])
	assert_eq(c.first(), 2)

func test_first_all_disabled_is_minus_one():
	var c := MenuCursor.new([false, false])
	assert_eq(c.first(), -1)

func test_next_moves_down():
	var c := MenuCursor.new([true, true, true])
	assert_eq(c.step(0, 1), 1)

func test_next_wraps_to_top():
	var c := MenuCursor.new([true, true, true])
	assert_eq(c.step(2, 1), 0)

func test_prev_wraps_to_bottom():
	var c := MenuCursor.new([true, true, true])
	assert_eq(c.step(0, -1), 2)

func test_step_skips_disabled():
	var c := MenuCursor.new([true, false, false, true])
	assert_eq(c.step(0, 1), 3)
	assert_eq(c.step(3, 1), 0)
	assert_eq(c.step(0, -1), 3)

func test_step_from_minus_one_goes_to_first_enabled():
	var c := MenuCursor.new([false, true, true])
	assert_eq(c.step(-1, 1), 1)

func test_step_single_enabled_stays():
	var c := MenuCursor.new([false, true, false])
	assert_eq(c.step(1, 1), 1)

func test_step_all_disabled_is_minus_one():
	var c := MenuCursor.new([false, false])
	assert_eq(c.step(0, 1), -1)
