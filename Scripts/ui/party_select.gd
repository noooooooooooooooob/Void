class_name PartySelect
extends Control
## 파티 선택 화면. party_select.tscn 의 스크립트. 공허 지도에서 "들어가기"를 누르면 온다 (StageRun.pending_site 가 들어갈 공허).
## 카드(전투 유닛)가 있는 캐릭터만 고를 수 있고, 최대 MAX_PARTY 명. 고른 순서대로 아군 앞줄에 선다(StageRun.PARTY_CELLS).
## 캐릭터마다 CharacterCardTemplate(숨겨 둔 버튼 틀)을 복제한다. 모양은 씬에서 고친다.
## 조작: 캐릭터 클릭으로 넣고 빼기, "출발"(엔터) → 스테이지 지도, "뒤로"(ESC) → 공허 지도

## 한 번에 데려갈 수 있는 최대 인원 (설정집 후보 "출전 3명" — 노션 규칙이 정해지면 바꾼다)
const MAX_PARTY := 3

## 사원 명부 (인스펙터에서 entities/roster.tres 를 넣는다)
@export var roster: RosterData

## 고를 수 있는 캐릭터 (전투 유닛이 있는 캐릭터, 명부 순서)
var choices: Array[CharacterProfile] = []
## 고른 캐릭터 (고른 순서 = 자리 순서)
var chosen: Array[CharacterProfile] = []
## 캐릭터마다 만든 버튼 (choices 와 같은 순서)
var buttons: Array[Button] = []

@onready var _list: HBoxContainer = %CharacterList
@onready var _template: Button = %CharacterCardTemplate
@onready var _site_label: Label = %SiteLabel
@onready var _count: Label = %CountLabel
@onready var _start: Button = %StartButton


func _ready() -> void:
	%BackButton.pressed.connect(Router.goto.bind(Router.Screen.VOID_MAP))
	_start.pressed.connect(start)
	var site := StageRun.pending_site
	_site_label.text = ("들어갈 공허: " + site.display_name) if site else "들어갈 공허: (없음 — 개발용)"
	if roster == null:
		push_warning("PartySelect: roster 가 비어 있어요")
		return
	# 1. 카드가 있는 캐릭터마다 버튼을 틀에서 복제한다
	for c in roster.characters:
		if c == null or c.unit == null:
			continue
		choices.append(c)
		var b: Button = _template.duplicate()
		b.visible = true
		b.icon = c.pixel if c.pixel else c.portrait
		b.text = c.display_name
		b.pressed.connect(toggle.bind(c))
		_list.add_child(b)
		buttons.append(b)
	# 2. 첫 캐릭터를 기본으로 넣어 둔다
	if not choices.is_empty():
		chosen.append(choices[0])
	_refresh()


## c 를 파티에 넣거나 뺀다. 꽉 차 있으면 넣지 않는다
func toggle(c: CharacterProfile) -> void:
	if c in chosen:
		chosen.erase(c)
	elif chosen.size() < MAX_PARTY:
		chosen.append(c)
	_refresh()


## 고른 캐릭터로 의뢰를 시작하고 스테이지 지도로 (1명 이상일 때만)
func start() -> void:
	if chosen.is_empty():
		return
	var units: Array[UnitData] = []
	for c in chosen:
		units.append(c.unit)
	StageRun.start_run(StageRun.pending_site, 0, units)
	StageRun.go_to(Router.Screen.STAGE_MAP)


## 버튼 눌림 상태(고른 순서 번호), 인원 표시, 출발 버튼
func _refresh() -> void:
	for i in choices.size():
		var c := choices[i]
		var order := chosen.find(c)
		buttons[i].set_pressed_no_signal(order >= 0)
		buttons[i].text = ("%d. %s" % [order + 1, c.display_name]) if order >= 0 else c.display_name
	_count.text = "%d / %d명" % [chosen.size(), MAX_PARTY]
	_start.disabled = chosen.is_empty()


## ESC: 공허 지도로 (엔터는 포커스가 있는 버튼이 받는다)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Router.goto(Router.Screen.VOID_MAP)
