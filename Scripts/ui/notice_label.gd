class_name NoticeLabel
extends Label
## 잠깐 떴다가 사라지는 안내 한 줄 ("준비 중" 등). 타이틀·사무소 화면에서 쓴다.
## 씬에 Label 로 놓고 이 스크립트를 붙인 뒤, 다른 스크립트가 show_text("…") 를 부른다.

## 글이 완전히 보이는 시간 (초)
@export var hold_time := 1.4
## 사라지는 데 걸리는 시간 (초)
@export var fade_time := 0.4

var _tween: Tween


func _ready() -> void:
	# 처음엔 숨겨 두고, 마우스 입력을 막지 않게 한다
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## text 를 보여 주고 hold_time 뒤에 서서히 사라진다. 이미 떠 있으면 새 글로 바꾸고 시간을 다시 잰다
func show_text(message: String) -> void:
	text = message
	if _tween:
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(hold_time)
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
