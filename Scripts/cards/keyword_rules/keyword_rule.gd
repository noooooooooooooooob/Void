@tool
class_name KeywordRule
extends Resource
## 키워드 규칙 부품의 기반 클래스. KeywordData.rules 에 넣는다 (카드의 Effects 와 같은 방식).
## 특별한 동작이 있는 키워드에만 부품을 넣고, 나머지 키워드는 rules 를 비워 둔다.
## 예) 소멸 → ExileAfterUseRule (사용 후 제외)
##     개전 → (나중에) 첫 드로우 보장 규칙
## 새 동작은 이 클래스를 상속해서, 전투가 묻는 함수를 구현한다.
## 전투는 카드에 붙은 키워드들의 규칙을 모두 확인한다.


## 이 규칙이 붙은 카드는 사용 후 버린 더미 대신 제외 더미로 가는가
func exiles_after_use() -> bool:
	return false
