@tool
class_name TimeOfDayPreset
extends Resource
## 시간대 프리셋 (낮·노을·저녁·밤 등). 그 시각에 장면 무드가 어떤 값인지 묶어 둔 데이터.
## 파일 moods/time_of_day/*.tres (공유), 배경 전용은 moods/time_of_day/<배경>/ (바꿔 끼우기).
## BattleMood.presets 에 넣으면 지금 시각(time_of_day) 기준으로 앞뒤 프리셋 값을 섞어 무드에 넣는다
## (설계 docs/superpowers/specs/2026-11-28-day-cycle-design.md).
## 값 이름·뜻·기본값은 BattleMood 의 같은 이름 값과 같다.

## 시간 따라 섞는 값 이름 (BattleMood 의 같은 이름 값에 들어감). sun_color 는 해 원반에 따로 들어가서 뺌
const BLEND_KEYS: Array[StringName] = [
	&"darkness", &"sky_top", &"sky_bottom", &"fill_color", &"fill_energy", &"fill_angle",
	&"light_scale", &"halo_scale", &"rays_color", &"rays_strength", &"fog_color", &"fog_density",
	&"vignette", &"split_tone", &"cool", &"warm", &"bloom", &"bloom_threshold",
	&"haze_color", &"haze_amount", &"shadow_color", &"shadow_length", &"shadow_fade",
]

## 이 프리셋의 시각 (0~24시). 시각 사이는 앞뒤 프리셋을 섞는다
@export_range(0.0, 24.0, 0.1) var hour := 12.0

@export_group("어둠·하늘")
## 월드를 어둡게 하는 색 (흰색 = 그대로)
@export var darkness := Color(0.32, 0.36, 0.55)
## 하늘 위쪽 색
@export var sky_top := Color(0.03, 0.04, 0.1)
## 하늘 아래쪽(지평선) 색
@export var sky_bottom := Color(0.15, 0.17, 0.3)
## 해·달 원반·헤일로 색 (해에만 들어감 — 지평선 근처를 붉게)
@export var sun_color := Color(1, 0.75, 0.45)

@export_group("캐릭터 보조광")
## 보조광 색
@export var fill_color := Color(0.75, 0.8, 1.0)
## 보조광 세기
@export_range(0.0, 3.0, 0.05) var fill_energy := 0.9
## 보조광이 오는 방향 (도)
@export_range(-180.0, 180.0, 1.0) var fill_angle := -45.0

@export_group("빛나는 물품")
## 광원 밝기 배율 (석등 등)
@export_range(0.0, 3.0, 0.05) var light_scale := 1.0
## 헤일로 배율
@export_range(0.0, 3.0, 0.05) var halo_scale := 1.0

@export_group("빛줄기")
## 빛줄기 색
@export var rays_color := Color(1, 0.8, 0.55)
## 빛줄기 세기
@export_range(0.0, 3.0, 0.01) var rays_strength := 0.4

@export_group("안개")
## 안개 색
@export var fog_color := Color(0.55, 0.6, 0.8)
## 안개 진하기 (0~1)
@export_range(0.0, 1.0, 0.01) var fog_density := 0.25

@export_group("화면")
## 비네트 (가장자리 어둡게)
@export_range(0.0, 1.0, 0.01) var vignette := 0.6
## 냉난 대비 세기
@export_range(0.0, 1.0, 0.01) var split_tone := 0.6
## 어두운 쪽 색
@export var cool := Color(0.88, 0.95, 1.0)
## 밝은 쪽 색
@export var warm := Color(1.0, 0.95, 0.82)
## 빛 번짐 세기
@export_range(0.0, 2.0, 0.05) var bloom := 0.8
## 빛 번짐 문턱
@export_range(0.0, 2.0, 0.05) var bloom_threshold := 0.9

@export_group("공기원근")
## 멀수록 섞이는 공기 색
@export var haze_color := Color(0.35, 0.4, 0.6)
## 공기 색 섞는 비율 (0~1)
@export_range(0.0, 1.0, 0.01) var haze_amount := 0.35

@export_group("그림자")
## 그림자 색 (알파 = 진하기)
@export var shadow_color := Color(0, 0, 0, 0.55)
## 그림자 길이 (대상 키 대비)
@export_range(0.0, 3.0, 0.05) var shadow_length := 1.2
## 그림자 끝 흐림 (0~1)
@export_range(0.0, 1.0, 0.01) var shadow_fade := 0.7
