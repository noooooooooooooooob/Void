extends GutTest
# CameraMath: 연출 카메라의 위치·회전·줌을 월드를 움직일 변환으로 바꾼다.

const EPS := Vector2(0.001, 0.001)

func test_view_identity_when_camera_unchanged():
	var k := CameraMath.camera_xform(Vector2(100, 50), 0.0, Vector2.ONE)
	assert_true(CameraMath.view(k, k).is_equal_approx(Transform2D.IDENTITY))

func test_zoom_two_scales_world_about_camera_point():
	var k0 := CameraMath.camera_xform(Vector2(100, 50), 0.0, Vector2.ONE)
	var v := CameraMath.view(k0, CameraMath.camera_xform(Vector2(100, 50), 0.0, Vector2(2, 2)))
	assert_almost_eq(v.get_scale(), Vector2(2, 2), EPS)
	assert_almost_eq(v * Vector2(100, 50), Vector2(100, 50), EPS)

func test_pan_moves_world_opposite():
	var k0 := CameraMath.camera_xform(Vector2.ZERO, 0.0, Vector2.ONE)
	var v := CameraMath.view(k0, CameraMath.camera_xform(Vector2(40, 0), 0.0, Vector2.ONE))
	assert_almost_eq(v * Vector2(40, 0), Vector2.ZERO, EPS)

func test_world_xform_identity_when_camera_unchanged():
	var t := Transform2D(0.0, Vector2(100, 0))
	var k := CameraMath.camera_xform(Vector2(10, 5), 0.0, Vector2.ONE)
	assert_true(CameraMath.world_xform(t, k, k).is_equal_approx(Transform2D.IDENTITY))

func test_world_xform_zoom_keeps_camera_point():
	var t := Transform2D(0.0, Vector2(100, 0))
	var k0 := CameraMath.camera_xform(Vector2(10, 5), 0.0, Vector2.ONE)
	var w := CameraMath.world_xform(t, k0, CameraMath.camera_xform(Vector2(10, 5), 0.0, Vector2(2, 2)))
	assert_almost_eq(w.get_scale(), Vector2(2, 2), EPS)
	assert_almost_eq(w * (t * Vector2(10, 5)), t * Vector2(10, 5), EPS)
