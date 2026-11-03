@tool
class_name ValueSource
extends Resource
## 효과 수치나 스탯 보정에 곱하는 "배율"의 기반 클래스. (설계 문서 4.4)
## 예) 소모한 핏방울 수만큼 피해 → DamageEffect.multiplier = ConsumedValue("blood_drop")
## 새 배율은 이 클래스를 상속해서 evaluate 를 구현한다.


## 배율 값을 계산한다. ctx: 지금 실행 중인 효과·보정의 정보(EffectContext).
func evaluate(_ctx: EffectContext) -> float:
	return 1.0
