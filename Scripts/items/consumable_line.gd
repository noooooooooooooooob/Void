@tool
class_name ConsumableLine
extends Resource
## 소비 아이템의 효과 줄 하나 (웹 카드 에디터 "소비 아이템" 탭의 효과 줄과 같은 모양).
## ConsumableData.lines 에 들어가고, 아이템을 쓰면 Battle.use_item 이 위에서부터 차례로 적용한다.
## 지금은 HP 회복·SP 회복만 있다 (스탯 버프는 다음 단계. 설계: docs/superpowers/specs/2026-11-17-consumable-items-design.md).
## 수치는 음수도 된다 — 음수면 그만큼 깎는다 (HP 는 피해가 아니라 HP 만 줄어듦.
## 설계: docs/superpowers/specs/2026-11-17-consumable-targets-design.md).

## 효과 종류. 새 종류는 맨 뒤에 붙인다 (.tres 에 숫자로 저장됨).
enum Type {
	HEAL_HP,  ## HP 회복 (최대 HP 를 넘지 않음)
	HEAL_SP,  ## SP 회복 (최대 SP 를 넘어도 됨 — 2026-11-17 사용자 결정)
}

## 수치 방식.
enum Kind {
	FLAT,     ## amount 를 그대로 회복
	PERCENT,  ## 대상 최대치(최대 HP / 최대 SP)의 amount %
}

## 효과 종류
@export var type: Type = Type.HEAL_HP
## 수치 방식: FLAT 고정값 / PERCENT 대상 최대치의 %
@export var kind: Kind = Kind.FLAT
## 수치. FLAT 이면 회복량, PERCENT 면 퍼센트 (20 = 20%). 음수면 그만큼 깎고, 0 이면 아무 일도 없다.
@export var amount: int = 0


## 실제 변화량 (부호 있음: 양수 = 회복, 음수 = 깎음). max_value = 대상의 최대 HP(HEAL_HP) 또는 최대 SP(HEAL_SP).
## 규칙: 크기는 고정값 |amount| 또는 최대치 × |amount|% (내림), 0 이 아니면 크기는 최소 1. amount 0 이면 0.
func amount_for(max_value: int) -> int:
	if amount == 0:
		return 0
	var size := absi(amount)
	if kind == Kind.PERCENT:
		size = floori(max_value * size / 100.0)
	return signi(amount) * maxi(1, size)


## 화면에 보일 한 줄. 예) "HP 회복 +30", "SP 회복 +20%", "HP 회복 -20"
func describe() -> String:
	var what := "HP 회복" if type == Type.HEAL_HP else "SP 회복"
	return "%s %s%d%s" % [what, "-" if amount < 0 else "+", absi(amount), "%" if kind == Kind.PERCENT else ""]
