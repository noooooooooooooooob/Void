class_name BattleMovement
extends RefCounted
## 전투 중 격자 이동 규칙. Battle 이 하나 가지고 있고, Battle.move_unit / path_length 가 이것을 부른다.
## (battle.gd 가 길어져서 이동만 따로 떼어 낸 파일 — 2026-11-04)
##
## 규칙 (설계 문서 3.7, CLAUDE.md):
## - 자기 차례에 이동속도만큼 칸을 움직일 수 있다 (남은 이동력 = BattleUnit.move_left).
## - 자기 편 격자 안에서만 움직인다. 격자 크기는 전투마다 다르다 (Battle.in_grid).
## - 상하좌우 한 칸 = 1. 대각선 이동은 없다.
## - 다른 살아 있는 유닛이 있는 칸은 들어가거나 지나갈 수 없다 (같은 편 격자만 해당 — 적은 다른 격자에 있다).
## - 카드 사용 전후로 나눠서 움직일 수 있고, 남은 이동력은 차례가 끝나면 사라진다(차례 시작 때 다시 채움).

## 상하좌우 네 방향
const _DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## 이 이동 규칙이 속한 전투
var battle


func _init(owner_battle) -> void:
	battle = owner_battle


## u 가 지금 칸에서 to 까지 가는 가장 짧은 길의 칸 수. 갈 수 없으면 −1. 제자리는 0.
## 다른 살아 있는 유닛이 있는 칸은 지나갈 수 없다 (너비 우선 탐색).
func path_length(u: BattleUnit, to: Vector2i) -> int:
	if not battle.in_grid(u.side, to):
		return -1
	if to == u.cell:
		return 0
	if _blocked(u, to):
		return -1
	var dist := {u.cell: 0}
	var queue: Array[Vector2i] = [u.cell]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in _DIRS:
			var next := cur + d
			if dist.has(next) or not battle.in_grid(u.side, next) or _blocked(u, next):
				continue
			dist[next] = dist[cur] + 1
			if next == to:
				return dist[next]
			queue.append(next)
	return -1


## u 를 to 로 옮긴다. 갈 수 있고 남은 이동력이 충분하면 옮기고 이동력을 깎은 뒤 UNIT_MOVED 발행(amount = 칸 수).
## 반환: 옮겼으면 true. 못 옮기면 아무것도 바뀌지 않는다.
func move(u: BattleUnit, to: Vector2i) -> bool:
	if not u.alive:
		return false
	var steps := path_length(u, to)
	if steps <= 0 or steps > u.move_left:
		return false
	u.cell = to
	u.move_left -= steps
	battle.events.emit(BattleEvent.make(BattleTypes.Event.UNIT_MOVED, u, null, steps))
	return true


## 그 칸에 u 말고 다른 살아 있는 같은 편 유닛이 있는지
func _blocked(u: BattleUnit, cell: Vector2i) -> bool:
	var other: BattleUnit = battle.unit_at(u.side, cell)
	return other != null and other != u
