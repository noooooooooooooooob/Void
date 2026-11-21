extends GutTest
# 카드 연출 씬 루트: 타임라인의 Call Method 키를 시그널로 바꾸고, 위치를 실제 칸 기준으로 맞추고, perform 이 끝나면 done.

var log: Array = []

# CardPerformance + Home·Target·Actor·AnimationPlayer 를 코드로 조립한다 (실제 연출 씬은 에디터에서 만든다).
# keys: [[시각, 함수 이름, 인자 배열], ...] — Call Method 트랙
# actor_x_keys: [[시각, x], ...] — Actor:position:x 값 트랙
# anim_keys: [[시각, 동작 이름], ...] — Actor:animation 값 트랙
# cam_zoom_keys: [[시각, Vector2], ...] — Camera(Camera2D) 를 넣고 Camera:zoom 값 트랙
# Home (0,0), Target (200,0) + 미리보기 그림 하나
static func build(keys: Array, length := 0.2, actor_x_keys: Array = [], anim_keys: Array = [], cam_zoom_keys: Array = []) -> CardPerformance:
	var p := CardPerformance.new()
	var home := Marker2D.new()
	home.name = "Home"
	p.add_child(home)
	home.owner = p
	var target := Marker2D.new()
	target.name = "Target"
	target.position = Vector2(200, 0)
	p.add_child(target)
	target.owner = p
	var preview := Sprite2D.new()
	target.add_child(preview)
	preview.owner = p
	var actor := AnimatedSprite2D.new()
	actor.name = "Actor"
	actor.unique_name_in_owner = true
	p.add_child(actor)
	actor.owner = p
	if not cam_zoom_keys.is_empty():
		var cam := Camera2D.new()
		cam.name = "Camera"
		cam.enabled = false
		cam.position = Vector2(100, 0)
		p.add_child(cam)
		cam.owner = p
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	ap.unique_name_in_owner = true
	p.add_child(ap)
	ap.owner = p
	if keys.is_empty() and length <= 0.0:
		return p
	var anim := Animation.new()
	anim.length = length
	var t := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(t, NodePath("."))
	for k in keys:
		anim.track_insert_key(t, k[0], {"method": k[1], "args": k[2]})
	if not actor_x_keys.is_empty():
		var tx := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(tx, NodePath("Actor:position:x"))
		for k in actor_x_keys:
			anim.track_insert_key(tx, k[0], float(k[1]))
	if not anim_keys.is_empty():
		var ta := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(ta, NodePath("Actor:animation"))
		anim.value_track_set_update_mode(ta, Animation.UPDATE_DISCRETE)
		for k in anim_keys:
			anim.track_insert_key(ta, k[0], k[1])
	if not cam_zoom_keys.is_empty():
		var tz := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(tz, NodePath("Camera:zoom"))
		for k in cam_zoom_keys:
			anim.track_insert_key(tz, k[0], k[1])
	var lib := AnimationLibrary.new()
	lib.add_animation(&"perform", anim)
	ap.add_animation_library(&"", lib)
	return p

func _listen(p: CardPerformance) -> void:
	log = []
	p.hit_reached.connect(func(): log.append(["hit"]))
	p.results_requested.connect(func(): log.append(["results"]))
	p.zoom_requested.connect(func(s, time): log.append(["zoom", s, time]))
	p.done.connect(func(): log.append(["done"]))


func test_keys_emit_signals_in_order():
	var p := build([[0.05, "hit", []], [0.07, "hit", []],
		[0.1, "zoom", [0.1, 0.2]], [0.12, "show_results", []]])
	add_child_autofree(p)
	_listen(p)
	p.play(null)
	await wait_for_signal(p.done, 1.0)
	assert_eq(log.map(func(e): return e[0]), ["hit", "hit", "zoom", "results", "done"])

func test_missing_perform_finishes_immediately():
	var p := build([], 0.0)
	add_child_autofree(p)
	_listen(p)
	p.play(null)
	await wait_frames(2)
	assert_eq(log, [["done"]])

func test_play_sets_actor_frames():
	var p := build([], 0.1)
	add_child_autofree(p)
	var frames := SpriteFrames.new()
	p.play(frames)
	assert_eq(p.get_node("%Actor").sprite_frames, frames)

func test_set_paused_stops_animation_player():
	var p := build([[0.0, "hit", []]], 0.5)
	add_child_autofree(p)
	p.play(null)
	p.set_paused(true)
	assert_eq(p.get_node("%AnimationPlayer").speed_scale, 0.0)
	assert_eq(p.get_node("%Actor").speed_scale, 0.0)
	p.set_paused(false)
	assert_eq(p.get_node("%AnimationPlayer").speed_scale, 1.0)

func test_set_speed_slows_animation_player_and_sprites():
	var p := build([[0.0, "hit", []]], 0.5)
	add_child_autofree(p)
	p.play(null)
	p.set_speed(0.25)
	assert_eq(p.get_node("%AnimationPlayer").speed_scale, 0.25)
	assert_eq(p.get_node("%Actor").speed_scale, 0.25)
	p.set_speed(1.0)
	assert_eq(p.get_node("%AnimationPlayer").speed_scale, 1.0)

func test_overrides_default_to_unset():
	var p := CardPerformance.new()
	assert_eq([p.return_time, p.hit_shake, p.hitstop_time, p.hitstop_speed, p.knockback], [-1.0, -1.0, -1.0, -1.0, -1.0])
	assert_null(p.hit_effect)
	assert_null(p.hit_sound)
	# 2026-11-21: 피격 반응 값 전부 카드별로 (수치 -1 = 공통값, 색은 알파 0 = 공통값)
	assert_eq([p.hit_unit_shake, p.shake_time, p.flash_time, p.knockback_return, p.pitch_jitter], [-1.0, -1.0, -1.0, -1.0, -1.0])
	assert_eq(p.flash_color.a, 0.0)
	p.free()

func test_card_data_has_performance():
	assert_null(CardData.new().performance)

func test_looping_perform_still_finishes():
	var p := build([[0.05, "hit", []]], 0.1)
	p.get_node("%AnimationPlayer").get_animation(&"perform").loop_mode = Animation.LOOP_LINEAR
	add_child_autofree(p)
	_listen(p)
	p.play(null)
	await wait_for_signal(p.done, 1.0)
	assert_eq(log.back(), ["done"])

func test_actor_stretches_to_real_target():
	var p := build([], 0.4, [[0.0, 0.0], [0.1, 200.0]])
	add_child_autofree(p)
	p.set_stage(Vector2.ZERO, Vector2(500, 0))
	p.play(null)
	await wait_seconds(0.25)
	assert_almost_eq(p.get_node("%Actor").position.x, 500.0, 1.0)

func test_node_without_track_does_not_drift():
	var p := build([], 0.3)
	add_child_autofree(p)
	p.set_stage(Vector2.ZERO, Vector2(500, 0))
	p.get_node("%Actor").position = Vector2(200, 0)
	p.play(null)
	await wait_seconds(0.2)
	assert_almost_eq(p.get_node("%Actor").position.x, 500.0, 1.0)

func test_without_stage_keeps_editor_positions():
	var p := build([], 0.4, [[0.0, 0.0], [0.1, 200.0]])
	add_child_autofree(p)
	p.play(null)
	await wait_seconds(0.2)
	assert_almost_eq(p.get_node("%Actor").position.x, 200.0, 1.0)

func test_target_preview_hidden_on_play():
	var p := build([], 0.1)
	add_child_autofree(p)
	p.play(null)
	assert_false(p.get_node("Target").get_child(0).visible)

func test_paused_stops_manual_advance():
	var p := build([], 0.4, [[0.0, 0.0], [0.4, 200.0]])
	add_child_autofree(p)
	p.play(null)
	p.set_paused(true)
	await wait_seconds(0.15)
	assert_almost_eq(p.get_node("%Actor").position.x, 0.0, 1.0)

func test_no_camera_is_identity():
	var p := build([], 0.1)
	add_child_autofree(p)
	assert_false(p.has_camera())
	assert_eq(p.camera_xform(), Transform2D.IDENTITY)

func test_camera_xform_follows_zoom_track():
	var p := build([], 0.4, [], [], [[0.0, Vector2.ONE], [0.1, Vector2(2, 2)]])
	add_child_autofree(p)
	assert_true(p.has_camera())
	p.play(null)
	await wait_seconds(0.2)
	assert_almost_eq(p.camera_xform().get_scale(), Vector2(0.5, 0.5), Vector2(0.01, 0.01))

func test_actor_animation_track_keeps_playing():
	var p := build([], 0.2, [], [[0.0, &"idle"], [0.05, &"punch"]])
	add_child_autofree(p)
	p.play(load("res://entities/units/bram_frames.tres"))
	await wait_seconds(0.1)
	assert_eq(p.get_node("%Actor").animation, &"punch")
	assert_true(p.get_node("%Actor").is_playing())

func test_home_position_and_offset():
	var p := build([], 0.4, [[0.0, 0.0], [0.1, 200.0]])
	add_child_autofree(p)
	assert_eq(p.home_position(), Vector2.ZERO)
	p.set_stage(Vector2.ZERO, Vector2(500, 0))
	p.play(null)
	await wait_seconds(0.2)
	assert_almost_eq(p.actor_offset_from_home().x, 500.0, 1.0)

func test_play_disables_camera2d_so_it_never_takes_over():
	var p := build([], 0.2, [], [], [[0.0, Vector2.ONE]])
	p.get_node("Camera").enabled = true
	add_child_autofree(p)
	p.play(null)
	assert_false(p.get_node("Camera").enabled)
