@tool
class_name ExileAfterUseRule
extends KeywordRule
## 사용 후 제외: 이 규칙이 있는 키워드가 붙은 카드는 사용한 뒤 제외 더미로 간다.
## 제외 더미의 카드는 이번 전투에서 다시 돌아오지 않는다. (예: 소멸 키워드)
## 카드 대체로 바뀐 카드를 썼다면, 제외 더미에는 원래 카드가 들어간다.


func exiles_after_use() -> bool:
	return true
