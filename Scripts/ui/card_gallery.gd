@tool
class_name CardGallery
extends Control
## 확인용 카드 갤러리. cards/data 아래의 카드를 덱별로 카드 모양(CardView)으로 보여준다.
##
## - 에디터: 이 씬을 열기만 해도 카드가 보인다(@tool).
##   인스펙터의 Deck 으로 덱을 고르고, 카드를 다시 가져온 뒤에는 "새로고침" 버튼을 누른다.
## - 실행(F6): 위쪽 탭으로 덱을 고른다. 카드에 마우스를 올리면 키워드 설명이 뜬다.
## - 덱 = cards/data 아래 폴더 하나. common 폴더는 "공용"으로 표시한다.
## - 배경·여백·간격·탭 모양은 card_gallery.tscn 에서 에디터로 편집한다.
##   덱 제목과 카드 줄(HFlowContainer)은 덱 수만큼 생기므로 여기서 만든다.

## 카드 한 장을 그릴 씬
const CARD_VIEW := preload("res://Scenes/ui/card_view/card_view.tscn")
## "모든 덱" 선택지 이름
const ALL := "전체"
## 공용 카드 폴더 이름과 화면에 보일 이름
const COMMON_FOLDER := "common"
const COMMON_LABEL := "공용"

## 카드 데이터 폴더. 바꾸면 바로 다시 그린다. (테스트에서는 임시 폴더를 넣는다)
@export_dir var data_dir := "res://cards/data":
	set(value):
		data_dir = value
		refresh()
## 보여줄 덱. "전체" / "공용" / 덱 폴더 이름. 인스펙터에서는 드롭다운으로 고른다.
## 바꾸면 바로 다시 그린다.
@export var deck: String = ALL:
	set(value):
		deck = value
		refresh()
## 인스펙터의 "새로고침" 버튼. 카드를 다시 가져온 뒤 누르면 폴더를 다시 읽는다.
@export_tool_button("새로고침", "Reload") var refresh_button := refresh

# --- 씬의 노드 ---
@onready var deck_tabs: TabBar = %DeckTabs          ## 실행 중 덱 선택 탭 (에디터에서는 비어 있음)
@onready var empty_label: Label = %EmptyLabel       ## 카드가 하나도 없을 때 안내 문구
@onready var _sections: VBoxContainer = %Sections   # 덱 제목 + 카드 줄이 쌓이는 곳

## 마지막으로 읽은 카드. 표시 이름("공용", 덱 이름) → 이름순 카드 배열
var _decks: Dictionary = {}
## 탭을 코드로 다시 채우는 중인지. 그동안 생기는 tab_changed 신호는 무시한다.
var _syncing_tabs := false


func _ready() -> void:
	deck_tabs.tab_changed.connect(_on_tab_changed)
	refresh()


## 인스펙터에서 deck 을 드롭다운으로 보이게 한다. 선택지는 지금 읽은 덱 목록.
func _validate_property(property: Dictionary) -> void:
	if property.name == "deck":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(deck_options())


## 폴더를 다시 읽고 화면을 다시 그린다.
func refresh() -> void:
	if not is_node_ready():
		return  # 씬이 아직 준비 안 됨 (export 값이 먼저 들어오는 경우). _ready 에서 다시 부른다.
	_decks = _load_decks(data_dir)

	# 1. 이전에 그린 덱 제목·카드 줄을 지운다. 안내 문구(EmptyLabel)는 씬 노드라 남긴다.
	#    remove_child 를 먼저 해서, 지우는 중인 카드가 card_views() 에 잡히지 않게 한다.
	for child in _sections.get_children():
		if child != empty_label:
			_sections.remove_child(child)
			child.queue_free()

	# 2. 보여줄 덱: "전체"면 모든 덱, 아니면 고른 덱 하나.
	#    고른 덱이 없어졌으면(이름이 바뀌었거나 지워짐) 전체를 보여준다.
	var labels := deck_options().slice(1)  # 맨 앞 "전체" 제외
	var shown: PackedStringArray = labels if deck == ALL or not _decks.has(deck) else PackedStringArray([deck])
	var total := 0
	for label in shown:
		# "전체" 보기에서만 덱마다 "홍연 (10)" 같은 제목을 붙인다.
		if deck == ALL:
			var header := Label.new()
			header.text = "%s (%d)" % [label, _decks[label].size()]
			header.set_meta("deck", label)  # section_titles() 가 덱 이름을 찾는 표시
			header.add_theme_font_size_override("font_size", 18)
			header.add_theme_color_override("font_color", Color("1d1b24"))
			_sections.add_child(header)
		# 카드 줄: 폭이 모자라면 다음 줄로 넘어간다.
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 16)
		flow.add_theme_constant_override("v_separation", 16)
		_sections.add_child(flow)
		for card in _decks[label]:
			var view: CardView = CARD_VIEW.instantiate()
			flow.add_child(view)
			view.set_card(card)
			total += 1

	# 3. 안내 문구, 탭, 인스펙터 드롭다운 갱신
	empty_label.visible = total == 0
	_sync_tabs()
	notify_property_list_changed()


## 덱 선택지: ["전체", "공용"(있으면), 나머지 덱 이름(가나다순)]
func deck_options() -> PackedStringArray:
	var names := PackedStringArray(_decks.keys())
	names.erase(COMMON_LABEL)
	names.sort()
	var out := PackedStringArray([ALL])
	if _decks.has(COMMON_LABEL):
		out.append(COMMON_LABEL)
	out.append_array(names)
	return out


## 화면에 있는 덱 제목들 (테스트용)
func section_titles() -> PackedStringArray:
	var out := PackedStringArray()
	for child in _sections.get_children():
		if child.has_meta("deck"):
			out.append(child.get_meta("deck"))
	return out


## 화면에 있는 카드 화면들 (테스트용)
func card_views() -> Array[CardView]:
	var out: Array[CardView] = []
	for child in _sections.get_children():
		if child is HFlowContainer:
			for view in child.get_children():
				if view is CardView:
					out.append(view)
	return out


## 탭을 덱 선택지로 다시 채우고, 지금 덱을 선택 상태로 둔다.
func _sync_tabs() -> void:
	# 에디터에서는 탭을 건드리지 않는다. 바꾸면 씬 파일에 저장돼 버리기 때문.
	# (에디터에서는 인스펙터의 Deck 을 쓴다)
	if Engine.is_editor_hint():
		return
	_syncing_tabs = true
	var options := deck_options()
	deck_tabs.clear_tabs()
	for opt in options:
		deck_tabs.add_tab(opt)
	deck_tabs.current_tab = maxi(0, options.find(deck))
	_syncing_tabs = false


## 탭을 눌렀을 때: 그 덱으로 바꾼다 (deck 의 setter 가 다시 그린다).
func _on_tab_changed(index: int) -> void:
	if _syncing_tabs:
		return
	deck = deck_options()[index]


## 데이터 폴더를 읽어 { 표시 이름: 이름순 카드 배열 } 을 만든다.
## 폴더 하나 = 덱 하나. 카드가 없는 폴더는 건너뛴다.
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
