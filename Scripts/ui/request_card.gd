class_name RequestCard
extends Control
## 의뢰 게시판 왼쪽 목록의 카드 한 장 (Figma v6 01-A "Request Card"). 씬: `Scenes/ui/office_screen/request_card.tscn`.
## RequestsBoard 가 의뢰 수만큼 이 씬을 instantiate 해서 목록에 넣고 set_request 로 채운다.
## 보통·선택·잠김 세 모양을 판 그림(Plate·PlateSelected·PlateLocked)을 바꿔 보여 준다. 어떤 카드를 고를지는 RequestsBoard 가 정한다.
## 설계 docs/superpowers/specs/2026-11-24-request-board-design.md 4-1.

## 카드를 클릭했다 (잠긴 카드는 알리지 않음)
signal pressed

## 카드 칩 그림: 긴급(빨강 꽉 참) · 반복(청록 테두리) · 본 이야기(연보라 테두리)
const CHIP_URGENT := preload("res://Art/ui/requests/chip_urgent.svg")
const CHIP_REPEAT := preload("res://Art/ui/requests/chip_repeat.svg")
const CHIP_MAIN := preload("res://Art/ui/requests/chip_main.svg")
## 난이도 ◆ 밝은 것 / 어두운 것
const DIFF_ON := preload("res://Art/ui/requests/diff_on.svg")
const DIFF_OFF := preload("res://Art/ui/requests/diff_off.svg")

## 잠긴 카드 높이 (px, Figma 92). 보통 카드 높이는 씬에 놓인 크기
@export var locked_height := 92.0
## 칩 안 글자 양옆 여백 (px, Figma 10)
@export var chip_padding := 10.0

## 이 카드가 보여 주는 의뢰
var request: RequestData
## 지금 선택된 카드인지 (set_selected 로 바꾼다)
var selected := false

var _normal_height := 146.0  # 씬에 놓인 보통 카드 높이


func _ready() -> void:
	_normal_height = custom_minimum_size.y if custom_minimum_size.y > 0 else size.y


func _gui_input(event: InputEvent) -> void:
	# 왼쪽 클릭을 뗐을 때 알림 (잠긴 카드는 무시)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		accept_event()
		if request and request.is_selectable():
			pressed.emit()


## 의뢰를 넣고 글·칩·난이도·잠김 모양을 맞춘다
func set_request(r: RequestData) -> void:
	request = r
	_refresh()


## 선택 모양을 켜고 끈다 (빛나는 판 + 제목 연보라)
func set_selected(on: bool) -> void:
	selected = on
	_refresh()


## 지금 값으로 화면을 맞춘다
func _refresh() -> void:
	if request == null:
		return
	var locked := request.locked
	# 1. 크기와 판: 잠김 = 낮은 판, 선택 = 빛나는 판, 그 밖 = 보통 판
	custom_minimum_size.y = locked_height if locked else _normal_height
	size.y = custom_minimum_size.y
	%Plate.visible = not locked and not selected
	%PlateSelected.visible = not locked and selected
	%PlateLocked.visible = locked
	# 2. 보통 카드 내용 / 잠긴 카드 내용
	for n in [%Chip, %Code, %Title, %Client, %Reward, %Difficulty]:
		n.visible = not locked
	for n in [%LockedTitle, %LockedHint, %LockedLabel]:
		n.visible = locked
	if locked:
		%LockedTitle.text = request.card_title()
		%LockedHint.text = request.unlock_hint
		return
	# 3. 글
	%Code.text = request.code
	%Title.text = request.card_title()
	%Title.add_theme_color_override("font_color", UiPalette.ACCENT if selected else UiPalette.TEXT)
	%Client.text = request.client_line()
	%Reward.text = request.reward_text
	# 4. 칩 (Figma: 긴급 = Rose 바탕 + Ink 글, 반복 = Teal, 본 이야기 = Accent)
	var chip_text := "본편"
	var chip_tex: Texture2D = CHIP_MAIN
	var chip_color := UiPalette.ACCENT
	if request.urgent:
		chip_text = "긴급"
		chip_tex = CHIP_URGENT
		chip_color = UiPalette.INK
	elif request.kind == RequestData.Kind.REPEAT:
		chip_text = "반복"
		chip_tex = CHIP_REPEAT
		chip_color = UiPalette.TEAL
	%Chip.texture = chip_tex
	%ChipLabel.text = chip_text
	%ChipLabel.add_theme_color_override("font_color", chip_color)
	# 칩 폭 = 글 폭 + 양옆 여백
	%Chip.size.x = %ChipLabel.get_minimum_size().x + chip_padding * 2
	# 5. 난이도 ◆: difficulty 개만 밝게
	var diamonds: Array[Node] = %Difficulty.get_children()
	for i in diamonds.size():
		(diamonds[i] as TextureRect).texture = DIFF_ON if i < request.difficulty else DIFF_OFF
