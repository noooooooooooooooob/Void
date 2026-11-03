@tool
class_name CardCondition
extends Resource
## 카드 사용 조건 부품의 기반 클래스. CardData.conditions 에 넣는다.
## 비용과 달리 아무것도 소모하지 않고 확인만 한다.
## 예: HasStatusCondition(특정 상태 수치 이상). 새 조건은 이 클래스를 상속해서 check 를 구현한다.
## (근접 카드의 "같은 행에 적이 있어야 함"은 전투 쪽에서 자동으로 확인한다.)


## 조건을 만족하는지. 하나라도 false 면 카드를 쓸 수 없다.
## ctx: 이번 카드 사용의 정보
func check(_ctx: EffectContext) -> bool:
	return true
