@tool
class_name BlockEffect
extends CardEffect
## 방어도(쉴드) 효과. 대상이 방어도를 얻는다. 방어도는 피해를 HP 보다 먼저 막고, 라운드 시작 시 초기화된다.
## 수치: 방어 × percent/100 × 배율 (또는 flat × 배율) → 마지막에 내림, 최소 1. 배율 0 이하면 아무것도 안 함.
## 예) 혈갑: 엔드 페이즈에 use_flat, flat 1, multiplier = 혈갑 수치 → 수치만큼 방어도

## 방어 스탯의 몇 % 인지. use_flat 이면 무시.
@export var percent: float = 100.0
## true 면 방어 스탯 대신 flat 값을 기준으로 쓴다.
@export var use_flat: bool = false
## 고정 기준값 (use_flat 일 때)
@export var flat: int = 0
## 배율 (비우면 1)
@export var multiplier: ValueSource


func apply(ctx: EffectContext) -> void:
	var mult := scale_of(ctx, multiplier)
	if mult <= 0.0:
		return
	var who := stat_unit(ctx)
	var base: float
	if use_flat:
		base = flat
	elif who:
		base = who.get_stat(BattleTypes.Stat.DEFENSE) * percent / 100.0
	else:
		return
	var amount := final_amount(base * mult)
	for t in resolve_targets(ctx):
		ctx.battle.add_block(t, amount, ctx.source)
