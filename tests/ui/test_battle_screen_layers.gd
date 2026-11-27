extends GutTest
# 전투 화면 층 나누기: 월드는 기본 캔버스(0층), UI 2층, 연출·숫자 3층, 가방·화살표·결과 창 4층.

const SCREEN := "res://Scenes/ui/battle_screen/battle_screen.tscn"

var s: Node

func before_each():
	s = load(SCREEN).instantiate()
	s.enemy_delay = 0.0
	add_child_autofree(s)

func _layer(path: String) -> int:
	var l := (s.get_node(path) as CanvasItem).get_canvas_layer_node()
	return l.layer if l else 0

func test_world_stays_on_base_canvas():
	assert_eq(_layer("%World"), 0)

func test_ui_on_layer_2():
	for p in ["%RoundLabel", "%TurnQueue", "%TurnBanner", "%AllyPanel", "%EnemyPanel", "%Log", "%Hand", "UiLayer/BottomLeft", "UiLayer/BottomRight"]:
		assert_eq(_layer(p), 2, p)

func test_front_on_layer_3():
	assert_eq(_layer("%WorldFront"), 3)
	assert_eq(_layer("%FloatLayer"), 3)

func test_overlay_on_layer_4():
	for p in ["%BagPanel", "%TargetArrow", "%ResultOverlay", "%BackButton"]:
		assert_eq(_layer(p), 4, p)

# 화면 흔들기는 뷰포트 canvas_transform 을 흔든다. UI·연출·덮개 층은 그것을 따라가야 같이 흔들린다
func test_layers_follow_viewport():
	for n in ["UiLayer", "FrontLayer", "OverlayLayer"]:
		assert_true((s.get_node(n) as CanvasLayer).follow_viewport_enabled, n)

func test_screen_shake_moves_viewport_then_returns():
	await wait_frames(3)   # 화면을 막 띄운 첫 프레임은 길어서, 짧은 흔들기가 한 프레임에 끝날 수 있음
	s._shake_screen(6.0, 0.5)
	await wait_frames(2)
	assert_ne(s.get_viewport().canvas_transform.origin, Vector2.ZERO)
	await wait_seconds(0.7)
	assert_eq(s.get_viewport().canvas_transform, Transform2D.IDENTITY)

func test_closing_mid_shake_resets_viewport():
	var vp := s.get_viewport()
	s._shake_screen(6.0, 1.0)
	await wait_frames(2)
	s.get_parent().remove_child(s)
	assert_eq(vp.canvas_transform, Transform2D.IDENTITY)
	s.free()

# 캐릭터는 칸(바닥)의 자식이라, 그림이 뒤에 그려지는 칸으로 넘치면 바닥이 덮었다 → 캐릭터는 바닥보다 위 z
func test_unit_token_draws_above_floor_cells():
	for u in s._tokens:
		var t: CanvasItem = s._tokens[u]
		var cell := t.get_parent() as CanvasItem
		assert_gt(_abs_z(t), _abs_z(cell))

func _abs_z(n: CanvasItem) -> int:
	var z := 0
	var c: Node = n
	while c is CanvasItem:
		z += (c as CanvasItem).z_index
		if not (c as CanvasItem).z_as_relative:
			break
		c = c.get_parent()
	return z
