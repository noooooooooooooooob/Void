@tool
class_name DrawEffect
extends CardEffect
## 드로우 효과. 대상이 자기 덱에서 카드를 count 장 뽑는다. 보통 target 을 SELF 로 둔다.
## 행동 중 드로우라서 덱이 비면 버린 더미를 섞지 않고 더 못 뽑는다 (사용자 결정 2026-11-04).
## (버린 더미를 섞어 채우는 것은 차례 시작의 드로우 페이즈뿐)

## 뽑을 장수
@export var count: int = 1


func apply(ctx: EffectContext) -> void:
	if count <= 0:
		return
	for t in resolve_targets(ctx):
		ctx.battle.draw(t, count, false)
