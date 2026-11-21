extends GutTest
# PerformanceSpace: 에디터의 Home→Target 직선 위 위치를 실제 칸 사이로 늘려 옮긴다.

const H := Vector2(0, 0)
const T := Vector2(100, 0)

func test_home_maps_to_real_home():
	assert_eq(PerformanceSpace.map_point(Vector2(0, 0), H, T, Vector2(0, 0), Vector2(300, 0)), Vector2(0, 0))

func test_target_maps_to_real_target():
	assert_eq(PerformanceSpace.map_point(Vector2(100, 0), H, T, Vector2(0, 0), Vector2(300, 0)), Vector2(300, 0))

func test_midway_stretches():
	assert_eq(PerformanceSpace.map_point(Vector2(50, 0), H, T, Vector2(0, 0), Vector2(300, 0)), Vector2(150, 0))

# 가까운 쪽 기준 (2026-11-21): Target 쪽 1/3 은 대상에서 같은 픽셀, Home 쪽 1/3 은 행위자에서 같은 픽셀
func test_near_target_keeps_pixel_gap_to_target():
	assert_almost_eq(PerformanceSpace.map_point(Vector2(80, 0), H, T, Vector2(0, 0), Vector2(300, 0)), Vector2(280, 0), Vector2(0.01, 0.01))

func test_near_home_keeps_pixel_gap_to_home():
	assert_almost_eq(PerformanceSpace.map_point(Vector2(20, 0), H, T, Vector2(10, 0), Vector2(300, 0)), Vector2(30, 0), Vector2(0.01, 0.01))

func test_middle_third_blends_continuously():
	# w=0.4 → 섞는 비율 (0.4-1/3)*3 = 0.2 → 40 + 0.2*200
	assert_almost_eq(PerformanceSpace.map_point(Vector2(40, 0), H, T, Vector2(0, 0), Vector2(300, 0)), Vector2(80, 0), Vector2(0.01, 0.01))

func test_near_target_gap_same_for_any_distance():
	var a := PerformanceSpace.map_point(Vector2(80, 0), H, T, Vector2(0, 0), Vector2(150, 0))
	var b := PerformanceSpace.map_point(Vector2(80, 0), H, T, Vector2(0, 0), Vector2(600, 0))
	assert_almost_eq(150.0 - a.x, 600.0 - b.x, 0.01)

func test_height_off_line_kept():
	assert_eq(PerformanceSpace.map_point(Vector2(50, -40), H, T, Vector2(0, 0), Vector2(300, 0)), Vector2(150, -40))

func test_beyond_target_follows_target():
	assert_eq(PerformanceSpace.map_point(Vector2(130, 0), H, T, Vector2(0, 0), Vector2(300, 0)), Vector2(330, 0))

func test_behind_home_follows_home():
	assert_eq(PerformanceSpace.map_point(Vector2(-20, 0), H, T, Vector2(10, 0), Vector2(300, 0)), Vector2(-10, 0))

func test_same_home_and_target_no_nan():
	assert_eq(PerformanceSpace.map_point(Vector2(5, 5), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2(50, 0)), Vector2(5, 5))

func test_root_scale_divides_by_actor_scale():
	assert_eq(PerformanceSpace.root_scale(Vector2(0.2, 0.2), Vector2(0.2, 0.2)), Vector2.ONE)

func test_root_scale_zero_actor_scale_counts_as_one():
	assert_eq(PerformanceSpace.root_scale(Vector2(0.2, 0.2), Vector2.ZERO), Vector2(0.2, 0.2))

func test_root_position_puts_home_on_sprite():
	assert_eq(PerformanceSpace.root_position(Vector2(100, 50), Vector2(10, 0), Vector2(2, 2)), Vector2(80, 50))
