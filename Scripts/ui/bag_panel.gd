class_name BagPanel
extends PanelContainer
## 가방 패널: 파티 공용 가방의 5칸을 보여 준다. bag_panel.tscn 의 스크립트 (전투 화면에 하나 들어 있다).
## 칸 5개(ItemSlot)는 씬에 고정으로 들어 있고, 이 스크립트는 내용을 채우고 칸의 누름·뗌을 그대로 알리기만 한다.
## 무엇을 할지(고르기·끌어서 사용)는 전투 화면(BattleScreen)·상점 화면(ShopScreen)이 정한다.
## 버리기 (상점 설계 2026-11-17): 아이템 칸을 누른 채 끌어 "버리기" 칸(%DiscardZone) 위에서 떼면 discard_requested 를 낸다.

## 아이템이 있는 칸을 눌렀을 때. index = 가방 칸 번호
signal item_pressed(index: int)
## 누른 칸에서 손을 뗐을 때 (끌고 가서 다른 곳에서 떼도 나온다). index = 가방 칸 번호
signal item_released(index: int)
## 아이템 칸을 끌어 버리기 칸 위에서 뗐을 때 (item_released 대신 이것만 나온다). index = 가방 칸 번호
signal discard_requested(index: int)

## 버리기 칸에서 떼면 discard_requested 를 낼지. false 면 버리기 칸 위에서 떼도 보통의 item_released 만 나온다
@export var allow_discard := true

@onready var _title: Label = %Title           # "가방 (2/5)"
@onready var _slots: HBoxContainer = %Slots   # ItemSlot 5개
@onready var _discard: Control = %DiscardZone # 버리기 칸 (아이템을 끌어 여기서 떼면 버림)


func _ready() -> void:
	var all := slots()
	for i in all.size():
		all[i].index = i
		all[i].pressed.connect(func(index): item_pressed.emit(index))
		all[i].released.connect(func(index): _on_slot_released(index, get_global_mouse_position()))


## 가방 내용을 다시 그린다.
## items: 가방의 아이템들 (칸 수보다 적으면 나머지는 빈 칸)
## usable: 지금 아이템을 쓸 수 있는지 (false 면 아이템을 어둡게)
## selected: 고른 칸 번호 (없으면 -1)
func show_items(items: Array[ConsumableData], usable: bool, selected: int) -> void:
	var all := slots()
	for i in all.size():
		var item: ConsumableData = items[i] if i < items.size() else null
		all[i].set_item(item)
		all[i].set_dimmed(item != null and not usable)
		all[i].set_selected(item != null and i == selected)
	_title.text = "가방 (%d/%d)" % [items.size(), all.size()]


## 칸들 (왼쪽부터)
func slots() -> Array[ItemSlot]:
	var out: Array[ItemSlot] = []
	for c in _slots.get_children():
		if c is ItemSlot:
			out.append(c)
	return out


## 화면 위치 global_pos 가 버리기 칸 위인지
func is_over_discard(global_pos: Vector2) -> bool:
	return _discard.get_global_rect().has_point(global_pos)


## 누른 칸에서 손을 뗐을 때 (global_pos = 뗀 화면 위치): 버리기 칸 위면 버리기, 아니면 보통의 뗌으로 알린다
func _on_slot_released(index: int, global_pos: Vector2) -> void:
	if allow_discard and is_over_discard(global_pos):
		discard_requested.emit(index)
	else:
		item_released.emit(index)
