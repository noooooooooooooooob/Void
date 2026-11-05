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

## 이 박스가 보여 주는 유닛
var unit: BattleUnit

@onready var _body: ColorRect = %Body     # 배경 (편 색)
@onready var _name: Label = %Name         # 이름
@onready var _hp: Label = %Hp             # "HP/최대"
@onready var _block: Label = %Block       # 방어도 (0 이면 숨김)
var _highlight := false


func _ready() -> void:
	refresh()  # 트리에 들어가기 전에 set_unit 을 불렀으면 여기서 그린다


## 보여 줄 유닛을 정하고 바로 그린다 (트리에 들어가기 전이면 _ready 에서 그린다).
func set_unit(u: BattleUnit) -> void:
	unit = u
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


## 대상 후보로 강조할지
func set_highlight(on: bool) -> void:
	_highlight = on
	refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(unit)
		accept_event()
