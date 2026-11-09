@tool
class_name CurrentBlockValue
extends ValueSource
## 지금 가진 쉴드(방어도)의 몇 % 를 배율로 쓴다. 쉴드가 없으면 0 이라 효과가 실행되지 않는다.
## 예) 굳은살: BlockEffect(flat 1, multiplier = CurrentBlockValue 50%) → 현재 쉴드의 50% 만큼 추가

## 쉴드의 몇 % 인지 (100 = 쉴드와 같은 값)
@export var percent: float = 100.0


## 행위자의 쉴드를 본다. 행위자가 없으면(상태 발동) 상태 주인의 쉴드.
func evaluate(ctx: EffectContext) -> float:
	var who := ctx.actor if ctx.actor else ctx.owner
	return who.block * percent / 100.0
