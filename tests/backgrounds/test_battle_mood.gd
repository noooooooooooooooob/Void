extends GutTest
# 전투 무드 노드: 인스펙터 값이 자식(어둠·하늘·보조광·화면 효과·빛 번짐)과 공기원근 대상에 들어가는지.

const MOOD := "res://Scenes/backgrounds/parts/battle_mood.tscn"
const LANTERN := "res://Scenes/backgrounds/parts/lantern_light.tscn"
const FOG := "res://Scenes/backgrounds/parts/ground_fog.tscn"

var root: Control
var m: Node

func before_each():
	root = Control.new()
	add_child_autofree(root)
	m = load(MOOD).instantiate()
	root.add_child(m)

func _post(name: String) -> Variant:
	return (m.get_node("PostLayer/Post").material as ShaderMaterial).get_shader_parameter(name)

func test_darkness_goes_to_canvas_modulate():
	m.darkness = Color(0.2, 0.3, 0.4)
	assert_eq((m.get_node("Darkness") as CanvasModulate).color, Color(0.2, 0.3, 0.4))

func test_sky_colors_go_to_gradient():
	m.sky_top = Color.RED
	m.sky_bottom = Color.BLUE
	var g: Gradient = (m.get_node("Sky").texture as GradientTexture2D).gradient
	assert_eq(g.get_color(0), Color.RED)
	assert_eq(g.get_color(g.get_point_count() - 1), Color.BLUE)

func test_fill_light_values():
	m.fill_color = Color(0.5, 0.6, 0.7)
	m.fill_energy = 1.3
	m.fill_angle = 30.0
	var l := m.get_node("CharacterFill") as DirectionalLight2D
	assert_eq(l.color, Color(0.5, 0.6, 0.7))
	assert_almost_eq(l.energy, 1.3, 0.001)
	assert_almost_eq(l.rotation, deg_to_rad(30.0), 0.001)
	assert_eq(l.range_item_cull_mask, 2)

func test_screen_effect_values():
	m.vignette = 0.25
	m.split_tone = 0.5
	m.cool = Color(0.8, 0.9, 1.0)
	m.warm = Color(1.0, 0.9, 0.8)
	assert_almost_eq(_post("vignette"), 0.25, 0.001)
	assert_almost_eq(_post("split"), 0.5, 0.001)
	assert_eq(_post("cool"), Color(0.8, 0.9, 1.0))
	assert_eq(_post("warm"), Color(1.0, 0.9, 0.8))

func test_post_layer_sits_under_ui_and_ignores_mouse():
	assert_eq((m.get_node("PostLayer") as CanvasLayer).layer, 1)
	assert_eq((m.get_node("PostLayer/Post") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var env: Environment = (m.get_node("Glow") as WorldEnvironment).environment
	assert_eq(env.background_mode, Environment.BG_CANVAS)
	assert_eq(env.background_canvas_max_layer, 1)

func test_bloom_sets_glow_and_zero_turns_it_off():
	var env: Environment = (m.get_node("Glow") as WorldEnvironment).environment
	m.bloom = 0.7
	assert_true(env.glow_enabled)
	assert_almost_eq(env.glow_intensity, 0.7, 0.001)
	m.bloom = 0.0
	assert_false(env.glow_enabled)

func test_haze_applies_to_targets_and_skips_missing():
	var far := TextureRect.new()
	far.name = "Far"
	root.add_child(far)
	var paths: Array[NodePath] = [NodePath("../Far"), NodePath("../Nope"), NodePath("")]
	m.haze_targets = paths
	m.haze_color = Color(0.1, 0.2, 0.3)
	m.haze_amount = 0.4
	m.haze_blur = 2.0
	assert_eq(far.material, m.haze_material)
	assert_eq(m.haze_material.get_shader_parameter("haze"), Color(0.1, 0.2, 0.3))
	assert_almost_eq(m.haze_material.get_shader_parameter("amount"), 0.4, 0.001)
	assert_almost_eq(m.haze_material.get_shader_parameter("blur"), 2.0, 0.001)

func test_two_instances_do_not_share():
	var m2: Node = load(MOOD).instantiate()
	root.add_child(m2)
	m.darkness = Color(0.1, 0.1, 0.1)
	m.sky_top = Color.RED
	m.vignette = 0.1
	m.bloom = 0.3
	m.haze_amount = 0.9
	m2.sky_top = Color.GREEN
	m2.vignette = 0.9
	m2.bloom = 0.0
	m2.haze_amount = 0.1
	assert_eq((m.get_node("Sky").texture as GradientTexture2D).gradient.get_color(0), Color.RED)
	assert_almost_eq(_post("vignette"), 0.1, 0.001)
	assert_true((m.get_node("Glow") as WorldEnvironment).environment.glow_enabled)
	assert_almost_eq(m.haze_material.get_shader_parameter("amount"), 0.9, 0.001)

func test_lantern_part():
	var l := load(LANTERN).instantiate() as PointLight2D
	autofree(l)
	assert_not_null(l)
	assert_almost_eq(l.texture_scale, 6.0, 0.001)
	var halo := l.get_node("Halo") as Sprite2D
	var mat := halo.material as CanvasItemMaterial
	assert_eq(mat.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD)
	assert_eq(mat.light_mode, CanvasItemMaterial.LIGHT_MODE_UNSHADED)

func test_ground_fog_part():
	var f := load(FOG).instantiate() as Sprite2D
	autofree(f)
	assert_not_null(f)
	assert_true(f.texture is NoiseTexture2D)
	assert_almost_eq(f.modulate.a, 0.25, 0.001)
	assert_not_null(f.material as ShaderMaterial)
