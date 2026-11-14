class_name FloatNumber
extends Label
## 유닛 위에 잠깐 떠올랐다 사라지는 숫자 (피해 빨강, 방어도 파랑, 회복 초록).
## 전투 화면이 이벤트마다 float_number.tscn 을 복제해 FloatLayer 에 넣고 pop() 한다. 끝나면 스스로 지워진다.

## 떠오르는 시간 (초)
@export var duration := 0.9
## 떠오르는 높이 (픽셀)
@export var rise := 48.0
## 처음 튀어나올 때 목표 크기의 몇 배로 시작하는지 (숫자 강조)
@export var punch := 1.4
## 튀어나온 크기에서 목표 크기로 줄어드는 시간 (초)
@export var punch_time := 0.15


## text 를 color 로 띄운다. size_scale = 숫자 크기 (피해가 클수록·치명타면 크게, 전투 화면이 정함).
## 처음엔 size_scale × punch 로 튀어나왔다가 punch_time 동안 size_scale 로 줄어든다.
func pop(value: String, color: Color, size_scale := 1.0) -> void:
	text = value
	modulate = color
	# 가운데를 기준으로 커졌다 줄어들게
	pivot_offset = get_combined_minimum_size() * 0.5
	scale = Vector2.ONE * size_scale * punch
	create_tween().tween_property(self, "scale", Vector2.ONE * size_scale, punch_time)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y - rise, duration)
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.chain().tween_callback(queue_free)
