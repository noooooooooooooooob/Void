@tool
class_name CameraMath
extends RefCounted
## 연출 카메라 계산 (설계 docs/superpowers/specs/2026-11-19-performance-timeline-design.md 3장).
## 연출 씬의 Camera(위치·회전·줌)를 "월드 묶음을 어떻게 움직일지" 변환으로 바꾼다.
## BattleScreen 과 에디터 "연출 화면" 창이 같이 쓴다(그래서 @tool).


## 카메라 자세를 변환으로: pos 로 옮기고 rot 만큼 돌리고 1/zoom 크기 (zoom 2 = 두 배 확대해 보는 카메라).
## zoom 의 성분이 0 이면 1 로 본다.
static func camera_xform(pos: Vector2, rot: float, zoom: Vector2) -> Transform2D:
	var z := Vector2(zoom.x if zoom.x != 0.0 else 1.0, zoom.y if zoom.y != 0.0 else 1.0)
	return Transform2D(rot, Vector2(1.0 / z.x, 1.0 / z.y), 0.0, pos)


## 시작 카메라 cam0 기준으로 지금 카메라 cam 이 보는 화면이 되도록 월드에 줄 변환.
## 카메라가 그대로면 단위 변환, 카메라가 오른쪽으로 가면 월드는 왼쪽으로.
static func view(cam0: Transform2D, cam: Transform2D) -> Transform2D:
	return cam0 * cam.affine_inverse()


## 월드 묶음에 줄 변환. t = 월드 묶음 좌표에서 본 연출 루트의 변환, cam0·cam = 연출 루트 로컬의 시작·지금 카메라 자세
static func world_xform(t: Transform2D, cam0: Transform2D, cam: Transform2D) -> Transform2D:
	return t * view(cam0, cam) * t.affine_inverse()
