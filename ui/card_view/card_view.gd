@tool
class_name CardView
extends PanelContainer
## 카드 한 장의 화면. 모든 카드가 이 씬 하나를 같이 쓰고, set_card() 로 내용을 채운다.
## 노드·배치·스타일은 card_view.tscn 에서 편집한다. 여기서는 카드 내용과 분류 색만 바꾼다.
## 마우스를 올리면 오른쪽에 키워드 설명이 뜬다.

const CATEGORY_COLORS := {
	"attack": Color("c3413a"),
	"skill": Color("2d6cc9"),
	"special": Color("8b3fc2"),
	"enemy": Color("111014"),
}
const ATTACK_BADGES := {"melee": "근", "ranged": "원", "ally": "아", "self": "자"}
const CELL_OFF := Color("d3cfdc")
const AREA_RADIUS := 2

@export var keyword_dir := "res://cards/keywords"

var card: CardData

@onready var name_label: Label = %Name
@onready var sp_label: Label = %Sp
@onready var cost_label: Label = %Cost
@onready var description_label: Label = %Description
@onready var keywords_label: Label = %Keywords
@onready var attack_badge: Label = %AttackBadge
@onready var upgrade_badge: Label = %UpgradeBadge
@onready var art_rect: TextureRect = %Art
@onready var tooltip: PanelContainer = %Tooltip
@onready var _sp_circle: Panel = %SpCircle
@onready var _area_grid: GridContainer = %AreaGrid
@onready var _tooltip_box: VBoxContainer = %TooltipBox
@onready var _keyword_title: Label = %KeywordTitle
@onready var _keyword_body: Label = %KeywordBody

var _lit: Array[Vector2i] = []
var _keywords: Array[KeywordData] = []


func _ready() -> void:
	# 에디터에서 이 씬 자체를 편집 중이면 아무것도 바꾸지 않는다 (예시 글자·틀이 그대로 보이게).
	if Engine.is_editor_hint() and get_tree().edited_scene_root == self:
		return
	# 툴팁 항목 틀은 씬에서 모양만 정하고, 실제 항목은 복제해서 쓴다.
	_keyword_title.get_parent().visible = false
	tooltip.visible = false
	mouse_entered.connect(show_keyword_tooltip)
	mouse_exited.connect(hide_keyword_tooltip)
	if card:
		set_card(card)


func set_card(c: CardData) -> void:
	card = c
	if not is_node_ready():
		return  # _ready 에서 다시 채운다
	var color: Color = CATEGORY_COLORS.get(c.category, CATEGORY_COLORS["attack"])
	_panel_style(self).border_color = color
	_panel_style(_sp_circle).bg_color = color
	(upgrade_badge.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = color

	name_label.text = c.name_ko if not c.name_ko.is_empty() else "이름 없음"
	sp_label.text = str(c.sp)
	cost_label.text = "코스트 %d" % c.cost
	description_label.text = c.description_ko
	attack_badge.text = ATTACK_BADGES.get(c.attack_type, "?")
	upgrade_badge.visible = not c.upgrades.is_empty()
	upgrade_badge.text = "+%d" % c.upgrades.size()

	_lit.assign(c.area if not c.area.is_empty() else [Vector2i.ZERO])
	var cells := _area_grid.get_children()
	for i in cells.size():
		var cell := Vector2i(i % 5 - AREA_RADIUS, i / 5 - AREA_RADIUS)
		(cells[i] as ColorRect).color = color if _lit.has(cell) else CELL_OFF

	art_rect.texture = _load_art(c.art)

	_keywords.clear()
	for id in c.keywords:
		var path := keyword_dir.path_join(id + ".tres")
		if ResourceLoader.exists(path):
			var kw := load(path) as KeywordData
			if kw:
				_keywords.append(kw)
	var names := PackedStringArray()
	for kw in _keywords:
		names.append(kw.name_ko)
	keywords_label.text = "  ".join(names)
	keywords_label.visible = not _keywords.is_empty()
	hide_keyword_tooltip()


func border_color() -> Color:
	return _panel_style(self).border_color


func lit_cells() -> Array[Vector2i]:
	return _lit


func keyword_entries() -> Array[KeywordData]:
	return _keywords


## 카드 오른쪽에 키워드 설명. 화면 오른쪽이 모자라면 왼쪽에 띄운다.
func show_keyword_tooltip() -> void:
	if _keywords.is_empty():
		return
	var template := _keyword_title.get_parent()
	for child in _tooltip_box.get_children():
		if child != template:
			child.queue_free()
	for kw in _keywords:
		var entry := template.duplicate()
		entry.visible = true
		entry.get_node("KeywordTitle").text = kw.name_ko
		entry.get_node("KeywordBody").text = kw.description_ko if not kw.description_ko.is_empty() else "설명 없음"
		_tooltip_box.add_child(entry)
	tooltip.visible = true
	tooltip.reset_size()
	var rect := get_global_rect()
	var view := get_viewport_rect().size
	var gap := 8.0
	var x := rect.end.x + gap
	if x + tooltip.size.x > view.x - gap:
		x = rect.position.x - gap - tooltip.size.x
	var y := clampf(rect.position.y, gap, maxf(gap, view.y - tooltip.size.y - gap))
	tooltip.global_position = Vector2(maxf(gap, x), y)


func hide_keyword_tooltip() -> void:
	if tooltip:
		tooltip.visible = false


func tooltip_text_for_test() -> String:
	var parts := PackedStringArray()
	for entry in _tooltip_box.get_children():
		if not entry.visible or entry.is_queued_for_deletion():
			continue
		parts.append(entry.get_node("KeywordTitle").text)
		parts.append(entry.get_node("KeywordBody").text)
	return "\n".join(parts)


func _panel_style(c: Control) -> StyleBoxFlat:
	return c.get_theme_stylebox("panel") as StyleBoxFlat


func _load_art(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# 아직 에디터가 import 하지 않은 그림은 파일에서 직접 읽는다.
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null
