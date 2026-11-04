class_name Battle
extends RefCounted
## 전투 하나. 유닛·격자·이벤트·난수를 갖고, 피해·회복·방어도·상태 처리 규칙을 실행한다.
## 화면(씬) 없이 동작하는 순수 로직이라 테스트에서 바로 만들어 쓸 수 있다.
##
## 이 파일은 구현 계획의 Task 4~10 에 걸쳐 섹션별로 채워진다.
##   Task 4: 격자, 피해, 회복, 방어도, 상태 API (지금)
##   Task 6: 카드 사용 / Task 7: 덱과 턴 / Task 8: 상태 트리거 / Task 9: 이동 / Task 10: 적 행동
## 규칙 출처: docs/superpowers/specs/2026-11-03-card-effect-system-design.md (3장, 4장)
##
## 격자 좌표: 편마다 따로인 격자의 Vector2i(열, 행). 열 0 = 뒤, 열 (그 편의 열 수 - 1) = 맨 앞(상대 쪽).
## 격자 크기는 전투마다 정한다. 행 수는 양쪽 공통, 열 수는 편마다 다를 수 있다. (기획 결정)
## 아군·적 모두 같은 규칙이라, 광역 오프셋의 +x 는 항상 "앞쪽"이다.
## (화면에서 아군은 왼쪽·적은 오른쪽에 그리는 것은 UI 의 몫)

## 전투에 참여한 모든 유닛 (죽은 유닛도 남아 있고 alive 로 구분한다)
var units: Array[BattleUnit] = []
## 이 전투의 이벤트 관리자. 상태·패시브·장비·화면이 여기에 구독한다.
var events := BattleEvents.new()
## 이 전투의 모든 난수(치명타, 섞기, 적 선택)는 여기서 뽑는다. 시드를 주면 결과가 재현된다.
var rng := RandomNumberGenerator.new()
## 스태미너가 0이 됐을 때 붙일 상태 (기절·탈진 등, 기획 미정이라 비워 둘 수 있음)
var stamina_break_status: StatusData = null
## 격자 행 수 (양쪽 편 공통)
var grid_rows: int = BattleTypes.DEFAULT_GRID_ROWS
## 편 → 그 편 격자의 열 수
var grid_cols := {
	BattleTypes.Side.ALLY: BattleTypes.DEFAULT_GRID_COLS,
	BattleTypes.Side.ENEMY: BattleTypes.DEFAULT_GRID_COLS,
}


## units: 참여 유닛들. 배열 순서가 initial_index 가 된다 (속도가 같을 때 순서 기준).
## battle_seed: 난수 시드. 0 이어도 고정 시드로 동작한다(테스트 재현용).
## rows / ally_cols / enemy_cols: 이 전투의 격자 크기. 생략하면 기본 3행 × 4열.
## (전투 데이터에서 크기를 정해 넘겨 준다 — 전투 데이터 리소스는 나중에 만든다)
func _init(battle_units: Array[BattleUnit], battle_seed: int = 0,
		rows: int = BattleTypes.DEFAULT_GRID_ROWS,
		ally_cols: int = BattleTypes.DEFAULT_GRID_COLS,
		enemy_cols: int = BattleTypes.DEFAULT_GRID_COLS) -> void:
	units = battle_units
	rng.seed = battle_seed
	grid_rows = rows
	grid_cols[BattleTypes.Side.ALLY] = ally_cols
	grid_cols[BattleTypes.Side.ENEMY] = enemy_cols
	for i in units.size():
		units[i].battle = self
		units[i].initial_index = i


# --- 격자 ---

## 그 편 격자의 열 수
func cols_of(side: int) -> int:
	return grid_cols[side]


## 칸이 그 편 격자 안인지 (열 0 ~ 열 수-1, 행 0 ~ 행 수-1)
func in_grid(side: int, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols_of(side) and cell.y >= 0 and cell.y < grid_rows


## 그 편의 그 칸에 있는 살아 있는 유닛. 없으면 null.
func unit_at(side: int, cell: Vector2i) -> BattleUnit:
	for u in units:
		if u.alive and u.side == side and u.cell == cell:
			return u
	return null


## 그 편의 살아 있는 유닛들 (전투 참여 순서대로)
func living(side: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.alive and u.side == side:
			out.append(u)
	return out


## u 와 같은 편의 살아 있는 유닛들 (u 자신 포함)
func allies_of(u: BattleUnit) -> Array[BattleUnit]:
	return living(u.side)


## u 의 상대 편 살아 있는 유닛들
func enemies_of(u: BattleUnit) -> Array[BattleUnit]:
	return living(_other_side(u.side))


## 근접 공격 대상: u 와 같은 행에서 상대 격자의 맨 앞 열부터 찾아 처음 만나는 적.
## 그 행에 적이 없으면 null (= 근접 카드를 쓸 수 없음). (노션 구현 확정)
func melee_target(u: BattleUnit) -> BattleUnit:
	var enemy_side := _other_side(u.side)
	for col in range(cols_of(enemy_side) - 1, -1, -1):
		var hit := unit_at(enemy_side, Vector2i(col, u.cell.y))
		if hit:
			return hit
	return null


## 광역 대상: 기준 유닛(origin)의 칸에 오프셋들을 더한 칸의 유닛들.
## 기준 유닛이 있는 편의 격자 안에서만 찾고, 격자 밖·빈 칸은 무시한다. 범위가 비어 있으면 단일 대상.
func area_targets(origin: BattleUnit, area: Array[Vector2i]) -> Array[BattleUnit]:
	if area.is_empty():
		return [origin]
	var out: Array[BattleUnit] = []
	for offset in area:
		var cell := origin.cell + offset
		if not in_grid(origin.side, cell):
			continue
		var u := unit_at(origin.side, cell)
		if u and not out.has(u):
			out.append(u)
	return out


# --- 피해·회복·방어도 ---

## actor 가 target 에게 amount 만큼 피해를 준다. (설계 문서 3.5~3.6, 기획 결정)
## actor 는 null 일 수 있다 (예: 출혈을 건 유닛이 이미 죽음). source 는 이벤트에 담길 출처.
## 순서: 방어도 → HP / 대상 스태미너 감소 / 준 쪽 스태미너 회복 / 이벤트 / 사망
func apply_damage(actor: BattleUnit, target: BattleUnit, amount: int, source = null) -> void:
	if amount <= 0 or target == null or not target.alive:
		return

	# 1. 방어도가 먼저 막고, 남은 만큼 HP 가 깎인다.
	var blocked := mini(target.block, amount)
	target.block -= blocked
	target.hp -= amount - blocked

	# 2. 대상 스태미너는 막힌 양까지 포함한 전체 피해만큼 깎인다.
	#    0 보다 컸다가 0 이 되는 순간에만 "스태미너 0" 처리를 한다 (이미 0 이면 다시 안 함).
	var stamina_before := target.stamina
	target.stamina = maxi(0, target.stamina - amount)
	if stamina_before > 0 and target.stamina == 0:
		events.emit(BattleEvent.make(BattleTypes.Event.STAMINA_BROKEN, actor, target, 0, source))
		if stamina_break_status:
			apply_status(target, stamina_break_status, 1, actor)

	# 3. 피해를 준 쪽은 준 피해의 절반(내림)만큼 스태미너를 회복한다. 최대치를 넘지 않는다.
	if actor != null and actor.alive:
		var max_stamina := actor.get_stat(BattleTypes.Stat.STAMINA)
		actor.stamina = mini(max_stamina, actor.stamina + amount / 2)

	# 4. 이벤트: 준 쪽 기준(DEALT) → 받은 쪽 기준(TAKEN) 순서.
	events.emit(BattleEvent.make(BattleTypes.Event.DAMAGE_DEALT, actor, target, amount, source))
	events.emit(BattleEvent.make(BattleTypes.Event.DAMAGE_TAKEN, actor, target, amount, source))

	# 5. 사망
	if target.alive and target.hp <= 0:
		target.hp = 0
		_on_unit_died(target)


## target 의 HP 를 amount 만큼 회복한다. 최대 HP 를 넘지 않는다.
## HEALED 이벤트의 amount 는 실제로 회복한 양이다.
func heal(target: BattleUnit, amount: int, source = null) -> void:
	if amount <= 0 or target == null or not target.alive:
		return
	var max_hp := target.get_stat(BattleTypes.Stat.HP)
	var gained := mini(amount, max_hp - target.hp)
	target.hp += gained
	events.emit(BattleEvent.make(BattleTypes.Event.HEALED, null, target, gained, source))


## target 이 방어도(쉴드)를 amount 만큼 얻는다. 방어도는 라운드 시작 시 초기화된다(Task 7).
func add_block(target: BattleUnit, amount: int, source = null) -> void:
	if amount <= 0 or target == null or not target.alive:
		return
	target.block += amount
	events.emit(BattleEvent.make(BattleTypes.Event.BLOCK_GAINED, null, target, amount, source))


# --- 상태 ---
# 상태를 붙이고 떼는 것은 항상 이 함수들을 통한다.
# (이벤트 발행, 트리거 구독(Task 8), 행동 순서 갱신(Task 7)을 한곳에서 처리하기 위해)

## target 에 상태를 붙인다. 이미 있으면 수치를 합치고 건 유닛을 갱신한다. STATUS_APPLIED 발행.
func apply_status(target: BattleUnit, status: StatusData, stacks: int, applier: BattleUnit) -> StatusInstance:
	var inst := target.add_status(status, stacks, applier)
	events.emit(BattleEvent.make(BattleTypes.Event.STATUS_APPLIED, applier, target, stacks, status))
	return inst


## target 의 상태 수치를 delta 만큼 바꾼다. 그 결과 사라지면 STATUS_REMOVED 발행.
func change_stacks(target: BattleUnit, id: String, delta: int) -> void:
	var inst := target.get_status(id)
	if inst == null:
		return
	if target.change_stacks(id, delta):
		_on_status_removed(target, inst)


## target 의 상태를 뗀다. 있었으면 STATUS_REMOVED 발행.
func remove_status(target: BattleUnit, id: String) -> void:
	var inst := target.remove_status(id)
	if inst:
		_on_status_removed(target, inst)


## 상태가 사라진 뒤 공통 처리. (Task 8 에서 트리거 구독 해제를 여기에 더한다)
func _on_status_removed(target: BattleUnit, inst: StatusInstance) -> void:
	events.emit(BattleEvent.make(BattleTypes.Event.STATUS_REMOVED, null, target, 0, inst.data))


# --- 사망 ---

## 유닛이 죽었을 때 공통 처리. (Task 7 에서 행동 순서 제거·전투 종료 판정을 여기에 더한다)
func _on_unit_died(u: BattleUnit) -> void:
	u.alive = false
	events.emit(BattleEvent.make(BattleTypes.Event.UNIT_DIED, null, u))


# --- 내부 도우미 ---

## 상대 편
func _other_side(side: int) -> int:
	return BattleTypes.Side.ENEMY if side == BattleTypes.Side.ALLY else BattleTypes.Side.ALLY
