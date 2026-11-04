@tool
class_name ApplyStatusEffect
extends CardEffect
## 상태 부여 효과. 대상에게 상태를 건다. 이미 있으면 수치를 합치고, 건 유닛(행위자)을 기억한다.
## 수치: floor(stacks × 배율). 배율 0 이하이거나 결과가 0 이하면 아무것도 안 함.
## 예) 출혈 3 부여: status = 출혈.tres, stacks 3

## 걸 상태 데이터 (statuses/data/*.tres)
@export var status: StatusData
## 걸 수치
@export var stacks: int = 1
## 배율 (비우면 1)
@export var multiplier: ValueSource


func apply(ctx: EffectContext) -> void:
	if status == null:
		return
	var amount := floori(stacks * scale_of(ctx, multiplier))
	if amount <= 0:
		return
	for t in resolve_targets(ctx):
		ctx.battle.apply_status(t, status, amount, ctx.actor)
