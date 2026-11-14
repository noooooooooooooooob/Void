extends GutTest
# 카드 연출 씬 루트: 타임라인의 Call Method 키를 시그널로 바꾸고, perform 이 끝나면 done.

var log: Array = []

# CardPerformance + Actor + AnimationPlayer 를 코드로 조립한다 (실제 연출 씬은 에디터에서 만든다).
# keys: [[시각, 함수 이름, 인자 배열], ...]
static func build(keys: Array, length := 0.2) -> CardPerformance:
	var p := CardPerformance.new()
	var actor := AnimatedSprite2D.new()
	actor.name = "Actor"
	actor.unique_name_in_owner = true
	p.add_child(actor)
	actor.owner = p
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
	var lib := AnimationLibrary.new()
	lib.add_animation(&"perform", anim)
	ap.add_animation_library(&"", lib)
	return p

func _listen(p: CardPerformance) -> void:
	log = []
	p.move_requested.connect(func(off, time): log.append(["move", off, time]))
	p.hit_reached.connect(func(): log.append(["hit"]))
	p.results_requested.connect(func(): log.append(["results"]))
	p.zoom_requested.connect(func(s, time): log.append(["zoom", s, time]))
	p.done.connect(func(): log.append(["done"]))


func test_keys_emit_signals_in_order():
	var p := build([[0.0, "move", [-80.0, 0.0, 0.1]], [0.05, "hit", []], [0.07, "hit", []],
		[0.1, "zoom", [0.1, 0.2]], [0.12, "show_results", []]])
	add_child_autofree(p)
	_listen(p)
	p.play(null)
	await wait_for_signal(p.done, 1.0)
	assert_eq(log.map(func(e): return e[0]), ["move", "hit", "hit", "zoom", "results", "done"])
	assert_eq(log[0][1], Vector2(-80, 0))
	assert_almost_eq(log[0][2], 0.1, 0.001)

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

func test_overrides_default_to_unset():
	var p := CardPerformance.new()
	assert_eq([p.return_time, p.hit_shake, p.hitstop_time, p.knockback], [-1.0, -1.0, -1.0, -1.0])
	assert_null(p.hit_effect)
	assert_null(p.hit_sound)
	p.free()

func test_card_data_has_performance():
	assert_null(CardData.new().performance)
