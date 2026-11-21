class_name MenuCursor
extends RefCounted
## 세로 메뉴의 커서 규칙 (메인 메뉴·나중의 다른 목록에서 같이 쓴다).
## 줄마다 "고를 수 있는지"만 받아서, 처음 위치와 위/아래 한 칸 이동 결과(줄 번호)를 알려 준다.
## 규칙 (설계 docs/superpowers/specs/2026-11-21-ui-frame-design.md 5-1):
##   - 끝에서 더 가면 반대쪽 끝으로 돌아간다
##   - 고를 수 없는(비활성) 줄은 건너뛴다
##   - 고를 수 있는 줄이 하나도 없으면 -1

## 줄마다 고를 수 있는지 (true = 활성)
var enabled: Array[bool] = []


## enabled_rows: 줄마다 고를 수 있는지 (위에서부터 순서대로)
func _init(enabled_rows: Array = []) -> void:
	for e in enabled_rows:
		enabled.append(bool(e))


## 처음 커서가 갈 줄 = 위에서부터 첫 활성 줄 (없으면 -1)
func first() -> int:
	for i in enabled.size():
		if enabled[i]:
			return i
	return -1


## from 줄에서 dir(+1 = 아래, -1 = 위) 방향으로 다음 활성 줄.
## from 이 -1(커서 없음)이면 첫 활성 줄. 활성 줄이 그것 하나뿐이면 제자리
func step(from: int, dir: int) -> int:
	var n := enabled.size()
	if n == 0 or first() < 0:
		return -1
	if from < 0 or from >= n:
		return first()
	# 한 바퀴 안에서 다음 활성 줄을 찾는다 (돌아가기는 posmod 로)
	for k in range(1, n + 1):
		var i := posmod(from + dir * k, n)
		if enabled[i]:
			return i
	return from
