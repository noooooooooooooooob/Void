class_name UnitToken
extends Control
## 격자 위에 서 있는 유닛 하나 (이름, HP, 방어도). 전투 화면이 유닛 수만큼 unit_token.tscn 을 복제한다.
## 클릭하면 그 유닛을 알린다 (카드 대상 고르기). 죽으면 흐리게 표시한다.
## 두 가지 모양:
##   - 그림 모드: 유닛 데이터에 battle_sprite(픽셀 캐릭터)가 있으면 그림이 서 있고 발밑에 얇은 HP 띠 (이름은 옆 상태 줄에 있음)
##   - 상자 모드: 그림이 없으면(지금 적들) 편 색 네모 안에 이름·HP
## 전투 화면은 foot_offset() 을 써서 이 유닛의 "발" 을 칸 가운데에 맞춘다.

## 박스가 눌렸을 때
signal pressed(unit: BattleUnit)

## 편별 박스 색 (아군 / 적)
@export var ally_color := Color("2f6f6a")
@export var enemy_color := Color("7a2f3a")
## 대상으로 강조할 때 더하는 밝기
@export var highlight_boost := 0.35
## 상자 모드 크기 (px)
@export var box_size := Vector2(100, 100)
## 그림 모드 크기 (px, 그림 + 이름표)
@export var sprite_size := Vector2(160, 270)
## 그림 모드에서 발밑 HP 띠 높이 (px)
@export var plate_height := 26.0

## 이 박스가 보여 주는 유닛
var unit: BattleUnit

@onready var _body: ColorRect = %Body     # 배경 (편 색). 그림 모드에서는 발밑 이름표 바탕
@onready var _box: Control = %Box         # 이름·HP·방어도 글자 상자
@onready var _sprite: TextureRect = %Sprite  # 픽셀 캐릭터 그림 (그림 모드에서만 보임, Nearest)
@onready var _name: Label = %Name         # 이름
@onready var _hp: Label = %Hp             # "HP/최대"
@onready var _block: Label = %Block       # 방어도 (0 이면 숨김)
var _highlight := false


func _ready() -> void:
	refresh()  # 트리에 들어가기 전에 set_unit 을 불렀으면 여기서 그린다


## 보여 줄 유닛을 정하고 바로 그린다 (트리에 들어가기 전이면 _ready 에서 그린다).
func set_unit(u: BattleUnit) -> void:
	unit = u
	_apply_mode()
	refresh()


## 그림 모드인지 (유닛 데이터에 전투 그림이 있는지)
func has_sprite() -> bool:
	return unit != null and unit.data.battle_sprite != null


## 이 유닛의 발 위치 (이 노드 왼쪽 위 기준, px). 전투 화면이 이 점을 칸 가운데에 맞춘다
func foot_offset() -> Vector2:
	if has_sprite():
		return Vector2(size.x * 0.5, size.y - plate_height)
	return size * 0.5


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


## 대상 후보로 강조할지
func set_highlight(on: bool) -> void:
	_highlight = on
	refresh()


## 그림 모드/상자 모드에 맞게 크기와 바탕·글자 상자 위치를 바꾼다
func _apply_mode() -> void:
	if not is_node_ready():
		return
	var sprite := has_sprite()
	_sprite.visible = sprite
	_sprite.texture = unit.data.battle_sprite if sprite else null
	_sprite.offset_bottom = -plate_height
	_name.visible = not sprite  # 그림 모드에서는 이름 대신 HP 만 (뒷줄 캐릭터를 덜 가리게)
	custom_minimum_size = sprite_size if sprite else box_size
	size = custom_minimum_size
	# 바탕·글자 상자: 그림 모드면 아래쪽 이름표 띠, 상자 모드면 전체
	for c in [_body, _box]:
		c.anchor_left = 0.0
		c.anchor_right = 1.0
		c.anchor_bottom = 1.0
		c.anchor_top = 1.0 if sprite else 0.0
		c.offset_left = 0.0
		c.offset_right = 0.0
		c.offset_bottom = 0.0
		c.offset_top = -plate_height if sprite else 0.0


func _notification(what: int) -> void:
	# 트리에 들어가기 전에 set_unit 을 불렀으면 준비된 뒤 모드를 맞춘다
	if what == NOTIFICATION_READY and unit:
		_apply_mode()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(unit)
		accept_event()
