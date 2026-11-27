extends GutTest

const FRAMES := "res://entities/units/hongyeon_frames.tres"

func test_idle_frames_use_lit_canvas_texture():
	var frames: SpriteFrames = load(FRAMES)
	assert_eq(frames.get_frame_count(&"idle"), 8)
	for i in 8:
		var tex := frames.get_frame_texture(&"idle", i) as AtlasTexture
		assert_not_null(tex, "프레임 %d 은 AtlasTexture" % i)
		if tex == null:
			continue
		assert_eq(tex.region, Rect2(i * 128, 0, 128, 128))
		var canvas := tex.atlas as CanvasTexture
		assert_not_null(canvas, "프레임 %d 의 atlas 는 CanvasTexture" % i)
		if canvas == null:
			continue
		assert_not_null(canvas.diffuse_texture)
		assert_not_null(canvas.normal_texture)
		assert_not_null(canvas.specular_texture)
		assert_true(canvas.diffuse_texture.resource_path.ends_with("hongyeon_idle.png"))
		assert_true(canvas.normal_texture.resource_path.ends_with("hongyeon_idle_normal.png"))
		assert_true(canvas.specular_texture.resource_path.ends_with("hongyeon_idle_specular.png"))
