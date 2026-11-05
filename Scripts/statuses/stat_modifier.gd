@tool
class_name StatModifier
extends Resource
## 스탯 보정 하나. 상태(StatusData.modifiers)에 넣어서 그 상태를 가진 유닛의 스탯을 바꾼다.
## 장비 보너스도 장비가 붙여 주는 상태의 보정으로 표현한다.
##
## 계산 (설계 문서 3.4, 기획 결정):
##   최종 스탯 = floor(기본값 × (1 + PERCENT 보정 합 / 100)) + FLAT 보정 합
##   % 보정은 여러 개면 곱하지 않고 더한다. % 를 먼저 적용하고 고정값은 나중에 더한다.
##   예) 기본 100, +20%, +10%, +15 → 100 × 1.3 + 15 = 145
##
## 이 보정 하나의 기여값 = amount × scale (scale 이 없으면 amount 그대로).
##   예) "혈갑 수치당 공격력 +5%" = stat ATTACK, kind PERCENT, amount 5, scale = 혈갑 수치(StackCountValue)

## 바꿀 스탯 (BattleTypes.Stat)
@export var stat: BattleTypes.Stat = BattleTypes.Stat.ATTACK
## PERCENT: amount 가 퍼센트(20 = +20%). FLAT: amount 를 그대로 더함. 음수면 감소.
@export var kind: BattleTypes.ModKind = BattleTypes.ModKind.PERCENT
## 보정량. 단위는 kind 에 따라 % 또는 스탯 값.
@export var amount: float = 0.0
## 보정량에 곱할 값 (비우면 1). 예: 상태 수치, 잃은 HP 비율.
@export var scale: ValueSource


## 이 보정이 지금 기여하는 값. ctx 는 보정 주인 기준(actor = owner = 그 유닛).
func contribution(ctx: EffectContext) -> float:
	return amount * (scale.evaluate(ctx) if scale else 1.0)
