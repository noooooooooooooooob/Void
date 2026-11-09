@tool
class_name BlockCost
extends CardCost
## 쉴드(방어도)를 전부 소모하는 비용. 쉴드가 1 이상이어야 카드를 쓸 수 있다.
## 쉴드는 상태가 아니어서 StatusCost 로 표현할 수 없어 따로 둔다.
## 소모한 양은 ctx.values["consumed:block"] 에 기록되어, 효과의 배율 ConsumedValue("block") 이 읽는다.
## 예) 돌 던지기: 쉴드 전부 소모, 소모한 쉴드의 100% 피해


func can_pay(ctx: EffectContext) -> bool:
	return ctx.actor.block >= 1


func pay(ctx: EffectContext) -> void:
	ctx.values["consumed:block"] = ctx.battle.clear_block(ctx.actor, ctx.source)


func preview(ctx: EffectContext) -> void:
	ctx.values["consumed:block"] = ctx.actor.block
