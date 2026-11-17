class_name Shop
extends RefCounted
## 상점 한 번(상점 노드에 들어갔을 때)의 진열과 거래. 상점 화면(ShopScreen)이 하나 만들어 쓴다.
## 순수 로직 — 화면은 cards/items 를 보여 주고 버튼마다 여기 함수를 부르기만 한다.
##
## 규칙 (docs/superpowers/specs/2026-11-17-shop-design.md):
## - 진열 카드: 파티 캐릭터의 카드만 (CardPool.cards_for), 겹치지 않게 card_count 장. 산 카드는 그 캐릭터의 의뢰 덱 맨 뒤로
## - 진열 아이템: 후보 중 겹치지 않게 item_count 개. 가방이 가득 차면 못 산다
## - 카드 제거·강화: 의뢰 덱(BattleUnit.run_deck)의 한 칸만 바꾼다. UnitData 원본은 그대로
## - 카드 강화: 원래 카드의 강화 중 지금 카드를 뺀 것에서 최대 3개를 보여 주고 하나로 바꾼다
## - 파티 = 살아 있는 파티원만 (HP 0 으로 빠진 파티원은 상점에서도 빠진다). 파티 밖 유닛은 거래 불가
## - 가격은 고정. 조각이 모자라거나 칸이 잘못되면 false 이고 아무것도 바뀌지 않는다

## 강화 때 보여 줄 후보 최대 수 (상점 설계 2026-11-17)
const UPGRADE_CHOICES := 3

## 진열 카드 (산 칸은 null)
var cards: Array[CardData] = []
## 진열 카드마다 주인 캐릭터 (cards 와 같은 길이). 사면 이 유닛의 의뢰 덱으로 들어간다
var card_owners: Array[BattleUnit] = []
## 진열 소비 아이템 (산 칸은 null)
var items: Array[ConsumableData] = []
## 가격·개수 설정
var data: ShopData
## 상점에서 거래할 수 있는 파티원 (살아 있는 파티원)
var party: Array[BattleUnit] = []

var _wallet: Wallet
var _inventory: Inventory
var _pool: Array[CardData] = []
var _rng: RandomNumberGenerator


## shop_data: 가격·개수 / party_units: 살아 있는 파티원 / wallet: 공허 조각 / inventory: 파티 가방
## card_pool: 게임의 카드 전부 (CardPool.load_all) / item_pool: 소비 아이템 후보 / rng: 진열·강화 후보용 난수
## 만들 때 진열을 채운다.
func _init(shop_data: ShopData, party_units: Array[BattleUnit], wallet: Wallet, inventory: Inventory,
		card_pool: Array[CardData], item_pool: Array[ConsumableData], rng: RandomNumberGenerator) -> void:
	data = shop_data
	party = party_units
	_wallet = wallet
	_inventory = inventory
	_pool = card_pool
	_rng = rng
	_stock_cards()
	_stock_items(item_pool)


## index 칸의 카드를 산다: 조각을 내고 주인의 의뢰 덱 맨 뒤에 넣고 칸을 비운다.
func buy_card(index: int) -> bool:
	if index < 0 or index >= cards.size() or cards[index] == null:
		return false
	if not _wallet.pay(data.card_price):
		return false
	card_owners[index].run_deck.append(cards[index])
	cards[index] = null
	return true


## index 칸의 소비 아이템을 산다: 가방이 가득 찼으면 실패.
func buy_item(index: int) -> bool:
	if index < 0 or index >= items.size() or items[index] == null:
		return false
	if _inventory.is_full() or not _wallet.can_pay(data.item_price):
		return false
	_wallet.pay(data.item_price)
	_inventory.add(items[index])
	items[index] = null
	return true


## unit 의 의뢰 덱에서 deck_index 칸의 카드를 뺀다.
func remove_card(unit: BattleUnit, deck_index: int) -> bool:
	if not _valid_slot(unit, deck_index):
		return false
	if not _wallet.pay(data.remove_price):
		return false
	unit.run_deck.remove_at(deck_index)
	return true


## unit 의 의뢰 덱 deck_index 칸 카드를 강화할 때 보여 줄 후보 (최대 3개, 많으면 무작위로 겹치지 않게).
## 강화할 수 없는 카드거나 칸이 잘못되면 빈 배열.
func upgrade_choices(unit: BattleUnit, deck_index: int) -> Array[CardData]:
	if not _valid_slot(unit, deck_index):
		return []
	var out: Array[CardData] = []
	out.assign(_pick(CardPool.upgrade_options(unit.run_deck[deck_index], _pool), UPGRADE_CHOICES))
	return out


## unit 의 의뢰 덱 deck_index 칸을 choice 로 바꾼다. choice 는 그 카드의 강화 후보여야 한다.
func upgrade_card(unit: BattleUnit, deck_index: int, choice: CardData) -> bool:
	if not _valid_slot(unit, deck_index):
		return false
	if not choice in CardPool.upgrade_options(unit.run_deck[deck_index], _pool):
		return false
	if not _wallet.pay(data.upgrade_price):
		return false
	unit.run_deck[deck_index] = choice
	return true


## 파티원이고 그 의뢰 덱에 그 칸이 있는지
func _valid_slot(unit: BattleUnit, deck_index: int) -> bool:
	return unit in party and deck_index >= 0 and deck_index < unit.run_deck.size()


## 진열 카드 채우기: 파티원마다 그 캐릭터의 카드를 모아(주인 기억) 겹치지 않게 card_count 장
func _stock_cards() -> void:
	var candidates: Array[CardData] = []
	var owner_of := {}  # 카드 → 주인 (같은 카드가 두 캐릭터에 걸리면 먼저 찾은 쪽)
	for u in party:
		for c in CardPool.cards_for(u.data, _pool):
			if not owner_of.has(c):
				owner_of[c] = u
				candidates.append(c)
	for c in _pick(candidates, data.card_count):
		cards.append(c)
		card_owners.append(owner_of[c])


## 진열 아이템 채우기: 후보에서 겹치지 않게 item_count 개
func _stock_items(item_pool: Array[ConsumableData]) -> void:
	var unique: Array[ConsumableData] = []
	for i in item_pool:
		if i and not i in unique:
			unique.append(i)
	items.assign(_pick(unique, data.item_count))


## arr 에서 겹치지 않게 최대 n 개를 무작위로 고른다 (원래 배열은 그대로)
func _pick(arr: Array, n: int) -> Array:
	var rest := arr.duplicate()
	var out := []
	while out.size() < n and not rest.is_empty():
		out.append(rest.pop_at(_rng.randi_range(0, rest.size() - 1)))
	return out
