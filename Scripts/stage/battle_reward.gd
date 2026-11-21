class_name BattleReward
extends RefCounted
## 의뢰 전투 한 번의 승리 보상과 챙기기. 전투 화면(BattleScreen)이 승리 때 하나 만들고, 결과 창의 보상 줄을 누르면 여기 함수를 부른다.
## 순수 로직 — 무엇을 줄지(드랍 판정·카드 후보 뽑기)는 만드는 쪽이 정해서 넘긴다.
##
## 규칙 (docs/superpowers/specs/2026-11-19-battle-rewards-design.md):
## - 보상마다 한 번만 챙긴다. 챙기면 그 보상은 비워진다 (조각 0, 아이템 null, 카드 빈 배열)
## - 아이템: 가방에 빈 칸이 있을 때만 받는다. 가득 차면 한 칸과 바꾸거나 두고 간다
## - 카드: 후보 중 1장을 골라 그 카드 주인의 의뢰 덱(BattleUnit.run_deck) 맨 뒤로. UnitData.deck 원본은 그대로
## - 안 챙긴 보상은 결과 창을 떠나면 사라진다 (여기서는 아무것도 하지 않으면 된다)

## 남은 공허 조각 (0 = 없거나 챙김)
var shards := 0
## 남은 소비 아이템 (null = 없거나 챙김)
var item: ConsumableData = null
## 카드 보상 후보 (빈 배열 = 없거나 챙김). 고른 1장만 받는다
var cards: Array[CardData] = []
## 카드 후보마다 주인 캐릭터 (cards 와 같은 길이, 같은 순서)
var card_owners: Array[BattleUnit] = []


## shard_amount: 공허 조각 수 / drop: 드랍 아이템(없으면 null)
## card_offer·owners: 카드 후보와 주인 (CardPool.pick_party_cards 의 결과, 없으면 빈 배열)
func _init(shard_amount: int, drop: ConsumableData, card_offer: Array[CardData], owners: Array[BattleUnit]) -> void:
	shards = shard_amount
	item = drop
	cards = card_offer.duplicate()
	card_owners = owners.duplicate()


## 공허 조각을 지갑에 넣는다. 남은 조각이 없으면 false.
func claim_shards(wallet: Wallet) -> bool:
	if shards <= 0:
		return false
	wallet.add(shards)
	shards = 0
	return true


## 아이템을 가방 빈 칸에 넣는다. 아이템이 없거나 가방이 가득 차면 false (아무것도 바뀌지 않음).
func claim_item(inventory: Inventory) -> bool:
	if item == null or not inventory.add(item):
		return false
	item = null
	return true


## 가방 index 칸의 아이템을 버리고 보상 아이템으로 바꾼다. 아이템이 없거나 칸이 잘못되면 false.
func swap_item(inventory: Inventory, index: int) -> bool:
	if item == null or not inventory.replace(index, item):
		return false
	item = null
	return true


## 카드 후보 index 를 골라 주인의 의뢰 덱 맨 뒤에 넣는다. 나머지 후보는 사라진다.
## 후보가 없거나 index 가 범위 밖이면 false.
func claim_card(index: int) -> bool:
	if index < 0 or index >= cards.size():
		return false
	card_owners[index].run_deck.append(cards[index])
	cards.clear()
	card_owners.clear()
	return true


## 챙길 보상이 하나도 남지 않았는지
func is_empty() -> bool:
	return shards <= 0 and item == null and cards.is_empty()
