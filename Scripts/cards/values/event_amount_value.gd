@tool
class_name EventAmountValue
extends ValueSource
## 상태 트리거를 일으킨 이벤트의 수치(피해량, 회복량 등)를 배율로 쓴다. 이벤트가 없으면 0.
## 예) 핏방울: 출혈 피해를 줄 때마다 그 피해량만큼 쌓임 → ModifyStacksEffect(+1 × EventAmountValue)


func evaluate(ctx: EffectContext) -> float:
	return float(ctx.event.amount) if ctx.event else 0.0
