@tool
class_name RemoveBlockEffect
extends CardEffect
## 대상의 쉴드(방어도)를 모두 없앤다. 뒤이은 피해가 곧바로 HP 에 들어가게 할 때 쓴다.
## 예) 갈라치기: 쉴드 제거 → ATK 120% 피해


func apply(ctx: EffectContext) -> void:
	for t in resolve_targets(ctx):
		ctx.battle.clear_block(t, ctx.source)
