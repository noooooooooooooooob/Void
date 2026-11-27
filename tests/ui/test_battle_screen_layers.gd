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
	s._shake_screen(6.0, 0.1)
	await wait_frames(2)
	assert_ne(s.get_viewport().canvas_transform.origin, Vector2.ZERO)
	await wait_seconds(0.2)
	assert_eq(s.get_viewport().canvas_transform, Transform2D.IDENTITY)

func test_closing_mid_shake_resets_viewport():
	var vp := s.get_viewport()
	s._shake_screen(6.0, 1.0)
	await wait_frames(2)
	s.get_parent().remove_child(s)
	assert_eq(vp.canvas_transform, Transform2D.IDENTITY)
	s.free()
