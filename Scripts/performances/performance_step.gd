class_name PerformanceStep
extends RefCounted
## 화면이 재생할 연출 한 단계. PerformanceRecorder 가 전투 이벤트를 묶어 만들고, PerformanceQueue 가 하나씩 재생한다.
## (설계 docs/superpowers/specs/2026-11-14-card-performance-design.md)
##
## - CARD 단계: 카드 한 장의 BEFORE_CARD_PLAYED ~ AFTER_CARD_PLAYED 사이 이벤트 묶음
## - INSTANT 단계: 카드 밖에서 생긴 이벤트 하나 (차례 시작 출혈 피해, 이동 등)
## 전투 계산은 이미 끝났으므로, 화면은 이 단계의 이벤트와 state(단계가 닫힐 때의 유닛 상태)만 보고 그린다.

## 단계 종류
enum Kind { CARD, INSTANT }

## 단계 종류 (Kind)
var kind: int = Kind.INSTANT
## 카드를 쓴 유닛 (INSTANT 면 이벤트의 actor, 없으면 null)
var actor: BattleUnit
## 실제로 쓴 카드 (대체 카드면 대체 카드). INSTANT 면 null
var card: CardData
## 카드의 기준 대상 (근접 = 맨 앞 적, 원거리·아군 = 지정한 유닛, 자신 = 사용자). INSTANT 면 null
var target: BattleUnit
## 이 단계에 들어온 이벤트들 (발행 순서)
var events: Array[BattleEvent] = []
## 단계가 닫힐 때 전투의 모든 유닛 상태. BattleUnit → {"hp": int, "block": int, "alive": bool, "cell": Vector2i}
## 화면은 결과를 보여 줄 때 실제 값 대신 이 값으로 그린다 (뒤 단계의 결과가 미리 보이지 않게).
var state: Dictionary = {}


## 대상별 받은 피해 합계 (DAMAGE_TAKEN 의 amount 합). BattleUnit → int.
## 피해 효과가 여러 개면 합친다. 대신 맞기로 바뀐 경우 실제로 맞은 유닛 기준.
func damage_totals() -> Dictionary:
	var totals := {}
	for e in events:
		if e.type == BattleTypes.Event.DAMAGE_TAKEN:
			totals[e.target] = totals.get(e.target, 0) + e.amount
	return totals


## 맞는 반응(hit)을 보여 줄 유닛들: 기준 대상 + 피해를 받은 유닛 (중복 없음, 처음 나온 순서).
## 기준 대상이 없으면 카드를 쓴 유닛 (자신 카드 등).
func hit_targets() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var first: BattleUnit = target if target else actor
	if first:
		out.append(first)
	for e in events:
		if e.type == BattleTypes.Event.DAMAGE_TAKEN and e.target and not out.has(e.target):
			out.append(e.target)
	return out


## 단계를 닫는다: 전투의 모든 유닛 상태를 state 에 찍어 둔다.
func snapshot(units: Array[BattleUnit]) -> void:
	state.clear()
	for u in units:
		state[u] = {"hp": u.hp, "block": u.block, "alive": u.alive, "cell": u.cell}
