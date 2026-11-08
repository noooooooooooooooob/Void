class_name Roster
extends Control
## 캐릭터 페이지(사원 명부). roster.tscn 의 스크립트. 사무소의 "사원 명부"에서 온다.
## 배치 (사용자 목업 기준, 2026-11-08 설계 docs/superpowers/specs/2026-11-08-character-page-design.md):
##   위: 탭 줄 (캐릭터 · 덱 · 장비 · 기록 · 설정 — 지금은 캐릭터만, 나머지는 준비 중)
##   왼쪽: 초상 목록 (캐릭터마다 PortraitTemplate 을 복제한 버튼, 고른 캐릭터는 눌린 상태)
##   가운데: 큰 일러스트 + 프로필 (이름, 픽셀 캐릭터, 나이·키·소속·역할, 설명, 특성 칩)
##   오른쪽: 캐릭터 덱 (한 쪽에 CARDS_PER_PAGE 장, 쪽 넘기기). 전투 유닛이 없는 캐릭터는 "덱 미정"
## 조작: 초상 클릭 또는 W/S·↑/↓ 로 캐릭터 고르기, A/D·←/→ 로 덱 쪽 넘기기, ESC 로 사무소
## 모양(색·크기·위치)은 roster.tscn 에서 에디터로 고친다.

## 카드 한 장을 그리는 틀 씬
const CARD_VIEW := preload("res://Scenes/ui/card_view/card_view.tscn")
## 덱 한 쪽에 보여줄 카드 수 (4열 × 2줄)
const CARDS_PER_PAGE := 8

## 보여줄 사원 명부 (인스펙터에서 entities/roster.tres 를 넣는다)
@export var roster: RosterData

## 캐릭터마다 만든 초상 버튼 (roster.characters 와 같은 순서)
var portrait_buttons: Array[Button] = []
## 지금 고른 캐릭터
var selected: CharacterProfile = null
## 지금 보고 있는 덱 쪽 (0부터)
var page := 0

@onready var _portrait_list: VBoxContainer = %PortraitList
@onready var _portrait_template: Button = %PortraitTemplate   # 숨겨 둔 초상 버튼 틀
@onready var _portrait_scroll: ScrollContainer = %PortraitScroll
@onready var _illustration: TextureRect = %Illustration
@onready var _name: Label = %NameLabel
@onready var _pixel: TextureRect = %PixelImage
@onready var _pixel_empty: Label = %PixelEmpty
@onready var _age: Label = %AgeValue
@onready var _height: Label = %HeightValue
@onready var _affiliation: Label = %AffiliationValue
@onready var _role: Label = %RoleValue
@onready var _desc: Label = %DescLabel
@onready var _traits: HFlowContainer = %TraitsRow
@onready var _trait_template: Label = %TraitTemplate          # 숨겨 둔 특성 칩 틀
@onready var _deck_grid: GridContainer = %DeckGrid
@onready var _deck_count: Label = %DeckCount
@onready var _deck_empty: Label = %DeckEmpty
@onready var _page_label: Label = %PageLabel
@onready var _prev: Button = %PrevButton
@onready var _next: Button = %NextButton


func _ready() -> void:
	%BackButton.pressed.connect(Router.goto.bind(Router.Screen.OFFICE))
	%UpButton.pressed.connect(_move_selection.bind(-1))
	%DownButton.pressed.connect(_move_selection.bind(1))
	_prev.pressed.connect(prev_page)
	_next.pressed.connect(next_page)
	if roster == null:
		push_warning("Roster: roster 가 비어 있어요")
		return
	# 1. 캐릭터마다 초상 버튼을 틀에서 복제한다
	for c in roster.characters:
		var b: Button = _portrait_template.duplicate()
		b.visible = true
		b.icon = c.portrait
		b.tooltip_text = c.display_name
		b.pressed.connect(select.bind(c))
		_portrait_list.add_child(b)
		portrait_buttons.append(b)
	# 2. 첫 캐릭터를 골라 둔다
	if not roster.characters.is_empty():
		select(roster.characters[0])


## c 를 골라 가운데 프로필과 오른쪽 덱을 그린다
func select(c: CharacterProfile) -> void:
	selected = c
	page = 0
	# 1. 초상 버튼: 고른 캐릭터만 눌린 상태
	var index := roster.characters.find(c)
	for i in portrait_buttons.size():
		portrait_buttons[i].set_pressed_no_signal(i == index)
	if index >= 0:
		_portrait_scroll.ensure_control_visible(portrait_buttons[index])
	# 2. 프로필
	_name.text = c.display_name
	_illustration.texture = c.illustration
	_pixel.texture = c.pixel
	_pixel_empty.visible = c.pixel == null
	_age.text = c.age
	_height.text = c.height
	_affiliation.text = c.affiliation
	_role.text = c.role
	_desc.text = c.description
	# 3. 특성 칩: 틀(숨김)만 남기고 지운 뒤 다시 복제
	for child in _traits.get_children():
		if child != _trait_template:
			_traits.remove_child(child)
			child.queue_free()
	for t in c.traits:
		var chip: Label = _trait_template.duplicate()
		chip.visible = true
		chip.text = t
		_traits.add_child(chip)
	# 4. 덱
	_show_deck()


## 덱 쪽 수 (카드가 없어도 1)
func page_count() -> int:
	if selected == null or selected.unit == null:
		return 1
	return maxi(1, ceili(selected.unit.deck.size() / float(CARDS_PER_PAGE)))


## 다음 덱 쪽 (마지막 쪽이면 그대로)
func next_page() -> void:
	if page < page_count() - 1:
		page += 1
		_show_deck()


## 이전 덱 쪽 (첫 쪽이면 그대로)
func prev_page() -> void:
	if page > 0:
		page -= 1
		_show_deck()


## 덱에 그려진 카드 화면들 (테스트용)
func card_views() -> Array[CardView]:
	var out: Array[CardView] = []
	for child in _deck_grid.get_children():
		if child is CardView:
			out.append(child)
	return out


## 지금 쪽의 카드를 그린다. 유닛이 없으면 "덱 미정"
func _show_deck() -> void:
	# 이전 카드 지우기 (remove_child 먼저: 지우는 중인 카드가 card_views() 에 잡히지 않게)
	for child in _deck_grid.get_children():
		_deck_grid.remove_child(child)
		child.queue_free()
	var has_deck := selected != null and selected.unit != null
	_deck_empty.visible = not has_deck
	if not has_deck:
		_deck_count.text = "-"
		_page_label.text = "1 / 1"
		_prev.disabled = true
		_next.disabled = true
		return
	var deck := selected.unit.deck
	_deck_count.text = "%d장" % deck.size()
	var start := page * CARDS_PER_PAGE
	for i in range(start, mini(start + CARDS_PER_PAGE, deck.size())):
		var view: CardView = CARD_VIEW.instantiate()
		_deck_grid.add_child(view)
		view.set_card(deck[i])
	_page_label.text = "%d / %d" % [page + 1, page_count()]
	_prev.disabled = page == 0
	_next.disabled = page >= page_count() - 1


## 고른 캐릭터를 delta 칸 옮긴다 (-1 위, +1 아래, 끝에서 멈춤)
func _move_selection(delta: int) -> void:
	if roster == null or roster.characters.is_empty():
		return
	var i := clampi(roster.characters.find(selected) + delta, 0, roster.characters.size() - 1)
	select(roster.characters[i])


## W/S·↑/↓: 캐릭터, A/D·←/→: 덱 쪽, ESC: 사무소
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_up"):
		_move_selection(-1)
	elif event.is_action_pressed("map_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_A):
		prev_page()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_D):
		next_page()
	elif event.is_action_pressed("ui_cancel"):
		Router.goto(Router.Screen.OFFICE)
	else:
		return
	get_viewport().set_input_as_handled()
