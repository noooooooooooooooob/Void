@tool
class_name PerformanceSpace
extends RefCounted
## 연출 씬의 "에디터 자리 → 실제 칸 자리" 바꾸기 (설계 docs/superpowers/specs/2026-11-19-performance-timeline-design.md 2장).
## 에디터에서는 Home(행위자 자리)과 Target(대상 자리) 거리가 고정이지만, 실제 전투에서는 칸마다 다르다.
## CardPerformance 가 매 프레임 Actor·Camera·이펙트 위치에 쓴다. 에디터 "연출 화면" 창도 같은 식을 쓴다(그래서 @tool).


## 가까운 쪽 기준 구간 (Home→Target 거리에 대한 비율). 이 안은 비율로 늘리지 않고 가까운 쪽에서 같은 픽셀만큼 떨어진다
const ANCHOR_ZONE := 1.0 / 3.0


## 에디터 좌표 p 를 실제 좌표로 바꾼다 — "가까운 쪽에 붙어서 같은 거리만큼 따라간다" (2026-11-21 사용자 결정, A안).
## Home→Target 직선 위에서 간 비율 w(0~1)로 어느 쪽에 붙을지 정한다:
## - Target 쪽 1/3 (w ≥ 2/3): 실제 대상에서 에디터와 같은 픽셀만큼 떨어진 자리 (예: 대상 앞 20px → 어느 칸이든 대상 앞 20px)
## - Home 쪽 1/3 (w ≤ 1/3): 실제 행위자에서 같은 픽셀만큼 떨어진 자리
## - 가운데 1/3: 두 기준을 이어 붙여 섞는다 (미끄러지는 이동·날아가는 이펙트가 끊기지 않게)
## - 직선에서 위아래로 벗어난 거리(점프 높이 등)는 그대로
## - Home 뒤(w<0)는 행위자 기준, Target 너머(w>1)는 대상 기준
## - Home 과 Target 이 같으면 w = 0 (행위자 기준)
static func map_point(p: Vector2, home: Vector2, target: Vector2, real_home: Vector2, real_target: Vector2) -> Vector2:
	var d := target - home
	var len_sq := d.length_squared()
	var w := 0.0 if len_sq == 0.0 else clampf((p - home).dot(d) / len_sq, 0.0, 1.0)
	# 대상 기준 비율 s: Home 쪽 구간 0, Target 쪽 구간 1, 가운데는 0→1 로 곧게
	var s := clampf((w - ANCHOR_ZONE) / (1.0 - 2.0 * ANCHOR_ZONE), 0.0, 1.0)
	return p + (1.0 - s) * (real_home - home) + s * (real_target - target)


## 연출 씬 루트 배율: Actor 가 행위자 그림과 같은 크기가 되게 = 그림 배율 ÷ Actor 배율 (화면 크기로 짠 씬이면 1).
## actor_scale 의 0 성분은 1 로 본다
static func root_scale(sprite_scale: Vector2, actor_scale: Vector2) -> Vector2:
	var a := Vector2(actor_scale.x if actor_scale.x != 0.0 else 1.0, actor_scale.y if actor_scale.y != 0.0 else 1.0)
	return sprite_scale / a


## 연출 씬 루트 위치: Home(루트 로컬)이 행위자 그림 자리(sprite_pos)에 오게
static func root_position(sprite_pos: Vector2, home: Vector2, root_scale: Vector2) -> Vector2:
	return sprite_pos - home * root_scale
