class_name StageNode
extends RefCounted
## 스테이지 지도의 노드(칸) 하나. 시작·전투·이벤트·상점·보스 중 하나다.
## StageGenerator 가 스테이지에 들어갈 때마다 새로 만들고, StageMap 화면이 이걸 보고 그린다.
##
## 지도 모양 (열은 왼→오, 행은 위→아래):
##   열 0 = 시작(2행) / 열 1~3 = 전투·이벤트 3×3 / 열 4 = 상점(2행) / 열 5 = 보스(2행)
##   화면에서 2행은 가운데 줄이고, 코드에서는 row 1 이다 (0부터 셈)

## 노드 종류
enum Kind { START, BATTLE, EVENT, SHOP, BOSS }

## 이 노드의 종류
var kind: Kind
## 몇 번째 열인지. 0(시작) ~ 5(보스)
var column: int
## 몇 번째 행인지. 0 = 위, 1 = 가운데, 2 = 아래
var row: int
## 이 노드에서 갈 수 있는 다음 노드들 (오른쪽 열에 있는 노드만).
## ※ 거꾸로 가는 참조(이전 노드)는 두지 않는다. 서로 가리키면 RefCounted 가 메모리에서 안 풀린다
var next: Array[StageNode] = []
## 이미 실행(클리어)한 노드인지
var cleared := false


func _init(p_kind: Kind, p_column: int, p_row: int) -> void:
	kind = p_kind
	column = p_column
	row = p_row


## 다음 노드로 가는 길을 하나 잇는다. 이미 이어져 있으면 아무것도 안 한다.
## (이름이 connect 가 아닌 이유: connect 는 Godot 의 시그널 연결 함수라 이름이 겹친다)
func link_to(other: StageNode) -> void:
	if other not in next:
		next.append(other)


## other 로 바로 갈 수 있는지 (커서 이동·실행 가능 여부 판단용)
func can_go_to(other: StageNode) -> bool:
	return other in next


## 지도 위 위치. x = 열, y = 행
func cell() -> Vector2i:
	return Vector2i(column, row)


## 전투가 벌어지는 노드인지 (전투·보스)
func is_battle() -> bool:
	return kind == Kind.BATTLE or kind == Kind.BOSS
