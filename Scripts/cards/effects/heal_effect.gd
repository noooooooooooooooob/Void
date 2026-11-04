@tool
class_name HealEffect
extends CardEffect
## 회복 효과. 대상의 HP 를 회복한다 (최대 HP 까지).
## 수치: 공격 × percent/100 × 배율 → 마지막에 내림, 최소 1. 배율 0 이하면 아무것도 안 함. (노션: 회복은 공격 스탯 기준)

## 공격 스탯의 몇 % 인지
@export var percent: float = 100.0
## 배율 (비우면 1)
@export var multiplier: ValueSource


func apply(ctx: EffectContext) -> void:
	var mult := scale_of(ctx, multiplier)
	var who := stat_unit(ctx)
	if mult <= 0.0 or who == null:
		return
	var amount := final_amount(who.get_stat(BattleTypes.Stat.ATTACK) * percent / 100.0 * mult)
	for t in resolve_targets(ctx):
		ctx.battle.heal(t, amount, ctx.source)
