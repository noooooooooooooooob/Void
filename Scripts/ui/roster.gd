class_name Roster
extends Control
## 사원 명부 화면. roster.tscn 의 스크립트.
## 왼쪽: 캐릭터 목록 (roster 의 캐릭터마다 UnitButtonTemplate 을 복제한 버튼)
## 오른쪽: 고른 캐릭터의 이름·스탯·패시브·장비, 그 아래 덱 카드 (card_view.tscn, 덱 편집 화면이라 % 표시)
## 지금은 보기만 한다 (덱 편집은 나중에).

## 카드 한 장을 그리는 틀 씬
const CARD_VIEW := preload("res://Scenes/ui/card_view/card_view.tscn")

## 보여줄 사원 명부 (인스펙터에서 entities/roster.tres 를 넣는다)
@export var roster: RosterData

## 캐릭터마다 만든 목록 버튼 (roster.units 와 같은 순서)
var unit_buttons: Array[Button] = []
## 지금 고른 캐릭터
var selected: UnitData = null

@onready var _unit_list: VBoxContainer = %UnitList
@onready var _button_template: Button = %UnitButtonTemplate  # 숨겨 둔 목록 버튼 틀
@onready var _name: Label = %NameLabel
@onready var _stats: Label = %StatsLabel
@onready var _deck_title: Label = %DeckTitle
@onready var _deck: HFlowContainer = %DeckGrid
@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.pressed.connect(Router.goto.bind(Router.Screen.OFFICE))
	if roster == null:
		push_warning("Roster: roster 가 비어 있어요")
		return
	# 1. 캐릭터마다 목록 버튼을 틀에서 복제한다
	for unit in roster.units:
		var b: Button = _button_template.duplicate()
		b.visible = true
		b.text = unit.display_name
		b.pressed.connect(select.bind(unit))
		_unit_list.add_child(b)
		unit_buttons.append(b)
	# 2. 첫 캐릭터를 골라 둔다
	if not roster.units.is_empty():
		select(roster.units[0])
		unit_buttons[0].grab_focus()


## unit 을 골라 오른쪽에 정보와 덱을 그린다
func select(unit: UnitData) -> void:
	selected = unit
	_name.text = unit.display_name
	_stats.text = _stats_text(unit)
	_deck_title.text = "덱 (%d장)" % unit.deck.size()
	# 이전 캐릭터의 카드를 지운다 (remove_child 먼저: 지우는 중인 카드가 card_views() 에 잡히지 않게)
	for child in _deck.get_children():
		_deck.remove_child(child)
		child.queue_free()
	for card in unit.deck:
		var view: CardView = CARD_VIEW.instantiate()
		_deck.add_child(view)
		view.set_card(card)


## 덱에 그려진 카드 화면들 (테스트용)
func card_views() -> Array[CardView]:
	var out: Array[CardView] = []
	for child in _deck.get_children():
		if child is CardView:
			out.append(child)
	return out


## 스탯·패시브·장비 설명 글 (장비 보정 전 기본값)
func _stats_text(unit: UnitData) -> String:
	var lines := PackedStringArray()
	lines.append("HP %d · SP %d · 공격 %d · 방어 %d" % [unit.max_hp, unit.max_sp, unit.attack, unit.defense])
	lines.append("속도 %d~%d · 이동 %d · 행동 %d회 · 치명 %d%% / %d%%" % [
		unit.speed_min, unit.speed_max, unit.move, unit.actions_per_round, unit.crit_rate, unit.crit_damage])
	lines.append("패시브: " + _names(unit.passives))
	lines.append("장비: " + _names(unit.equipment))
	return "\n".join(lines)


## 상태·장비 목록 → "이름, 이름" (없으면 "없음")
func _names(list: Array) -> String:
	var out := PackedStringArray()
	for item in list:
		if item:
			out.append(item.display_name)
	return "없음" if out.is_empty() else ", ".join(out)


## ESC: 사무소로
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Router.goto(Router.Screen.OFFICE)
