@tool
class_name CardEffect
extends Resource
## 효과 부품의 기반 클래스. 카드(CardData.effects)와 상태 트리거가 같은 부품을 같이 쓴다.
## 예: 피해, 방어도, 회복, 상태 부여, 수치 변경, 드로우, 전용 스크립트.
## 새 효과는 이 클래스를 상속해서 apply 를 구현한다. (설계 문서 4.4)


## 효과를 실행한다.
## ctx: 실행 정보(EffectContext — 행위자, 주인, 대상 목록, 이벤트, 이번 사용에서 기록한 값 등)
func apply(_ctx) -> void:
	pass
