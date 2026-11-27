@tool
class_name MoodRays
extends Node2D
## 빛줄기 묶음. 부품 Scenes/backgrounds/parts/light_rays.tscn 의 루트. 그룹 mood_rays.
## 빔(자식 Polygon2D)마다 노드 위치 = 빛이 닿는 곳. 에디터 2D 화면에서 빔을 끌어 닿는 곳을 옮긴다.
## 빔 모양은 이 스크립트가 해·달 위치(source) → 닿는 곳으로 채운다 (빔 노드를 새로 만들지는 않음).
## source 는 BattleMood 가 보이는 해·달 위치로 넣는다. 색·세기(modulate)도 BattleMood 가 넣는다
## (설계 docs/superpowers/specs/2026-11-27-battle-mood-sliders-design.md).

## 해·달이 없을 때 빛이 오는 곳 = 닿는 곳에서 이만큼 위 (px)
const NO_SOURCE_HEIGHT := 1000.0
## 빔이 이보다 짧으면 (해가 닿는 곳 바로 위) 안 그린다 (px)
const MIN_LENGTH := 1.0
## 빔 텍스처(light_beam.tres) 가로 크기. 빔 폭 방향으로 0 → 이 값까지 uv 를 깐다
const UV_WIDTH := 64.0

## 해·달 쪽 빔 폭 (px)
@export_range(0.0, 1000.0, 1.0) var width_near := 110.0:
	set(v):
		width_near = v
		_redraw()
## 닿는 곳 빔 폭 (px)
@export_range(0.0, 1000.0, 1.0) var width_far := 250.0:
	set(v):
		width_far = v
		_redraw()

## 빛이 오는 곳 (전역 좌표). has_source 가 true 일 때만 쓴다. BattleMood 가 넣는다
var source := Vector2.ZERO:
	set(v):
		source = v
		_redraw()
## false 면 해·달이 없다는 뜻: 빔이 닿는 곳에서 똑바로 위에서 내려온다
var has_source := false:
	set(v):
		has_source = v
		_redraw()

## 에디터에서 빔을 끌었는지 알아보려고 지난번 빔 위치를 기억 (빔 이름 → 전역 위치)
var _last_positions := {}


func _ready() -> void:
	_redraw()


func _process(_delta: float) -> void:
	# 에디터에서 빔 노드를 끌어 옮기면 부모에게 알림이 안 오므로 위치를 살펴 다시 그린다
	if not Engine.is_editor_hint():
		return
	for b in _beams():
		if _last_positions.get(b.name) != b.global_position:
			_redraw()
			return


## 빔 전부를 source → 각 빔 위치로 다시 그린다. 준비 전에는 건너뛴다
func _redraw() -> void:
	if not is_node_ready():
		return
	_last_positions.clear()
	for b in _beams():
		_last_positions[b.name] = b.global_position
		_shape_beam(b)


## 빔 하나의 모양: 해 쪽 두 점(폭 width_near, 알파 1) → 닿는 곳 두 점(폭 width_far, 알파 0)
func _shape_beam(b: Polygon2D) -> void:
	var from_global := source if has_source else b.global_position + Vector2(0, -NO_SOURCE_HEIGHT)
	var src := b.to_local(from_global)
	if src.length() < MIN_LENGTH:
		b.polygon = PackedVector2Array()
		b.uv = PackedVector2Array()
		b.vertex_colors = PackedColorArray()
		return
	# 빔 방향에 수직인 쪽으로 폭을 벌린다
	var side := src.normalized().orthogonal()
	var hn := side * width_near * 0.5
	var hf := side * width_far * 0.5
	b.polygon = PackedVector2Array([src + hn, src - hn, -hf, hf])
	b.uv = PackedVector2Array([Vector2(0, 0), Vector2(UV_WIDTH, 0), Vector2(UV_WIDTH, 4), Vector2(0, 4)])
	var lit := Color(1, 1, 1, 1)
	var faded := Color(1, 1, 1, 0)
	b.vertex_colors = PackedColorArray([lit, lit, faded, faded])


func _beams() -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	for c in get_children():
		if c is Polygon2D:
			out.append(c)
	return out
