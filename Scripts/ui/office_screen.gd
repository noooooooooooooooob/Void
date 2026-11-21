class_name OfficeScreen
extends Control
## 사무소(로비) 화면. Figma v6 00-A 기본 상태 + 01~07 패널. 씬: `Scenes/ui/office_screen/office_screen.tscn`.
## 설계 docs/superpowers/specs/2026-11-21-ui-frame-design.md 5-2.
##
## - 왼쪽 레일 메뉴(%RailMenu 의 RailMenuItem 7개)를 누르면 같은 순서의 패널(%Panels 의 OfficePanel 7개)이 열린다
## - 한 번에 패널 하나. 같은 메뉴를 다시 누르거나 ESC·닫기 → 닫힘, 다른 메뉴 → 바로 바뀜
## - 숫자키 1~7 로도 연다
## - 오른쪽 위 자금 HUD, 설정·하루 마치기 버튼(아직 "준비 중")
## - 의뢰 게시판 패널의 임시 버튼 "시험 의뢰 출발" → 스테이지 지도 (의뢰 게시판을 만들면 지운다)

## 자금 (cr.). 자금 시스템이 생기기 전까지 이 값을 그대로 보여 준다
@export var funds := 0:
	set(v):
		funds = v
		if is_node_ready():
			%FundsLabel.text = format_funds(funds)
## 임시 의뢰 버튼이 넘어갈 씬. 인스펙터에서 stage_map.tscn 을 끌어다 넣는다
@export var stage_scene: PackedScene

## 지금 열린 패널 번호 (0 부터, 없으면 -1). 테스트에서도 읽는다
var open_index := -1

var _rail: Array[RailMenuItem] = []
var _panels: Array[OfficePanel] = []


func _ready() -> void:
	# 1. 레일 메뉴와 패널을 순서대로 모으고 서로 잇는다
	for c in %RailMenu.get_children():
		if c is RailMenuItem:
			_rail.append(c)
	for c in %Panels.get_children():
		if c is OfficePanel:
			_panels.append(c)
	if _rail.size() != _panels.size():
		push_warning("OfficeScreen: 레일 메뉴(%d)와 패널(%d) 수가 달라요" % [_rail.size(), _panels.size()])
	for i in _rail.size():
		_rail[i].pressed.connect(toggle.bind(i))
	for i in _panels.size():
		_panels[i].close_requested.connect(close_panel)
		_panels[i].close(false)
	# 2. 버튼들
	%SettingsButton.pressed.connect(func(): %Notice.show_text("설정은 준비 중입니다"))
	%EndDayButton.pressed.connect(func(): %Notice.show_text("하루 마치기는 준비 중입니다"))
	%TestQuestButton.pressed.connect(_on_test_quest_pressed)
	# 3. 처음 모양: 패널 없음, 안내 글 보임, 자금 표시
	%FundsLabel.text = format_funds(funds)
	_update_rail()


func _unhandled_input(event: InputEvent) -> void:
	# ESC: 열린 패널 닫기 (없으면 아무 일 없음)
	if event.is_action_pressed("ui_cancel") and open_index >= 0:
		close_panel()
		get_viewport().set_input_as_handled()
		return
	# 숫자키 1~7: 그 메뉴 열기/닫기
	if event is InputEventKey and event.pressed and not event.echo:
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < _panels.size():
			toggle(i)
			get_viewport().set_input_as_handled()


## index 번 패널을 연다. 이미 열려 있으면 닫는다. 다른 패널이 열려 있으면 연출 없이 닫고 바꾼다
func toggle(index: int) -> void:
	if index == open_index:
		close_panel()
		return
	open_panel(index)


## index 번 패널을 연다 (0 부터)
func open_panel(index: int) -> void:
	if index < 0 or index >= _panels.size():
		return
	if open_index >= 0:
		_panels[open_index].close(false)
	open_index = index
	_panels[index].open()
	_update_rail()


## 열린 패널을 닫는다
func close_panel() -> void:
	if open_index < 0:
		return
	_panels[open_index].close()
	open_index = -1
	_update_rail()


## 레일의 선택 모양과 "메뉴를 고르면…" 안내 글을 지금 열린 패널에 맞춘다
func _update_rail() -> void:
	for i in _rail.size():
		_rail[i].set_selected(i == open_index)
	%EmptyHint.visible = open_index < 0


## 임시: 지금 있는 의뢰(스테이지 지도)로. StageMap 이 들어가면서 start_run 한다
func _on_test_quest_pressed() -> void:
	if stage_scene == null:
		push_warning("OfficeScreen: stage_scene 이 비어 있어요")
		return
	get_tree().change_scene_to_packed(stage_scene)


## 자금을 세 자리마다 쉼표로 ("1250" → "1,250", 음수도)
static func format_funds(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
