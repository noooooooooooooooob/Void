@tool
class_name SkyBody
extends Node2D
## 하늘의 해·달. 부품 Scenes/backgrounds/parts/sun.tscn, moon.tscn 의 루트 (같은 스크립트, 값만 다름). 그룹 mood_sky_body.
## 배경 씬에 놓고 에디터 2D 화면에서 끌어 옮긴다. 빛줄기(MoodRays)는 BattleMood 를 거쳐 이 위치에서 뻗어 나온다
## (보이는 해·달 중 첫 번째, 설계 docs/superpowers/specs/2026-11-27-battle-mood-sliders-design.md).
##
## 자식: Glow (Sprite2D, 더하기 헤일로) / Disc (Sprite2D, 원반). 둘 다 빛을 안 받는다 (light_mask 0, unshaded).

## 옮겨졌거나 보이기/숨기기가 바뀌었거나 트리에서 빠짐. BattleMood 가 받아 빛줄기를 다시 맞춘다
signal moved

## Disc 텍스처 원래 크기 (px). body_size 를 배율로 바꿀 때 쓴다
const DISC_TEXTURE_SIZE := 128.0
## 헤일로 크기 = 원반 지름 × 이 값
const GLOW_RATIO := 4.0

## 원반·헤일로 색
@export var body_color := Color(1, 0.75, 0.45):
	set(v):
		body_color = v
		_apply()
## 원반 지름 (px, 기준 해상도 1920×1080)
@export_range(4.0, 600.0, 1.0) var body_size := 120.0:
	set(v):
		body_size = v
		_apply()
## 헤일로 세기 (색에 곱함, HDR 이라 1 을 넘으면 더 번짐). 0 = 헤일로 없음
@export_range(0.0, 3.0, 0.05) var glow_strength := 1.5:
	set(v):
		glow_strength = v
		_apply()


func _ready() -> void:
	# 위치가 바뀌면 NOTIFICATION_TRANSFORM_CHANGED 를 받는다 (에디터에서 끌 때도)
	set_notify_transform(true)
	_apply()


func _notification(what: int) -> void:
	# 트리에서 빠질 때(지움·옮김)도 알려야 빛줄기가 없는 해를 계속 가리키지 않는다.
	# 받는 쪽(BattleMood)은 한 프레임 뒤에 다시 맞춘다 (빠지는 중에는 아직 트리·그룹에 있음)
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_VISIBILITY_CHANGED \
			or what == NOTIFICATION_EXIT_TREE:
		moved.emit()
	# 형제 사이 순서가 바뀌어도 알린다 — "트리 순서 첫 번째 해"가 바뀔 수 있음 (부모의 child_order_changed)
	if what == NOTIFICATION_ENTER_TREE:
		if not get_parent().child_order_changed.is_connected(_on_order_changed):
			get_parent().child_order_changed.connect(_on_order_changed)
	elif what == NOTIFICATION_EXIT_TREE:
		if get_parent().child_order_changed.is_connected(_on_order_changed):
			get_parent().child_order_changed.disconnect(_on_order_changed)


func _on_order_changed() -> void:
	moved.emit()


## 값을 원반·헤일로에 넣는다. 준비 전에는 건너뛰고 _ready 에서 넣는다
func _apply() -> void:
	if not is_node_ready():
		return
	var disc := $Disc as Sprite2D
	var s := body_size / DISC_TEXTURE_SIZE
	disc.scale = Vector2(s, s)
	disc.modulate = body_color
	var glow := $Glow as Sprite2D
	var g := body_size * GLOW_RATIO / float(glow.texture.get_width())
	glow.scale = Vector2(g, g)
	glow.modulate = Color(body_color.r * glow_strength, body_color.g * glow_strength, body_color.b * glow_strength, 1.0)
	glow.visible = glow_strength > 0.0
