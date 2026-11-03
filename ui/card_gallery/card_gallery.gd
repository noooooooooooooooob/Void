@tool
class_name CardGallery
extends Control
## 확인용 카드 갤러리. 에디터에서 이 씬을 열기만 해도 카드가 보인다(@tool).
## - 에디터: 인스펙터의 Deck 로 덱을 고르고, 카드를 다시 가져온 뒤엔 "새로고침"
## - 실행(F6): 위쪽 탭으로 덱 선택, 카드에 마우스를 올리면 키워드 설명
## 덱 = cards/data 아래 폴더 (common 은 "공용"). 배경·여백·간격은 card_gallery.tscn 에서 편집.

const CARD_VIEW := preload("res://ui/card_view/card_view.tscn")
const ALL := "전체"
const COMMON_FOLDER := "common"
const COMMON_LABEL := "공용"

@export_dir var data_dir := "res://cards/data":
	set(value):
		data_dir = value
		refresh()
@export var deck: String = ALL:
	set(value):
		deck = value
		refresh()
@export_tool_button("새로고침", "Reload") var refresh_button := refresh

@onready var deck_tabs: TabBar = %DeckTabs
@onready var empty_label: Label = %EmptyLabel
@onready var _sections: VBoxContainer = %Sections

var _decks: Dictionary = {}  # 표시 이름 -> Array[CardData]
var _syncing_tabs := false


func _ready() -> void:
	deck_tabs.tab_changed.connect(_on_tab_changed)
	refresh()


func _validate_property(property: Dictionary) -> void:
	if property.name == "deck":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(deck_options())


func refresh() -> void:
	if not is_node_ready():
		return
	_decks = _load_decks(data_dir)
	for child in _sections.get_children():
		if child != empty_label:
			_sections.remove_child(child)
			child.queue_free()

	var labels := deck_options().slice(1)
	var shown: PackedStringArray = labels if deck == ALL or not _decks.has(deck) else PackedStringArray([deck])
	var total := 0
	for label in shown:
		if deck == ALL:
			var header := Label.new()
			header.text = "%s (%d)" % [label, _decks[label].size()]
			header.set_meta("deck", label)
			header.add_theme_font_size_override("font_size", 18)
			header.add_theme_color_override("font_color", Color("1d1b24"))
			_sections.add_child(header)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 16)
		flow.add_theme_constant_override("v_separation", 16)
		_sections.add_child(flow)
		for card in _decks[label]:
			var view: CardView = CARD_VIEW.instantiate()
			flow.add_child(view)
			view.set_card(card)
			total += 1
	empty_label.visible = total == 0
	_sync_tabs()
	notify_property_list_changed()


func deck_options() -> PackedStringArray:
	var names := PackedStringArray(_decks.keys())
	names.erase(COMMON_LABEL)
	names.sort()
	var out := PackedStringArray([ALL])
	if _decks.has(COMMON_LABEL):
		out.append(COMMON_LABEL)
	out.append_array(names)
	return out


func section_titles() -> PackedStringArray:
	var out := PackedStringArray()
	for child in _sections.get_children():
		if child.has_meta("deck"):
			out.append(child.get_meta("deck"))
	return out


func card_views() -> Array[CardView]:
	var out: Array[CardView] = []
	for child in _sections.get_children():
		if child is HFlowContainer:
			for view in child.get_children():
				if view is CardView:
					out.append(view)
	return out


func _sync_tabs() -> void:
	# 에디터에서는 탭을 건드리지 않는다 (씬 파일에 저장되지 않도록). 에디터에선 인스펙터 Deck 사용.
	if Engine.is_editor_hint():
		return
	_syncing_tabs = true
	var options := deck_options()
	deck_tabs.clear_tabs()
	for opt in options:
		deck_tabs.add_tab(opt)
	deck_tabs.current_tab = maxi(0, options.find(deck))
	_syncing_tabs = false


func _on_tab_changed(index: int) -> void:
	if _syncing_tabs:
		return
	deck = deck_options()[index]


## { 표시 이름: 이름순 카드 배열 }. 폴더 하나 = 덱 하나.
func _load_decks(dir_path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		var cards: Array[CardData] = []
		var sub_path := dir_path.path_join(sub)
		for f in DirAccess.get_files_at(sub_path):
			if f.get_extension() == "tres":
				var card := load(sub_path.path_join(f)) as CardData
				if card:
					cards.append(card)
		if cards.is_empty():
			continue
		cards.sort_custom(func(a: CardData, b: CardData) -> bool: return a.name_ko < b.name_ko)
		out[COMMON_LABEL if sub == COMMON_FOLDER else sub] = cards
	return out
