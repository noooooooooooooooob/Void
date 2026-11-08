class_name BattleSession
extends RefCounted
## 전투 화면과 Battle 사이의 진행 담당. 전투 화면(battle_screen.gd)이 하나 가지고 쓴다.
## BattleData 로 전투를 만들고, 차례를 진행하고, 아군 입력(카드·이동·차례 종료)을 받고, 적 차례를 한 번에 하나씩 진행한다.
## 시간과 무관한 순수 로직이라 GUT 로 테스트한다. 적 차례 사이 간격(0.7초)은 화면이 타이머로 step_enemy() 를 불러서 만든다.
##
## 규칙 판정은 직접 하지 않고 반드시 Battle 의 함수(can_play, melee_target, path_length …)를 쓴다.
## 진행 흐름 (CLAUDE.md "행동 하나 = 온전한 차례 하나"):
##   advance() → next_turn
##     아군: begin_turn → active 로 두고 입력을 기다림 (드로우 페이즈에 죽으면 다음 차례로)
##     적:   pending 으로 두고 멈춤 → 화면이 step_enemy() → run_enemy_turn → advance()
##   한쪽이 전멸하면 그 자리에서 finished 를 한 번 내고 더 진행하지 않는다.

## 상태가 바뀔 때마다 (카드·이동·차례 시작/끝·적 행동 후). 화면은 이것을 받아 전부 다시 그린다.
signal changed()
## 새 차례가 열렸을 때 (아군이면 입력 대기, 적이면 step_enemy 대기)
signal turn_started(unit: BattleUnit)
## 전투가 끝났을 때 한 번. winner = BattleTypes.Side (ALLY 면 승리)
signal finished(winner: int)

## 진행 중인 전투
var battle: Battle
## 입력을 기다리는 아군 (아군 차례가 아니면 null)
var active: BattleUnit = null
## 이 세션을 만든 전투 데이터
var data: BattleData

var _seed: int
var _pending: BattleUnit = null  # 화면이 step_enemy() 를 부르기를 기다리는 적
var _finished := false


## data: 전투 데이터. allies: 밖에서 넣는 아군 유닛(의뢰 파티 — HP 유지). 비우면 data 의 아군 배치로 새로 만든다.
## battle_seed: 난수 시드 (같으면 같은 전투).
func _init(battle_data: BattleData, allies: Array[BattleUnit] = [], battle_seed: int = 0) -> void:
	data = battle_data
	_seed = battle_seed
	var units: Array[BattleUnit] = []
	if allies.is_empty():
		units = data.make_units()
	else:
		units.append_array(allies)
		units.append_array(data.make_enemy_units())
	battle = Battle.new(units, battle_seed, data.rows, data.ally_cols, data.enemy_cols)


## 전투를 시작하고 첫 차례(아군 입력 대기 또는 적 차례 대기)까지 진행한다.
func start() -> void:
	battle.start_battle()
	advance()


## 다음 차례를 연다. 아군 차례면 입력 대기, 적 차례면 step_enemy 대기에서 멈춘다.
## 전투가 끝났거나 이미 차례가 열려 있으면 아무것도 하지 않는다.
func advance() -> void:
	while not _finished and active == null and _pending == null:
		if _check_end():
			return
		var u := battle.next_turn()
		if u == null:
			_check_end()
			return
		if u.side == BattleTypes.Side.ALLY:
			# 드로우 페이즈(출혈 등)에 죽으면 그 차례는 건너뛴다 (end_turn 없이).
			if battle.begin_turn(u):
				active = u
				turn_started.emit(u)
				changed.emit()
				return
			changed.emit()
		else:
			_pending = u
			turn_started.emit(u)
			changed.emit()
			return


## 지금 적 차례를 기다리는 중인지 (화면이 타이머 뒤 step_enemy 를 부른다)
func is_enemy_turn() -> bool:
	return _pending != null


## 차례를 기다리는 적 (없으면 null)
func pending_enemy() -> BattleUnit:
	return _pending


## 기다리던 적의 차례를 처음부터 끝까지 진행하고 다음 차례를 연다.
func step_enemy() -> void:
	if _pending == null or _finished:
		return
	var u := _pending
	_pending = null
	battle.run_enemy_turn(u)
	changed.emit()
	if _check_end():
		return
	advance()


## 지금 아군이 card 를 쓴다 (원거리·아군 카드는 origin 지정). 아군 차례가 아니면 false.
func play(card: CardData, origin: BattleUnit = null) -> bool:
	if active == null or _finished:
		return false
	var ok := battle.play_card(active, card, origin)
	if ok:
		changed.emit()
		_check_end()
	return ok


## 지금 아군을 cell 로 옮긴다 (이동력만큼). 아군 차례가 아니거나 못 가면 false.
func move(cell: Vector2i) -> bool:
	if active == null or _finished:
		return false
	var ok := battle.move_unit(active, cell)
	if ok:
		changed.emit()
	return ok


## 아군 차례를 끝낸다 (엔드 페이즈 → 손패 전부 버림) → 다음 차례.
func end_player_turn() -> void:
	if active == null or _finished:
		return
	var u := active
	active = null
	battle.end_turn(u)
	changed.emit()
	if _check_end():
		return
	advance()


## card 의 기준 유닛으로 고를 수 있는 유닛들. 비어 있으면 지금 쓸 수 없는 카드다.
## 원거리·아군: 살아 있는 유닛 중 can_play 가 통과하는 것 / 근접: 자동 대상 하나 / 자신: 지금 아군.
func targets_for(card: CardData) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	if active == null or _finished:
		return out
	var eff := battle.effective_card(active, card)
	match eff.attack_type:
		"melee":
			if battle.can_play(active, card) == "":
				out.append(battle.melee_target(active))
		"self":
			if battle.can_play(active, card) == "":
				out.append(active)
		_:
			for u in battle.living_all():
				if battle.can_play(active, card, u) == "":
					out.append(u)
	return out


## 지금 아군이 이동할 수 있는 빈 칸들 (자기 칸 제외, 거리 ≤ 남은 이동력).
func reachable_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if active == null or _finished:
		return out
	for x in battle.cols_of(active.side):
		for y in battle.grid_rows:
			var cell := Vector2i(x, y)
			var d := battle.path_length(active, cell)
			if d >= 1 and d <= active.move_left:
				out.append(cell)
	return out


## 손패에 크게 보여 줄 계산된 수치: 첫 피해/방어도/회복 효과의 미리보기 값 (치명 제외). 없으면 -1.
func card_preview(card: CardData) -> int:
	var who := active if active else _pending
	if who == null:
		return -1
	var eff := battle.effective_card(who, card)
	var ctx := battle.card_play.card_context(who, eff)
	for e in eff.effects:
		var v := e.preview_amount(ctx)
		if v >= 0:
			return v
	return -1


## 행동 순서 표시용 목록 [{unit, speed}]: 지금 차례 유닛이 맨 앞, 그 뒤로 이번 라운드 남은 행동 순서.
func turn_queue() -> Array:
	var out: Array = []
	var now := active if active else _pending
	if now:
		out.append({"unit": now, "speed": battle.current_speed})
	for e in battle.turn_order.remaining():
		out.append({"unit": e.unit, "speed": e.speed})
	return out


## 전투가 끝났는지
func is_finished() -> bool:
	return _finished


## 전투를 그 자리에서 끝낸다 (개발용 전투 스킵). winner 편(BattleTypes.Side)이 이긴 것으로 finished 를 한 번 낸다.
## 이미 끝난 전투면 아무것도 하지 않는다. 유닛 HP 등 전투 상태는 건드리지 않는다.
func force_finish(winner: int) -> void:
	if _finished:
		return
	_finished = true
	active = null
	_pending = null
	finished.emit(winner)
	changed.emit()


## 같은 전투 데이터로 새 세션을 만든다 (시험판 "다시 하기"). 시드는 1 늘려서 다른 판이 나오게 한다.
## 부르는 쪽이 start() 를 부른다.
func restart() -> BattleSession:
	return BattleSession.new(data, [], _seed + 1)


## 한쪽이 전멸했으면 finished 를 (한 번만) 내고 true.
func _check_end() -> bool:
	if _finished:
		return true
	var w := battle.winner()
	if w == -1:
		return false
	_finished = true
	active = null
	_pending = null
	finished.emit(w)
	changed.emit()
	return true
