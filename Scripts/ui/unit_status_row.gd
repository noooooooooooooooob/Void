class_name UnitStatusRow
extends PanelContainer
## 왼쪽(아군)·오른쪽(적) 상태 패널의 한 줄: 이름, HP 바, 방어도, 스태미너, 상태 이름·수치.
## 전투 화면이 유닛 수만큼 unit_status_row.tscn 을 복제한다.

## 이 줄이 보여 주는 유닛
var unit: BattleUnit

@onready var _name: Label = %Name             # 이름
@onready var _hp_bar: ProgressBar = %HpBar    # HP 바
@onready var _hp: Label = %Hp                 # "HP/최대"
@onready var _block: Label = %Block           # "방어도 N"
@onready var _stamina: Label = %Stamina       # "스태미너 N"
@onready var _statuses: Label = %Statuses     # "출혈 3  혈갑 4" (없으면 빈 글자)


## 보여 줄 유닛을 정하고 바로 그린다.
func set_unit(u: BattleUnit) -> void:
	unit = u
	refresh()


## 유닛의 지금 값으로 다시 그린다. 죽은 유닛은 흐리게.
func refresh() -> void:
	if unit == null:
		return
	var max_hp := unit.get_stat(BattleTypes.Stat.HP)
	_name.text = unit.data.display_name
	_hp_bar.max_value = max_hp
	_hp_bar.value = unit.hp
	_hp.text = "%d/%d" % [unit.hp, max_hp]
	_block.text = "방어도 %d" % unit.block
	_stamina.text = "스태미너 %d" % unit.stamina
	# 상태: 패시브인데 수치가 0 인 것(쌓기 전 핏방울 등)은 보여 줄 게 없어서 숨긴다.
	var parts := PackedStringArray()
	for inst in unit.statuses:
		if inst.data.tag == BattleTypes.StatusTag.PASSIVE and inst.stacks <= 0:
			continue
		var label := inst.data.display_name if not inst.data.display_name.is_empty() else inst.data.id
		parts.append("%s %d" % [label, inst.stacks] if inst.data.uses_stacks else label)
	_statuses.text = "  ".join(parts)
	modulate.a = 1.0 if unit.alive else 0.45
