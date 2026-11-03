@tool
class_name EquipmentData
extends Resource
## 장비 하나. 장비 = 전투 시작 시 착용자에게 붙여 주는 상태들의 묶음. (설계 문서 4)
## 예) 공격력 +5 무기 = ATTACK FLAT +5 보정을 가진 패시브 상태 하나.
## 기획 규칙: 장비 공격 보너스는 카드 피해가 아니라 공격 스탯에 더해진다.

## 화면에 보일 이름
@export var display_name: String
## 착용하면 전투 시작 시 붙는 상태들 (보통 uses_stacks = false 인 패시브)
@export var statuses: Array[StatusData] = []
