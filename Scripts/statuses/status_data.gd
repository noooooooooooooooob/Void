@tool
class_name StatusData
extends Resource
## 상태(버프 / 디버프 / 패시브) 하나의 데이터. 게임에서 쓸 상태는 .tres 로 만들어 둔다.
## 예: 출혈, 혈갑, 핏방울, 피의 갈망 (노션 "버프 상태" DB)
##
## 상태 = 트리거(언제 → 무엇을) + 스탯 보정 + 카드 대체. (설계 문서 4.5)
## - 같은 상태가 다시 걸리면 수치를 하나로 합친다 (부여자별로 나누지 않음).
## - 수치 감소 규칙은 상태마다 다르므로 공통 시스템이 없다. 각자 트리거로 정한다.
##   예) "차례 종료 시 수치 −1" = TURN_END 트리거 + ModifyStacksEffect(−1)

## 상태 id. 같은 id 면 같은 상태로 보고 수치를 합친다. 비용·배율·트리거가 이 id 로 상태를 찾는다.
@export var id: String
## 화면에 보일 이름
@export var display_name: String
## 설명 (툴팁 등)
@export_multiline var description: String
## 종류 (BUFF 버프 / DEBUFF 디버프 / PASSIVE 패시브). 규칙에는 영향 없고 분류·표시용.
@export var tag: BattleTypes.StatusTag = BattleTypes.StatusTag.BUFF
## 수치를 쓰는 상태인지. true 면 수치가 0 이하가 되는 순간 사라진다.
## 단, 태그가 PASSIVE 면 0 이 되어도 사라지지 않는다 (핏방울처럼 쌓았다 쓰는 카운터용).
## 수치 없이 계속 유지되는 상태는 false.
@export var uses_stacks: bool = true
## 새 라운드 시작 시 방어도가 초기화되지 않게 하는 상태인지 (방어도 유지 예외용).
@export var keeps_block: bool = false
## 언제 무엇을 할지 목록
@export var triggers: Array[StatusTrigger] = []
## 이 상태를 가진 동안 적용되는 스탯 보정
@export var modifiers: Array[StatModifier] = []
## 카드 대체: { 원본 CardData: 대체 CardData }.
## 이 상태를 가진 유닛이 원본 카드를 보거나 쓰면 대체 카드로 취급한다. (예: 혈갑: 공격태세 → 해체 카드가 피의 참격으로)
@export var replacements: Dictionary = {}
