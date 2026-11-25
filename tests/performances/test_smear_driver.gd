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


func test_shader_has_region_uniform():
	var names := SmearDriver.SMEAR_SHADER.get_shader_uniform_list().map(func(u): return u.name)
	assert_has(names, "region")


func test_shader_compiles_when_drawn():
	# 셰이더 문법 오류는 그릴 때 엔진 에러로 나온다 — GUT 가 예상 밖 에러로 잡는다
	var s := _sprite()
	_driver(s)
	s.position.x += 300
	await wait_process_frames(3)
	assert_not_null(s.material)


func test_replaces_copied_smear_material():
	# 연출 화면 탭은 Actor 를 material 째 복제한다 — 스머지 material 이면 내 것으로 새로 만든다 (원본과 공유 안 함)
	var s := _sprite()
	var copied := ShaderMaterial.new()
	copied.shader = SmearDriver.SMEAR_SHADER
	s.material = copied
	_driver(s)
	assert_ne(s.material, copied)
	assert_eq((s.material as ShaderMaterial).shader, SmearDriver.SMEAR_SHADER)


# --- 리뷰 수정 (2026-11-25) ---

func test_flip_sent_to_shader():
	# 반전된 그림은 꼭짓점 넓히는 방향도 뒤집어야 한다 (엔진이 반전을 UV 로 처리)
	var s := _sprite()
	s.flip_h = true
	_driver(s)
	assert_eq(_param(s, &"flip"), Vector2(-1, 1))


func test_measured_in_screen_px_under_scaled_root():
	# 연출 루트가 10배(픽셀 그림 행위자)면 부모 좌표 30 = 화면 300px
	var root := Node2D.new()
	root.scale = Vector2(10, 10)
	add_child_autofree(root)
	var s := AnimatedSprite2D.new()
	s.scale = Vector2(0.2, 0.2)
	var f := SpriteFrames.new()
	f.add_frame(&"default", _tex())
	s.sprite_frames = f
	root.add_child(s)
	var d := _driver(s)
	s.position.x += 30
	d.step(DT)
	assert_almost_eq(d.trail().x, -150.0, 0.01)  # 화면 px
	assert_almost_eq((_param(s, &"smear") as Vector2).x, -75.0, 0.01)  # 그림 px = 150 / (0.2 × 10)
	assert_almost_eq(_param(s, &"pad") as float, 200.0, 0.01)  # 400 / 2


func test_same_trail_at_144hz_as_60hz():
	# 60fps 기준: 2400px/s 이동은 주사율과 상관없이 꼬리 20px (60fps 한 프레임 40px × 0.5)
	var s := _sprite()
	var d := _driver(s)
	var dt := 1.0 / 144.0
	for i in 3:
		s.position.x += 2400.0 * dt
		d.step(dt)
	assert_almost_eq(d.trail().length(), 20.0, 3.0)


func test_teleport_same_at_144hz():
	var s := _sprite()
	var d := _driver(s)
	var dt := 1.0 / 144.0
	s.position.x += 300
	d.step(dt)
	d.step(dt)
	d.step(dt)
	assert_almost_eq(d.trail().length(), 150.0, 25.0)


func test_low_fps_scaled_to_60():
	# 30fps 한 프레임에 80px = 60fps 기준 40px → 꼬리 20px
	var s := _sprite()
	var d := _driver(s)
	s.position.x += 80
	d.step(1.0 / 30.0)
	assert_almost_eq(d.trail().length(), 20.0, 0.01)


func test_region_follows_frame_change_without_step():
	# 연출 화면 탭은 처리 순서가 달라 step 전에 프레임이 바뀔 수 있다 — 바뀌는 즉시 맞춘다
	var atlas := _tex(256, 128)
	var a0 := AtlasTexture.new()
	a0.atlas = atlas
	a0.region = Rect2(0, 0, 128, 128)
	var a1 := AtlasTexture.new()
	a1.atlas = atlas
	a1.region = Rect2(128, 0, 128, 128)
	var s := _sprite(a0)
	s.sprite_frames.add_frame(&"default", a1)
	_driver(s)
	s.frame = 1
	var r: Vector4 = _param(s, &"region")
	assert_almost_eq(r.x, 0.5, 0.001)
