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
## - 원거리·아군 카드: 카드를 누른 채 끌면 휜 화살표가 마우스를 따라온다 → 대상 유닛 위에서 손을 떼면 사용.
## - 근접 카드: 화살표가 자동 대상에 고정 → 대상 위에서 손을 떼면 사용.
## - 자신 카드: 손패 위로 끌어 올려 놓으면 사용.
## - 쓸 수 없는 곳에서 떼거나, 끌지 않고 그냥 클릭했다 떼면 카드가 손패로 돌아간다 (2026-11-15).
## - 우클릭 / ESC: 취소.
## - 이동 (2026-11-17, 설계 docs/superpowers/specs/2026-11-17-move-button-design.md):
##   이동 버튼을 눌러 이동 모드를 켜야 갈 수 있는 칸이 빛나고, 그 칸을 누르면 이동한 뒤 모드가 꺼진다.
## - 소비 아이템 (설계 docs/superpowers/specs/2026-11-17-consumable-items-design.md):
##   TAB 또는 가방 버튼으로 가방을 열고, 아이템 칸을 누른 채 끌어 아군 위에서 떼면 사용 (카드와 같은 화살표).
##   그 밖에서 떼면(제자리 클릭도) 취소. 아군 차례의 카드 사용 페이즈에만 쓸 수 있고 비용은 없다.
## - 적 차례는 enemy_delay 초 간격으로 자동 진행. 그동안 입력은 무시한다.
##
## 카드 연출 (설계 docs/superpowers/specs/2026-11-14-card-performance-design.md):
## - 전투 계산은 즉시 끝나지만, 화면은 이벤트를 PerformanceRecorder 로 단계별로 모아 PerformanceQueue 에 넘긴다.
## - 연출 씬이 있는 카드는 연출이 끝날 때까지 결과(숫자·HP)를 미루고, 그동안 입력·적 행동·결과 창도 기다린다.
## - 연출 씬이 없는 카드·카드 밖 이벤트는 그 자리에서 바로 그린다 (예전과 같음).
##
## 의뢰 모드: 스테이지 지도에서 전투 노드로 들어오면(StageRun.in_battle()) battle_data 대신 의뢰의 전투 데이터와
## 파티(HP 유지)를 쓰고, 결과 버튼이 "계속"(승리 → 지도) / "처음으로"(패배 → 의뢰 실패) 가 된다.

## 플레이할 전투 데이터 (기본: battles/test_battle.tres)
@export var battle_data: BattleData
## 적 행동 사이 간격 (초). 0 이면 자동으로 진행하지 않는다 (테스트에서 직접 step_enemy 를 부름).
@export var enemy_delay := 0.7
## 난수 시드. "다시 하기"마다 1씩 늘어난다.
@export var battle_seed := 0
## 손패에서 이만큼(픽셀) 위로 끌어 올린 뒤 놓으면 자신·근접 카드를 쓴다 (대상 고를 필요 없는 카드)
@export var drag_play_height := 120.0
## 전투 기록에 남길 줄 수
@export var log_lines := 8
## 손패 카드가 평소에 내려가 있는 거리 (픽셀). 화면 아래로 이만큼 묻히고, 마우스를 올린 카드만 떠오른다
@export var hand_sink := 150.0
## 손패 카드가 떠오르고 내려가는 빠르기 (클수록 빠름, 1초에 남은 거리의 대략 이 배수만큼)
@export var hand_rise_speed := 14.0
## 시험용 아이템: 의뢰 밖에서(F6 시험 전투) 가방에 넣어 두는 소비 아이템. "다시 하기" 때도 다시 채운다. 의뢰 전투에서는 쓰지 않는다
@export var test_items: Array[ConsumableData] = []
## 의뢰의 일반 전투에서 이겼을 때 소비 아이템 1개가 나올 확률 (0 ~ 1, 전투 공통 값). 보스·시험 전투는 드랍 없음
@export_range(0.0, 1.0) var item_drop_chance := 0.4
## 의뢰의 일반 전투에서 이겼을 때 카드 보상으로 보여 줄 후보 장수 (그중 1장을 고른다). 보스·시험 전투는 카드 보상 없음
@export var card_reward_count := 3

@export_group("피격 반응 (공통값)")
## hit 때 대상 위치에 띄우는 이펙트 씬 (한 번 재생하고 스스로 지워지는 씬). 비우면 이펙트 없음. 카드 연출 씬의 hit_effect 가 있으면 그것
@export var hit_effect: PackedScene
## hit 때 효과음. 비우면 소리 없음. 카드 연출 씬의 hit_sound 가 있으면 그것
@export var hit_sound: AudioStream
## hit 때 화면 흔들림 세기 (픽셀). 카드 연출 씬의 hit_shake 가 0 이상이면 그것
@export var hit_shake := 6.0
## hit 때 대상 캐릭터 그림 흔들림 세기 (픽셀, 공통값만)
@export var hit_unit_shake := 4.0
## 흔들림이 약해지며 멈추는 데 걸리는 시간 (초)
@export var shake_time := 0.2
## 효과음 음높이를 매번 이만큼(비율) 안에서 무작위로 바꾼다 (0.08 = ±8%)
@export var pitch_jitter := 0.08
## 히트스톱: hit 순간 연출(공격자·이펙트·이동)과 대상 그림을 함께 느리게 하는 시간 (초). 카드 연출 씬의 hitstop_time 이 0 이상이면 그것
## (2026-11-21 사용자 결정: 정지 대신 슬로우모션)
@export var hitstop_time := 0.15
## 히트스톱 동안의 배속 (0 = 정지, 0.2 = 5배 느리게). 카드 연출 씬의 hitstop_speed 가 0 이상이면 그것
@export var hitstop_speed := 0.2
## 피격 번쩍임: hit 순간 대상 그림을 이 색(1 보다 크면 하얗게 빛남)으로 했다가 flash_time 초 동안 원래 색으로
@export var flash_color := Color(3, 3, 3)
## 피격 번쩍임이 사라지는 시간 (초)
@export var flash_time := 0.08
## 넉백: hit 순간 대상 그림이 공격자 반대쪽으로 밀리는 거리 (화면 픽셀). 카드 연출 씬의 knockback 이 0 이상이면 그것
@export var knockback := 12.0
## 넉백 뒤 제자리로 천천히 돌아오는 시간 (초)
@export var knockback_return := 0.25

@export_group("숫자 색")
## 피해 숫자 색 (부호 없이 색으로 구분)
@export var damage_color := Color("ff5a5a")
## 회복 숫자 색
@export var heal_color := Color("7ee08a")
## 방어도 숫자 색
@export var block_color := Color("7fb8ff")

@export_group("강조 (공통값)")
## 피해 숫자 크기: 1 + (피해 / 대상 최대 HP, 최대 1) × 이 값. 최대 HP 를 한 번에 깎으면 1 + 이 값 배
@export var big_number_boost := 0.6
## 치명타 피해 숫자 크기 배율
@export var crit_number_scale := 1.3
## 치명타가 있으면 결과 표시 때 화면을 hit_shake × 이 값으로 한 번 더 흔든다
## (hit_shake 등은 카드별 값이 있으면 그것 — 2026-11-21)
@export var crit_shake_boost := 1.3
## 치명타가 있으면 결과 표시 때 히트스톱 슬로우모션을 hitstop_time × 이 값 동안 한 번 더 (2026-11-21)
@export var crit_hitstop_boost := 1.3
## 쓰러뜨린 결과면 결과 표시 때 화면 흔들림·히트스톱 슬로우모션을 (카드별 값 또는 공통값) × 이 값으로 한 번 더
@export var kill_boost := 1.8

const GRID_CELL := preload("res://Scenes/ui/battle_screen/grid_cell.tscn")
const UNIT_TOKEN := preload("res://Scenes/ui/battle_screen/unit_token.tscn")
const TURN_PORTRAIT := preload("res://Scenes/ui/battle_screen/turn_portrait.tscn")
const STATUS_ROW := preload("res://Scenes/ui/battle_screen/unit_status_row.tscn")
const FLOAT_NUMBER := preload("res://Scenes/ui/battle_screen/float_number.tscn")
const CARD_VIEW := preload("res://Scenes/ui/card_view/card_view.tscn")
## 카드 보상 후보 한 칸의 틀 (상점과 같은 칸: CardView %Card + Button %Button)
const CARD_OFFER := preload("res://Scenes/ui/shop_screen/shop_card_offer.tscn")

## 지금 진행 중인 세션
var session: BattleSession
## 지금 고른 카드 (없으면 null)
var selected: CardData = null
## 고른 카드의 손패 번호 (없으면 -1). 같은 카드 리소스가 여러 장 있어도(타격 4장 등) 한 장만 고르기 위해 번호로 기억한다.
var selected_index := -1
## 지금 고른(끌고 있는) 아이템의 가방 칸 번호 (없으면 -1). 카드와 아이템은 동시에 고르지 않는다.
var selected_item := -1
## 드랍 후보 아이템 폴더 (이 폴더의 소비 아이템 중 하나가 같은 확률로 나온다). 테스트에서 바꾼다.
var drop_pool_dir := StageRun.ITEM_DIR
## 카드 보상 후보 폴더 (하위 폴더 포함, 파티 캐릭터의 카드만 후보). 테스트에서 바꾼다.
var card_pool_dir := CardPool.DEFAULT_DIR
## 이번 승리의 보상 (결과 창 보상 목록). 의뢰 전투에서 이겼을 때만 있고, 패배·시험 전투는 null
var reward: BattleReward = null

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
@onready var _bag_button: Button = %BagButton
@onready var _move_button: Button = %MoveButton
@onready var _bag_panel: BagPanel = %BagPanel
@onready var _log: Label = %Log
@onready var _float_layer: Control = %FloatLayer
@onready var _arrow: TargetArrow = %TargetArrow
@onready var _result: Control = %ResultOverlay
@onready var _result_label: Label = %ResultLabel
@onready var _restart_button: Button = %RestartButton
@onready var _drop_box: Control = %DropBox
@onready var _drop_label: Label = %DropLabel    # 바꿀 칸 고르기 안내 (받을 아이템 이름 포함)
@onready var _drop_slots: HBoxContainer = %DropSlots
@onready var _reward_list: VBoxContainer = %RewardList     # 결과 창 보상 목록
@onready var _reward_template: Button = %RewardTemplate     # 보상 한 줄의 틀 (숨김, 복제해서 쓴다)
@onready var _card_pick: Control = %CardPick                # 카드 보상 고르기 창
@onready var _card_pick_row: HBoxContainer = %CardPickRow   # 카드 후보 칸들
@onready var _card_pick_skip: Button = %CardPickSkip        # 카드 고르기 창 닫기 (보상 줄은 남음)
@onready var _result_box: Control = %ResultOverlay/Box       # 결과 글자·보상 목록·계속 버튼 묶음 (카드 고르기 창이 열리면 숨김)
@onready var _skip_button: Button = %SkipButton
@onready var _enemy_timer: Timer = %EnemyTimer
@onready var _perf_layer: Control = %PerformanceLayer
## 연출 카메라가 움직이는 월드 묶음 (배경·격자). UI 는 여기에 없어서 고정된다
@onready var _world: Control = %World
## 연출 카메라가 움직이는 앞쪽 월드 묶음 (연출·숫자 레이어). World 와 같은 변환을 받는다 — 그리기 순서를 지키려고 둘로 나눔
@onready var _world_front: Control = %WorldFront
@onready var _queue: PerformanceQueue = %PerformanceQueue
@onready var _hit_sound: AudioStreamPlayer = %HitSound

var _cells := {}        # Vector3i(편, 열, 행) → GridCell
var _tokens := {}       # BattleUnit → UnitToken
var _rows := {}         # BattleUnit → UnitStatusRow
var _round := 0         # 라운드 번호 (ROUND_START 를 셈)
var _log_texts: Array[String] = []
var _dragging := false  # 손패 카드를 누른 채 끌고 있는지
var _dragging_item := false  # 가방 칸을 누른 채 끌고 있는지 (카드의 _dragging 과 같은 역할)
var _move_mode := false  # 이동 버튼을 눌러 이동 칸을 고르는 중인지
var _press_pos := Vector2.ZERO
var _stage_mode := false  # 의뢰(스테이지) 전투인지. 그러면 결과 버튼이 "다시 하기" 대신 지도로/처음으로 간다
var _won := false         # 마지막 전투를 이겼는지 (의뢰 모드 결과 버튼용)
var _recorder: PerformanceRecorder  # 이번 전투의 이벤트 → 연출 단계 기록기
var _pending_winner := -1  # 연출 중에 전투가 끝났으면 이긴 편 (연출이 끝나면 결과 창). 없으면 -1
var _lifts: Array[float] = []  # 손패 카드마다 떠오른 정도 (0 = 내려감, 1 = 다 떠오름). 손패를 다시 깔아도 번호로 이어진다
var _zoom_tween: Tween  # 지금 돌아오는 중인 줌 펀치 (줌이 겹치면 앞의 것을 멈추려고 기억)
var _cam_perf: CardPerformance  # 마지막으로 카메라를 따라간 연출
var _cam_following := false  # 연출 카메라를 따라가는 중인지 (연출이 지워지면 _cam_perf 가 null 처럼 보여서 따로 기억)
var _cam0 := Transform2D.IDENTITY  # 그 연출의 시작 카메라 자세
var _cam_base := Transform2D.IDENTITY  # 그 연출이 시작할 때의 월드 변환 (앞 연출이 덜 돌아왔어도 튀지 않게)
var _cam_return := 0.2  # 그 연출이 끝난 뒤 카메라가 돌아오는 시간 (초)
var _cam_tween: Tween  # 카메라 복귀 tween
var _screen_shake: Tween  # 화면 흔들기 tween (_shake_screen)
var _fx_rng := RandomNumberGenerator.new()  # 흔들림·음높이·아이템 드랍 판정용 난수. 전투 rng 와 따로 (전투 결과 재현에 영향 없게)


func _ready() -> void:
	_end_turn.pressed.connect(press_end_turn)
	_bag_button.pressed.connect(toggle_bag)
	# "← 사무소로": 확인 없이 의뢰를 끝내고 사무소로 (F6 시험 전투에서도 사무소로)
	%BackButton.pressed.connect(StageRun.leave_run)
	_move_button.pressed.connect(toggle_move)
	_bag_panel.item_pressed.connect(_on_item_pressed)
	_bag_panel.item_released.connect(_on_item_released)
	_bag_panel.discard_requested.connect(_on_item_discard)
	_bag_panel.visible = false
	# 결과 창의 보상: 가방이 가득 찼을 때 바꿀 칸 누르기 / 취소, 카드 고르기 창 넘어가기
	_skip_button.pressed.connect(skip_drop)
	_card_pick_skip.pressed.connect(close_card_pick)
	_reward_template.visible = false
	_card_pick.visible = false
	for i in _drop_slots.get_child_count():
		var slot := _drop_slots.get_child(i) as ItemSlot
		slot.index = i
		slot.pressed.connect(swap_drop)
	_drop_box.visible = false
	_restart_button.pressed.connect(_on_result_button)
	_enemy_timer.timeout.connect(_on_enemy_timer)
	# 연출 대기열: 연출 씬은 PerformanceLayer 에 띄우고, 유닛 박스는 _tokens 에서 찾는다
	_queue.layer = _perf_layer
	_queue.token_of = func(u): return _tokens.get(u)
	_queue.step_results.connect(_on_step_results)
	_queue.drained.connect(_on_drained)
	_queue.hit.connect(_on_hit)
	_queue.zoom.connect(_on_zoom)
	_fx_rng.randomize()
	_arrow.visible = false
	_result.visible = false
	# 의뢰 지도에서 전투 노드로 들어왔으면 의뢰의 전투 데이터와 파티(HP 유지)를 쓴다
	_stage_mode = StageRun.in_battle()
	if _stage_mode:
		battle_data = StageRun.battle_data()
		# 전투마다 새 시드. 씬 기본값(0)을 그대로 쓰면 모든 전투의 첫 손패·행동 순서가 같아진다
		battle_seed = randi()
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
	# 카드를 고르면 고른 아이템은 내려놓고 이동 모드도 끈다
	selected_item = -1
	_move_mode = false
	_dragging_item = false
	refresh()
	return true


## 유닛을 눌렀을 때: 고른 카드가 있고 그 유닛이 대상 후보면 카드를 쓴다.
## 아이템을 고른 상태면 그 유닛(살아 있는 아군)에게 아이템을 쓴다.
func click_unit(u: BattleUnit) -> bool:
	if selected_item >= 0:
		return _use_item(u)
	if not _input_ok() or selected == null or u == null:
		return false
	if not session.targets_for(selected).has(u):
		return false
	var kind := _attack_type(selected)
	_play(u if kind == "ranged" or kind == "ally" else null)
	return true


## 칸을 눌렀을 때: 카드를 고른 상태면 그 칸의 유닛을 대상으로, 이동 모드면 그 칸으로 이동.
## 이동하면 이동 모드는 꺼진다 (이동력이 남아도 다시 버튼을 눌러야 함 — 2026-11-17 사용자 승인).
func click_cell(side: int, cell: Vector2i) -> bool:
	if not _input_ok():
		return false
	if selected or selected_item >= 0:
		return click_unit(session.battle.unit_at(side, cell))
	if not _move_mode or side != session.active.side or not session.reachable_cells().has(cell):
		return false
	_move_mode = false
	if not session.move(cell):
		refresh()
		return false
	return true


## 이동 버튼: 이동 모드를 켜고 끈다. 켤 수 있는 건 입력을 받을 수 있고 이동력이 남았을 때뿐.
## 켜면 고른 카드·아이템은 내려놓는다.
func toggle_move() -> void:
	if _move_mode:
		_move_mode = false
	elif _can_move():
		_move_mode = true
		selected = null
		selected_index = -1
		_dragging = false
		selected_item = -1
		_dragging_item = false
	refresh()


## 이동 모드인지 (이동 버튼이 눌려 있고 갈 수 있는 칸이 빛나는 중)
func is_move_mode() -> bool:
	return _move_mode


## 이동 버튼을 쓸 수 있는지: 입력을 받을 수 있고 지금 유닛의 이동력이 남았을 때
func _can_move() -> bool:
	return _input_ok() and session.active.move_left > 0


## 가방을 연다 / 닫는다 (TAB 또는 가방 버튼). 열어 보는 것은 언제든 된다 (적 차례·연출 중에도).
## 닫으면 고른 아이템은 내려놓는다.
func toggle_bag() -> void:
	_bag_panel.visible = not _bag_panel.visible
	if not _bag_panel.visible:
		selected_item = -1
		_dragging_item = false
	if session:
		_draw_bag()
		refresh()


## 가방이 열려 있는지
func is_bag_open() -> bool:
	return _bag_panel.visible


## 가방 index 칸의 아이템을 고른다 (끌기 시작). 고른 카드는 내려놓는다.
## 아군 차례가 아니거나(적 차례·연출 중·전투 끝) 빈 칸이거나 쓸 대상이 없으면 false.
func select_item(index: int) -> bool:
	if not _input_ok():
		return false
	var items := session.inventory.items
	if index < 0 or index >= items.size():
		return false
	if session.item_targets(items[index]).is_empty():
		return false
	selected = null
	selected_index = -1
	_dragging = false
	_move_mode = false
	selected_item = index
	refresh()
	return true


## 취소 (우클릭 / ESC). 순서: 이동 모드 → 고른 아이템 → (고른 카드가 없으면) 열린 가방 닫기 → 고른 카드 내려놓기.
func cancel() -> void:
	# 결과 창: 카드 고르기 창 → 바꿀 칸 고르기 순서로 닫는다 (보상 줄은 남음)
	if _card_pick.visible:
		close_card_pick()
		return
	if _drop_box.visible:
		skip_drop()
		return
	if _move_mode:
		_move_mode = false
		refresh()
		return
	if selected_item >= 0:
		selected_item = -1
		_dragging_item = false
		refresh()
		return
	if selected == null and is_bag_open():
		toggle_bag()
		return
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
	selected_item = -1
	_dragging_item = false
	_move_mode = false
	session.end_player_turn()


## 보상 줄 "공허 조각": 의뢰 지갑에 넣는다 (한 번만).
func click_shards() -> void:
	if reward and reward.claim_shards(StageRun.wallet):
		_draw_rewards()
		_focus_result()   # 누른 줄이 사라져도 키보드 포커스가 남게


## 보상 줄 "아이템": 가방에 빈 칸이 있으면 바로 넣고, 가득 찼으면 바꿀 칸 고르기(DropBox)를 연다.
func click_item() -> void:
	if reward == null or reward.item == null:
		return
	if reward.claim_item(session.inventory):
		_close_drop()
	else:
		_show_swap()


## 가방이 가득 찼을 때: index 칸의 아이템을 버리고 보상 아이템으로 바꾼다.
func swap_drop(index: int) -> void:
	if reward == null or not reward.swap_item(session.inventory, index):
		return
	_close_drop()


## 바꿀 칸 고르기 취소: 아이템 보상 줄은 그대로 남는다.
func skip_drop() -> void:
	_close_drop()


## 보상 줄 "카드 추가": 카드 후보(승리 때 정한 그대로) 고르기 창을 연다.
## 칸 하나 = 상점 카드 칸 틀(shop_card_offer.tscn: 카드 + 버튼). 버튼 = "<주인> 덱에 추가"
## 창이 열린 동안은 결과 묶음(계속·다른 보상 줄·바꿀 칸)을 숨겨, 고르거나 넘어가기 전에는 다른 것을 누를 수 없게 한다.
func open_card_pick() -> void:
	if reward == null or reward.cards.is_empty():
		return
	_drop_box.visible = false
	_result_box.visible = false
	for c in _card_pick_row.get_children():
		_card_pick_row.remove_child(c)
		c.queue_free()
	for i in reward.cards.size():
		var offer := CARD_OFFER.instantiate()
		_card_pick_row.add_child(offer)
		(offer.get_node("%Card") as CardView).set_card(reward.cards[i])
		var button: Button = offer.get_node("%Button")
		button.text = reward.card_owners[i].data.display_name + " 덱에 추가"
		button.pressed.connect(pick_card.bind(i))
	_card_pick.visible = true
	(_card_pick_row.get_child(0).get_node("%Button") as Button).grab_focus()


## 카드 후보 index 를 골라 주인의 의뢰 덱에 넣고 창을 닫는다.
func pick_card(index: int) -> void:
	if reward and reward.claim_card(index):
		close_card_pick()


## 카드 고르기 창을 닫는다. 고르지 않았으면 카드 보상 줄은 남는다 (다시 열면 같은 후보).
func close_card_pick() -> void:
	_card_pick.visible = false
	_result_box.visible = true
	_draw_rewards()
	_focus_result()


## 바꿀 칸 고르기 구역을 닫고 보상 목록·가방을 다시 그린다.
func _close_drop() -> void:
	_drop_box.visible = false
	_draw_rewards()
	_draw_bag()
	_focus_result()


## "다시 하기": 같은 전투 데이터로 새 전투 (시드 +1).
func restart() -> void:
	battle_seed += 1
	_start(BattleSession.new(battle_data, [], battle_seed))


# --- 세션 연결 ---

func _start(s: BattleSession) -> void:
	_enemy_timer.stop()
	session = s
	# 가방: 의뢰 전투면 의뢰의 가방(전투가 끝나도 남음), 시험 전투면 test_items 로 채운 임시 가방
	if _stage_mode:
		session.inventory = StageRun.inventory
	else:
		session.inventory = Inventory.new()
		for item in test_items:
			session.inventory.add(item)
	selected = null
	selected_index = -1
	selected_item = -1
	_dragging_item = false
	_round = 0
	_pending_winner = -1
	_log_texts.clear()
	_result.visible = false
	reward = null
	_drop_box.visible = false
	_card_pick.visible = false
	_result_box.visible = true
	_draw_rewards()
	_build_board()
	_recorder = PerformanceRecorder.new(session.battle)
	session.changed.connect(_on_changed)
	session.finished.connect(_on_finished)
	session.start()
	_flush()
	refresh()


## 격자 칸·유닛 박스·상태 줄을 데이터 크기만큼 새로 깐다.
## 배경 씬에 아군·적 격자판(BattleBoard)이 있으면 그 칸을 쓰고, 없으면 기본 격자(AllyGrid·EnemyGrid)를 깐다.
func _build_board() -> void:
	# 1. 지난 전투의 유닛 박스를 지운다 (격자판 칸은 지우지 않으므로 그 위의 박스를 따로 지워야 한다)
	for t in _tokens.values():
		if is_instance_valid(t):
			t.queue_free()
	for parent in [_ally_grid, _enemy_grid, _ally_panel, _enemy_panel]:
		for c in parent.get_children():
			parent.remove_child(c)
			c.queue_free()
	_cells.clear()
	_tokens.clear()
	_rows.clear()
	var bt := session.battle
	# 2. 칸: 배경의 격자판이 있으면 그것, 없으면 기본 격자
	var use_boards := _use_background_boards(bt)
	_ally_grid.visible = not use_boards
	_enemy_grid.visible = not use_boards
	if not use_boards:
		_build_default_grids(bt)
	# 3. 유닛 박스·상태 줄
	for u in bt.units:
		var t: UnitToken = UNIT_TOKEN.instantiate()
		t.set_unit(u)
		t.pressed.connect(func(unit): click_unit(unit))
		_tokens[u] = t
		var row: UnitStatusRow = STATUS_ROW.instantiate()
		(_ally_panel if u.side == BattleTypes.Side.ALLY else _enemy_panel).add_child(row)
		row.set_unit(u)
		_rows[u] = row


## 배경 씬 안의 아군·적 격자판 칸을 이번 전투 크기에 맞게 켜고 _cells 에 넣는다.
## 두 편의 판이 다 있고 전투 크기(최대 5×5)를 그릴 수 있을 때만 true.
func _use_background_boards(bt: Battle) -> bool:
	# 1. 배경에서 편마다 판 하나를 찾는다
	var boards := {}
	for b in _find_boards(_bg_layer):
		boards[b.side] = b
	if boards.size() < 2:
		return false
	for side in boards:
		if not boards[side].supports(bt.cols_of(side), bt.grid_rows):
			push_warning("BattleScreen: 전투 크기가 격자판(5×5)보다 커서 기본 격자를 써요")
			return false
	# 2. 쓰는 칸만 켜고, 어느 편의 어느 칸인지 알려 준다
	for side in boards:
		var used: Dictionary = boards[side].use_cells(bt.cols_of(side), bt.grid_rows)
		for at in used:
			var c: GridCell = used[at]
			c.setup(side, at)
			# 다시 하기로 판을 또 쓰면 같은 칸이 두 번 연결되지 않게 한다
			if not c.pressed.is_connected(click_cell):
				c.pressed.connect(click_cell)
			_cells[Vector3i(side, at.x, at.y)] = c
	return true


## node 아래의 모든 격자판 (배경 씬 안 어디에 넣어도 찾는다)
func _find_boards(node: Node) -> Array[BattleBoard]:
	var out: Array[BattleBoard] = []
	for c in node.get_children():
		if c is BattleBoard:
			out.append(c)
		out.append_array(_find_boards(c))
	return out


## 기본 격자: 데이터 크기만큼 grid_cell.tscn 을 복제해 AllyGrid·EnemyGrid 에 깐다.
func _build_default_grids(bt: Battle) -> void:
	_ally_grid.columns = bt.cols_of(BattleTypes.Side.ALLY)
	_enemy_grid.columns = bt.cols_of(BattleTypes.Side.ENEMY)
	for y in bt.grid_rows:
		# 아군 격자: 왼쪽이 후열(0), 오른쪽이 전열 → 가운데를 향함
		for x in bt.cols_of(BattleTypes.Side.ALLY):
			_add_cell(_ally_grid, BattleTypes.Side.ALLY, Vector2i(x, y))
		# 적 격자: 왼쪽이 전열(큰 값) → 가운데를 향함
		for x in range(bt.cols_of(BattleTypes.Side.ENEMY) - 1, -1, -1):
			_add_cell(_enemy_grid, BattleTypes.Side.ENEMY, Vector2i(x, y))


func _add_cell(grid: GridContainer, side: int, cell: Vector2i) -> void:
	var c: GridCell = GRID_CELL.instantiate()
	grid.add_child(c)
	c.setup(side, cell)
	c.pressed.connect(func(s, at): click_cell(s, at))
	_cells[Vector3i(side, cell.x, cell.y)] = c


## 기록기에 쌓인 단계를 연출 대기열로 넘긴다. 연출 없는 단계는 이 호출 안에서 바로 그려진다.
func _flush() -> void:
	if _recorder:
		_queue.push(_recorder.take_steps())


## 대기열이 단계 하나의 결과를 보여 줄 때: 숫자·기록, 그리고 그 단계가 끝났을 때의 값으로 박스·상태 줄
func _on_step_results(step: PerformanceStep) -> void:
	var is_card := step.kind == PerformanceStep.Kind.CARD
	# 1. 카드: 사용 기록, 연출 씬이 없으면 박스 그림의 동작만, 피해는 대상별 합계 숫자 하나
	if is_card:
		var to: String = (" → " + step.target.data.display_name) if step.target and step.target != step.actor else ""
		_add_log("%s: %s%s" % [step.actor.data.display_name, step.card.name_ko, to])
		var token: UnitToken = _tokens.get(step.actor)
		var totals := step.damage_totals()
		if step.card.performance == null:
			if token:
				token.play_card_animation(step.card)
			# 연출 씬이 없으면 hit 키도 없으므로, 피해를 받은 유닛의 맞는 동작을 여기서 튼다 (2026-11-25).
			# 쓴 유닛 자신은 빼서 공격 동작을 끊지 않는다
			for u in totals:
				var hit_token: UnitToken = _tokens.get(u)
				if hit_token and u != step.actor:
					hit_token.play_hit()
		var crits := step.crit_targets()
		for u in totals:
			var crit := crits.has(u)
			_pop(u, str(totals[u]), damage_color,
				number_scale(totals[u], u.get_stat(BattleTypes.Stat.HP), crit))
		# 연출이 있는 카드만: 쓰러뜨림·치명타는 결과가 보이는 순간 한 번 더 강조 (설계 5-1 의 6·7)
		if step.card.performance:
			_emphasize(step)
	# 2. 나머지 이벤트: 숫자·기록 (카드의 피해 숫자는 위에서 합쳐 띄웠으므로 기록만)
	for e in step.events:
		_show_event(e, not is_card)
	# 3. 박스: 이 단계가 끝났을 때의 HP·방어도·위치
	for u in step.state:
		var t: UnitToken = _tokens.get(u)
		if t == null:
			continue
		t.show_state(step.state[u])
		_place_token(t, u.side, step.state[u].cell)
		if _rows.has(u):
			_rows[u].show_state(step.state[u])


## 연출의 hit 키: 대상들의 맞는 반응 (설계 5장 — 캐릭터 그림·화면 흔들림, 피격 이펙트, 효과음).
## 숫자는 띄우지 않는다 (결과는 show_results 때). 카드 연출 씬에 값이 있으면 공통값 대신 그것을 쓴다.
func _on_hit(step: PerformanceStep, perf: CardPerformance) -> void:
	var fx: PackedScene = perf.hit_effect if perf.hit_effect else hit_effect
	var snd: AudioStream = perf.hit_sound if perf.hit_sound else hit_sound
	var screen := perf.hit_shake if perf.hit_shake >= 0.0 else hit_shake
	var stop := perf.hitstop_time if perf.hitstop_time >= 0.0 else hitstop_time
	var slow := perf.hitstop_speed if perf.hitstop_speed >= 0.0 else hitstop_speed
	var push := perf.knockback if perf.knockback >= 0.0 else knockback
	var push_back := perf.knockback_return if perf.knockback_return >= 0.0 else knockback_return
	var unit_shake := perf.hit_unit_shake if perf.hit_unit_shake >= 0.0 else hit_unit_shake
	var s_time := perf.shake_time if perf.shake_time >= 0.0 else shake_time
	var f_color := perf.flash_color if perf.flash_color.a > 0.0 else flash_color
	var f_time := perf.flash_time if perf.flash_time >= 0.0 else flash_time
	var jitter := perf.pitch_jitter if perf.pitch_jitter >= 0.0 else pitch_jitter
	var from: UnitToken = _tokens.get(step.actor)
	# 1. 대상마다: 캐릭터 그림 흔들림, 대상 위치에 이펙트
	for u in step.hit_targets():
		var t: UnitToken = _tokens.get(u)
		if t == null:
			continue
		Shaker.shake(t.sprite(), unit_shake, s_time, _fx_rng)
		_flash(t.sprite(), f_color, f_time)
		t.play_hit()
		if from and u != step.actor:
			_knockback(t.sprite(), signf(t.get_global_rect().get_center().x - from.get_global_rect().get_center().x), push, push_back)
		if fx:
			var e: Node = fx.instantiate()
			_perf_layer.add_child(e)
			if e is Node2D or e is Control:
				e.global_position = t.get_global_rect().get_center()
	# 2. 화면 전체 흔들림
	_shake_screen(screen, s_time)
	# 3. 효과음 (음높이는 매번 조금씩 다르게)
	if snd:
		_hit_sound.stream = snd
		_hit_sound.pitch_scale = 1.0 + _fx_rng.randf_range(-jitter, jitter)
		_hit_sound.play()
	# 4. 히트스톱 슬로우모션 (공격자만 느려지면 어색하므로 대상 그림도 함께)
	_hitstop(perf, step.hit_targets(), stop, slow)


## 피격 번쩍임: 그림을 color 로 했다가 time 초 동안 원래 색(흰색)으로 (값은 _on_hit 이 공통값/카드별 값으로 정함)
func _flash(sprite: CanvasItem, color: Color, time: float) -> void:
	sprite.modulate = color
	sprite.create_tween().tween_property(sprite, "modulate", Color.WHITE, maxf(time, 0.001))


## 넉백: 그림을 dir(+1 오른쪽 / −1 왼쪽) 쪽으로 dist 픽셀 밀었다가 back 초 동안 제자리로.
## 흔들림(position)과 겹쳐도 되게 그림의 offset 을 움직인다. 겹친 넉백도 원래 offset 으로 돌아온다.
func _knockback(sprite: AnimatedSprite2D, dir: float, dist: float, back: float) -> void:
	if dist <= 0.0 or dir == 0.0:
		return
	var home: Vector2 = sprite.get_meta(&"_kb_home", sprite.offset)
	sprite.set_meta(&"_kb_home", home)
	sprite.set_meta(&"_kb_count", int(sprite.get_meta(&"_kb_count", 0)) + 1)
	# offset 은 그림 크기(scale) 기준이라 화면 픽셀로 맞춘다
	var sx := absf(sprite.global_scale.x) if sprite.global_scale.x != 0.0 else 1.0
	sprite.offset = home + Vector2(dir * dist / sx, 0)
	var tw := sprite.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sprite, "offset", home, maxf(back, 0.001))
	tw.finished.connect(func():
		var n := int(sprite.get_meta(&"_kb_count", 1)) - 1
		sprite.set_meta(&"_kb_count", n)
		if n <= 0:
			sprite.offset = home
			sprite.remove_meta(&"_kb_home")
			sprite.remove_meta(&"_kb_count"))


## 연출 씬·이동·대상 그림을 time 초 동안 speed 배속으로 느리게(0 이면 멈춤) 했다가 보통 속도로 되돌린다.
## UI·타이머·흔들림은 느려지지 않는다 (Engine.time_scale 을 쓰지 않는 이유).
func _hitstop(perf: CardPerformance, targets: Array[BattleUnit], time: float, speed := 0.0) -> void:
	if time <= 0.0:
		return
	var sprites: Array[AnimatedSprite2D] = []
	for u in targets:
		if _tokens.has(u):
			sprites.append(_tokens[u].sprite())
	var tw := _queue.return_tween if _queue.current_performance() == perf else null
	# 느리게 하기는 노드마다 센다: 겹친 히트스톱이 있어도 각 노드는 자기를 느리게 한 히트스톱이 다 끝날 때 풀린다
	speed = maxf(speed, 0.0)
	if _hold(perf):
		perf.set_speed(speed)
		if tw and tw.is_valid():
			tw.set_speed_scale(speed)
	for sp in sprites:
		if _hold(sp):
			sp.speed_scale = speed
	await get_tree().create_timer(time).timeout
	if is_instance_valid(perf) and _release(perf):
		perf.set_speed(1.0)
		if tw and tw.is_valid():
			tw.set_speed_scale(1.0)
	for sp in sprites:
		if is_instance_valid(sp) and _release(sp):
			sp.speed_scale = 1.0


## 히트스톱 멈춤 수를 하나 늘린다. 처음 멈추는 거면 true
func _hold(n: Node) -> bool:
	var c := int(n.get_meta(&"_hitstop", 0)) + 1
	n.set_meta(&"_hitstop", c)
	return c == 1


## 히트스톱 멈춤 수를 하나 줄인다. 마지막이면 true (이제 다시 움직여도 됨)
func _release(n: Node) -> bool:
	var c := int(n.get_meta(&"_hitstop", 1)) - 1
	if c > 0:
		n.set_meta(&"_hitstop", c)
		return false
	n.remove_meta(&"_hitstop")
	return true


## 연출의 zoom 키 (줌 펀치): 기준 대상을 중심으로 화면을 1 + strength 배로 키웠다가 time 초 동안 원래대로.
func _on_zoom(step: PerformanceStep, strength: float, time: float) -> void:
	var t: UnitToken = _tokens.get(step.target if step.target else step.actor)
	var center := t.get_global_rect().get_center() if t else get_global_rect().get_center()
	pivot_offset = get_global_transform().affine_inverse() * center
	scale = Vector2.ONE * (1.0 + strength)
	# 앞의 줌이 아직 돌아오는 중이면 멈춘다. 그대로 두면 앞의 줌이 끝나면서 중심을 되돌려,
	# 아직 확대 중인 이번 줌의 화면이 튄다
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_zoom_tween.tween_property(self, "scale", Vector2.ONE, maxf(time, 0.01))
	_zoom_tween.finished.connect(func(): pivot_offset = Vector2.ZERO)


## 피해 숫자 크기. 피해가 대상 최대 HP 에 가까울수록 크고, 치명타면 crit_number_scale 배.
func number_scale(amount: int, max_hp: int, crit: bool) -> float:
	var ratio := clampf(float(amount) / maxf(float(max_hp), 1.0), 0.0, 1.0)
	var s := 1.0 + ratio * big_number_boost
	return s * crit_number_scale if crit else s


## 쓰러뜨린 결과·치명타 결과 강조: 화면 흔들림 + 히트스톱 슬로우모션 한 번 더 (2026-11-21 사용자 결정).
## 기준값은 재생 중인 연출 씬의 카드별 값이 있으면 그것, 없으면 공통값 (hit 때와 같은 규칙)
func _emphasize(step: PerformanceStep) -> void:
	var perf := _queue.current_performance()
	var screen := perf.hit_shake if perf and perf.hit_shake >= 0.0 else hit_shake
	var s_time := perf.shake_time if perf and perf.shake_time >= 0.0 else shake_time
	var stop := perf.hitstop_time if perf and perf.hitstop_time >= 0.0 else hitstop_time
	var slow := perf.hitstop_speed if perf and perf.hitstop_speed >= 0.0 else hitstop_speed
	# 1. 쓰러뜨림: 흔들림 세기·시간, 슬로우모션 시간 모두 kill_boost 배 (쓰러뜨림과 치명타가 겹치면 쓰러뜨림만)
	if not step.killed().is_empty():
		_shake_screen(screen * kill_boost, s_time * kill_boost)
		if perf:
			_hitstop(perf, step.hit_targets(), stop * kill_boost, slow)
	# 2. 치명타: 흔들림 세기 crit_shake_boost 배, 슬로우모션 시간 crit_hitstop_boost 배
	elif not step.crit_targets().is_empty():
		_shake_screen(screen * crit_shake_boost, s_time)
		if perf:
			_hitstop(perf, step.hit_targets(), stop * crit_hitstop_boost, slow)


## 이벤트 하나를 떠오르는 숫자·전투 기록·라운드 번호로 보여 준다. pop_damage 가 false 면 피해 숫자는 안 띄운다.
func _show_event(e: BattleEvent, pop_damage: bool) -> void:
	var E := BattleTypes.Event
	match e.type:
		E.ROUND_START:
			_round += 1
		E.DAMAGE_TAKEN:
			if pop_damage:
				_pop(e.target, str(e.amount), damage_color)
			_add_log("%s → %s 피해 %d" % [_who(e), e.target.data.display_name, e.amount])
		E.BLOCK_GAINED:
			_pop(e.target, str(e.amount), block_color)
			_add_log("%s 방어도 +%d" % [e.target.data.display_name, e.amount])
		E.HEALED:
			_pop(e.target, str(e.amount), heal_color)
			_add_log("%s 회복 +%d" % [e.target.data.display_name, e.amount])
		E.HP_LOST:
			# 피해가 아닌 HP 감소 (음수 아이템). 숫자는 피해 숫자와 같은 색
			_pop(e.target, str(e.amount), damage_color)
			_add_log("%s HP -%d" % [e.target.data.display_name, e.amount])
		E.UNIT_MOVED:
			_add_log("%s 이동 %d칸" % [e.actor.data.display_name, e.amount])
		E.UNIT_DIED:
			_add_log("✖ %s 쓰러짐" % e.target.data.display_name)
		E.ITEM_USED:
			_add_log("아이템: %s → %s" % [e.source.display_name, e.target.data.display_name])


func _on_changed() -> void:
	_flush()
	# 가방은 연출 중에도 다시 그린다 (연출 중에는 아이템이 어두워야 한다)
	_draw_bag()
	# 연출 중이면 다시 그리기·적 진행은 연출이 끝난 뒤(_on_drained)
	if _queue.is_busy():
		return
	refresh()
	_continue_enemy()


## 적 차례면 잠깐 뒤에 진행 (enemy_delay 가 0 이면 부르는 쪽이 직접 step_enemy)
func _continue_enemy() -> void:
	if session.is_enemy_turn() and enemy_delay > 0.0 and _enemy_timer.is_stopped():
		_enemy_timer.start(enemy_delay)


## 연출이 다 끝남: 미뤄 둔 다시 그리기·적 진행·결과 창
func _on_drained() -> void:
	refresh()
	if _pending_winner != -1:
		_show_result(_pending_winner)
		return
	_continue_enemy()


func _on_enemy_timer() -> void:
	session.step_enemy()


func _on_finished(winner: int) -> void:
	_enemy_timer.stop()
	selected = null
	selected_index = -1
	selected_item = -1
	_dragging_item = false
	_flush()
	# 연출 중이면 결과 창은 연출이 끝난 뒤
	if _queue.is_busy():
		_pending_winner = winner
		return
	_show_result(winner)


func _show_result(winner: int) -> void:
	_pending_winner = -1
	_won = winner == BattleTypes.Side.ALLY
	_result_label.text = "승리" if _won else "패배"
	# 의뢰 전투: 이기면 지도로 계속, 지면 의뢰 실패 → 시작 화면 (CLAUDE.md 의뢰 스테이지 규칙)
	if _stage_mode:
		_restart_button.text = "계속" if _won else "처음으로"
	# 보상: 의뢰 전투에서 이겼을 때만. 결과 창의 보상 줄을 눌러야 챙겨지고, "계속"을 누르면 안 챙긴 건 사라진다
	reward = _roll_reward() if _stage_mode and _won else null
	_drop_box.visible = false
	_card_pick.visible = false
	_result_box.visible = true
	_draw_rewards()
	_result.visible = true
	_focus_result()


## 이번 승리의 보상을 정한다 (전투 보상 설계 2026-11-19).
## - 공허 조각: 전투 데이터의 shard_reward (일반·보스 모두)
## - 아이템: 일반 전투만, item_drop_chance 확률로 후보 중 하나
## - 카드: 일반 전투만, 살아 있는 파티원의 카드 중 card_reward_count 장 (상점과 같은 규칙)
## 보스는 이기면 의뢰가 끝나므로 아이템·카드 없음.
## 난수는 전투 난수(Battle.rng)가 아니라 화면용 난수 — 같은 시드의 전투 결과가 보상 때문에 달라지지 않게.
func _roll_reward() -> BattleReward:
	var shards := battle_data.shard_reward if battle_data else 0
	var drop: ConsumableData = null
	var cards: Array[CardData] = []
	var owners: Array[BattleUnit] = []
	if not StageRun.is_boss_battle():
		drop = StageRun.roll_item_drop(item_drop_chance, StageRun.item_pool(drop_pool_dir), _fx_rng)
		var picked := CardPool.pick_party_cards(StageRun.living_party(), CardPool.load_all(card_pool_dir),
				card_reward_count, _fx_rng)
		cards.assign(picked.cards)
		owners.assign(picked.owners)
	return BattleReward.new(shards, drop, cards, owners)


## 결과 창의 보상 목록을 남은 보상만큼 다시 그린다 (줄 = RewardTemplate 복제).
## 줄 순서: 공허 조각 → 아이템 → 카드 추가. 남은 보상이 없으면 목록을 숨긴다.
func _draw_rewards() -> void:
	for c in _reward_list.get_children():
		if c != _reward_template:
			_reward_list.remove_child(c)
			c.queue_free()
	_reward_list.visible = reward != null and not reward.is_empty()
	if not _reward_list.visible:
		return
	if reward.shards > 0:
		_add_reward_row("공허 조각 %d" % reward.shards, click_shards)
	if reward.item:
		_add_reward_row("아이템: " + reward.item.display_name, click_item)
	if not reward.cards.is_empty():
		_add_reward_row("카드 추가", open_card_pick)


## 결과 창의 키보드 포커스: 남은 보상 줄이 있으면 첫 줄, 없으면 "계속" 버튼.
## 스페이스/엔터 한 번에 "계속"이 눌려 안 챙긴 보상이 사라지지 않게 한다 (코드 리뷰 2026-11-19).
func _focus_result() -> void:
	for row in _reward_list.get_children():
		if row != _reward_template and row.visible and _reward_list.visible:
			(row as Button).grab_focus()
			return
	_restart_button.grab_focus()


## 보상 줄 하나를 만든다: 템플릿을 복제해 글자를 넣고, 누르면 action 을 부른다.
func _add_reward_row(text: String, action: Callable) -> void:
	var row := _reward_template.duplicate() as Button
	row.text = text
	row.visible = true
	row.pressed.connect(action)
	_reward_list.add_child(row)


## 가방이 가득 찼을 때 바꿀 칸 고르기 구역을 연다 (가방 5칸을 보여 준다).
func _show_swap() -> void:
	_drop_label.text = "가방이 가득 찼어요 — [%s] 대신 버릴 칸을 고르세요" % reward.item.display_name
	var items := session.inventory.items
	for i in _drop_slots.get_child_count():
		(_drop_slots.get_child(i) as ItemSlot).set_item(items[i] if i < items.size() else null)
	_drop_box.visible = true


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
## 연출 중에는 그리지 않는다 (아직 안 보여 준 결과가 미리 보이지 않게). 연출이 끝나면 다시 부른다.
func refresh() -> void:
	if session == null or _queue.is_busy():
		return
	var bt := session.battle
	var hero := session.active
	# 이동 모드는 이동할 수 없게 되면(적 차례·전투 끝·이동력 0) 저절로 꺼진다
	if _move_mode and not _can_move():
		_move_mode = false
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
	# 아이템을 골랐으면 쓸 수 있는 아군을 강조한다 (가방이 바뀌어 그 칸이 없어졌으면 고르기를 푼다)
	if selected_item >= session.inventory.items.size():
		selected_item = -1
	var item_targets: Array[BattleUnit] = []
	if selected_item >= 0:
		item_targets = session.item_targets(session.inventory.items[selected_item])
		if item_targets.is_empty():
			selected_item = -1
	for u in _tokens:
		var t: UnitToken = _tokens[u]
		_place_token(t, u.side, u.cell)
		t.set_highlight(targets.has(u) or item_targets.has(u))
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
	_move_button.disabled = not _can_move()
	_move_button.set_pressed_no_signal(_move_mode)
	_draw_bag()
	_update_arrow()


## 가방 버튼의 개수와 가방 패널의 칸들을 다시 그린다. 쓸 수 없는 때(적 차례·연출 중·전투 끝)는 아이템이 어둡다.
func _draw_bag() -> void:
	var items := session.inventory.items
	_bag_button.text = "가방 %d/%d" % [items.size(), Inventory.CAPACITY]
	_bag_panel.show_items(items, _input_ok(), selected_item)


## 유닛 박스를 그 칸으로 옮긴다 (이미 그 칸이면 그대로).
func _place_token(t: UnitToken, side: int, at: Vector2i) -> void:
	var cell: GridCell = _cells.get(Vector3i(side, at.x, at.y))
	if cell == null or t.get_parent() == cell:
		return
	if t.get_parent():
		t.get_parent().remove_child(t)
	cell.add_child(t)
	# 칸 중심에 놓는다. 격자판 칸은 사각형이라 경계 상자 중심과 다르다
	t.position = cell.center() - t.custom_minimum_size * 0.5


func _draw_queue() -> void:
	for c in _turn_queue.get_children():
		_turn_queue.remove_child(c)
		c.queue_free()
	var q := session.turn_queue()
	for i in q.size():
		var p: TurnPortrait = TURN_PORTRAIT.instantiate()
		_turn_queue.add_child(p)
		p.set_entry(q[i].unit, q[i].speed, i == 0)


## 칸 표시: 카드를 골랐으면 대상 칸(빨강)과 마우스 아래 대상의 광역 범위(주황), 이동 모드면 이동 가능 칸(하늘).
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
	elif selected_item >= 0:
		# 아이템을 끄는 중: 쓸 수 있는 유닛 위면 범위 칸을 카드 광역처럼 표시한다 (대상 유닛은 박스가 빛난다)
		if selected_item < session.inventory.items.size():
			var item := session.inventory.items[selected_item]
			if hover and session.item_targets(item).has(hover):
				for u in session.battle.item_affected(item, hover):
					_mark(u.side, u.cell, GridCell.Mark.AREA)
	elif _move_mode:
		# 이동 버튼을 눌렀을 때만 이동 칸을 표시한다
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
	# 떠오른 정도는 번호로 이어 간다 (다시 깔 때마다 처음부터 떠오르면 깜빡여 보인다)
	_lifts.resize(hero.hand.size())


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = get_global_mouse_position()
			_dragging = select_card(index) and selected != null
		elif _dragging:
			_release_drag(get_global_mouse_position())


## 손을 뗐을 때 (mouse = 뗀 화면 위치): 대상 유닛 위면 사용.
## 대상을 고를 필요 없는 자신·근접 카드는 drag_play_height 넘게 끌어 올렸으면 어디서 떼든 사용 (근접은 자동 대상, 2026-11-17).
## 그 밖에는 (끌지 않고 그 자리에서 뗀 클릭도) 고르기를 취소해 카드가 손패로 돌아간다. (2026-11-15 사용자 결정)
func _release_drag(mouse: Vector2) -> void:
	_dragging = false
	if selected == null:
		return
	var hover := _unit_under(mouse)
	if hover and click_unit(hover):
		return
	if _attack_type(selected) in ["self", "melee"] and _press_pos.y - mouse.y > drag_play_height:
		_play(null)
		return
	cancel()


# --- 아이템 끌기 (카드와 같은 규칙) ---

## 가방 칸을 눌렀을 때: 그 아이템을 고르고 끌기 시작한다.
func _on_item_pressed(index: int) -> void:
	_dragging_item = select_item(index)


## 누른 가방 칸에서 손을 뗐을 때 (마우스가 어디에 있든 누른 칸이 알려 준다).
func _on_item_released(_index: int) -> void:
	if _dragging_item:
		_release_item_drag(get_global_mouse_position())


## 아이템을 끌어 가방의 버리기 칸에서 뗐을 때: 그 아이템을 버린다 (상점 설계 2026-11-17).
## 끌기는 아이템을 쓸 수 있을 때(아군 카드 사용 페이즈)만 시작되므로 버리기도 그때만 된다.
func _on_item_discard(index: int) -> void:
	if not _dragging_item:
		return
	_dragging_item = false
	selected_item = -1
	session.inventory.remove_at(index)
	refresh()


## 아이템을 끌다가 손을 뗐을 때 (mouse = 뗀 화면 위치): 쓸 수 있는 아군 위면 사용.
## 그 밖에는 (끌지 않고 그 자리에서 뗀 클릭도) 고르기를 취소하고 아이템은 가방에 남는다 — 카드의 2026-11-15 규칙과 같다.
func _release_item_drag(mouse: Vector2) -> void:
	_dragging_item = false
	if selected_item < 0:
		return
	var hover := _unit_under(mouse)
	if hover and click_unit(hover):
		return
	selected_item = -1
	refresh()


## 고른 아이템을 u 에게 쓴다. 아군 차례가 아니거나 u 가 대상(살아 있는 아군)이 아니면 false (이때는 아이템을 그대로 고른 채 둔다).
## 쓰고 나면 고르기를 풀고, 가방은 열린 채 둔다.
func _use_item(u: BattleUnit) -> bool:
	if not _input_ok() or u == null or selected_item >= session.inventory.items.size():
		return false
	if not session.item_targets(session.inventory.items[selected_item]).has(u):
		return false
	var index := selected_item
	selected_item = -1
	_dragging_item = false
	if not session.use_item(index, u):
		refresh()
		return false
	return true


## TAB(입력 액션 toggle_bag): 가방 열기/닫기. 결과 창이 떠 있으면 무시한다.
## _unhandled_input 이 아니라 _input 에서 받는다: 버튼에 포커스가 있으면 TAB 을 UI 가 먼저(포커스 이동으로) 써 버린다.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_bag") and not _result.visible:
		toggle_bag()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _dragging:
		_release_drag(get_global_mouse_position())
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _dragging_item:
		_release_item_drag(get_global_mouse_position())


func _process(delta: float) -> void:
	_update_camera()
	if selected or selected_item >= 0:
		_update_arrow()
	_update_hand_lift(delta, _hand_index_under(get_global_mouse_position()))


## 연출 카메라 (설계 docs/superpowers/specs/2026-11-19-performance-timeline-design.md 3장):
## 재생 중인 연출에 Camera 가 있으면 시작 자세 대비 지금 자세만큼 월드 묶음을 움직이고,
## perform 이 끝나면(행위자 복귀와 함께) return_time 동안 원래대로 돌린다. Camera 가 없는 연출은 월드를 건드리지 않는다.
func _update_camera() -> void:
	var perf := _queue.current_performance()
	if perf and perf.has_camera() and perf != _cam_perf:
		_cam_perf = perf
		_cam_following = true
		_cam0 = perf.camera_xform()
		_cam_base = _world.get_transform()
		_cam_return = perf.return_time if perf.return_time >= 0.0 else _queue.default_return_time
		if _cam_tween and _cam_tween.is_valid():
			_cam_tween.kill()
		perf.done.connect(_return_camera, CONNECT_ONE_SHOT)
	if not _cam_following:
		return
	if perf == null or perf != _cam_perf:
		_return_camera()
		return
	# 연출 루트 좌표 → 월드 묶음 좌표 (WorldFront 기준이라 월드 자신의 변환이 섞이지 않는다)
	var t := _world_front.get_global_transform().affine_inverse() * perf.get_global_transform()
	_set_world_xform(_cam_base * CameraMath.world_xform(t, _cam0, perf.camera_xform()))


## 카메라 따라가기를 멈추고 return_time 동안 월드를 원래대로 돌린다
func _return_camera() -> void:
	if not _cam_following:
		return
	_cam_following = false
	var from := _world.get_transform()
	_cam_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_cam_tween.tween_method(func(k: float): _set_world_xform(from.interpolate_with(Transform2D.IDENTITY, k)),
		0.0, 1.0, maxf(_cam_return, 0.01))


## 화면 전체를 strength 픽셀 세기로 time 초 동안 흔든다 (Shaker 와 같은 모양: 무작위 방향, 점점 약해져 원래 자리로).
## 루트가 아니라 뷰포트의 canvas_transform 을 흔든다: 전투 화면은 CanvasLayer 로 나뉘어 있고(전투 무드 1단계),
## UI·연출·덮개 층은 follow_viewport 라서 이것을 따라 같이 흔들린다. 층마다 좌표가 어긋나지 않는다.
## 흔드는 도중에 또 흔들면 앞의 흔들기를 멈추고 새로 시작한다.
func _shake_screen(strength: float, time: float) -> void:
	if not is_inside_tree() or strength <= 0.0 or time <= 0.0:
		return
	var vp := get_viewport()
	if _screen_shake and _screen_shake.is_valid():
		_screen_shake.kill()
	_screen_shake = create_tween()
	_screen_shake.tween_method(func(t: float):
		var left := strength * (1.0 - t)
		vp.canvas_transform = Transform2D(0.0, Vector2(_fx_rng.randf_range(-left, left), _fx_rng.randf_range(-left, left))),
		0.0, 1.0, time)
	_screen_shake.finished.connect(func(): vp.canvas_transform = Transform2D.IDENTITY)


## 흔드는 도중에 화면이 닫히면(씬 전환·도주) 뷰포트가 어긋난 채로 남지 않게 되돌린다
func _exit_tree() -> void:
	if _screen_shake and _screen_shake.is_valid():
		_screen_shake.kill()
		get_viewport().canvas_transform = Transform2D.IDENTITY


## 월드 묶음 둘(World·WorldFront)에 같은 변환을 넣는다
func _set_world_xform(x: Transform2D) -> void:
	for w: Control in [_world, _world_front]:
		w.pivot_offset = Vector2.ZERO
		w.position = x.origin
		w.rotation = x.get_rotation()
		w.scale = x.get_scale()


## 마우스 아래의 손패 카드 번호 (없으면 -1).
## 카드 가로 범위 × (그 카드의 지금 윗변 ~ 화면 아래) 로 본다: 실제로 보이는 카드에 닿아야 올린 것으로 친다.
## (손패 줄 위쪽부터 보면 내려가 있는 카드보다 한참 위의 빈 곳에서도 반응한다 — 2026-11-15 수정)
## 카드는 올리면 위로만 움직이므로 마우스는 계속 카드 안에 남아 깜빡이지 않는다.
func _hand_index_under(pos: Vector2) -> int:
	for i in _hand.get_child_count():
		var r: Rect2 = _hand.get_child(i).get_global_rect()
		if pos.x >= r.position.x and pos.x < r.end.x and pos.y >= r.position.y:
			return i
	return -1


## 손패 카드 높이: 고른 카드는 맨 위, 마우스를 올린 카드(hover)는 떠오르고, 나머지는 hand_sink 만큼 내려간다.
## delta 초만큼 목표 쪽으로 부드럽게 움직인다. 위치는 손패 줄(HBoxContainer)이 정한 자리를 기준으로 덮어쓴다.
func _update_hand_lift(delta: float, hover: int) -> void:
	var n := _hand.get_child_count()
	if _lifts.size() != n:
		_lifts.resize(n)
	var k := minf(1.0, delta * hand_rise_speed)
	for i in n:
		var v: Control = _hand.get_child(i)
		var target := 1.0 if i == hover or i == selected_index else 0.0
		_lifts[i] = lerpf(_lifts[i], target, k)
		if absf(_lifts[i] - target) < 0.001:
			_lifts[i] = target
		# 고른 카드는 손패 줄 맨 위(SHRINK_BEGIN), 나머지는 맨 아래 기준에서 내려간 만큼
		if i == selected_index:
			v.position.y = 0.0
		else:
			v.position.y = _hand.size.y - v.size.y + hand_sink * (1.0 - _lifts[i])


## 화살표: 원거리·아군·근접 카드를 골랐을 때 고른 카드 위쪽 가운데 → 마우스(근접은 자동 대상)
## 아이템을 골랐을 때는 그 가방 칸 위쪽 가운데 → 마우스. 쓸 수 있는 아군 위면 유효 색.
func _update_arrow() -> void:
	if session and selected_item >= 0:
		if session.active == null or not is_bag_open() or selected_item >= session.inventory.items.size():
			_arrow.visible = false
			return
		var slot := _bag_panel.slots()[selected_item]
		var item_from := slot.get_global_rect().get_center() - Vector2(0, slot.size.y * 0.5)
		var over := _unit_under(get_global_mouse_position())
		_arrow.visible = true
		_arrow.set_points(item_from, get_global_mouse_position())
		_arrow.set_valid(over != null and session.item_targets(session.inventory.items[selected_item]).has(over))
		_draw_marks([], over)
		return
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
	return session != null and session.active != null and not session.is_finished() and not _queue.is_busy()


func _attack_type(card: CardData) -> String:
	return session.battle.effective_card(session.active, card).attack_type if session.active else card.attack_type


## 전투 기록에 쓸 "누가": 행위자 이름. 행위자가 없으면(상태·아이템으로 생긴 효과) 출처 이름을 괄호로.
func _who(e: BattleEvent) -> String:
	if e.actor:
		return e.actor.data.display_name
	if e.source is StatusData or e.source is ConsumableData:
		return "(%s)" % e.source.display_name
	return "(상태)"


func _pop(u: BattleUnit, text: String, color: Color, size_scale := 1.0) -> void:
	var t: UnitToken = _tokens.get(u)
	if t == null or not t.is_inside_tree():
		return
	var f: FloatNumber = FLOAT_NUMBER.instantiate()
	_float_layer.add_child(f)
	# 박스 위쪽 가운데. 가로 가운데 맞춤·흩어짐은 FloatNumber.pop 이 한다
	f.global_position = t.get_global_rect().get_center() - Vector2(0, 70)
	f.pop(text, color, size_scale)


func _add_log(line: String) -> void:
	_log_texts.append(line)
	while _log_texts.size() > log_lines:
		_log_texts.pop_front()
	_log.text = "\n".join(_log_texts)
