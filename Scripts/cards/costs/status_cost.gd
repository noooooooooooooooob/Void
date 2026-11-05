@tool
class_name StatusCost
extends CardCost
## 상태 수치를 소모하는 비용. (설계 문서 4.2, 기획 결정: 고정량 / 전부 소모 둘 다 있음)
## - 고정량: 수치가 amount 이상이어야 쓸 수 있고, 쓰면 amount 만큼 소모.
## - 전부 소모(consume_all): 수치가 min_stacks 이상이어야 쓸 수 있고, 쓰면 가진 만큼 전부 소모.
## 소모한 양은 ctx.values["consumed:<상태 id>"] 에 기록되어, 효과의 배율(ConsumedValue)이 읽는다.
## 예) 피의 참격: status_id "blood_drop", consume_all = true, min_stacks 1

## 소모할 상태 id (카드를 쓰는 유닛의 상태)
@export var status_id: String
## 고정 소모량 (consume_all 이 아닐 때)
@export var amount: int = 1
## true 면 가진 수치를 전부 소모한다
@export var consume_all: bool = false
## 전부 소모일 때 최소로 있어야 하는 수치
@export var min_stacks: int = 1


func can_pay(ctx: EffectContext) -> bool:
	var have := ctx.actor.stacks_of(status_id)
	return have >= (min_stacks if consume_all else amount)


func pay(ctx: EffectContext) -> void:
	var paid := ctx.actor.stacks_of(status_id) if consume_all else amount
	ctx.battle.change_stacks(ctx.actor, status_id, -paid)
	ctx.values["consumed:" + status_id] = paid
