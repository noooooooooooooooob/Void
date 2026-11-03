@tool
class_name StackCountValue
extends ValueSource
## 어떤 상태의 현재 수치를 배율로 쓴다. 상태가 없으면 0.
## 예) 출혈 피해 = 고정 피해 1 × 출혈 수치 → StackCountValue("bleed")

## 수치를 볼 상태 id
@export var status_id: String
## 누구의 수치를 볼지. OWNER = 상태 주인(카드에서는 사용자), ACTOR = 행위자.
@export var of: BattleTypes.Who = BattleTypes.Who.OWNER


func _init(id: String = "", who: int = BattleTypes.Who.OWNER) -> void:
	status_id = id
	of = who


func evaluate(ctx: EffectContext) -> float:
	var u := ctx.who(of)
	return float(u.stacks_of(status_id)) if u else 0.0
