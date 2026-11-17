class_name ShopScreen
extends Control
## 상점 화면. shop_screen.tscn 의 스크립트. 의뢰 지도에서 상점 노드로 들어오면 열린다 (StageRun.scene_for).
## 거래 규칙은 Shop(순수 로직)이 하고, 여기서는 진열·버튼을 그리고 누름을 Shop 에 넘기기만 한다.
## 규칙: docs/superpowers/specs/2026-11-17-shop-design.md
##
## 화면 구성 (노드·배치는 shop_screen.tscn 에서 에디터로 고친다):
##   - 위: 공허 조각 수 / 진열 카드 줄 / 진열 아이템 줄 / 카드 제거·카드 강화·나가기 버튼 / 가방
##   - 덱 패널(%DeckPanel): 제거·강화할 카드를 고른다 (파티원 탭 + 의뢰 덱 카드)
##   - 강화 패널(%UpgradePanel): 강화 후보(최대 3장) 중 하나를 고른다
## 진열·덱 카드 한 칸은 shop_card_offer.tscn(카드 + 버튼), 진열 아이템 한 칸은 shop_item_offer.tscn(아이템 칸 + 버튼)을 복제한다.

## 진열·덱·강화 카드 한 칸의 틀 (CardView %Card + Button %Button)
const CARD_OFFER := preload("res://Scenes/ui/shop_screen/shop_card_offer.tscn")
## 진열 아이템 한 칸의 틀 (ItemSlot %Item + Button %Button)
const ITEM_OFFER := preload("res://Scenes/ui/shop_screen/shop_item_offer.tscn")

## 덱 패널을 연 목적
enum Mode { NONE, REMOVE, UPGRADE }

## 가격·진열 개수 (보통 res://shop/shop_data.tres)
@export var shop_data: ShopData

## 이번 상점의 진열과 거래
var shop: Shop
## 덱 패널을 연 목적 (Mode)
var mode: int = Mode.NONE
## 덱 패널에서 보고 있는 파티원
var viewing: BattleUnit = null
## 강화 패널에 띄운 후보들
var upgrade_choices: Array[CardData] = []

var _pool: Array[CardData] = []     # 게임의 카드 전부 (강화 가능 여부 판정용)
var _pick_unit: BattleUnit = null   # 강화하려고 고른 카드의 주인
var _pick_index := -1               # 강화하려고 고른 카드의 의뢰 덱 칸

@onready var _shard_label: Label = %ShardLabel
@onready var _card_row: HBoxContainer = %CardRow
@onready var _item_row: HBoxContainer = %ItemRow
@onready var _remove_button: Button = %RemoveButton
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _bag: BagPanel = %BagPanel
@onready var _deck_panel: Control = %DeckPanel
@onready var _deck_title: Label = %DeckTitle
@onready var _unit_tabs: HBoxContainer = %UnitTabs
@onready var _unit_tab_template: Button = %UnitTabTemplate
@onready var _deck_grid: GridContainer = %DeckGrid
@onready var _deck_cancel: Button = %DeckCancel
@onready var _upgrade_panel: Control = %UpgradePanel
@onready var _upgrade_row: HBoxContainer = %UpgradeRow
@onready var _upgrade_cancel: Button = %UpgradeCancel


func _ready() -> void:
	# 1. 이번 상점: 살아 있는 파티원만 (HP 0 으로 빠진 파티원은 상점에서도 빠진다)
	if shop_data == null:
		shop_data = ShopData.new()
	_pool = CardPool.load_all()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	shop = Shop.new(shop_data, StageRun.living_party(), StageRun.wallet, StageRun.inventory,
			_pool, StageRun.item_pool(), rng)
	# 2. 버튼 연결
	_remove_button.pressed.connect(open_remove)
	_upgrade_button.pressed.connect(open_upgrade)
	_leave_button.pressed.connect(leave)
	_deck_cancel.pressed.connect(close_panels)
	_upgrade_cancel.pressed.connect(close_panels)
	_bag.discard_requested.connect(_on_discard)
	_unit_tab_template.visible = false
	close_panels()


## 화면 전체를 지금 상태로 다시 그린다 (조각 수, 진열, 버튼 가능 여부, 가방, 열린 패널)
func refresh() -> void:
	var wallet := StageRun.wallet
	_shard_label.text = "공허 조각 %d" % wallet.shards
	_draw_cards()
	_draw_items()
	_remove_button.text = "카드 제거 (%d)" % shop_data.remove_price
	_upgrade_button.text = "카드 강화 (%d)" % shop_data.upgrade_price
	_remove_button.disabled = shop.party.is_empty() or not wallet.can_pay(shop_data.remove_price)
	_upgrade_button.disabled = shop.party.is_empty() or not wallet.can_pay(shop_data.upgrade_price)
	_bag.show_items(StageRun.inventory.items, true, -1)
	if _deck_panel.visible:
		_draw_deck()


## 진열 카드 i 를 산다
func click_buy_card(i: int) -> void:
	shop.buy_card(i)
	refresh()


## 진열 아이템 i 를 산다
func click_buy_item(i: int) -> void:
	shop.buy_item(i)
	refresh()


## 카드 제거: 덱 패널을 연다
func open_remove() -> void:
	_open_deck(Mode.REMOVE)


## 카드 강화: 덱 패널을 연다
func open_upgrade() -> void:
	_open_deck(Mode.UPGRADE)


## 덱 패널에서 볼 파티원을 바꾼다 (파티원 탭)
func select_unit(unit: BattleUnit) -> void:
	viewing = unit
	_draw_deck()


## 덱 패널에서 unit 의 의뢰 덱 deck_index 칸 카드를 골랐을 때.
## 제거면 바로 빼고 닫는다. 강화면 후보를 뽑아 강화 패널을 연다.
func pick_deck_card(unit: BattleUnit, deck_index: int) -> void:
	if mode == Mode.REMOVE:
		if shop.remove_card(unit, deck_index):
			close_panels()
	elif mode == Mode.UPGRADE:
		upgrade_choices = shop.upgrade_choices(unit, deck_index)
		if upgrade_choices.is_empty():
			return
		_pick_unit = unit
		_pick_index = deck_index
		_draw_upgrades()
		_upgrade_panel.visible = true


## 강화 패널에서 후보 하나를 골랐을 때: 그 카드로 바꾸고 패널을 닫는다
func pick_upgrade(choice: CardData) -> void:
	if shop.upgrade_card(_pick_unit, _pick_index, choice):
		close_panels()


## 덱·강화 패널을 닫고 다시 그린다
func close_panels() -> void:
	mode = Mode.NONE
	upgrade_choices = []
	_pick_unit = null
	_pick_index = -1
	_deck_panel.visible = false
	_upgrade_panel.visible = false
	refresh()


## 나가기: 상점 노드를 클리어로 처리하고 지도로 (다시 들어올 수 없다)
func leave() -> void:
	StageRun.complete_node()


# --- 내부 ---

## 덱 패널 열기 (첫 파티원부터)
func _open_deck(m: int) -> void:
	if shop.party.is_empty():
		return
	mode = m
	viewing = shop.party[0]
	_deck_title.text = "제거할 카드를 고르세요" if m == Mode.REMOVE else "강화할 카드를 고르세요"
	_deck_panel.visible = true
	_upgrade_panel.visible = false
	_draw_deck()


## 진열 카드 줄 그리기
func _draw_cards() -> void:
	_clear(_card_row)
	for i in shop.cards.size():
		var offer := CARD_OFFER.instantiate()
		_card_row.add_child(offer)
		var card := shop.cards[i]
		var view: CardView = offer.get_node("%Card")
		var button: Button = offer.get_node("%Button")
		if card == null:
			view.visible = false
			button.text = "판매됨"
			button.disabled = true
			continue
		view.set_card(card)
		button.text = "%s · %d" % [shop.card_owners[i].data.display_name, shop_data.card_price]
		button.disabled = not StageRun.wallet.can_pay(shop_data.card_price)
		button.pressed.connect(click_buy_card.bind(i))


## 진열 아이템 줄 그리기 (가방이 가득 차면 살 수 없음)
func _draw_items() -> void:
	_clear(_item_row)
	for i in shop.items.size():
		var offer := ITEM_OFFER.instantiate()
		_item_row.add_child(offer)
		var item := shop.items[i]
		var slot: ItemSlot = offer.get_node("%Item")
		var button: Button = offer.get_node("%Button")
		slot.set_item(item)
		if item == null:
			button.text = "판매됨"
			button.disabled = true
			continue
		button.text = "구매 %d" % shop_data.item_price
		button.disabled = StageRun.inventory.is_full() or not StageRun.wallet.can_pay(shop_data.item_price)
		button.pressed.connect(click_buy_item.bind(i))


## 덱 패널 그리기: 파티원 탭 + 보고 있는 파티원의 의뢰 덱
func _draw_deck() -> void:
	# 1. 파티원 탭 (탭 틀을 복제)
	_clear(_unit_tabs, _unit_tab_template)
	for u in shop.party:
		var tab := _unit_tab_template.duplicate() as Button
		tab.visible = true
		tab.text = u.data.display_name
		tab.button_pressed = u == viewing
		tab.pressed.connect(select_unit.bind(u))
		_unit_tabs.add_child(tab)
	# 2. 의뢰 덱 카드 (강화 모드면 강화 후보가 없는 카드는 못 고름)
	_clear(_deck_grid)
	if viewing == null:
		return
	for i in viewing.run_deck.size():
		var card := viewing.run_deck[i]
		var offer := CARD_OFFER.instantiate()
		_deck_grid.add_child(offer)
		(offer.get_node("%Card") as CardView).set_card(card)
		var button: Button = offer.get_node("%Button")
		if mode == Mode.REMOVE:
			button.text = "제거"
		else:
			button.text = "강화"
			button.disabled = CardPool.upgrade_options(card, _pool).is_empty()
		button.pressed.connect(pick_deck_card.bind(viewing, i))


## 강화 패널 그리기: 후보 카드마다 "선택"
func _draw_upgrades() -> void:
	_clear(_upgrade_row)
	for c in upgrade_choices:
		var offer := CARD_OFFER.instantiate()
		_upgrade_row.add_child(offer)
		(offer.get_node("%Card") as CardView).set_card(c)
		var button: Button = offer.get_node("%Button")
		button.text = "선택"
		button.pressed.connect(pick_upgrade.bind(c))


## 가방의 버리기 칸에 아이템을 끌어다 놓았을 때: 버린다
func _on_discard(index: int) -> void:
	StageRun.inventory.remove_at(index)
	refresh()


## parent 의 자식을 모두 지운다 (keep 은 남김). 바로 빼서 개수가 즉시 맞게 한다
func _clear(parent: Node, keep: Node = null) -> void:
	for c in parent.get_children():
		if c == keep:
			continue
		parent.remove_child(c)
		c.queue_free()
