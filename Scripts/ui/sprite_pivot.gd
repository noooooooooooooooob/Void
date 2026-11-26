class_name SpritePivot
extends RefCounted
## 전투 그림의 기준점(피벗)을 발밑에 맞추는 계산. 유닛 박스(UnitToken)·연출 씬(CardPerformance)·연출 미리보기가 같이 쓴다.
## 그림 규약: 한 SpriteFrames 의 모든 프레임은 같은 캔버스 크기이고, 두 발 가운데가 캔버스 아래 가운데에 온다
## (상태 이펙트 그림도 같은 규약 — 이펙트의 바닥 가운데가 유닛 발밑에 놓인다).
## 이 규약대로면 AnimatedSprite2D(centered) 의 offset 을 (0, -캔버스 높이/2) 로 두면 노드 위치 = 발밑이 된다.


## frames 의 발밑 offset (그림 픽셀 단위, 배율과 무관). idle 첫 프레임 크기 기준, idle 이 없으면 첫 애니메이션.
## 묶음이 없거나 비었으면 fallback 을 돌려준다.
static func foot_offset(frames: SpriteFrames, fallback := Vector2.ZERO) -> Vector2:
	if frames == null:
		return fallback
	var anim := &"idle"
	if not frames.has_animation(anim):
		var names := frames.get_animation_names()
		if names.is_empty():
			return fallback
		anim = names[0]
	if frames.get_frame_count(anim) == 0:
		return fallback
	var tex := frames.get_frame_texture(anim, 0)
	if tex == null:
		return fallback
	return Vector2(0, -tex.get_height() * 0.5)
