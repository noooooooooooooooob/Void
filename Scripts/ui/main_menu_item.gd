@tool
class_name MainMenuItem
extends Control
## 메인 메뉴 한 줄 (Figma v6 T-B "Menu / 이어하기" 등). 씬: `Scenes/ui/title_screen/main_menu_item.tscn`.
## 번호(01) · 한글 이름(이어하기) · 영문(Continue) 을 보여 주고, 커서가 오면 선택 모양(왼쪽 막대 · 옅어지는 바탕 · 화살표 · 연보라 글자),
## 고를 수 없으면 흐리게 한다. 키보드 커서는 TitleScreen 이 정하고, 이 줄은 마우스 올림·클릭만 알린다.
## @tool 이라 인스펙터에서 글을 바꾸면 에디터 화면에도 바로 보인다.

## 마우스가 이 줄 위에 올라왔다 (TitleScreen 이 커서를 여기로 옮김)
signal hovered
## 이 줄을 클릭했다 (고를 수 없는 줄이면 알리지 않음)
signal pressed

## 번호 글 ("01" ~ "06")
@export var number := "01":
	set(v):
		number = v
		_refresh()
## 한글 이름 ("이어하기")
@export var title_ko := "메뉴":
	set(v):
		title_ko = v
		_refresh()
## 영문 부제 ("Continue")
@export var title_en := "Menu":
	set(v):
		title_en = v
		_refresh()
## 고를 수 없는 줄 (저장이 없을 때의 이어하기·불러오기). 흐리게 보이고 커서가 건너뛴다
@export var disabled := false:
	set(v):
		disabled = v
		_refresh()
## 비활성일 때 줄 전체 투명도 (0~1)
@export_range(0.0, 1.0) var disabled_alpha := 0.35

## 지금 커서가 이 줄에 있는지 (set_selected 로 바꾼다)
var selected := false


func _ready() -> void:
	_refresh()
	if Engine.is_editor_hint():
		return
	mouse_entered.connect(func(): hovered.emit())


func _gui_input(event: InputEvent) -> void:
	# 왼쪽 클릭을 뗐을 때 실행 (고를 수 없으면 무시)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# 처리 표시를 먼저: 새 게임처럼 장면이 바뀌면 이 줄이 트리에서 빠진다
		accept_event()
		if not disabled:
			pressed.emit()


## 커서가 이 줄에 왔는지/떠났는지에 따라 모양을 바꾼다
func set_selected(on: bool) -> void:
	selected = on
	_refresh()


## 글·선택·비활성 모양을 지금 값으로 맞춘다
func _refresh() -> void:
	if not is_node_ready():
		return
	%Number.text = number
	%TitleKo.text = title_ko
	%TitleEn.text = title_en
	# 1. 선택 모양: 막대·바탕·화살표는 선택일 때만
	var sel := selected and not disabled
	%SelBg.visible = sel
	%SelBar.visible = sel
	%Arrow.visible = sel
	# 2. 글 색 (Figma: 선택 = 번호·이름 Accent, 영문 Line / 보통 = 번호 Dim, 이름 Text, 영문 Sub)
	%Number.add_theme_color_override("font_color", UiPalette.ACCENT if sel else UiPalette.DIM)
	%TitleKo.add_theme_color_override("font_color", UiPalette.ACCENT if sel else UiPalette.TEXT)
	var en := UiPalette.LINE if sel else UiPalette.SUB
	en.a = 0.85
	%TitleEn.add_theme_color_override("font_color", en)
	# 3. 비활성은 줄 전체를 흐리게
	modulate.a = disabled_alpha if disabled else 1.0
