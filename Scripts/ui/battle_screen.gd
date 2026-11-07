class_name BattleScreen
extends Control
## 전투 화면 (시험판). battle_screen.tscn 의 스크립트. 씬을 열고 F6 → battle_data 로 전투 한 판을 직접 플레이한다.
## 설계: docs/superpowers/specs/2026-11-05-battle-screen-design.md (배치는 Figma 와이어프레임 08-A 전투 HUD 기준)
##
## 역할 나눔:
## - 진행·규칙은 BattleSession / Battle 이 한다. 이 스크립트는 세션 상태를 그리고, 마우스 입력을 세션 호출로 바꾸기만 한다.
## - 노드 배치·스타일은 씬에서 편집한다. 여기서 만드는 노드는 데이터 개수만큼 복제하는 부품(칸, 유닛 박스, 초상화, 상태 줄, 손패 카드, 떠오르는 숫자)뿐이다.
##
## 조작 (설계 4장):
## - 원거리·아군 카드: 카드를 누르면 휜 화살표가 마우스를 따라온다 → 대상 유닛 클릭(또는 끌던 손을 뗌)으로 사용.
## - 근접 카드: 화살표가 자동 대상에 고정 → 대상 클릭 또는 카드를 한 번 더 누르면 사용.
## - 자신 카드: 한 번 더 누르거나 손패 위로 끌어 올려 놓으면 사용.
## - 우클릭 / ESC: 취소. 카드를 안 고른 상태에서 빛나는 칸 클릭: 이동.
## - 적 차례는 enemy_delay 초 간격으로 자동 진행. 그동안 입력은 무시한다.
##
## 의뢰 모드: 스테이지 지도에서 전투 노드로 들어오면(StageRun.in_battle()) battle_data 대신 의뢰의 전투 데이터와
## 파티(HP 유지)를 쓰고, 결과 버튼이 "계속"(승리 → 지도) / "처음으로"(패배 → 의뢰 실패) 가 된다.

## 플레이할 전투 데이터 (기본: battles/test_battle.tres)
@export var battle_data: BattleData
## 적 행동 사이 간격 (초). 0 이면 자동으로 진행하지 않는다 (테스트에서 직접 step_enemy 를 부름).
@export var enemy_delay := 0.7
## 난수 시드. "다시 하기"마다 1씩 늘어난다.
@export var battle_seed := 0
## 손패에서 이만큼(픽셀) 위로 끌어 올린 뒤 놓으면 자신 카드를 쓴다
@export var drag_play_height := 120.0
## 전투 기록에 남길 줄 수
@export var log_lines := 8

const GRID_CELL := preload("res://Scenes/ui/battle_screen/grid_cell.tscn")
const UNIT_TOKEN := preload("res://Scenes/ui/battle_screen/unit_token.tscn")
const TURN_PORTRAIT := preload("res://Scenes/ui/battle_screen/turn_portrait.tscn")
const STATUS_ROW := preload("res://Scenes/ui/battle_screen/unit_status_row.tscn")
const FLOAT_NUMBER := preload("res://Scenes/ui/battle_screen/float_number.tscn")
const CARD_VIEW := preload("res://Scenes/ui/card_view/card_view.tscn")

## 지금 진행 중인 세션
var session: BattleSession
## 지금 고른 카드 (없으면 null)
var selected: CardData = null
## 고른 카드의 손패 번호 (없으면 -1). 같은 카드 리소스가 여러 장 있어도(타격 4장 등) 한 장만 고르기 위해 번호로 기억한다.
var selected_index := -1

# --- 씬의 노드 ---
@onready var _bg_layer: Control = %BackgroundLayer
@onready var _round_label: Label = %RoundLabel
@onready var _banner: Label = %TurnBanner
@onready var _turn_queue: HBoxContainer = %TurnQueue
@onready var _ally_panel: VBoxContainer = %AllyPanel
@onready var _enemy_panel: VBoxContainer = %EnemyPanel
@onready var _ally_grid: GridContainer = %AllyGrid
@onready var _enemy_grid: GridContainer = %EnemyGrid
@onready var _hand: HBoxContainer = %Hand
@onready var _sp_label: Label = %SpLabel
@onready var _move_label: Label = %MoveLabel
@onready var _deck_label: Label = %DeckLabel
@onready var _discard_label: Label = %DiscardLabel
@onready var _exile_label: Label = %ExileLabel
@onready var _end_turn: Button = %EndTurnButton
@onready var _log: Label = %Log
@onready var _float_layer: Control = %FloatLayer
@onready var _arrow: TargetArrow = %TargetArrow
@onready var _result: Control = %ResultOverlay
@onready var _result_label: Label = %ResultLabel
@onready var _restart_button: Button = %RestartButton
@onready var _enemy_timer: Timer = %EnemyTimer

var _cells := {}        # Vector3i(편, 열, 행) → GridCell
var _tokens := {}       # BattleUnit → UnitToken
var _rows := {}         # BattleUnit → UnitStatusRow
var _round := 0         # 라운드 번호 (ROUND_START 를 셈)
var _log_texts: Array[String] = []
var _dragging := false  # 손패 카드를 누른 채 끌고 있는지
var _press_pos := Vector2.ZERO
var _stage_mode := false  # 의뢰(스테이지) 전투인지. 그러면 결과 버튼이 "다시 하기" 대신 지도로/처음으로 간다
var _won := false         # 마지막 전투를 이겼는지 (의뢰 모드 결과 버튼용)


func _ready() -> void:
	_end_turn.pressed.connect(press_end_turn)
	_restart_button.pressed.connect(_on_result_button)
	_enemy_timer.timeout.connect(_on_enemy_timer)
	_arrow.visible = false
	_result.visible = false
	# 의뢰 지도에서 전투 노드로 들어왔으면 의뢰의 전투 데이터와 파티(HP 유지)를 쓴다
	_stage_mode = StageRun.in_battle()
	if _stage_mode:
		battle_data = StageRun.battle_data()
	# 배경 씬은 전투 데이터마다 다르다. 없으면 뒤의 단색만 보인다
	if battle_data and battle_data.background:
		_bg_layer.add_child(battle_data.background.instantiate())
	if battle_data == null:
		push_warning("BattleScreen: battle_data 가 비어 있어요")
		return
	var allies: Array[BattleUnit] = []
	if _stage_mode:
		allies = StageRun.living_party()
	_start(BattleSession.new(battle_data, allies, battle_seed))


# --- 입력 진입점 (마우스 처리도 이 함수들을 부른다. 테스트도 이걸로 조작한다) ---

## 손패 index 번째 카드를 고른다. 이미 고른 카드면 자신·근접 카드는 바로 쓴다.
## 지금 쓸 수 없는 카드(대상 없음, SP 부족 등)거나 아군 차례가 아니면 false.
func select_card(index: int) -> bool:
	if not _input_ok() or index < 0 or index >= session.active.hand.size():
		return false
	var card := session.active.hand[index]
	if index == selected_index:
		# 같은 카드를 다시 누름: 자신 카드 = 사용, 근접 카드 = 자동 대상에 사용
		var kind := _attack_type(card)
		if kind == "self" or kind == "melee":
			_play(null)
		return true
	if session.targets_for(card).is_empty():
		return false
	selected = card
	selected_index = index
	refresh()
	return true


## 유닛을 눌렀을 때: 고른 카드가 있고 그 유닛이 대상 후보면 카드를 쓴다.
func click_unit(u: BattleUnit) -> bool:
	if not _input_ok() or selected == null or u == null:
		return false
	if not session.targets_for(selected).has(u):
		return false
	var kind := _attack_type(selected)
	_play(u if kind == "ranged" or kind == "ally" else null)
	return true


## 칸을 눌렀을 때: 카드를 고른 상태면 그 칸의 유닛을 대상으로, 아니면 이동.
func click_cell(side: int, cell: Vector2i) -> bool:
	if not _input_ok():
		return false
	if selected:
		return click_unit(session.battle.unit_at(side, cell))
	if side != session.active.side or not session.reachable_cells().has(cell):
		return false
	return session.move(cell)


## 고른 카드를 내려놓는다.
func cancel() -> void:
	selected = null
	selected_index = -1
	_dragging = false
	refresh()


## 차례 종료 버튼
func press_end_turn() -> void:
	if not _input_ok():
		return
	selected = null
	selected_index = -1
	session.end_player_turn()


## "다시 하기": 같은 전투 데이터로 새 전투 (시드 +1).
func restart() -> void:
	battle_seed += 1
	_start(BattleSession.new(battle_data, [], battle_seed))


# --- 세션 연결 ---

func _start(s: BattleSession) -> void:
	_enemy_timer.stop()
	session = s
	selected = null
	selected_index = -1
	_round = 0
	_log_texts.clear()
	_result.visible = false
	_build_board()
	_subscribe_events()
	session.changed.connect(_on_changed)
	session.finished.connect(_on_finished)
	session.start()
	refresh()


## 격자 칸·유닛 박스·상태 줄을 데이터 크기만큼 새로 깐다.
func _build_board() -> void:
	for parent in [_ally_grid, _enemy_grid, _ally_panel, _enemy_panel]:
		for c in parent.get_children():
			parent.remove_child(c)
			c.queue_free()
	_cells.clear()
	_tokens.clear()
	_rows.clear()
	var bt := session.battle
	_ally_grid.columns = bt.cols_of(BattleTypes.Side.ALLY)
	_enemy_grid.columns = bt.cols_of(BattleTypes.Side.ENEMY)
	for y in bt.grid_rows:
		# 아군 격자: 왼쪽이 후열(0), 오른쪽이 전열 → 가운데를 향함
		for x in bt.cols_of(BattleTypes.Side.ALLY):
			_add_cell(_ally_grid, BattleTypes.Side.ALLY, Vector2i(x, y))
		# 적 격자: 왼쪽이 전열(큰 값) → 가운데를 향함
		for x in range(bt.cols_of(BattleTypes.Side.ENEMY) - 1, -1, -1):
			_add_cell(_enemy_grid, BattleTypes.Side.ENEMY, Vector2i(x, y))
	for u in bt.units:
		var t: UnitToken = UNIT_TOKEN.instantiate()
		t.set_unit(u)
		t.pressed.connect(func(unit): click_unit(unit))
		_tokens[u] = t
		var row: UnitStatusRow = STATUS_ROW.instantiate()
		(_ally_panel if u.side == BattleTypes.Side.ALLY else _enemy_panel).add_child(row)
		row.set_unit(u)
		_rows[u] = row


func _add_cell(grid: GridContainer, side: int, cell: Vector2i) -> void:
	var c: GridCell = GRID_CELL.instantiate()
	grid.add_child(c)
	c.setup(side, cell)
	c.pressed.connect(func(s, at): click_cell(s, at))
	_cells[Vector3i(side, cell.x, cell.y)] = c


## 전투 이벤트 → 떠오르는 숫자·전투 기록·라운드 번호
func _subscribe_events() -> void:
	var ev := session.battle.events
	var E := BattleTypes.Event
	ev.subscribe(E.ROUND_START, func(_e): _round += 1)
	ev.subscribe(E.DAMAGE_TAKEN, func(e):
		_pop(e.target, "-%d" % e.amount, Color("ff5a5a"))
		_add_log("%s → %s 피해 %d" % [_who(e), e.target.data.display_name, e.amount]))
	ev.subscribe(E.BLOCK_GAINED, func(e):
		_pop(e.target, "+%d" % e.amount, Color("7fb8ff"))
		_add_log("%s 방어도 +%d" % [e.target.data.display_name, e.amount]))
	ev.subscribe(E.HEALED, func(e):
		_pop(e.target, "+%d" % e.amount, Color("7ee08a"))
		_add_log("%s 회복 +%d" % [e.target.data.display_name, e.amount]))
	ev.subscribe(E.BEFORE_CARD_PLAYED, func(e):
		var to: String = (" → " + e.target.data.display_name) if e.target and e.target != e.actor else ""
		_add_log("%s: %s%s" % [e.actor.data.display_name, e.card.name_ko, to]))
	ev.subscribe(E.UNIT_MOVED, func(e): _add_log("%s 이동 %d칸" % [e.actor.data.display_name, e.amount]))
	ev.subscribe(E.UNIT_DIED, func(e): _add_log("✖ %s 쓰러짐" % e.target.data.display_name))


func _on_changed() -> void:
	refresh()
	# 적 차례면 잠깐 뒤에 진행 (enemy_delay 가 0 이면 부르는 쪽이 직접 step_enemy)
	if session.is_enemy_turn() and enemy_delay > 0.0 and _enemy_timer.is_stopped():
		_enemy_timer.start(enemy_delay)


func _on_enemy_timer() -> void:
	session.step_enemy()


func _on_finished(winner: int) -> void:
	_enemy_timer.stop()
	selected = null
	selected_index = -1
	_won = winner == BattleTypes.Side.ALLY
	_result_label.text = "승리" if _won else "패배"
	# 의뢰 전투: 이기면 지도로 계속, 지면 의뢰 실패 → 시작 화면 (CLAUDE.md 의뢰 스테이지 규칙)
	if _stage_mode:
		_restart_button.text = "계속" if _won else "처음으로"
	_result.visible = true
	_restart_button.grab_focus()


## 결과 창 버튼: 의뢰 전투면 지도로(승리)/시작 화면으로(패배), 아니면 "다시 하기"
func _on_result_button() -> void:
	if not _stage_mode:
		restart()
	elif _won:
		StageRun.complete_node()
	else:
		StageRun.fail_run()


# --- 그리기 ---

## 세션의 지금 상태로 화면 전체를 다시 그린다.
func refresh() -> void:
	if session == null:
		return
	var bt := session.battle
	var hero := session.active
	_round_label.text = "라운드 %d" % _round
	if hero:
		_banner.text = "내 차례 · " + hero.data.display_name
	elif session.is_enemy_turn():
		_banner.text = "적 차례 · " + session.pending_enemy().data.display_name
	else:
		_banner.text = ""
	_draw_queue()
	# 유닛 박스: 서 있는 칸으로 옮기고 다시 그림 / 상태 줄
	var targets: Array[BattleUnit] = []
	if selected:
		targets = session.targets_for(selected)
	for u in _tokens:
		var t: UnitToken = _tokens[u]
		var cell: GridCell = _cells.get(Vector3i(u.side, u.cell.x, u.cell.y))
		if cell and t.get_parent() != cell:
			if t.get_parent():
				t.get_parent().remove_child(t)
			cell.add_child(t)
			t.position = (cell.custom_minimum_size - t.custom_minimum_size) * 0.5
		t.set_highlight(targets.has(u))
		t.visible = u.alive
	for u in _rows:
		_rows[u].refresh()
	_draw_marks(targets, null)
	_draw_hand()
	# 아래쪽 숫자: 지금 아군(없으면 첫 아군) 기준
	var who := hero if hero else (bt.living(BattleTypes.Side.ALLY)[0] if not bt.living(BattleTypes.Side.ALLY).is_empty() else null)
	if who:
		_sp_label.text = "SP %d / %d" % [who.sp, who.get_stat(BattleTypes.Stat.SP)]
		_move_label.text = "이동력 %d" % who.move_left
		_deck_label.text = "덱 %d" % who.deck.size()
		_discard_label.text = "버린 카드 %d" % who.discard.size()
		_exile_label.text = "제외 %d" % who.exiled.size()
	_end_turn.disabled = not _input_ok()
	_update_arrow()


func _draw_queue() -> void:
	for c in _turn_queue.get_children():
		_turn_queue.remove_child(c)
		c.queue_free()
	var q := session.turn_queue()
	for i in q.size():
		var p: TurnPortrait = TURN_PORTRAIT.instantiate()
		_turn_queue.add_child(p)
		p.set_entry(q[i].unit, q[i].speed, i == 0)


## 칸 표시: 카드를 골랐으면 대상 칸(빨강)과 마우스 아래 대상의 광역 범위(주황), 아니면 이동 가능 칸(하늘).
func _draw_marks(targets: Array[BattleUnit], hover: BattleUnit) -> void:
	for k in _cells:
		_cells[k].set_mark(GridCell.Mark.NONE)
	if session.active == null:
		return
	if selected:
		for u in targets:
			_mark(u.side, u.cell, GridCell.Mark.TARGET)
		if hover and targets.has(hover):
			var eff := session.battle.effective_card(session.active, selected)
			for u in session.battle.area_targets(hover, eff.area):
				_mark(u.side, u.cell, GridCell.Mark.AREA)
	else:
		for cell in session.reachable_cells():
			_mark(session.active.side, cell, GridCell.Mark.MOVE)


func _mark(side: int, cell: Vector2i, kind: int) -> void:
	var c: GridCell = _cells.get(Vector3i(side, cell.x, cell.y))
	if c:
		c.set_mark(kind)


## 손패: 지금 아군의 카드를 CardView 로 깐다. 손패에서는 대체 카드로 보인다 (CLAUDE.md 카드 대체).
## 계산된 수치를 크게 표시하고, 쓸 수 없는 카드는 어둡게, 고른 카드는 위로 올린다.
func _draw_hand() -> void:
	for c in _hand.get_children():
		_hand.remove_child(c)
		c.queue_free()
	var hero := session.active
	if hero == null:
		return
	for i in hero.hand.size():
		var card := hero.hand[i]
		var v: CardView = CARD_VIEW.instantiate()
		_hand.add_child(v)
		v.set_card(session.battle.effective_card(hero, card))
		v.show_amount(session.card_preview(card))
		v.set_dimmed(session.targets_for(card).is_empty())
		# 고른 카드는 손패 줄 위쪽에 붙어서 올라와 보이고, 나머지는 아래쪽에 붙는다.
		v.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if i == selected_index else Control.SIZE_SHRINK_END
		v.gui_input.connect(_on_card_input.bind(i))


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = get_global_mouse_position()
			_dragging = select_card(index) and selected != null
		elif _dragging:
			_release_drag()


## 손을 뗐을 때: 대상 유닛 위면 사용, 자신 카드를 충분히 끌어 올렸으면 사용. 그 자리에서 뗀 클릭은 고른 상태 유지.
func _release_drag() -> void:
	_dragging = false
	if selected == null:
		return
	var mouse := get_global_mouse_position()
	if mouse.distance_to(_press_pos) < 12.0:
		return
	var hover := _unit_under(mouse)
	if hover and click_unit(hover):
		return
	if _attack_type(selected) == "self" and _press_pos.y - mouse.y > drag_play_height:
		_play(null)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _dragging:
		_release_drag()


func _process(_delta: float) -> void:
	if selected:
		_update_arrow()


## 화살표: 원거리·아군·근접 카드를 골랐을 때 고른 카드 위쪽 가운데 → 마우스(근접은 자동 대상)
func _update_arrow() -> void:
	var kind := _attack_type(selected) if selected else ""
	if session == null or session.active == null or kind == "" or kind == "self":
		_arrow.visible = false
		return
	var view := _selected_view()
	if view == null:
		_arrow.visible = false
		return
	var from := view.get_global_rect().get_center() - Vector2(0, view.size.y * 0.5)
	var targets := session.targets_for(selected)
	var hover := _unit_under(get_global_mouse_position())
	var to := get_global_mouse_position()
	if kind == "melee" and not targets.is_empty():
		to = _tokens[targets[0]].get_global_rect().get_center()
		hover = targets[0]
	_arrow.visible = true
	_arrow.set_points(from, to)
	_arrow.set_valid(hover != null and targets.has(hover))
	_draw_marks(targets, hover)


func _selected_view() -> CardView:
	if session.active == null:
		return null
	var i := selected_index
	return _hand.get_child(i) as CardView if i >= 0 and i < _hand.get_child_count() else null


## 화면 좌표 아래에 있는 살아 있는 유닛 (없으면 null)
func _unit_under(pos: Vector2) -> BattleUnit:
	for u in _tokens:
		var t: UnitToken = _tokens[u]
		if u.alive and t.is_visible_in_tree() and t.get_global_rect().has_point(pos):
			return u
	return null


# --- 도우미 ---

func _play(origin: BattleUnit) -> void:
	var card := selected
	selected = null
	selected_index = -1
	_dragging = false
	if not session.play(card, origin):
		refresh()


func _input_ok() -> bool:
	return session != null and session.active != null and not session.is_finished()


func _attack_type(card: CardData) -> String:
	return session.battle.effective_card(session.active, card).attack_type if session.active else card.attack_type


func _who(e: BattleEvent) -> String:
	if e.actor:
		return e.actor.data.display_name
	return "(%s)" % (e.source.display_name if e.source is StatusData else "상태")


func _pop(u: BattleUnit, text: String, color: Color) -> void:
	var t: UnitToken = _tokens.get(u)
	if t == null or not t.is_inside_tree():
		return
	var f: FloatNumber = FLOAT_NUMBER.instantiate()
	_float_layer.add_child(f)
	f.global_position = t.get_global_rect().get_center() - Vector2(f.size.x * 0.5, 70)
	f.pop(text, color)


func _add_log(line: String) -> void:
	_log_texts.append(line)
	while _log_texts.size() > log_lines:
		_log_texts.pop_front()
	_log.text = "\n".join(_log_texts)
