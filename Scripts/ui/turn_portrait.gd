class_name TurnPortrait
extends Control
## 위쪽 행동 순서 줄의 초상화 하나 (이름 첫 글자, 속도). 전투 화면이 남은 행동 수만큼 turn_portrait.tscn 을 복제한다.
## 지금 차례인 유닛은 크게·밝게 표시한다.

## 편별 색 (아군 / 적)
@export var ally_color := Color("2f6f6a")
@export var enemy_color := Color("7a2f3a")

## 지금 차례 표시인지
var is_current := false

@onready var _body: ColorRect = %Body         # 배경 (편 색)
@onready var _name: Label = %Name             # 이름 (짧게)
@onready var _speed: Label = %Speed           # 이번 행동의 속도
@onready var _current_mark: ColorRect = %CurrentMark  # 지금 차례 테두리


## u 의 행동 하나를 표시한다. speed = 이번 행동의 속도, current = 지금 차례인지.
func set_entry(u: BattleUnit, speed: int, current: bool) -> void:
	is_current = current
	_name.text = u.data.display_name
	_speed.text = str(speed)
	_body.color = ally_color if u.side == BattleTypes.Side.ALLY else enemy_color
	_current_mark.visible = current
	modulate.a = 1.0 if current else 0.8
