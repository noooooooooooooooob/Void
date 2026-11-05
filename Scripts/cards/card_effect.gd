@tool
class_name CardEffect
extends Resource
## 효과 부품의 기반 클래스. 카드(CardData.effects)와 상태 트리거가 같은 부품을 같이 쓴다.
## 예: 피해, 방어도, 회복, 상태 부여, 수치 변경, 드로우, 전용 스크립트.
## 새 효과는 이 클래스를 상속해서 apply 를 구현하고, 대상은 resolve_targets 로 구한다. (설계 문서 4.4)

## 효과를 누구에게 적용할지 (BattleTypes.Target)
## TARGETS: 카드가 정한 대상들(범위 포함) / 상태 트리거에서는 이벤트의 대상
## SELF: 행위자 / OWNER: 상태를 가진 유닛 (카드에서는 사용자) / ALL_ALLIES·ALL_ENEMIES: 주인 기준 아군·적 전체
@export var target: BattleTypes.Target = BattleTypes.Target.TARGETS


## 효과를 실행한다. 하위 클래스가 구현한다.
## ctx: 실행 정보 (행위자, 주인, 대상 목록, 이벤트, 이번 사용에서 기록한 값 등)
func apply(_ctx: EffectContext) -> void:
	pass


## target 설정에 따라 실제 대상 목록을 구한다. 비어 있는 자리(null)와 죽은 유닛은 뺀다.
## (앞 효과로 대상이 죽었으면 다음 효과는 그 대상에게 적용되지 않는다)
func resolve_targets(ctx: EffectContext) -> Array[BattleUnit]:
	var raw: Array = []
	match target:
		BattleTypes.Target.TARGETS:
			raw = ctx.targets
		BattleTypes.Target.SELF:
			raw = [ctx.actor]
		BattleTypes.Target.OWNER:
			raw = [ctx.owner]
		BattleTypes.Target.ALL_ALLIES:
			raw = ctx.battle.allies_of(ctx.owner) if ctx.battle and ctx.owner else []
		BattleTypes.Target.ALL_ENEMIES:
			raw = ctx.battle.enemies_of(ctx.owner) if ctx.battle and ctx.owner else []
	var out: Array[BattleUnit] = []
	for u in raw:
		if u != null and u.alive:
			out.append(u)
	return out


## 전투 화면 손패에 보여 줄 계산된 수치 (CLAUDE.md "전투 중엔 계산된 수치").
## 치명·대상과 무관한 기본값. 수치를 보여 줄 게 없는 효과는 -1.
func preview_amount(_ctx: EffectContext) -> int:
	return -1


# --- 하위 효과들이 같이 쓰는 계산 (설계 문서 4.4, 기획 결정) ---

## 배율 값. 비어 있으면 1. 효과는 배율이 0 이하이면 아무것도 하지 않는다.
func scale_of(ctx: EffectContext, multiplier: ValueSource) -> float:
	return multiplier.evaluate(ctx) if multiplier else 1.0


## 수치 계산에 쓸 스탯의 주인: 행위자, 없으면(예: 상태를 건 유닛이 죽음) 상태 주인.
func stat_unit(ctx: EffectContext) -> BattleUnit:
	return ctx.actor if ctx.actor else ctx.owner


## 최종 수치: 모두 곱한 값을 마지막에 내림하고, 최소 1. (기획 결정: 내림은 마지막에 한 번)
func final_amount(value: float) -> int:
	return maxi(1, floori(value))
