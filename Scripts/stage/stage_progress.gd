class_name StageProgress
extends RefCounted
## 스테이지 지도 위에서 지금 어디까지 왔는지와 커서(고른 다음 노드)를 기억하는 순수 로직.
## StageRun(자동 로드)이 하나 가지고 있고, StageMap 화면이 이걸 보고 커서·상태를 그린다.
##
## 흐름: 시작 노드에서 출발 → 커서로 다음 노드 고르기(select / move_cursor)
##       → enter() 로 실행 시작 → 노드가 끝나면 complete() → 그 노드가 새 현재 위치
##       → 보스까지 끝내면 is_finished()

## 이 스테이지의 모든 노드 ([0] = 시작, 마지막 = 보스. StageGenerator.generate() 결과)
var nodes: Array[StageNode] = []
## 마지막으로 끝낸 노드 = 지금 서 있는 곳. 처음에는 시작 노드
var current: StageNode
## 지금 실행 중인 노드 (전투·이벤트·상점 화면에 들어가 있는 동안). 없으면 null
var entering: StageNode = null
## 커서 위치. choices() 안의 번호 (0 = 가장 위 행)
var cursor := 0


func _init(p_nodes: Array[StageNode]) -> void:
	nodes = p_nodes
	current = nodes[0]
	current.cleared = true  # 시작 노드는 처음부터 지나온 것으로 본다
	cursor = _nearest_row_index(current.row)


## 지금 갈 수 있는 다음 노드들. 위 행 → 아래 행 순서 (W/S 로 커서를 옮기는 순서)
func choices() -> Array[StageNode]:
	return sorted_by_row(current.next)


## 커서가 가리키는 노드. 갈 곳이 없으면(보스까지 끝남) null
func selected() -> StageNode:
	var c := choices()
	if c.is_empty():
		return null
	return c[clampi(cursor, 0, c.size() - 1)]


## 커서를 delta 칸 옮긴다 (-1 = 위, +1 = 아래). 끝에서 멈춘다 (돌아가지 않음)
func move_cursor(delta: int) -> void:
	var c := choices()
	if c.is_empty():
		return
	cursor = clampi(cursor + delta, 0, c.size() - 1)


## 커서를 node 로 옮긴다 (마우스 클릭). 지금 갈 수 없는 노드면 false
func select(node: StageNode) -> bool:
	var index := choices().find(node)
	if index < 0:
		return false
	cursor = index
	return true


## 커서가 가리키는 노드의 실행을 시작한다. 그 노드를 돌려준다 (갈 곳이 없으면 null)
func enter() -> StageNode:
	entering = selected()
	return entering


## 실행 중인 노드를 끝낸다 → 클리어 표시, 새 현재 위치, 커서는 같은 행(없으면 가장 가까운 행)으로
func complete() -> void:
	if entering == null:
		return
	entering.cleared = true
	current = entering
	entering = null
	cursor = _nearest_row_index(current.row)


## 보스까지 끝냈는지 (= 의뢰 성공)
func is_finished() -> bool:
	return current.kind == StageNode.Kind.BOSS


## 노드 배열을 행 순서(위 → 아래)로 정렬한 복사본
static func sorted_by_row(list: Array[StageNode]) -> Array[StageNode]:
	var out: Array[StageNode] = list.duplicate()
	out.sort_custom(func(a: StageNode, b: StageNode): return a.row < b.row)
	return out


## choices() 중 row 와 가장 가까운 행의 번호 (같은 행이 있으면 그것)
func _nearest_row_index(row: int) -> int:
	var c := choices()
	var best := 0
	for i in c.size():
		if absi(c[i].row - row) < absi(c[best].row - row):
			best = i
	return best
