class_name BagPanel
extends PanelContainer
## 가방 패널: 파티 공용 가방의 5칸을 보여 준다. bag_panel.tscn 의 스크립트 (전투 화면에 하나 들어 있다).
## 칸 5개(ItemSlot)는 씬에 고정으로 들어 있고, 이 스크립트는 내용을 채우고 칸의 누름·뗌을 그대로 알리기만 한다.
## 무엇을 할지(고르기·끌어서 사용)는 전투 화면(BattleScreen)이 정한다.

## 아이템이 있는 칸을 눌렀을 때. index = 가방 칸 번호
signal item_pressed(index: int)
## 누른 칸에서 손을 뗐을 때 (끌고 가서 다른 곳에서 떼도 나온다). index = 가방 칸 번호
signal item_released(index: int)

@onready var _title: Label = %Title           # "가방 (2/5)"
@onready var _slots: HBoxContainer = %Slots   # ItemSlot 5개


func _ready() -> void:
	var all := slots()
	for i in all.size():
		all[i].index = i
		all[i].pressed.connect(func(index): item_pressed.emit(index))
		all[i].released.connect(func(index): item_released.emit(index))


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
