@tool
class_name DamageEffect
extends CardEffect
## 피해 효과. 대상마다 피해를 주고, 방어도·스태미너·사망 처리는 Battle.apply_damage 가 한다.
##
## 수치 (기획 결정):
##   일반:   공격 × percent/100 × 배율 × (치명이면 치명피해/100) → 마지막에 내림, 최소 1
##   고정값: flat × 배율 × (치명) → 출혈 같은 고정 피해. 고정 피해도 방어도·치명·스태미너 규칙을 똑같이 따른다
##   배율이 0 이하이면 아무것도 하지 않는다.
## 치명: 피해 효과에만, 맞는 유닛마다 따로 판정. 행위자가 없으면(상태로 생긴 피해) 치명 없음.
## 상태로 생긴 피해(출혈 등)는 행위자가 없으므로 아무도 스태미너를 회복하지 않는다 (사용자 결정).
## 예) 피의 참격: percent 40, multiplier = 소모한 핏방울 수 → 공격 100, 5 소모면 200 피해

## 공격 스탯의 몇 % 인지 (100 = 공격과 같은 값). use_flat 이면 무시.
@export var percent: float = 100.0
## true 면 공격 스탯 대신 flat 값을 기준으로 쓴다 (고정 피해).
@export var use_flat: bool = false
## 고정 피해 기준값 (use_flat 일 때)
@export var flat: int = 0
## 배율 (비우면 1). 예: 상태 수치, 소모한 수치.
@export var multiplier: ValueSource
## 치명타가 터질 수 있는지
@export var can_crit: bool = true


func apply(ctx: EffectContext) -> void:
	var mult := scale_of(ctx, multiplier)
	if mult <= 0.0:
		return
	var who := stat_unit(ctx)
	# 기준값: 고정값이면 flat, 아니면 공격 × %. 스탯 주인이 없으면 고정값만 가능.
	var base: float
	if use_flat:
		base = flat
	elif who:
		base = who.get_stat(BattleTypes.Stat.ATTACK) * percent / 100.0
	else:
		return
	for t in resolve_targets(ctx):
		var value := base * mult
		# 치명 판정은 대상마다 따로. 행위자 기준 치명확률·치명피해.
		if can_crit and ctx.actor:
			var rate := ctx.actor.get_stat(BattleTypes.Stat.CRIT_RATE)
			if ctx.battle.rng.randf() * 100.0 < rate:
				value *= ctx.actor.get_stat(BattleTypes.Stat.CRIT_DAMAGE) / 100.0
		ctx.battle.apply_damage(ctx.actor, t, final_amount(value), ctx.source, ctx.applier)
