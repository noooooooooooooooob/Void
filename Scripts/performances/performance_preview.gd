class_name PerformancePreview
extends Control
## 연출 미리보기 (개발용). Scenes/performances/performance_preview.tscn 을 열고 F6.
## 실제 전투 화면(시험 전투) 위에서 고른 카드를 바로 써서, 피격 반응·숫자·카메라까지 진짜 전투와 똑같이 연출을 본다.
## (설계 docs/superpowers/specs/2026-11-19-performance-timeline-design.md 5장)
##
## ▶ 할 때마다 전투를 처음으로 되돌리고, 행위자 유닛을 "그 카드만 든 덱·SP 넉넉·가장 빠름" 으로 바꾼 복사본으로 시작한다.
## 원본 UnitData(.tres)는 건드리지 않는다. 연출 씬을 고친 뒤에는 F6 을 다시 눌러야 새 내용이 보인다.

## 연출이 한 번 끝났다 (반복이 켜져 있으면 곧바로 다시 재생)
signal preview_finished()

## 미리볼 카드. 정해 두면 그 카드가 처음부터 골라져 있다
@export var card: CardData
## 연출 있는 카드를 찾을 폴더 (하위 폴더 포함)
@export_dir var cards_dir := "res://cards/data/"
## 켜져 있으면 실행하자마자 한 번 재생한다
@export var autoplay := true

## 속도 목록 칸에 넣을 배속들
const SPEEDS := [0.25, 0.5, 1.0]

@onready var _screen: BattleScreen = $BattleScreen
@onready var _card_list: OptionButton = %CardList
@onready var _target_list: OptionButton = %TargetList
@onready var _play_button: Button = %PlayButton
@onready var _loop_check: CheckBox = %LoopCheck
@onready var _speed_list: OptionButton = %SpeedList

var _cards: Array[CardData] = []   # 목록 칸 순서대로의 카드들
var _source: BattleData            # 시험 전투 원본 (전투 화면에 처음 들어 있던 것)
var _waiting := false              # 이번 재생이 끝나길 기다리는 중인지
var _actor := 0                    # 행위자 아군 번호 — 고른 카드를 덱에 가진 아군으로 자동 (목록 없음, 2026-11-21)


## dir 아래(하위 폴더 포함)에서 연출 씬이 있는 카드를 이름순으로 모은다
static func performance_cards(dir: String) -> Array[CardData]:
	var out: Array[CardData] = []
	_collect(dir, out)
	out.sort_custom(func(a: CardData, b: CardData): return a.name_ko < b.name_ko)
	return out


static func _collect(dir: String, out: Array[CardData]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_collect(dir.path_join(sub), out)
	for f in d.get_files():
		# 내보낸 게임에서는 .tres.remap 으로 남으므로 그 이름도 받는다
		var path := dir.path_join(f.trim_suffix(".remap"))
		if not path.ends_with(".tres"):
			continue
		var c := load(path) as CardData
		if c and c.performance:
			out.append(c)


func _ready() -> void:
	_source = _screen.battle_data
	# 1. 카드 목록
	_cards = performance_cards(cards_dir)
	for c in _cards:
		_card_list.add_item(c.name_ko)
	var start := 0
	if card:
		for i in _cards.size():
			if _cards[i].id == card.id:
				start = i
	if not _cards.is_empty():
		_card_list.select(start)
	# 2. 대상(적) 목록. 행위자는 카드 주인으로 자동
	for s in _source.enemies:
		_target_list.add_item(s.unit.display_name)
	_select_owner()
	# 3. 속도
	for sp in SPEEDS:
		_speed_list.add_item("%s×" % sp)
	_speed_list.select(SPEEDS.size() - 1)
	_card_list.item_selected.connect(func(_i): _select_owner())
	_speed_list.item_selected.connect(func(i): set_speed(SPEEDS[i]))
	_play_button.pressed.connect(play_once)
	_screen.get_node("%PerformanceQueue").drained.connect(_on_drained)
	if autoplay and not _cards.is_empty():
		play_once.call_deferred()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## 재생 속도 (1 = 보통). 개발용 씬이라 Engine.time_scale 을 쓴다. 씬을 나가면 1 로 돌아간다
func set_speed(s: float) -> void:
	Engine.time_scale = s


## 고른 카드로 전투를 처음부터 다시 시작하고, 행위자가 그 카드를 고른 대상에게 쓴다
func play_once() -> void:
	var c := _current_card()
	if c == null or _source == null:
		return
	# 1. 행위자 복사본: 그 카드만 든 덱, SP 넉넉, 가장 먼저 행동
	var data: BattleData = _source.duplicate()  # 격자 크기·배경 등 나머지 칸은 그대로
	var allies: Array[BattleSlot] = []
	for i in _source.allies.size():
		var slot: BattleSlot = _source.allies[i]
		if i == _actor:
			var u: UnitData = slot.unit.duplicate()
			var deck: Array[CardData] = []
			for k in 10:
				deck.append(c)
			u.deck = deck
			u.max_sp = 99
			u.speed_min = 999
			u.speed_max = 999
			var copy := BattleSlot.new()
			copy.unit = u
			copy.cell = slot.cell
			slot = copy
		allies.append(slot)
	data.allies = allies
	_screen.battle_data = data
	_screen.restart()
	# 2. 카드 사용 (근접·자신은 같은 카드를 두 번 누르면 자동 대상)
	var session := _screen.session
	if session.active == null or session.active.hand.is_empty():
		return
	var hand_card := session.active.hand[0]
	var targets := session.targets_for(hand_card)
	if targets.is_empty() or not _screen.select_card(0):
		push_warning("PerformancePreview: %s 을(를) 지금 쓸 수 없어요" % c.name_ko)
		return
	_waiting = true
	if not _screen.select_card(0):
		_waiting = false
		return
	if _screen.get_node("%PerformanceQueue").is_busy():
		return
	var want := _target_unit()
	_screen.click_unit(want if targets.has(want) else targets[0])


## 지금 행위자의 유닛 데이터 (원본, 테스트·확인용)
func actor_unit() -> UnitData:
	return _source.allies[_actor].unit if _source and _actor < _source.allies.size() else null


## 목록에서 고른 카드 (없으면 null)
func _current_card() -> CardData:
	var i := _card_list.selected
	return _cards[i] if i >= 0 and i < _cards.size() else null


## 목록에서 고른 적 유닛 (전투 안의 BattleUnit, 없으면 null)
func _target_unit() -> BattleUnit:
	var i := _target_list.selected
	if i < 0 or i >= _source.enemies.size():
		return null
	var want: UnitData = _source.enemies[i].unit
	for u in _screen.session.battle.units:
		if u.data == want:
			return u
	return null


## 행위자 = 그 카드를 덱에 가진 아군 (없으면 첫 아군)
func _select_owner() -> void:
	var c := _current_card()
	var pick := 0
	if c:
		for i in _source.allies.size():
			if _source.allies[i].unit.deck.any(func(d: CardData): return d.id == c.id):
				pick = i
				break
	_actor = pick


## 연출이 다 끝남: 알리고, 반복이 켜져 있으면 다시
func _on_drained() -> void:
	if not _waiting:
		return
	_waiting = false
	preview_finished.emit()
	if _loop_check.button_pressed:
		play_once.call_deferred()
