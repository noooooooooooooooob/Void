class_name BoardShape
extends RefCounted
## 전투 격자판의 모양 계산 (노드 없는 순수 계산).
## 보드 네 모서리로 원근(호모그래피)을 구해 칸의 꼭짓점을 만들고, 에디터 핸들을 찾는다.
## BattleBoard 가 칸을 배치할 때, addons/board_shape_editor 가 드래그할 때 쓴다.
##
## 네 점의 순서는 어디서나 왼쪽 위, 오른쪽 위, 오른쪽 아래, 왼쪽 아래.

## 이보다 작은 분모는 0 으로 본다 (네 모서리가 일직선일 때)
const EPSILON := 0.000001


## 단위 정사각형의 uv (0~1) 를 네 모서리 사각형 위의 점으로 바꾼다.
## 선형 보간이 아니라 투영 변환이라 먼 쪽 칸이 실제로 작아진다.
static func point_at(corners: PackedVector2Array, uv: Vector2) -> Vector2:
	var p0 := corners[0]
	var p1 := corners[1]
	var p2 := corners[2]
	var p3 := corners[3]
	# 1. 원근 계수 g, h. 네 모서리가 일직선이면 원근 없이 평행 사변형으로 계산한다
	var d1 := p1 - p2
	var d2 := p3 - p2
	var s := p0 - p1 + p2 - p3
	var den := d1.x * d2.y - d2.x * d1.y
	var g := 0.0
	var h := 0.0
	if absf(den) > EPSILON:
		g = (s.x * d2.y - d2.x * s.y) / den
		h = (d1.x * s.y - s.x * d1.y) / den
	# 2. 투영 변환을 적용한다
	var top := (p1 - p0 + g * p1) * uv.x + (p3 - p0 + h * p3) * uv.y + p0
	var w := g * uv.x + h * uv.y + 1.0
	# 꼬인 사각형에서 w 가 0 이 되면 나누지 않는다
	return top / w if absf(w) > EPSILON else top


## 판의 (col, row) 칸 네 꼭짓점. gap 은 칸 피치 대비 칸 사이 틈 비율, grid 는 판 한 변의 칸 수.
static func cell_quad(corners: PackedVector2Array, col: int, row: int, gap: float, grid: int = 5) -> PackedVector2Array:
	var half := gap * 0.5
	var left := (col + half) / grid
	var right := (col + 1 - half) / grid
	var up := (row + half) / grid
	var down := (row + 1 - half) / grid
	return PackedVector2Array([
		point_at(corners, Vector2(left, up)),
		point_at(corners, Vector2(right, up)),
		point_at(corners, Vector2(right, down)),
		point_at(corners, Vector2(left, down)),
	])


## points 중 at 에서 radius 안에 있는 가장 가까운 점의 번호. 없으면 -1.
static func nearest_handle(points: PackedVector2Array, at: Vector2, radius: float) -> int:
	var best := -1
	var best_dist := radius
	for i in points.size():
		var dist := points[i].distance_to(at)
		if dist <= best_dist:
			best = i
			best_dist = dist
	return best
