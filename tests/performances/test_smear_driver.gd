extends GutTest

const DT := 1.0 / 60.0


func _tex(w := 100, h := 100) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(w, h, false, Image.FORMAT_RGBA8))


func _sprite(tex: Texture2D = null) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.scale = Vector2(0.2, 0.2)
	var f := SpriteFrames.new()
	f.add_frame(&"default", tex if tex else _tex())
	s.sprite_frames = f
	add_child_autofree(s)
	return s


func _driver(s: AnimatedSprite2D) -> SmearDriver:
	var d := SmearDriver.new()
	s.add_child(d)
	d.set_process(false)  # 테스트가 step 을 직접 부른다
	d.step(DT)  # 첫 프레임 (무시됨)
	return d


func _param(s: CanvasItem, name: StringName) -> Variant:
	return (s.material as ShaderMaterial).get_shader_parameter(name)


func test_small_move_no_trail():
	var s := _sprite()
	var d := _driver(s)
	s.position.x += 19
	d.step(DT)
	assert_eq(d.trail(), Vector2.ZERO)


func test_trail_is_move_times_ratio():
	var s := _sprite()
	var d := _driver(s)
	s.position.x += 300
	d.step(DT)
	assert_almost_eq(d.trail().x, -150.0, 0.01)
	assert_almost_eq(d.trail().y, 0.0, 0.01)
	assert_almost_eq((_param(s, &"smear") as Vector2).x, -750.0, 0.01)


func test_trail_capped():
	var s := _sprite()
	var d := _driver(s)
	s.position.x += 1000
	d.step(DT)
	assert_almost_eq(d.trail().length(), 400.0, 0.01)


func test_trail_gone_after_decay():
	var s := _sprite()
	var d := _driver(s)
	s.position.x += 300
	d.step(DT)
	d.step(0.13)
	assert_eq(d.trail(), Vector2.ZERO)


func test_first_frame_ignored():
	var s := _sprite()
	var d := SmearDriver.new()
	s.add_child(d)
	d.set_process(false)
	s.position.x += 500
	d.step(DT)
	assert_eq(d.trail(), Vector2.ZERO)


func test_flip_mirrors_trail():
	var s := _sprite()
	s.flip_h = true
	var d := _driver(s)
	s.position.x += 300
	d.step(DT)
	assert_gt((_param(s, &"smear") as Vector2).x, 0.0)


func test_keeps_existing_material():
	var s := _sprite()
	var mat := CanvasItemMaterial.new()
	s.material = mat
	var d := _driver(s)
	s.position.x += 300
	d.step(DT)
	assert_same(s.material, mat)


func test_atlas_frame_region_sent():
	var at := AtlasTexture.new()
	at.atlas = _tex(512, 128)
	at.region = Rect2(128, 0, 128, 128)
	var s := _sprite(at)
	_driver(s)
	var r: Vector4 = _param(s, &"region")
	assert_almost_eq(r.x, 0.25, 0.001)
	assert_almost_eq(r.y, 0.0, 0.001)
	assert_almost_eq(r.z, 0.25, 0.001)
	assert_almost_eq(r.w, 1.0, 0.001)


func test_plain_texture_region_is_whole():
	assert_eq(SmearDriver.frame_region(_tex()), Vector4(0, 0, 1, 1))
