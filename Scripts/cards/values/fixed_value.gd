@tool
class_name FixedValue
extends ValueSource
## 항상 같은 값을 내는 배율. 예) FixedValue(2) = 2배.

## 낼 값
@export var value: float = 1.0


func _init(v: float = 1.0) -> void:
	value = v


func evaluate(_ctx: EffectContext) -> float:
	return value
