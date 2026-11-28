extends GutTest
# 바닥 그림자(GroundShadow): 대상 그림을 복사해 해 반대쪽 바닥으로 눕힌다 (설계 2026-11-28-ground-shadow-design.md)

const SHADOW := "res://Scenes/backgrounds/parts/ground_shadow.tscn"


func _tex(c: Color) -> ImageTexture:
	var img := Image.create(4, 8, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


func _frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.add_frame(&"default", _tex(Color.RED))
	f.add_frame(&"default", _tex(Color.BLUE))
	return f


## 대상 그림 + 자식 그림자. 그림자를 돌려준다
func _with_shadow(target: Node2D) -> GroundShadow:
	add_child_autofree(target)
	var s: GroundShadow = load(SHADOW).instantiate()
	target.add_child(s)
	return s


func test_basis_no_source():
	var t := GroundShadow.shadow_basis(Vector2(500, 800), null, 0.2, 0.5)
	assert_eq(t.x, Vector2(1, 0))
	assert_almost_eq(t.y, Vector2(0, -0.2), Vector2(0.0001, 0.0001))
	assert_eq(t.origin, Vector2.ZERO)


func test_basis_sun_behind_right():
	var t := GroundShadow.shadow_basis(Vector2(500, 800), Vector2(1500, 300), 1.0, 0.5)
	assert_almost_eq(t.y, Vector2(0.894, -0.224), Vector2(0.01, 0.01))
	# 그림 위쪽 점은 발밑의 왼쪽 앞(화면 아래)으로 간다
	var top := t * Vector2(0, -100)
	assert_lt(top.x, 0.0)
	assert_gt(top.y, 0.0)


func test_copies_animated_frame():
	var a := AnimatedSprite2D.new()
	a.sprite_frames = _frames()
	a.offset = Vector2(0, -200)
	a.flip_h = true
	var s := _with_shadow(a)
	a.frame = 1
	s.sync_from_target()
	assert_eq(s.texture, a.sprite_frames.get_frame_texture(&"default", 1))
	assert_eq(s.offset, Vector2(0, -200))
	assert_true(s.flip_h)


func test_copies_sprite2d():
	var p := Sprite2D.new()
	p.texture = _tex(Color.GREEN)
	p.flip_h = true
	p.centered = false
	var s := _with_shadow(p)
	s.sync_from_target()
	assert_eq(s.texture, p.texture)
	assert_true(s.flip_h)
	assert_false(s.centered)


func test_null_frames_no_error():
	var a := AnimatedSprite2D.new()
	var s := _with_shadow(a)
	s.sync_from_target()
	assert_null(s.texture)


func test_no_mood_defaults():
	var a := AnimatedSprite2D.new()
	a.sprite_frames = _frames()
	var s := _with_shadow(a)
	await wait_process_frames(2)
	assert_almost_eq(s.transform.y, Vector2(0, -GroundShadow.NO_MOOD_LENGTH), Vector2(0.0001, 0.0001))
	assert_eq(s.light_mask, 0)
	assert_true(s.show_behind_parent)
	assert_true(s.is_in_group("mood_shadow"))
