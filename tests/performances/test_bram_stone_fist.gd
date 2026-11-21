extends GutTest
# 브람 돌주먹 시험 연출 씬: 타임라인 규약(Home·Target·Actor·Camera·AnimationPlayer·perform)을 지키고, hit→결과→끝 순서로 재생된다.

const SCENE := "res://Scenes/performances/bram_stone_fist.tscn"

func test_card_uses_stone_fist_performance():
	var card: CardData = load("res://cards/data/브람/돌주먹.tres")
	assert_eq(card.performance.resource_path, SCENE)
	assert_eq(card.upgrades[0].performance.resource_path, SCENE)

func test_scene_follows_timeline_contract():
	var p: CardPerformance = load(SCENE).instantiate()
	add_child_autofree(p)
	for n in ["Home", "Target", "Actor", "Camera", "AnimationPlayer"]:
		assert_not_null(p.get_node_or_null(n), n)
	assert_true(p.has_camera())
	var anim: Animation = p.get_node("%AnimationPlayer").get_animation(&"perform")
	assert_ne(anim.find_track(NodePath("Actor:animation"), Animation.TYPE_VALUE), -1)
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_METHOD:
			for k in anim.track_get_key_count(t):
				assert_ne(anim.method_track_get_name(t, k), &"move")
				assert_ne(anim.method_track_get_name(t, k), &"play")

func test_plays_hit_results_in_order():
	var p: CardPerformance = load(SCENE).instantiate()
	add_child_autofree(p)
	var log := []
	p.hit_reached.connect(func(): log.append("hit"))
	p.results_requested.connect(func(): log.append("results"))
	p.done.connect(func(): log.append("done"))
	p.play(load("res://entities/units/bram_frames.tres"))
	await wait_for_signal(p.done, 2.0)
	assert_eq(log, ["hit", "results", "done"])

# 순간이동 (2026-11-21): 0.15초에 대상 앞 50px 로 툭, 0.6초에 제자리로 툭 (사이 보간 없음)
func test_actor_teleports_to_target_and_back():
	var p: CardPerformance = load(SCENE).instantiate()
	var anim: Animation = p.get_node("AnimationPlayer").get_animation(&"perform")
	var t := anim.find_track(^"Actor:position", Animation.TYPE_VALUE)
	assert_ne(t, -1)
	assert_eq(anim.value_track_get_update_mode(t), Animation.UPDATE_DISCRETE)
	var target_x: float = p.get_node("Target").position.x
	assert_eq(anim.value_track_interpolate(t, 0.1), Vector2.ZERO)
	assert_eq(anim.value_track_interpolate(t, 0.2), Vector2(target_x - 50.0, 0))
	assert_eq(anim.value_track_interpolate(t, 0.65), Vector2.ZERO)
	p.free()

# 화면 크기로 짠다: Actor·대상 미리보기 그림이 유닛 박스 그림과 같은 배율이라 카메라 사각형 = 실제 화면
func test_authored_at_screen_scale():
	var p: CardPerformance = load(SCENE).instantiate()
	var token: Node = load("res://Scenes/ui/battle_screen/unit_token.tscn").instantiate()
	var unit_scale: Vector2 = token.find_child("Sprite", true, false).scale
	assert_eq(p.get_node("Actor").scale, unit_scale)
	assert_eq(p.get_node("Target/Preview").scale, unit_scale)
	p.free()
	token.free()

# 시험용 소리: 0.3초(hit 시점)에 PunchSound 로 Audio/test.mp3 를 튼다
func test_punch_sound_on_audio_track_at_hit():
	var p: CardPerformance = load(SCENE).instantiate()
	assert_true(p.get_node_or_null("PunchSound") is AudioStreamPlayer)
	var anim: Animation = p.get_node("AnimationPlayer").get_animation(&"perform")
	var t := anim.find_track(NodePath("PunchSound"), Animation.TYPE_AUDIO)
	assert_ne(t, -1)
	assert_eq(anim.track_get_key_count(t), 1)
	assert_almost_eq(anim.track_get_key_time(t, 0), 0.3, 0.001)
	assert_eq(anim.audio_track_get_key_stream(t, 0).resource_path, "res://Audio/test.mp3")
	p.free()

# 게임처럼 수동 진행(advance)으로 재생해도 Audio 트랙이 소리를 낸다
func test_punch_sound_plays_during_game_playback():
	var p: CardPerformance = load(SCENE).instantiate()
	add_child_autofree(p)
	p.play(load("res://entities/units/bram_frames.tres"))
	await wait_seconds(0.35)
	assert_true(p.get_node("PunchSound").playing)
