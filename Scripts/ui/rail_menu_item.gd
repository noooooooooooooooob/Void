@tool
class_name RailMenuItem
extends Control
## 사무소 왼쪽 레일 메뉴 한 줄 (Figma v6 00-A "Menu / 의뢰 게시판" 등). 씬: `Scenes/ui/office_screen/rail_menu_item.tscn`.
## 번호(01) · 한글 이름 · 영문 · 오른쪽 상태 글("새 의뢰 2건") · 숫자 배지를 보여 주고,
## 그 메뉴의 패널이 열려 있으면 선택 모양(왼쪽 막대 · 옅어지는 바탕 · 패널 쪽 화살표와 연결선)이 된다.
## 클릭하면 pressed 를 알리고, 어떤 패널을 열지는 OfficeScreen 이 정한다.

## 이 줄을 클릭했다
signal pressed

## 배지 색 (Figma 규칙: 빨강 = 새 소식, 호박색 = 할 수 있는 일)
enum BadgeKind { ROSE, AMBER }

## 번호 글 ("01" ~ "07")
@export var number := "01":
	set(v):
		number = v
		_refresh()
## 한글 이름 ("의뢰 게시판")
@export var title_ko := "메뉴":
	set(v):
		title_ko = v
		_refresh()
## 영문 부제 ("Requests")
@export var title_en := "Menu":
	set(v):
		title_en = v
		_refresh()
## 오른쪽 상태 글 ("새 의뢰 2건"). 비우면 안 보임 (시스템이 생기기 전까지 비워 둔다)
@export var status_text := "":
	set(v):
		status_text = v
		_refresh()
## 배지 숫자. 0 이면 배지 숨김
@export var badge_count := 0:
	set(v):
		badge_count = v
		_refresh()
## 배지 색
@export var badge_kind := BadgeKind.ROSE:
	set(v):
		badge_kind = v
		_refresh()
## 빨강 배지 그림 (Art/ui/office/badge_rose.svg)
@export var rose_badge: Texture2D
## 호박색 배지 그림 (Art/ui/office/badge_amber.svg)
@export var amber_badge: Texture2D
## 마우스를 올렸을 때 바탕 투명도 (선택 바탕의 몇 배, 0~1)
@export_range(0.0, 1.0) var hover_strength := 0.45

## 이 메뉴의 패널이 열려 있는지 (set_selected 로 바꾼다)
var selected := false
var _hover := false


func _ready() -> void:
	_refresh()
	if Engine.is_editor_hint():
		return
	mouse_entered.connect(func():
		_hover = true
		_refresh())
	mouse_exited.connect(func():
		_hover = false
		_refresh())


func _gui_input(event: InputEvent) -> void:
	# 왼쪽 클릭을 뗐을 때 알린다
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pressed.emit()
		accept_event()


## 패널이 열렸는지/닫혔는지에 따라 모양을 바꾼다
func set_selected(on: bool) -> void:
	selected = on
	_refresh()


## 글·배지·선택 모양을 지금 값으로 맞춘다
func _refresh() -> void:
	if not is_node_ready():
		return
	%Number.text = number
	%TitleKo.text = title_ko
	%TitleEn.text = title_en
	# 1. 상태 글·배지 (비었으면 숨김)
	%Status.text = status_text
	%Status.visible = not status_text.is_empty()
	%Badge.visible = badge_count > 0
	%BadgeCount.text = str(badge_count)
	%Badge.texture = amber_badge if badge_kind == BadgeKind.AMBER else rose_badge
	# 배지 숫자 색: 빨강 배지 = 밝은 글자, 호박색 배지 = 어두운 글자 (Figma)
	%BadgeCount.add_theme_color_override("font_color", UiPalette.INK if badge_kind == BadgeKind.AMBER else UiPalette.TEXT)
	# 2. 선택 모양: 막대·화살표·연결선은 선택일 때만, 바탕은 마우스를 올려도 옅게
	%SelBar.visible = selected
	%Pointer.visible = selected
	%Link.visible = selected
	%SelBg.visible = selected or _hover
	%SelBg.modulate.a = 1.0 if selected else hover_strength
	# 3. 글 색 (Figma: 선택 = 번호·이름 Accent, 영문 Line, 상태 Text / 보통 = 번호 Dim, 이름 Text, 영문 Sub 80%, 상태 Sub)
	%Number.add_theme_color_override("font_color", UiPalette.ACCENT if selected else UiPalette.DIM)
	%TitleKo.add_theme_color_override("font_color", UiPalette.ACCENT if selected else UiPalette.TEXT)
	var en := UiPalette.LINE if selected else UiPalette.SUB
	if not selected:
		en.a = 0.8
	%TitleEn.add_theme_color_override("font_color", en)
	%Status.add_theme_color_override("font_color", UiPalette.TEXT if selected else UiPalette.SUB)
