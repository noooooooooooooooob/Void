@tool
class_name MoodLight
extends PointLight2D
## 빛나는 물품의 빛 (석등·횃불·수정 등). 부품 Scenes/backgrounds/parts/lantern_light.tscn 의 루트.
## 다른 물품은 이 부품을 복제해 색·밝기·범위만 바꿔 쓴다. 그룹 mood_light.
##
## 색·밝기·헤일로·범위(texture_scale)는 물품마다 정하고, 장면 전체 배율은 BattleMood 가 넣는다
## (설계 docs/superpowers/specs/2026-11-27-battle-mood-sliders-design.md).
## 자식 Halo (Sprite2D, 더하기·빛 안 받음): 빛 주변 번지는 동그라미.

## 빛과 헤일로의 색
@export var light_color := Color(1, 0.62, 0.3):
	set(v):
		light_color = v
		_apply()
## 기본 밝기 (PointLight2D energy). 실제 밝기 = 이 값 × BattleMood 광원 밝기 배율
@export_range(0.0, 5.0, 0.05) var brightness := 2.2:
	set(v):
		brightness = v
		_apply()
## 헤일로 세기 (색에 곱함). HDR 이라 1 을 넘으면 더 번진다. 0 = 헤일로 없음
@export_range(0.0, 3.0, 0.05) var halo_strength := 0.85:
	set(v):
		halo_strength = v
		_apply()
## 헤일로 크기 (Halo 배율, 1 = 256px)
@export_range(0.0, 3.0, 0.05) var halo_size := 0.7:
	set(v):
		halo_size = v
		_apply()

## BattleMood 가 넣는 광원 밝기 배율 (장면 전체). BattleMood 가 없으면 1
var mood_brightness_scale := 1.0:
	set(v):
		mood_brightness_scale = v
		_apply()
## BattleMood 가 넣는 헤일로 배율 (장면 전체). BattleMood 가 없으면 1
var mood_halo_scale := 1.0:
	set(v):
		mood_halo_scale = v
		_apply()


func _ready() -> void:
	_apply()


## 값을 빛과 헤일로에 넣는다. 씬 로드 중(준비 전)에는 건너뛰고 _ready 에서 넣는다
func _apply() -> void:
	if not is_node_ready():
		return
	# 1. 빛: 밝기 0 이면 꺼서 비용을 아낀다
	color = light_color
	energy = brightness * mood_brightness_scale
	enabled = energy > 0.0
	# 2. 헤일로: 더하기 섞기라 알파 1 에 색 밝기로 세기를 낸다
	var halo := $Halo as Sprite2D
	var k := halo_strength * mood_halo_scale
	halo.modulate = Color(light_color.r * k, light_color.g * k, light_color.b * k, 1.0)
	halo.scale = Vector2(halo_size, halo_size)
