@tool
class_name HasStatusCondition
extends CardCondition
## 카드를 쓰는 유닛이 특정 상태를 일정 수치 이상 가지고 있어야 쓸 수 있다는 조건. 수치는 소모하지 않는다.
## (소모까지 하려면 StatusCost 를 쓴다)

## 확인할 상태 id
@export var status_id: String
## 최소 수치
@export var min_stacks: int = 1


func check(ctx: EffectContext) -> bool:
	return ctx.actor.stacks_of(status_id) >= min_stacks
