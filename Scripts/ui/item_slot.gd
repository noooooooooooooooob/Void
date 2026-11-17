class_name ItemSlot
extends PanelContainer
## 소비 아이템 칸 하나 (이름 + 효과 줄). item_slot.tscn 의 스크립트.
## 가방 패널(BagPanel)의 5칸과 결과 창의 "바꿀 칸 고르기"에서 쓴다.
## 왼쪽 버튼을 누르면 pressed, 누른 뒤 떼면 released 를 낸다 — 전투 화면이 이것으로 카드처럼 끌어서 쓴다.
## (마우스를 누른 칸이 뗄 때의 입력도 받으므로, 다른 곳까지 끌고 가서 떼도 released 가 나온다)
## 빈 칸은 눌러도 아무것도 내지 않는다.

## 아이템이 있는 칸에서 왼쪽 버튼을 눌렀을 때. index = 가방 칸 번호
signal pressed(index: int)
## pressed 를 낸 뒤 왼쪽 버튼을 뗐을 때 (어디서 떼든). index = 가방 칸 번호
signal released(index: int)

## 고른 칸의 패널 색 배율 (1 보다 크면 밝아짐)
@export var selected_tint := Color(1.6, 1.5, 0.9)
## 지금 쓸 수 없는 아이템의 어두운 색 (카드의 CardView.set_dimmed 와 같은 값)
@export var dimmed_tint := Color(0.45, 0.45, 0.45)

## 가방에서 이 칸의 번호 (0 부터). 패널이 정해 준다.
var index := 0
## 이 칸의 아이템 (빈 칸이면 null)
var item: ConsumableData = null

@onready var _name: Label = %Name    # 아이템 이름
@onready var _lines: Label = %Lines  # 효과 줄 ("HP 회복 +30")
var _down := false      # 이 칸에서 누른 채인지 (released 를 한 번만 내려고)
var _dimmed := false
var _selected := false


func _ready() -> void:
	_refresh()  # 트리에 들어가기 전에 set_item 을 불렀으면 여기서 그린다


## 보여 줄 아이템을 정한다. null 이면 빈 칸 (이름·효과 줄·설명 풍선을 비움).
func set_item(new_item: ConsumableData) -> void:
	item = new_item
	_refresh()


## 지금 쓸 수 없는 아이템을 어둡게 표시한다 (적 차례·연출 중·전투 끝).
func set_dimmed(on: bool) -> void:
	_dimmed = on
	_refresh()


## 고른(끌고 있는) 칸을 밝게 표시한다.
func set_selected(on: bool) -> void:
	_selected = on
	_refresh()


## 어둡게 표시 중인지
func is_dimmed() -> bool:
	return _dimmed


## 고른 칸으로 표시 중인지
func is_selected() -> bool:
	return _selected


func _refresh() -> void:
	if not is_node_ready():
		return
	_name.text = item.display_name if item else ""
	_lines.text = item.describe_lines() if item else ""
	# 마우스를 올리면 뜨는 풍선: 이름 + 설명 + 효과 줄 (빈 줄은 뺀다)
	var tip := PackedStringArray()
	if item:
		for t in [item.display_name, item.description_ko, item.describe_lines()]:
			if not t.is_empty():
				tip.append(t)
	tooltip_text = "\n".join(tip)
	modulate = dimmed_tint if _dimmed else Color.WHITE
	self_modulate = selected_tint if _selected else Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		if item == null:
			return
		_down = true
		pressed.emit(index)
	elif _down:
		_down = false
		released.emit(index)
