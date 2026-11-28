@tool
class_name GroundShadow
extends Sprite2D
## 바닥 그림자. 부품 Scenes/backgrounds/parts/ground_shadow.tscn 의 루트. 그룹 mood_shadow.
## 그림자를 드리울 그림(AnimatedSprite2D 또는 Sprite2D)의 **자식**으로 둔다 — 전투 유닛(unit_token.tscn 의 Sprite),
## 카드 연출의 Actor(연출 큐가 붙임), 나중에 따로 그린 석등·도리이 같은 정지 그림.
## 원점 = 대상의 발밑 (전투 그림은 발밑 피벗 규약). 대상의 위치·배율·보이기를 자식이라 그대로 받는다.
##
## 매 프레임 대상의 지금 그림(동작·칸)을 복사하고, 해·달 반대쪽 바닥으로 눕혀 기울인다 (설계 2026-11-28-ground-shadow-design.md).
## 방향·길이·색은 그룹 battle_mood 의 BattleMood 에서 읽고, 없으면 NO_MOOD_* 값으로 발밑에 짧게.
## 빛을 안 받고(light_mask 0) 대상 뒤에 그린다(show_behind_parent). 장면 어둠(CanvasModulate)은 받는다.

## BattleMood 가 없을 때 그림자 색 (알파 = 진하기)
const NO_MOOD_COLOR := Color(0, 0, 0, 0.5)
## BattleMood 가 없을 때 길이 (대상 키 대비 배율)
const NO_MOOD_LENGTH := 0.2
## BattleMood 가 없을 때 끝 흐림 (0~1)
const NO_MOOD_FADE := 0.6
## BattleMood 가 없을 때 바닥 기울기 (세로 누름)
const NO_MOOD_TILT := 0.5


func _process(_delta: float) -> void:
	sync_from_target()
	var parent := get_parent() as Node2D
	if parent == null:
		return
	# 그림자 값: 지금은 BattleMood 없이 기본값 (해 없음 → 발밑에 짧게)
	transform = shadow_basis(parent.global_position, null, NO_MOOD_LENGTH, NO_MOOD_TILT)
	_set_look(NO_MOOD_COLOR, NO_MOOD_FADE)


## 그림자 변환. 그림 안 높이 h 인 점(대상 기준 (x, -h))이 발밑에서 h × length × d 만큼 떨어진 바닥 점으로 간다.
## foot = 대상 발밑 전역 위치, source = 해·달 전역 위치(Vector2) 또는 null(해 없음 → 똑바로 앞(화면 아래)),
## length = 대상 키 대비 그림자 길이, tilt = 바닥이 비스듬히 보이는 만큼 세로를 누르는 값 (1 = 안 누름).
static func shadow_basis(foot: Vector2, source: Variant, length: float, tilt: float) -> Transform2D:
	var d := Vector2(0, 1)
	if source is Vector2:
		d = (foot - (source as Vector2)).normalized()
		d.y *= tilt
	return Transform2D(Vector2(1, 0), -length * d, Vector2.ZERO)


## 부모 그림의 지금 텍스처·오프셋·뒤집기를 복사한다. AnimatedSprite2D 는 지금 동작·칸, Sprite2D 는 텍스처·영역·칸.
## 그림이 없으면(sprite_frames 없음·동작 없음) texture = null
func sync_from_target() -> void:
	var p := get_parent()
	if p is AnimatedSprite2D:
		var a := p as AnimatedSprite2D
		var f := a.sprite_frames
		texture = f.get_frame_texture(a.animation, a.frame) if f and f.has_animation(a.animation) \
				and a.frame < f.get_frame_count(a.animation) else null
		region_enabled = false
		hframes = 1
		vframes = 1
		_copy_common(a.offset, a.centered, a.flip_h, a.flip_v)
	elif p is Sprite2D:
		var s := p as Sprite2D
		texture = s.texture
		region_enabled = s.region_enabled
		region_rect = s.region_rect
		hframes = s.hframes
		vframes = s.vframes
		frame = s.frame
		_copy_common(s.offset, s.centered, s.flip_h, s.flip_v)


func _copy_common(off: Vector2, c: bool, fh: bool, fv: bool) -> void:
	offset = off
	centered = c
	flip_h = fh
	flip_v = fv


## 셰이더 인스턴스 값: 색·끝 흐림, 발밑·그림 맨 위 y (끝 흐림 기준)
func _set_look(color: Color, fade: float) -> void:
	set_instance_shader_parameter(&"shadow_color", color)
	set_instance_shader_parameter(&"fade", fade)
	set_instance_shader_parameter(&"foot_y", 0.0)
	set_instance_shader_parameter(&"top_y", _top_y())


## 그림 맨 위의 대상 기준 y (눕히기 전). 칸·영역을 쓰면 한 칸 높이로
func _top_y() -> float:
	if texture == null:
		return -1.0
	var h := float(texture.get_height()) / maxf(vframes, 1)
	if region_enabled:
		h = region_rect.size.y
	return offset.y - h * 0.5 if centered else offset.y
