class_name RequestsBoard
extends Control
## 사무소 의뢰 게시판 패널의 내용 (Figma v6 01-A). 씬: `Scenes/ui/office_screen/requests_board.tscn`.
## 의뢰 게시판 패널(office_panel.tscn 의 %Content)에 넣는다. 설계 docs/superpowers/specs/2026-11-24-request-board-design.md 4-2.
##
## - 왼쪽: 필터 칩 3개(전체 N / 본 이야기 / 반복 의뢰) + 의뢰 카드 목록 (request_card.tscn 을 의뢰 수만큼 복제)
## - 오른쪽: 고른 의뢰의 의뢰인·장·제목·인용·정보·목표·보상 + "지도에서 보기" · "의뢰 수락" 버튼 + 긴급 도장
## - 조작: 카드 클릭, ↑↓/W·S 로 고르기(잠긴 카드는 건너뜀), Enter·Space·E 로 수락. 패널이 보일 때만 키를 받는다
## - 수락·지도 버튼은 시그널만 보낸다. 씬 바꾸기·패널 열기는 OfficeScreen 이 한다

## "의뢰 수락" (버튼·Enter). OfficeScreen 이 받아서 StageRun.start_request 를 부른다
signal accepted(request: RequestData)
## "지도에서 보기". OfficeScreen 이 공허 지도 패널을 연다
signal map_requested

## 카드 한 장 틀 씬 (의뢰 수만큼 instantiate)
const CARD_SCENE := preload("res://Scenes/ui/office_screen/request_card.tscn")
## 필터 칩 그림: 고른 칩(연보라 꽉 참) / 안 고른 칩(연보라 테두리, 반복 의뢰는 청록 테두리)
const CHIP_FILLED := preload("res://Art/ui/requests/chip_filled.svg")
const CHIP_MAIN := preload("res://Art/ui/requests/chip_main.svg")
const CHIP_REPEAT := preload("res://Art/ui/requests/chip_repeat.svg")

## 의뢰 데이터(.tres) 폴더. 시작할 때 이 폴더의 의뢰를 모두 읽는다
@export_dir var request_dir := "res://requests"
## 필터 칩 안 글자 양옆 여백 (px, Figma 10)
@export var chip_padding := 10.0

## 게시판의 의뢰 전부 (게시판 순서)
var requests: Array[RequestData] = []
## 지금 필터
var filter := RequestData.Filter.ALL
## 지금 고른 의뢰 (없으면 null)
var selected: RequestData = null

var _cards: Array[RequestCard] = []  # 지금 목록에 보이는 카드 (필터 적용 후, 화면 순서)
var _objective_rows: Array[Control] = []  # 템플릿에서 복제한 목표 줄


func _ready() -> void:
	# 1. 필터 칩 클릭 연결 (칩 = NinePatchRect, 순서 = Filter 값)
	var chips := _chips()
	for i in chips.size():
		chips[i].gui_input.connect(_on_chip_input.bind(i))
	# 2. 버튼
	%AcceptButton.pressed.connect(accept)
	%MapButton.pressed.connect(func(): map_requested.emit())
	%ObjectiveTemplate.visible = false
	# 3. 데이터 읽기
	set_requests(RequestData.load_all(request_dir))


func _unhandled_input(event: InputEvent) -> void:
	# 패널이 닫혀 있으면(안 보이면) 키를 받지 않는다
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_up") or _is_key(event, KEY_W):
		move_selection(-1)
	elif event.is_action_pressed("ui_down") or _is_key(event, KEY_S):
		move_selection(1)
	elif event.is_action_pressed("ui_accept") or _is_key(event, KEY_E):
		# 수락하면 장면이 바뀌므로 처리 표시를 먼저
		get_viewport().set_input_as_handled()
		accept()
		return
	else:
		return
	get_viewport().set_input_as_handled()


## 의뢰 목록을 바꾼다 (게시판 순서로 정렬). 필터는 그대로, 선택은 첫 고를 수 있는 의뢰
func set_requests(list: Array[RequestData]) -> void:
	requests = RequestData.sort_for_board(list)
	selected = null
	_rebuild()


## 필터를 바꾼다. 고른 의뢰가 걸러지면 첫 고를 수 있는 의뢰로
func set_filter(f: RequestData.Filter) -> void:
	filter = f
	_rebuild()


## 의뢰를 고른다 (잠긴 의뢰·목록에 없는 의뢰는 무시)
func select(r: RequestData) -> void:
	if r == null or not r.is_selectable() or not r in visible_requests():
		return
	selected = r
	_refresh_selection()


## 지금 필터로 목록에 보이는 의뢰들 (화면 순서)
func visible_requests() -> Array[RequestData]:
	return RequestData.filtered(requests, filter)


## 선택을 dir(+1 아래, -1 위) 방향 다음 고를 수 있는 의뢰로. 끝에서는 멈춘다
func move_selection(dir: int) -> void:
	var list := visible_requests()
	var i := list.find(selected)
	while true:
		i += dir
		if i < 0 or i >= list.size():
			return
		if list[i].is_selectable():
			select(list[i])
			return


## 고른 의뢰를 수락한다 (없으면 아무 일 없음)
func accept() -> void:
	if selected:
		accepted.emit(selected)


## 필터에 맞게 카드를 다시 만들고 선택·칩·자세히를 맞춘다
func _rebuild() -> void:
	# 1. 기존 카드 지우기 (틀 씬에서 복제한 것들)
	for c in _cards:
		c.queue_free()
	_cards.clear()
	# 2. 보이는 의뢰마다 카드 하나
	var list := visible_requests()
	for r in list:
		var card: RequestCard = CARD_SCENE.instantiate()
		%CardList.add_child(card)
		card.set_request(r)
		card.pressed.connect(select.bind(r))
		_cards.append(card)
	# 3. 고른 의뢰가 목록에 없으면 첫 고를 수 있는 의뢰로
	if selected == null or not selected in list:
		selected = null
		for r in list:
			if r.is_selectable():
				selected = r
				break
	_refresh_chips()
	_refresh_selection()


## 카드 선택 모양 + 오른쪽 자세히를 지금 선택에 맞춘다
func _refresh_selection() -> void:
	for c in _cards:
		c.set_selected(c.request == selected)
	_refresh_detail()


## 필터 칩 글·그림 (고른 칩 = 꽉 찬 연보라 + Ink 글)
func _refresh_chips() -> void:
	var chips := _chips()
	var texts := ["전체 %d" % requests.size(), "본 이야기", "반복 의뢰"]
	var idle_tex: Array[Texture2D] = [CHIP_MAIN, CHIP_MAIN, CHIP_REPEAT]
	var idle_color: Array[Color] = [UiPalette.ACCENT, UiPalette.ACCENT, UiPalette.TEAL]
	for i in chips.size():
		var on := i == filter
		var label: Label = chips[i].get_child(0)
		label.text = texts[i]
		label.add_theme_color_override("font_color", UiPalette.INK if on else idle_color[i])
		chips[i].texture = CHIP_FILLED if on else idle_tex[i]
		chips[i].custom_minimum_size.x = label.get_minimum_size().x + chip_padding * 2


## 오른쪽 자세히 보기를 고른 의뢰로 채운다. 고른 의뢰가 없으면 숨긴다
func _refresh_detail() -> void:
	%Detail.visible = selected != null
	if selected == null:
		return
	var r := selected
	# 1. 의뢰인
	%Portrait.texture = r.portrait
	%PortraitHint.visible = r.portrait == null
	%ClientKo.text = r.client_ko
	%ClientEn.text = r.client_en
	# 2. 장 줄 · 제목 · 인용 · 정보
	%ChapterLine.text = r.chapter_line()
	%DetailTitle.text = r.title
	%Quote.text = r.quote
	%Rank.text = r.rank
	%Region.text = r.region
	%Enemies.text = r.enemies
	# 3. 목표 줄: 템플릿을 복제해 목표 수만큼 (체크는 아직 없음 — 모두 빈 칸)
	for row in _objective_rows:
		row.queue_free()
	_objective_rows.clear()
	for text in r.objectives:
		var row: Control = %ObjectiveTemplate.duplicate()
		row.visible = true
		%ObjectiveList.add_child(row)
		row.get_node("Text").text = text
		_objective_rows.append(row)
	# 4. 보상 글, 긴급 도장
	%RewardText.text = r.reward_text
	%Stamp.visible = r.urgent


## 필터 칩 3개 (Filter 순서)
func _chips() -> Array[NinePatchRect]:
	var out: Array[NinePatchRect] = []
	for c in %Filters.get_children():
		if c is NinePatchRect:
			out.append(c)
	return out


## 칩 클릭 → 그 필터로
func _on_chip_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_filter(index as RequestData.Filter)


## event 가 keycode 키를 누른 순간인지 (W/S/E — ui_* 액션에 없는 키)
func _is_key(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == keycode
