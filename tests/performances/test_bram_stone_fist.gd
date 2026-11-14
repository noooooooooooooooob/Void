extends GutTest
# 브람 돌주먹 시험 연출 씬: 규약(Actor·AnimationPlayer·perform)을 지키고, 이동→hit→결과→끝 순서로 재생된다.

const SCENE := "res://Scenes/performances/bram_stone_fist.tscn"

func test_card_uses_stone_fist_performance():
	var card: CardData = load("res://cards/data/브람/돌주먹.tres")
	assert_eq(card.performance.resource_path, SCENE)
	assert_eq(card.upgrades[0].performance.resource_path, SCENE)

func test_plays_move_hit_results_in_order():
	var p: CardPerformance = load(SCENE).instantiate()
	add_child_autofree(p)
	var log := []
	p.move_requested.connect(func(_o, _t): log.append("move"))
	p.hit_reached.connect(func(): log.append("hit"))
	p.results_requested.connect(func(): log.append("results"))
	p.done.connect(func(): log.append("done"))
	p.play(load("res://entities/units/bram_frames.tres"))
	await wait_for_signal(p.done, 2.0)
	assert_eq(log, ["move", "hit", "results", "done"])
