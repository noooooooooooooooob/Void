@tool
class_name KeywordRule
extends Resource
## 키워드 규칙 부품의 기반 클래스. KeywordData.rules 에 넣는다 (카드의 Effects 와 같은 방식).
## 특별한 동작이 있는 키워드에만 부품을 넣고, 나머지 키워드는 rules 를 비워 둔다.
## 예) 소멸 → ExileAfterUseRule (사용 후 제외)
##     개전 → (나중에) 첫 드로우 보장 규칙
##
## 카드 효과(CardEffect.apply)처럼, 규칙 부품이 정해진 시점에 직접 일을 한다.
## 전투가 시점마다 카드에 붙은 키워드들의 규칙 함수를 부르고, 규칙은 ctx.battle 의 기능으로 처리한다.
## 새 동작은 이 클래스를 상속해서, 필요한 시점 함수를 구현한다. (새 시점이 필요하면 여기에 추가)


## 카드를 사용한 직후 (효과가 모두 실행된 뒤, 카드가 손패에서 빠진 상태).
## ctx: 이번 카드 사용의 정보 (ctx.actor = 사용한 유닛, ctx.card = 실제로 쓴 카드)
## card: 옮길 카드 = 원래 카드 (카드 대체로 바뀐 카드를 썼어도 원래 카드가 옮겨진다)
## 반환: 이 규칙이 카드를 어딘가로 옮겼으면 true. 아무 규칙도 옮기지 않으면 버린 더미로 간다.
func after_use(_ctx: EffectContext, _card: CardData) -> bool:
	return false
