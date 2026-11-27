class_name TitleScreen
extends Control
## 게임 시작 화면 (메인 씬). Figma v6 의 T-A 타이틀과 T-B 메인 메뉴를 한 씬에서 오간다.
## 설계 docs/superpowers/specs/2026-11-21-ui-frame-design.md 5-1.
##
## - TITLE 상태: 가운데 로고 + "PRESS ANY KEY" 깜빡임. 아무 키·클릭 → MENU 상태
## - MENU 상태: 로고가 왼쪽 위로 움직이고 메뉴 6줄이 나타남. ↑↓/W·S 이동, Enter/Space 실행, ESC → TITLE 상태
## - 메뉴: 이어하기·불러오기(저장 기능 전까지 비활성) / 새 게임 → 사무소 / 설정 → 설정 창(%SettingsPanel) / 제작진 → "준비 중" / 종료

## 화면 상태
enum State { TITLE, MENU }
## 메뉴 줄 순서 (씬의 %Menu 자식 순서와 같아야 한다)
enum Item { CONTINUE, NEW_GAME, LOAD, SETTINGS, CREDITS, QUIT }

## 새 게임을 누르면 넘어갈 씬. 인스펙터에서 office_screen.tscn 을 끌어다 넣는다
@export var office_scene: PackedScene
## 저장된 게임이 있는지. 저장 기능이 생기기 전까지 false (이어하기·불러오기 비활성, 최근 저장 카드 숨김)
@export var save_available := false
## 메뉴 상태에서 로고가 갈 자리 (화면 왼쪽 위 기준 픽셀, Figma T-B Logo 위치)
@export var menu_logo_position := Vector2(120, 110)
## 로고 이동·메뉴 나타나기에 걸리는 시간 (초)
@export var transition_time := 0.5
## "PRESS ANY KEY" 가 한 번 흐려졌다 돌아오는 시간 (초)
@export var blink_time := 1.6

## 지금 상태 (테스트에서도 읽는다)
var state := State.TITLE
## 메뉴 커서가 있는 줄 (Item 값, 없으면 -1)
var cursor := -1

var _title_logo_position := Vector2.ZERO  # 타이틀 상태의 로고 자리 (씬에 놓인 자리를 기억)
var _cursor_rule: MenuCursor
var _tween: Tween
var _blink: Tween

@onready var _logo: Control = %Logo
@onready var _menu: Control = %Menu
var _items: Array[MainMenuItem] = []  # 메뉴 줄 (Item 순서)


func _ready() -> void:
	# 1. 메뉴 줄 모으기, 저장이 없으면 이어하기·불러오기 비활성
	for c in _menu.get_children():
		if c is MainMenuItem:
			_items.append(c)
	_items[Item.CONTINUE].disabled = not save_available
	_items[Item.LOAD].disabled = not save_available
	var enabled: Array[bool] = []
	for i in _items.size():
		enabled.append(not _items[i].disabled)
		_items[i].hovered.connect(_on_item_hovered.bind(i))
		_items[i].pressed.connect(activate.bind(i))
	_cursor_rule = MenuCursor.new(enabled)
	# 2. 타이틀 상태로 시작 (씬에 놓인 로고 자리가 타이틀 자리)
	_title_logo_position = _logo.position
	_apply_state(State.TITLE, false)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.TITLE:
		# 아무 키(누르는 순간만)나 마우스 클릭 → 메뉴
		var key_down: bool = event is InputEventKey and event.pressed and not event.echo
		var click: bool = event is InputEventMouseButton and event.pressed
		if key_down or click:
			show_menu()
			get_viewport().set_input_as_handled()
		return
	# MENU 상태 키 조작
	if event.is_action_pressed("ui_cancel"):
		show_title()
	elif event.is_action_pressed("ui_up") or _is_key(event, KEY_W):
		move_cursor(-1)
	elif event.is_action_pressed("ui_down") or _is_key(event, KEY_S):
		move_cursor(1)
	elif event.is_action_pressed("ui_accept") or _is_key(event, KEY_E):
		# 확인 = 엔터·스페이스(ui_accept) 또는 E.
		# 새 게임은 장면을 바꿔 이 노드가 트리에서 빠지므로, 입력 처리 표시를 먼저 하고 실행한다
		get_viewport().set_input_as_handled()
		if cursor >= 0:
			activate(cursor)
		return
	else:
		return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	# 화면 전체를 덮는 이 노드가 마우스 클릭을 먼저 받아서 _unhandled_input 까지 안 내려간다.
	# 그래서 타이틀 상태의 "클릭으로 시작"은 여기서 처리한다
	if state == State.TITLE and event is InputEventMouseButton and event.pressed:
		show_menu()
		accept_event()


## 메뉴 상태로: 로고가 왼쪽 위로, 메뉴가 나타나고, 커서는 첫 활성 줄
func show_menu() -> void:
	_apply_state(State.MENU, true)
	_set_cursor(_cursor_rule.first())


## 타이틀 상태로 돌아간다 (메뉴에서 ESC)
func show_title() -> void:
	_apply_state(State.TITLE, true)


## 커서를 dir(+1 아래, -1 위) 방향 다음 활성 줄로
func move_cursor(dir: int) -> void:
	_set_cursor(_cursor_rule.step(cursor, dir))


## 메뉴 줄 실행 (index = Item 값). 비활성 줄은 무시
func activate(index: int) -> void:
	if index < 0 or index >= _items.size() or _items[index].disabled:
		return
	_set_cursor(index)
	match index:
		Item.NEW_GAME:
			if office_scene == null:
				push_warning("TitleScreen: office_scene 이 비어 있어요")
				return
			get_tree().change_scene_to_packed(office_scene)
		Item.SETTINGS:
			# 설정 창 (화면 모드·창 크기, 2026-11-28)
			%SettingsPanel.open()
		Item.CREDITS:
			# 아직 화면이 없다 (설계 비목표)
			%Notice.show_text("준비 중입니다")
		Item.QUIT:
			get_tree().quit()
		_:
			# 이어하기·불러오기: 저장 기능이 생기면 여기서 처리
			pass


## 커서를 index 줄로 옮기고 줄 모양을 맞춘다. 최근 저장 카드는 이어하기에 커서가 있을 때만
func _set_cursor(index: int) -> void:
	cursor = index
	for i in _items.size():
		_items[i].set_selected(i == cursor)
	%SaveCard.visible = save_available and state == State.MENU and cursor == Item.CONTINUE


## 상태를 바꾸고 화면을 맞춘다. animate = false 면 연출 없이 바로
func _apply_state(next: State, animate: bool) -> void:
	state = next
	var menu := next == State.MENU
	# 1. 로고 정렬: 타이틀 = 가운데, 메뉴 = 왼쪽 (글은 바로 바뀌고 자리만 움직인다)
	var align := HORIZONTAL_ALIGNMENT_LEFT if menu else HORIZONTAL_ALIGNMENT_CENTER
	for c in _logo.get_children():
		if c is Label:
			c.horizontal_alignment = align
	%RuleRow.alignment = BoxContainer.ALIGNMENT_BEGIN if menu else BoxContainer.ALIGNMENT_CENTER
	# 2. 보이는 것들: 메뉴 상태 = 메뉴·안내·왼쪽 어둡게 / 타이틀 상태 = 로고 판·PRESS ANY KEY
	var logo_to := menu_logo_position if menu else _title_logo_position
	# (삼항식 안의 배열 글자는 타입 없는 Array 라서, 타입 붙은 변수에 먼저 담고 고른다)
	var menu_set: Array[CanvasItem] = [_menu, %Hint, %LeftFade]
	var title_set: Array[CanvasItem] = [%LogoBackdrop, %PressKeyBackdrop, %PressAnyKey]
	var fade_in: Array[CanvasItem] = menu_set if menu else title_set
	var fade_out: Array[CanvasItem] = title_set.duplicate() if menu else menu_set.duplicate()
	if not menu:
		fade_out.append(%SaveCard)
	if _tween:
		_tween.kill()
	for n in fade_in:
		n.visible = true
	if not animate:
		_logo.position = logo_to
		for n in fade_in:
			n.modulate.a = 1.0
		for n in fade_out:
			n.modulate.a = 0.0
			n.visible = false
	else:
		_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_logo, "position", logo_to, transition_time)
		for n in fade_in:
			_tween.tween_property(n, "modulate:a", 1.0, transition_time)
		for n in fade_out:
			_tween.tween_property(n, "modulate:a", 0.0, transition_time * 0.5)
		# 다 사라진 것은 숨겨서 마우스 입력도 받지 않게
		_tween.chain().tween_callback(func():
			for n in fade_out:
				n.visible = false)
	# 3. 메뉴 커서는 메뉴 상태에서만
	if not menu:
		_set_cursor(-1)
	_update_blink()


## 타이틀 상태일 때만 "PRESS ANY KEY" 를 천천히 깜빡인다
func _update_blink() -> void:
	if _blink:
		_blink.kill()
		_blink = null
	var label: CanvasItem = %PressAnyKeyText
	label.modulate.a = 1.0
	if state != State.TITLE or not is_inside_tree():
		return
	_blink = create_tween().set_loops()
	_blink.tween_property(label, "modulate:a", 0.35, blink_time * 0.5)
	_blink.tween_property(label, "modulate:a", 1.0, blink_time * 0.5)


## 마우스가 줄 위에 올라옴 → 커서 이동 (비활성 줄은 무시)
func _on_item_hovered(index: int) -> void:
	if state == State.MENU and not _items[index].disabled:
		_set_cursor(index)


## event 가 keycode 키를 누른 순간인지 (W/S 이동용 — ui_up/ui_down 은 화살표만 있어서)
func _is_key(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == keycode
