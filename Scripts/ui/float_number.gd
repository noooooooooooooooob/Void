class_name FloatNumber
extends Label
## 유닛 위에 잠깐 떠올랐다 사라지는 숫자 (피해 빨강, 방어도 파랑, 회복 초록).
## 전투 화면이 이벤트마다 float_number.tscn 을 복제해 FloatLayer 에 넣고 pop() 한다. 끝나면 스스로 지워진다.

## 떠오르는 시간 (초)
@export var duration := 0.9
## 떠오르는 높이 (픽셀)
@export var rise := 48.0


## text 를 color 로 띄운다.
func pop(value: String, color: Color) -> void:
	text = value
	modulate = color
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y - rise, duration)
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.chain().tween_callback(queue_free)
