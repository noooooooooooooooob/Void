@tool
class_name DrawEffect
extends CardEffect
## 드로우 효과. 대상이 자기 덱에서 카드를 count 장 뽑는다.
## 덱이 비면 버린 더미를 섞어 덱으로 만들고, 둘 다 비면 거기서 멈춘다 (Battle.draw).
## 보통 target 을 SELF 로 둔다.

## 뽑을 장수
@export var count: int = 1


func apply(ctx: EffectContext) -> void:
	if count <= 0:
		return
	for t in resolve_targets(ctx):
		ctx.battle.draw(t, count)
