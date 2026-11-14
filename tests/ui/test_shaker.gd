extends GutTest
# 흔들기: 세기 안에서 무작위로 흔들리며 약해지고, 끝나면 정확히 원래 자리.

var rng := RandomNumberGenerator.new()

func _node() -> Node2D:
	var n := Node2D.new()
	n.position = Vector2(10, 10)
	add_child_autofree(n)
	return n

func test_shake_moves_within_strength():
	var n := _node()
	rng.seed = 1
	Shaker.shake(n, 5.0, 0.2, rng)
	await wait_frames(2)
	assert_ne(n.position, Vector2(10, 10))
	assert_lte(n.position.distance_to(Vector2(10, 10)), 5.0 * sqrt(2.0) + 0.01)

func test_shake_returns_to_origin():
	var n := _node()
	Shaker.shake(n, 5.0, 0.1, rng)
	await wait_seconds(0.2)
	assert_eq(n.position, Vector2(10, 10))

func test_overlapping_shakes_keep_origin():
	var n := _node()
	Shaker.shake(n, 5.0, 0.1, rng)
	await wait_seconds(0.05)
	Shaker.shake(n, 5.0, 0.1, rng)
	await wait_seconds(0.2)
	assert_eq(n.position, Vector2(10, 10))

func test_origin_of_unshaken_node_is_position():
	var n := _node()
	assert_eq(Shaker.origin(n), Vector2(10, 10))
