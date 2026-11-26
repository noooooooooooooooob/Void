class_name UnitToken
extends Control
## 격자 위에 서 있는 유닛 하나의 박스 (이름, HP, 방어도). 전투 화면이 유닛 수만큼 unit_token.tscn 을 복제한다.
## 클릭하면 그 유닛을 알린다 (카드 대상 고르기). 죽으면 흐리게 표시한다.

## 박스가 눌렸을 때
signal pressed(unit: BattleUnit)

## 편별 박스 색 (아군 / 적)
@export var ally_color := Color("2f6f6a")
@export var enemy_color := Color("7a2f3a")
## 대상으로 강조할 때 더하는 밝기
@export var highlight_boost := 0.35
## 상태 이펙트(혈갑 등) 그림의 배율. UnitData.battle_scale 과 같은 단위 (10 = 128px 픽셀 그림을 화면 2배로).
## 이펙트는 유닛 그림의 자식이라 흔들림·숨김을 같이 따라가고, 크기만 이 값으로 맞춘다.
@export var effect_scale := 10.0

## 이 박스가 보여 주는 유닛
var unit: BattleUnit

@onready var _body: ColorRect = %Body     # 배경 (편 색)
@onready var _name: Label = %Name         # 이름
@onready var _hp: Label = %Hp             # "HP/최대"
@onready var _block: Label = %Block       # 방어도 (0 이면 숨김)
@onready var _sprite: AnimatedSprite2D = %Sprite  # 전투 그림 (유닛의 battle_frames)
@onready var _effect_behind: AnimatedSprite2D = $Sprite/EffectBehind  # 상태 이펙트 (그림 뒤)
@onready var _effect_front: AnimatedSprite2D = $Sprite/EffectFront    # 상태 이펙트 (그림 앞)
@onready var _base_scale := _sprite.scale    # 씬에 정한 기본 그림 크기 (battle_scale 1 일 때)
var _highlight := false


func _ready() -> void:
	# 한 동작이 끝나면 서 있는 동작(idle)으로 돌아간다 (idle 은 반복이라 끝나지 않는다)
	_sprite.animation_finished.connect(_play_idle)
	_setup_sprite()
	refresh()  # 트리에 들어가기 전에 set_unit 을 불렀으면 여기서 그린다


## 보여 줄 유닛을 정하고 바로 그린다 (트리에 들어가기 전이면 _ready 에서 그린다).
func set_unit(u: BattleUnit) -> void:
	unit = u
	_setup_sprite()
	refresh()


## 유닛의 지금 값으로 다시 그린다.
func refresh() -> void:
	if unit == null or not is_node_ready():
		return
	_name.text = unit.data.display_name
	_hp.text = "%d/%d" % [unit.hp, unit.get_stat(BattleTypes.Stat.HP)]
	_block.visible = unit.block > 0
	_block.text = str(unit.block)
	var base := ally_color if unit.side == BattleTypes.Side.ALLY else enemy_color
	_body.color = base.lightened(highlight_boost) if _highlight else base
	modulate.a = 1.0 if unit.alive else 0.35
	_refresh_effects()


## 연출 중 결과를 보여 줄 때: 실제 유닛 값 대신 그 단계가 끝났을 때의 값으로 HP·방어도·흐림만 다시 그린다.
## s = PerformanceStep.state 의 한 유닛 값 {"hp": int, "block": int, "alive": bool}
func show_state(s: Dictionary) -> void:
	if unit == null or not is_node_ready():
		return
	_hp.text = "%d/%d" % [s.hp, unit.get_stat(BattleTypes.Stat.HP)]
	_block.visible = s.block > 0
	_block.text = str(s.block)
	modulate.a = 1.0 if s.alive else 0.35


## 전투 그림 노드 (연출이 숨기고, 피격 반응이 흔든다)
func sprite() -> AnimatedSprite2D:
	return _sprite


## 캐릭터 UI (이름·HP·방어도 묶음). 피격 반응이 흔든다
func ui_box() -> Control:
	return $Box


## 대상 후보로 강조할지
func set_highlight(on: bool) -> void:
	_highlight = on
	refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(unit)
		accept_event()

## 카드를 쓸 때 전투 화면이 부른다. 카드의 animation 을 한 번 재생하고, 끝나면 idle 로 돌아간다.
## 이름이 비었거나 유닛의 battle_frames 에 그 애니메이션이 없으면 아무것도 안 한다.
func play_card_animation(card: CardData) -> void:
	if unit == null or _sprite.sprite_frames == null:
		return
	var anim := card.animation
	# 강화본(+)은 칸이 비어 있으면 원래 카드의 이름을 쓴다.
	# 1. 기본 덱에서 먼저 찾고, 2. 없으면(상점에서 산 뒤 강화한 카드) 카드 데이터 전체에서 원래 카드를 찾는다
	if anim == &"":
		for base in unit.data.deck:
			if base and card in base.upgrades:
				anim = base.animation
	# 카드 폴더 전체를 읽는 건 무거우므로, 다른 카드 파일 안에 든 강화본일 때만 찾는다
	if anim == &"" and is_embedded_upgrade(card):
		var base := CardPool.find_base(card, CardPool.load_all())
		if base != card:
			anim = base.animation
	if anim == &"" or not _sprite.sprite_frames.has_animation(anim):
		return
	_sprite.play(anim)


## 맞는 동작: 연출의 hit 키 때 전투 화면이 부른다. 그림 묶음에 hit 애니메이션이 있으면 한 번 재생하고,
## 끝나면 idle 로 돌아간다 (반복 없이 만들어야 끝남). 없으면 아무것도 안 한다 (2026-11-21)
func play_hit() -> void:
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"hit"):
		_sprite.play(&"hit")


## card 가 다른 카드 .tres 안에 든 리소스(강화본)인지. 강화본은 따로 파일이 없어 경로가 "<파일>::<id>" 꼴이다.
static func is_embedded_upgrade(card: CardData) -> bool:
	return card != null and card.resource_path.contains("::")


## 유닛의 애니메이션 묶음을 Sprite 에 넣고(배율·필터 포함) idle 을 튼다. 묶음이 없는 유닛(적 등)은 그림을 숨긴다.
func _setup_sprite() -> void:
	if unit == null or not is_node_ready():
		return
	var frames := unit.data.battle_frames
	_sprite.visible = frames != null
	_sprite.sprite_frames = frames
	# 편 색 박스는 그림이 없는 유닛의 자리 표시 — 그림이 있으면 숨긴다 (대상 표시는 격자 칸이 한다)
	_body.visible = frames == null
	# 유닛 배율은 크기에만 곱한다. 기준점은 발밑 — Sprite 노드 위치(씬에서 정함)에 두 발 가운데가 선다
	var k := unit.data.battle_scale if unit.data.battle_scale > 0.0 else 1.0
	_sprite.scale = _base_scale * k
	_sprite.offset = SpritePivot.foot_offset(frames, _sprite.offset)
	_sprite.texture_filter = TEXTURE_FILTER_NEAREST if unit.data.battle_pixel_art else TEXTURE_FILTER_PARENT_NODE
	# 이펙트는 그림의 자식이라 그림 배율이 곱해진다 → 나눠서 effect_scale 크기로. 바닥 가운데는 발밑(그림 노드 원점)에 (_show_effect)
	var e := effect_scale / k
	for fx in [_effect_behind, _effect_front]:
		fx.scale = Vector2(e, e)
	_play_idle()


## 유닛이 가진 상태 중 이펙트가 있는 첫 상태의 이펙트를 그림 앞뒤에 반복 재생한다. 없으면 숨긴다.
## 상태가 사라지면(수치 0 등) 다음 refresh 때 같이 사라진다.
func _refresh_effects() -> void:
	var behind: SpriteFrames = null
	var front: SpriteFrames = null
	if unit.alive:
		for inst in unit.statuses:
			if inst.data.effect_behind or inst.data.effect_front:
				behind = inst.data.effect_behind
				front = inst.data.effect_front
				break
	_show_effect(_effect_behind, behind)
	_show_effect(_effect_front, front)


## 이펙트 노드 하나에 묶음을 넣고 튼다. 같은 묶음이면 처음부터 다시 틀지 않는다 (refresh 가 자주 불리므로).
func _show_effect(fx: AnimatedSprite2D, frames: SpriteFrames) -> void:
	fx.visible = frames != null
	if frames == fx.sprite_frames:
		return
	fx.sprite_frames = frames
	fx.offset = SpritePivot.foot_offset(frames)
	if frames and not frames.get_animation_names().is_empty():
		fx.play(frames.get_animation_names()[0])


## 서 있는 동작(idle)을 튼다. 묶음에 idle 이 없으면 그대로 둔다.
func _play_idle() -> void:
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"idle"):
		_sprite.play(&"idle")
