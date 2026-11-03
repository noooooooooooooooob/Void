@tool
class_name CardCost
extends Resource
## 카드 사용 비용 부품의 기반 클래스. SP는 CardData.sp 로 처리하므로 여기엔 추가 비용만 둔다.

func can_pay(_ctx) -> bool:
	return true

func pay(_ctx) -> void:
	pass
