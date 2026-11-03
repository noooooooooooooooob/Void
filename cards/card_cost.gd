@tool
class_name CardCost
extends Resource
## 카드 사용 비용 부품의 기반 클래스. CardData.costs 에 넣는다.
## SP 는 CardData.sp 로 자동 처리하므로, 여기에는 SP 외의 추가 비용만 만든다.
## 예: StatusCost(상태 수치 소모). 새 비용은 이 클래스를 상속해서 두 함수를 구현한다.
## (설계 문서 4.2)


## 지금 이 비용을 낼 수 있는지. 하나라도 false 면 카드를 쓸 수 없다.
## ctx: 이번 카드 사용의 정보(EffectContext — 사용자, 카드, 대상 등)
func can_pay(_ctx) -> bool:
	return true


## 비용을 실제로 지불한다. 지불한 양은 ctx.values 에 기록해서 효과가 참조할 수 있게 한다.
func pay(_ctx) -> void:
	pass
