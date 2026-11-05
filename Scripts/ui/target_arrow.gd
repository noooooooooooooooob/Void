class_name TargetArrow
extends Node2D
## 대상을 고르는 카드를 집었을 때 카드에서 마우스(또는 고정 대상)까지 이어지는 휜 화살표 (슬레이 더 스파이어 방식, 사용자 결정 2026-11-05).
## 전투 화면(battle_screen.tscn)에 하나 들어 있고, 화면 스크립트가 set_points() 로 시작·끝 점만 바꾼다.
## 모양(굵기·색)은 target_arrow.tscn 의 Line / Head 노드에서 편집한다.

## 고를 수 있는 대상 위에 있을 때 색
@export var valid_color := Color("ff5a5a")
## 대상이 아닌 곳에 있을 때 색
@export var idle_color := Color("e8e2f0")
## 곡선이 위로 휘는 정도 (두 점 거리 대비 비율)
@export var bend := 0.35
## 곡선을 이루는 점 개수
@export var segments := 24

@onready var _line: Line2D = $Line      # 곡선 몸통
@onready var _head: Polygon2D = $Head   # 끝의 화살촉 (원점이 끝, +x 방향을 향하게 그려 둔 삼각형)


## 화살표를 from → to 로 다시 그린다 (화면 좌표).
## 2차 베지어: 조절점은 두 점의 가운데에서 위쪽으로 거리 × bend 만큼 올린 곳.
func set_points(from: Vector2, to: Vector2) -> void:
	var mid := (from + to) * 0.5 + Vector2(0, -from.distance_to(to) * bend)
	var pts := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / segments
		pts.append(from.lerp(mid, t).lerp(mid.lerp(to, t), t))
	_line.points = pts
	_head.position = to
	# 화살촉 방향 = 곡선 끝의 진행 방향
	_head.rotation = (to - pts[pts.size() - 2]).angle() if pts.size() > 1 else 0.0


## 지금 마우스가 고를 수 있는 대상 위인지에 따라 색을 바꾼다.
func set_valid(on: bool) -> void:
	var c := valid_color if on else idle_color
	_line.default_color = c
	_head.color = c
