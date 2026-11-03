@tool
class_name ConsumedValue
extends ValueSource
## 이번 카드 사용에서 비용으로 소모한 상태 수치를 배율로 쓴다. 소모하지 않았으면 0.
## StatusCost 가 지불할 때 ctx.values["consumed:<상태 id>"] 에 기록한 값을 읽는다.
## 예) 핏방울을 전부 소모해서 소모량 × 40% 피해 → DamageEffect(40%, multiplier = ConsumedValue("blood_drop"))

## 소모량을 볼 상태 id
@export var status_id: String


func _init(id: String = "") -> void:
	status_id = id


func evaluate(ctx: EffectContext) -> float:
	return float(ctx.values.get("consumed:" + status_id, 0))
