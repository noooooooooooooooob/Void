class_name TurnOrder
extends RefCounted
## 한 라운드의 행동 순서. Battle 이 하나 가지고 있다. (설계 문서 3.1, 4.8)
##
## 규칙 (사용자 결정 2026-11-04):
## - 라운드 시작 시 각 유닛이 행동 횟수만큼 속도를 굴린다 (속도 범위 안에서 행동마다 따로).
## - 행동 하나 = 온전한 차례 하나. 모든 행동을 속도 내림차순으로 줄 세운다.
##   예) A 행동 2회 [8, 2], B 속도 5 → A, B, A
## - 속도가 바뀌면(감속·가속) 아직 안 쓴 행동들을 즉시 다시 정렬한다. 이미 쓴 행동은 다시 들어오지 않는다.
## - 속도가 같으면: 아군 먼저 → 전투 참여 순서(initial_index) → 행동 순번 — 설계자 판단
##
## 항목(행동) = { "unit": BattleUnit, "index": int(그 유닛의 몇 번째 행동), "speed": int(정렬에 쓴 속도) }

## 이번 라운드에 아직 쓰지 않은 행동들 (맨 앞이 다음 차례)
var _entries: Array = []


## 새 라운드: 유닛마다 속도를 굴리고, 행동 횟수만큼 항목을 넣어 정렬한다.
## units: 이번 라운드에 행동할 (살아 있는) 유닛들. rng: 전투의 난수 생성기.
func start_round(units: Array[BattleUnit], rng: RandomNumberGenerator) -> void:
	_entries.clear()
	for u in units:
		u.roll_speeds(rng)
		for i in u.speed_rolls.size():
			_entries.append({"unit": u, "index": i, "speed": 0})
	resort()


## 다음 행동을 꺼낸다. 없으면 빈 Dictionary.
func pop_next() -> Dictionary:
	return _entries.pop_front() if not _entries.is_empty() else {}


## 지금 속도로 남은 행동들을 다시 정렬한다.
func resort() -> void:
	for e in _entries:
		e.speed = e.unit.action_speed(e.index)
	_entries.sort_custom(_before)


## 남은 행동들의 지금 속도가 마지막 정렬 때와 다르면 다시 정렬하고 true. 그대로면 false.
## (상태가 붙거나 떨어진 뒤 Battle 이 부른다 — 감속·가속을 즉시 반영하기 위함)
func refresh() -> bool:
	for e in _entries:
		if e.unit.action_speed(e.index) != e.speed:
			resort()
			return true
	return false


## 유닛의 남은 행동을 전부 뺀다 (사망 등).
func remove(u: BattleUnit) -> void:
	_entries = _entries.filter(func(e): return e.unit != u)


## 남은 행동 항목들 (순서대로)
func remaining() -> Array:
	return _entries.duplicate()


## 남은 행동의 유닛들 (순서대로, 행동이 여러 번이면 같은 유닛이 여러 번 나온다). 화면의 순서 표시용.
func remaining_units() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for e in _entries:
		out.append(e.unit)
	return out


## 이번 라운드의 행동을 다 썼는지
func is_round_over() -> bool:
	return _entries.is_empty()


## 정렬 기준: a 가 b 보다 먼저 행동하면 true.
## 속도 높은 순 → 아군 먼저 → 전투 참여 순서 → 행동 순번
func _before(a: Dictionary, b: Dictionary) -> bool:
	if a.speed != b.speed:
		return a.speed > b.speed
	if a.unit.side != b.unit.side:
		return a.unit.side == BattleTypes.Side.ALLY
	if a.unit.initial_index != b.unit.initial_index:
		return a.unit.initial_index < b.unit.initial_index
	return a.index < b.index
