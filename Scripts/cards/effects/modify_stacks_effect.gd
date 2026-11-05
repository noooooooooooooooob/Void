@tool
class_name ModifyStacksEffect
extends CardEffect
## 상태 수치 변경 효과. 대상이 이미 가진 상태의 수치를 늘리거나 줄인다 (없으면 아무것도 안 함).
## 수치를 쓰는 상태가 0 이하가 되면 사라진다.
## 변화량: floor(delta × 배율). 배율 0 이하이면 아무것도 안 함.
## 예) 상태 자연 감소: TURN_END 트리거에서 delta −1
##     핏방울: 출혈 피해를 줄 때마다 delta +1 × 이벤트 피해량(EventAmountValue)

## 바꿀 상태 id
@export var status_id: String
## 바꿀 양 (음수면 감소)
@export var delta: int = 1
## 배율 (비우면 1)
@export var multiplier: ValueSource


func apply(ctx: EffectContext) -> void:
	var mult := scale_of(ctx, multiplier)
	if mult <= 0.0:
		return
	var change := floori(delta * mult)
	if change == 0:
		return
	for t in resolve_targets(ctx):
		ctx.battle.change_stacks(t, status_id, change)
