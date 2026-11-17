class_name Inventory
extends RefCounted
## 파티 공용 가방. 소비 아이템(ConsumableData)을 CAPACITY 칸까지 담는다.
## 의뢰마다 StageRun 이 하나 갖고(의뢰 시작 때 비어 있고 끝나면 사라짐), 전투에서는 BattleSession.inventory 로 쓴다.
## 순수 로직 — 화면(BagPanel)은 items 를 읽어 보여 주기만 한다.

## 가방 칸 수 (2026-11-17 사용자 결정: 5칸)
const CAPACITY := 5

## 들어 있는 아이템들. 앞에서부터 채워지고, 빼면 뒤의 것이 당겨진다.
var items: Array[ConsumableData] = []


## 가방이 꽉 찼는지
func is_full() -> bool:
	return items.size() >= CAPACITY


## 맨 뒤에 넣는다. 꽉 찼거나 item 이 없으면 넣지 않고 false.
func add(item: ConsumableData) -> bool:
	if item == null or is_full():
		return false
	items.append(item)
	return true


## index 칸의 아이템을 빼서 돌려준다. 범위 밖이면 null.
func remove_at(index: int) -> ConsumableData:
	if index < 0 or index >= items.size():
		return null
	return items.pop_at(index)


## index 칸의 아이템을 item 으로 바꾼다 (꽉 찬 가방에 드랍이 왔을 때). 범위 밖이거나 item 이 없으면 false.
func replace(index: int, item: ConsumableData) -> bool:
	if item == null or index < 0 or index >= items.size():
		return false
	items[index] = item
	return true
