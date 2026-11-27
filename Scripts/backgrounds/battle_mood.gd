@tool
class_name BattleMood
extends Node2D
## 전투 배경의 분위기(무드). 배경 씬(Scenes/backgrounds/*.tscn)에 battle_mood.tscn 을 맨 앞 자식으로 넣고 인스펙터 값으로 맞춘다.
## @tool 이라 에디터 2D 화면에서 값을 바꾸면 바로 보인다 (설계 docs/superpowers/specs/2026-11-27-battle-mood-design.md).
##
## 값은 자식 노드에 들어간다:
## - Sky (TextureRect, 세로 그라데이션): 맨 뒤 하늘. 배경 그림의 하늘이 투명하면 이것이 보인다
## - Darkness (CanvasModulate): 월드 층(0층) 전체를 어둡게. UI 는 다른 층이라 안 어두워짐
## - CharacterFill (PointLight2D, 커링 마스크 2): 캐릭터만 비추는 보조광. 어두운 장면에서도 캐릭터가 보이고 노말맵 음영이 산다.
##   멀리(FILL_DISTANCE) 둔 아주 큰 점광이라 화면 안에서는 한 방향 빛처럼 보인다.
##   DirectionalLight2D 를 안 쓰는 이유: range_item_cull_mask 를 무시하고 배경까지 비춘다 (2026-11-27 시험으로 확인)
## - PostLayer/Post (CanvasLayer 1 의 화면 셰이더): 비네트·냉난 대비. 1층이라 월드에만 걸림
## - Glow (WorldEnvironment): 빛 번짐. background_canvas_max_layer = 1 이라 UI 층(2~4)은 안 번짐
## - haze_targets 의 노드들: 공기원근 셰이더(haze_material)를 건다 (먼 배경 그림)

## 화면 가운데 (기준 해상도 1920×1080). 보조광 위치의 기준
const SCREEN_CENTER := Vector2(960, 540)
## 보조광을 화면 가운데에서 떨어뜨려 두는 거리 (픽셀). 멀수록 캐릭터마다 빛 방향이 같아진다
const FILL_DISTANCE := 4000.0

## 월드를 어둡게 하는 색 (흰색 = 그대로). 배경·캐릭터에 곱해지고, 빛을 받은 곳만 다시 밝아진다
@export var darkness := Color(0.32, 0.36, 0.55):
	set(v):
		darkness = v
		_apply()
## 하늘 위쪽 색
@export var sky_top := Color(0.03, 0.04, 0.1):
	set(v):
		sky_top = v
		_apply()
## 하늘 아래쪽(지평선) 색
@export var sky_bottom := Color(0.15, 0.17, 0.3):
	set(v):
		sky_bottom = v
		_apply()

@export_group("캐릭터 보조광")
## 보조광 색
@export var fill_color := Color(0.75, 0.8, 1.0):
	set(v):
		fill_color = v
		_apply()
## 보조광 세기 (0 = 끔)
@export_range(0.0, 3.0, 0.05) var fill_energy := 0.9:
	set(v):
		fill_energy = v
		_apply()
## 보조광이 오는 쪽 (도, 화면 가운데 기준). 0 = 오른쪽, -90 = 위, 180 = 왼쪽
@export_range(-180.0, 180.0, 1.0) var fill_angle := -120.0:
	set(v):
		fill_angle = v
		_apply()

@export_group("화면")
## 비네트 (화면 가장자리 어둡게, 0~1)
@export_range(0.0, 1.0, 0.01) var vignette := 0.6:
	set(v):
		vignette = v
		_apply()
## 냉난 대비 (어두운 곳 cool, 밝은 곳 warm 을 곱하는 정도, 0~1)
@export_range(0.0, 1.0, 0.01) var split_tone := 0.6:
	set(v):
		split_tone = v
		_apply()
## 냉난 대비의 어두운 쪽 색
@export var cool := Color(0.88, 0.95, 1.0):
	set(v):
		cool = v
		_apply()
## 냉난 대비의 밝은 쪽 색
@export var warm := Color(1.0, 0.95, 0.82):
	set(v):
		warm = v
		_apply()
## 빛 번짐 세기 (glow intensity). 0 이면 끔
@export_range(0.0, 2.0, 0.05) var bloom := 0.8:
	set(v):
		bloom = v
		_apply()

@export_group("공기원근")
## 공기원근을 걸 노드 (먼 배경 그림). 이 노드 기준 경로. 없는 경로·빈 경로는 건너뜀
@export var haze_targets: Array[NodePath] = []:
	set(v):
		haze_targets = v
		_apply()
## 멀수록 섞이는 공기 색
@export var haze_color := Color(0.35, 0.4, 0.6):
	set(v):
		haze_color = v
		_apply()
## 공기 색을 섞는 비율 (0~1)
@export_range(0.0, 1.0, 0.01) var haze_amount := 0.35:
	set(v):
		haze_amount = v
		_apply()
## 흐림 거리 (그림 픽셀 단위, 0 = 안 흐림)
@export_range(0.0, 4.0, 0.1) var haze_blur := 1.5:
	set(v):
		haze_blur = v
		_apply()
## 공기원근 셰이더 재질 (mood_haze.gdshader). 대상들이 이 하나를 같이 쓴다. 씬마다 따로(local to scene)
@export var haze_material: ShaderMaterial


func _ready() -> void:
	_apply()


## 지금 값을 자식 노드·공기원근 대상에 넣는다. 준비 전(씬 로드 중 setter)에는 건너뛰고 _ready 에서 한 번에 넣는다
func _apply() -> void:
	if not is_node_ready():
		return
	# 1. 어둠
	($Darkness as CanvasModulate).color = darkness
	# 2. 하늘: 그라데이션 첫 점 = 위, 마지막 점 = 아래
	var g := ($Sky.texture as GradientTexture2D).gradient
	g.set_color(0, sky_top)
	g.set_color(g.get_point_count() - 1, sky_bottom)
	# 3. 캐릭터 보조광
	var fill := $CharacterFill as PointLight2D
	fill.color = fill_color
	fill.energy = fill_energy
	fill.enabled = fill_energy > 0.0
	fill.position = SCREEN_CENTER + Vector2.from_angle(deg_to_rad(fill_angle)) * FILL_DISTANCE
	# 4. 화면 효과 (비네트·냉난 대비)
	var post := $PostLayer/Post.material as ShaderMaterial
	post.set_shader_parameter("vignette", vignette)
	post.set_shader_parameter("split", split_tone)
	post.set_shader_parameter("cool", cool)
	post.set_shader_parameter("warm", warm)
	# 5. 빛 번짐: 0 이면 꺼서 비용도 아낀다
	var env := ($Glow as WorldEnvironment).environment
	env.glow_enabled = bloom > 0.0
	env.glow_intensity = bloom
	# 6. 공기원근: 재질 값 넣고 대상에 건다
	if haze_material:
		haze_material.set_shader_parameter("haze", haze_color)
		haze_material.set_shader_parameter("amount", haze_amount)
		haze_material.set_shader_parameter("blur", haze_blur)
		for p in haze_targets:
			var t := get_node_or_null(p) as CanvasItem if not p.is_empty() else null
			if t and t.material != haze_material:
				t.material = haze_material
