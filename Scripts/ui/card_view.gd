@tool
class_name CardView
extends PanelContainer
## 카드 한 장의 화면. 모든 카드가 이 씬(card_view.tscn) 하나를 같이 쓰고, set_card() 로 내용을 채운다.
##
## - 노드 구성·배치·글자 크기·스타일은 card_view.tscn 에서 에디터로 편집한다.
##   여기서는 카드마다 달라지는 것(글자, 그림, 범위 칸, 분류 색)만 바꾼다.
## - 모양은 웹 카드 에디터의 카드와 같다: 이름 / 그림 + SP 원 / 공격 종류·범위·강화 배지 / 키워드 / 설명 / 코스트.
## - 마우스를 올리면 카드 오른쪽에 키워드 이름과 설명이 뜬다 (화면이 모자라면 왼쪽).
## - @tool 이라 갤러리 씬을 에디터에서 열기만 해도 카드가 그려진다.
##
## 주의: 아래 %이름 노드(Name, Sp, AreaGrid, KeywordEntry 등)는 씬의 노드 이름과 맞아야 한다.
## 씬에서 노드 이름을 바꾸면 여기 @onready 줄도 같이 바꿔야 한다.

## 카드 분류(CardData.category) → 테두리·SP 원·강화 배지 색. 웹 에디터와 같은 색.
const CATEGORY_COLORS := {
	"attack": Color("c3413a"),   # 공격: 빨강
	"skill": Color("2d6cc9"),    # 스킬: 파랑
	"special": Color("8b3fc2"),  # 특수: 보라
	"enemy": Color("111014"),    # 적 전용: 검정
}
## 공격 종류(CardData.attack_type) → 배지 글자 (근접/원거리/아군/자신)
const ATTACK_BADGES := {"melee": "근", "ranged": "원", "ally": "아", "self": "자"}
## 범위 미니 격자에서 범위가 아닌 칸의 색
const CELL_OFF := Color("d3cfdc")
## 범위 격자의 반지름. 5×5 격자 = 기준 칸에서 −2..2.
const AREA_RADIUS := 2

## 키워드 데이터(KeywordData .tres)가 있는 폴더. 카드에는 키워드 id 만 있어서 여기서 이름·설명을 찾는다.
@export var keyword_dir := "res://cards/keywords"

## 지금 표시 중인 카드
var card: CardData

# --- 씬의 노드 (card_view.tscn 에서 "고유 이름으로 접근"이 켜진 노드들) ---
@onready var name_label: Label = %Name              ## 카드 이름
@onready var sp_label: Label = %Sp                  ## SP 원 안의 숫자
@onready var cost_label: Label = %Cost              ## 아래쪽 "코스트 N"
@onready var description_label: Label = %Description  ## 카드 설명
@onready var keywords_label: Label = %Keywords      ## 설명 위의 키워드 이름들 (주황)
@onready var attack_badge: Label = %AttackBadge     ## 오른쪽 위 공격 종류 배지
@onready var upgrade_badge: Label = %UpgradeBadge   ## 강화 단계 수 배지 (+N)
@onready var art_rect: TextureRect = %Art           ## 카드 그림
@onready var tooltip: PanelContainer = %Tooltip     ## 키워드 설명 툴팁 (top_level 이라 카드 밖에 그려짐)
@onready var _sp_circle: Panel = %SpCircle
@onready var _area_grid: GridContainer = %AreaGrid  # 칸 25개 (ColorRect), 왼쪽 위부터 줄 순서
@onready var _tooltip_box: VBoxContainer = %TooltipBox
@onready var _keyword_title: Label = %KeywordTitle  # 툴팁 항목 틀(KeywordEntry) 안의 제목
@onready var _keyword_body: Label = %KeywordBody    # 툴팁 항목 틀 안의 설명

## 범위 격자에서 켜진 칸들 (테스트에서 확인용으로도 씀)
var _lit: Array[Vector2i] = []
## 이 카드의 키워드 중 데이터 파일을 찾은 것들 (지워진 키워드는 빠짐)
var _keywords: Array[KeywordData] = []


func _ready() -> void:
	# 에디터에서 이 씬 자체를 편집 중이면 아무것도 바꾸지 않는다 (예시 글자·툴팁 틀이 그대로 보이게).
	if Engine.is_editor_hint() and get_tree().edited_scene_root == self:
		return
	# 툴팁 항목 틀(KeywordEntry)은 씬에서 모양만 정하고 숨긴다. 실제 항목은 이 틀을 복제해서 만든다.
	_keyword_title.get_parent().visible = false
	tooltip.visible = false
	mouse_entered.connect(show_keyword_tooltip)
	mouse_exited.connect(hide_keyword_tooltip)
	# set_card() 가 _ready 전에 불렸으면 여기서 마저 채운다.
	if card:
		set_card(card)


## 카드 내용을 화면에 채운다. 씬에 붙기 전에 불러도 되고, 그 경우 _ready 에서 채운다.
func set_card(c: CardData) -> void:
	card = c
	if not is_node_ready():
		return  # 노드가 아직 없다. _ready 에서 다시 부른다.

	# 1. 분류 색: 테두리, SP 원, 강화 배지.
	#    씬의 스타일박스는 "씬별로 로컬"이라 카드마다 따로 색을 바꿀 수 있다.
	var color: Color = CATEGORY_COLORS.get(c.category, CATEGORY_COLORS["attack"])
	_panel_style(self).border_color = color
	_panel_style(_sp_circle).bg_color = color
	(upgrade_badge.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = color

	# 2. 글자
	name_label.text = c.name_ko if not c.name_ko.is_empty() else "이름 없음"
	sp_label.text = str(c.sp)
	cost_label.text = "코스트 %d" % c.cost
	description_label.text = c.description_ko
	attack_badge.text = ATTACK_BADGES.get(c.attack_type, "?")
	upgrade_badge.visible = not c.upgrades.is_empty()
	upgrade_badge.text = "+%d" % c.upgrades.size()

	# 3. 범위 미니 격자: 범위가 비어 있으면 단일 대상(기준 칸만).
	#    칸 순서 i → 좌표 (열 i%5, 행 i/5) 에서 반지름을 빼서 −2..2 로.
	_lit.assign(c.area if not c.area.is_empty() else [Vector2i.ZERO])
	var cells := _area_grid.get_children()
	for i in cells.size():
		var cell := Vector2i(i % 5 - AREA_RADIUS, i / 5 - AREA_RADIUS)
		(cells[i] as ColorRect).color = color if _lit.has(cell) else CELL_OFF

	# 4. 그림
	art_rect.texture = _load_art(c.art)

	# 5. 키워드: id 로 데이터 파일을 찾는다. 파일이 없는 키워드(웹 에디터에서 지운 것)는 건너뛴다.
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


## 지금 테두리 색 (테스트용)
func border_color() -> Color:
	return _panel_style(self).border_color


## 범위 격자에서 켜진 칸 좌표들 (테스트용)
func lit_cells() -> Array[Vector2i]:
	return _lit


## 찾은 키워드 데이터들 (테스트용)
func keyword_entries() -> Array[KeywordData]:
	return _keywords


## 카드 오른쪽에 키워드 설명 툴팁을 띄운다. 화면 오른쪽이 모자라면 왼쪽에 띄운다.
## 마우스가 카드에 들어오면 자동으로 불린다. 키워드가 없으면 아무것도 안 한다.
func show_keyword_tooltip() -> void:
	if _keywords.is_empty():
		return

	# 1. 이전 항목을 지우고(틀은 남김), 키워드마다 틀을 복제해서 채운다.
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

	# 2. 내용에 맞게 크기를 다시 계산한다.
	tooltip.visible = true
	tooltip.reset_size()

	# 3. 위치: 카드 오른쪽 8px. 화면 밖으로 나가면 카드 왼쪽으로. 위아래도 화면 안으로 맞춘다.
	var rect := get_global_rect()
	var view := get_viewport_rect().size
	var gap := 8.0
	var x := rect.end.x + gap
	if x + tooltip.size.x > view.x - gap:
		x = rect.position.x - gap - tooltip.size.x
	var y := clampf(rect.position.y, gap, maxf(gap, view.y - tooltip.size.y - gap))
	tooltip.global_position = Vector2(maxf(gap, x), y)


## 툴팁을 숨긴다. 마우스가 카드에서 나가면 자동으로 불린다.
func hide_keyword_tooltip() -> void:
	if tooltip:
		tooltip.visible = false


## 툴팁에 보이는 글자를 줄 단위로 모아 돌려준다 (테스트용)
func tooltip_text_for_test() -> String:
	var parts := PackedStringArray()
	for entry in _tooltip_box.get_children():
		if not entry.visible or entry.is_queued_for_deletion():
			continue
		parts.append(entry.get_node("KeywordTitle").text)
		parts.append(entry.get_node("KeywordBody").text)
	return "\n".join(parts)


## 패널 계열 노드의 "panel" 스타일박스
func _panel_style(c: Control) -> StyleBoxFlat:
	return c.get_theme_stylebox("panel") as StyleBoxFlat


## 그림 경로 → 텍스처. 경로가 비었으면 null (그림 자리는 ArtFrame 의 회색 배경만 보임).
func _load_art(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# 방금 가져와서 아직 에디터가 import 하지 않은 그림은 파일에서 직접 읽는다.
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null
