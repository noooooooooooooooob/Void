@tool
class_name MissingHpPercentValue
extends ValueSource
## 잃은 HP 비율(0~100)을 배율로 쓴다. HP 가 가득이면 0, 절반이면 50.
## 예) 피의 갈망: HP 가 적을수록 공격력 증가 → StatModifier(ATTACK, PERCENT, amount, scale = 이것)

## 누구의 HP 를 볼지. OWNER = 상태 주인, ACTOR = 행위자.
@export var of: BattleTypes.Who = BattleTypes.Who.OWNER


func _init(who: int = BattleTypes.Who.OWNER) -> void:
	of = who


func evaluate(ctx: EffectContext) -> float:
	var u := ctx.who(of)
	if u == null:
		return 0.0
	var max_hp := u.get_stat(BattleTypes.Stat.HP)
	if max_hp <= 0:
		return 0.0
	return (1.0 - float(u.hp) / max_hp) * 100.0
