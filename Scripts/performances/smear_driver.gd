@tool
class_name SmearDriver
extends Node
## 스머지(스미어) 효과: 부모 그림(AnimatedSprite2D, 연출 씬의 Actor 등)이 빠르게 움직이거나 순간이동하면
## 지나온 쪽으로 부드러운 모션 블러 꼬리를 잠깐 그린다 (smear.gdshader).
## 쓰는 법: 연출 씬의 Actor 아래에 Scenes/performances/smear.tscn 을 끌어다 놓는다 (설계 docs/superpowers/specs/2026-11-25-smear-effect-design.md).
## 부모에 이미 material 이 있으면 덮어쓰지 않고 경고만 한다.
## 에디터에서는 연출 화면 탭의 복제본에서만 돈다 — 편집 중인 씬에서 돌면 material 이 씬 파일에 저장되므로 거기선 쉰다.
## 위치는 그림의 부모(연출 씬 루트) 좌표로 본다 — 카메라가 움직여도 꼬리가 생기지 않게. 연출 씬은 1 = 화면 1px.

const SMEAR_SHADER := preload("res://Scripts/performances/smear.gdshader")

## 한 프레임에 이만큼(px) 이상 움직이면 꼬리를 그린다
@export var min_move := 20.0
## 꼬리 길이 = 이동 거리 × 이 비율. 멀리 뛸수록 길고, 가까우면 짧다 (0.5 = 이동 거리의 절반)
@export_range(0.0, 2.0, 0.01) var length_ratio := 0.5
## 꼬리 최대 길이 (px). 아주 멀리 뛰어도 이 길이까지만 (그림 사각형 여백도 이만큼 넓어져 너무 크면 무거움)
@export var max_length := 400.0
## 꼬리가 0 으로 줄어드는 시간 (초). 길든 짧든 이 시간 안에 사라진다
@export var decay_time := 0.12

var _sprite: Node2D
var _mat: ShaderMaterial
var _last: Vector2
var _trail := Vector2.ZERO  # 지금 꼬리 (px, 지금 위치 → 지나온 쪽)
var _start_len := 0.0  # 꼬리가 생길 때의 길이 (decay_time 동안 이 길이에서 0 으로)
var _fresh := true  # 첫 프레임: 연출 시작 때 자리 맞추기로 생기는 이동은 무시


func _ready() -> void:
	if Engine.is_editor_hint() and _in_edited_scene():
		set_process(false)
		return
	_sprite = get_parent() as Node2D
	if _sprite == null:
		return
	# 이미 다른 material 이 있으면 덮어쓰지 않는다 (설계: 경고만)
	if _sprite.material != null:
		push_warning("SmearDriver: %s 에 이미 material 이 있어 스머지를 끕니다" % _sprite.name)
		return
	_mat = ShaderMaterial.new()
	_mat.shader = SMEAR_SHADER
	_sprite.material = _mat
	# 꼬리가 그림 밖으로 나갈 수 있게 사각형 여백을 꼬리 최대 길이만큼 (그림 픽셀로)
	_mat.set_shader_parameter(&"pad", max_length / _pixel_scale())
	_send_region()


func _process(delta: float) -> void:
	step(delta)


## 한 프레임 진행: 이동을 재서 꼬리를 정하고 셰이더 값을 넣는다. _process 가 부르고, 테스트는 직접 부른다.
func step(delta: float) -> void:
	if _mat == null:
		return
	# 1. 이번 프레임 이동 → 충분히 크면 꼬리를 새로 (이동 × 비율, 최대 길이까지)
	var now := _sprite.position
	var moved := now - _last
	_last = now
	if _fresh:
		_fresh = false
	elif moved.length() >= min_move:
		_trail = (-moved * length_ratio).limit_length(max_length)
		_start_len = _trail.length()
	# 2. 꼬리는 decay_time 동안 줄어든다
	elif decay_time > 0.0:
		_trail = _trail.move_toward(Vector2.ZERO, _start_len * delta / decay_time)
	else:
		_trail = Vector2.ZERO
	# 3. px → 그림 픽셀 (배율·좌우 반전 반영)
	var local := _trail / _pixel_scale()
	var s := _sprite as AnimatedSprite2D
	if s and s.flip_h:
		local.x = -local.x
	_mat.set_shader_parameter(&"smear", local)
	# 4. 꼬리가 길면 짚는 수도 늘려 끊기지 않게 (화면 8px 에 한 번, 4~48)
	_mat.set_shader_parameter(&"samples", clampi(int(_trail.length() / 8.0), 4, 48))
	_send_region()


## 지금 꼬리 (부모 좌표 px, 지금 위치 → 지나온 쪽). 꼬리가 없으면 Vector2.ZERO
func trail() -> Vector2:
	return _trail


## 텍스처가 그리는 영역 (텍스처 UV 기준 x, y, 너비, 높이). AtlasTexture 프레임이면 아틀라스 안의 그 칸, 아니면 전체.
## 셰이더가 이 영역 밖(아틀라스의 옆 프레임)을 꼬리로 읽지 않게 쓴다
static func frame_region(tex: Texture2D) -> Vector4:
	var at := tex as AtlasTexture
	if at and at.atlas:
		var size := Vector2(at.atlas.get_size())
		return Vector4(at.region.position.x / size.x, at.region.position.y / size.y,
			at.region.size.x / size.x, at.region.size.y / size.y)
	return Vector4(0, 0, 1, 1)


## 지금 보이는 프레임의 영역을 셰이더에 넣는다
func _send_region() -> void:
	var s := _sprite as AnimatedSprite2D
	var tex: Texture2D = null
	if s and s.sprite_frames and s.sprite_frames.has_animation(s.animation) \
			and s.frame < s.sprite_frames.get_frame_count(s.animation):
		tex = s.sprite_frames.get_frame_texture(s.animation, s.frame)
	_mat.set_shader_parameter(&"region", frame_region(tex))


## 에디터에서 지금 편집 중인 씬 안의 노드인지 (연출 화면 탭의 복제본은 아님)
func _in_edited_scene() -> bool:
	var root := get_tree().edited_scene_root
	return root != null and (root == self or root.is_ancestor_of(self))


## 그림 픽셀 하나가 부모 좌표에서 몇 px 인지 (그림 노드의 scale)
func _pixel_scale() -> float:
	var sc := absf(_sprite.scale.x)
	return sc if sc > 0.0 else 1.0
