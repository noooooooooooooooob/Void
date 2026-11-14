class_name FloatNumber
extends Label
## 유닛 위에 잠깐 떠올랐다 사라지는 숫자 (부호 없이 색으로 구분: 피해 빨강, 회복 초록, 방어도 파랑).
## 전투 화면이 이벤트마다 float_number.tscn 을 복제해 FloatLayer 에 넣고 pop() 한다. 끝나면 스스로 지워진다.

## 떠오르는 시간 (초)
@export var duration := 0.9
## 떠오르는 높이 (픽셀). 매번 rise × (1 ± rise_jitter) 안에서 무작위
@export var rise := 48.0
## 떠오르는 높이를 매번 이 비율 안에서 바꾼다 (0.25 = ±25%)
@export var rise_jitter := 0.25
## 떠오르면서 옆으로 흘러가는 거리 (픽셀). 매번 −drift ~ +drift 안에서 무작위 (왼쪽·오른쪽 다 나옴)
@export var drift := 28.0
## 처음 나타나는 자리를 가로·세로로 이만큼(픽셀) 안에서 무작위로 비튼다 (여러 숫자가 겹치지 않게)
@export var start_jitter := 12.0
## 숫자 상자 너비 (픽셀). 글자는 가운데 정렬이라 상자 가운데가 곧 글자 가운데
@export var box_width := 240.0
## 처음 튀어나올 때 목표 크기의 몇 배로 시작하는지 (숫자 강조)
@export var punch := 1.4
## 튀어나온 크기에서 목표 크기로 줄어드는 시간 (초)
@export var punch_time := 0.15

## 흩어짐용 난수 (전투 rng 와 따로)
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


## 지금 위치를 가운데로 해서 text 를 color 로 띄운다. size_scale = 숫자 크기 (피해가 클수록·치명타면 크게, 전투 화면이 정함).
## 처음엔 size_scale × punch 로 튀어나왔다가 punch_time 동안 size_scale 로 줄어든다.
## 떠오르는 높이·옆으로 흐르는 방향과 거리·시작 자리는 매번 조금씩 다르다.
func pop(value: String, color: Color, size_scale := 1.0) -> void:
	text = value
	modulate = color
	# 1. 지금 위치가 글자 가운데가 되게 (예전엔 상자 왼쪽 끝이 와서 오른쪽으로 치우쳐 보였다).
	#    글자 너비는 이 프레임엔 아직 계산 전이라, 넓은 고정 상자 + 가운데 정렬로 맞춘다
	size = Vector2(box_width, get_combined_minimum_size().y)
	position -= Vector2(size.x * 0.5, 0)
	position += Vector2(rng.randf_range(-start_jitter, start_jitter), rng.randf_range(-start_jitter, start_jitter))
	# 2. 가운데를 기준으로 커졌다 줄어들게
	pivot_offset = size * 0.5
	scale = Vector2.ONE * size_scale * punch
	create_tween().tween_property(self, "scale", Vector2.ONE * size_scale, punch_time)
	# 3. 무작위 높이·옆 방향으로 떠오르며 사라짐 (위로는 빨리 솟았다 느려지게)
	var up := rise * (1.0 + rng.randf_range(-rise_jitter, rise_jitter))
	var side := rng.randf_range(-drift, drift)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y - up, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "position:x", position.x + side, duration)
	tw.tween_property(self, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
