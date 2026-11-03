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
