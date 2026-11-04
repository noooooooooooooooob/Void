class_name BattleEvent
extends RefCounted
## 전투 이벤트 한 건. BattleEvents.emit() 으로 구독자들에게 전달된다.
## 예: "A 가 B 에게 30 피해를 줌(출처: 출혈)" = make(DAMAGE_DEALT, A, B, 30, 출혈 상태)
##
## actor / target 은 보통 BattleUnit 이지만, 타입을 정하지 않았다(Variant).
## 이벤트는 유닛보다 먼저 만들어지는 기반 클래스라 서로 얽히지 않게 하려는 것.

## 이벤트 종류 (BattleTypes.Event)
var type: int
## 이벤트를 일으킨 유닛. 피해라면 피해를 준 쪽, 차례 이벤트라면 차례인 유닛. 없으면 null.
var actor
## 이벤트를 받은 유닛. 피해라면 피해를 받은 쪽. 없으면 null.
var target
## 관련된 카드 (카드 사용 이벤트 등). 없으면 null.
var card
## 이벤트의 출처 (어떤 카드 또는 상태 데이터에서 나왔는지). 상태 트리거의 "출처 필터"가 이 값을 본다.
var source
## 수치 (피해량, 회복량, 이동 칸 수 등). 없으면 0.
var amount: int = 0
## 상태 때문에 생긴 이벤트일 때, 그 상태를 건 유닛 (예: 출혈 피해 → 출혈을 건 유닛). 아니면 null.
## 행위자(actor)와 다르다: 상태로 생긴 피해는 행위자가 없고, 건 유닛은 "기억"만 된다.
var applier


## 이벤트를 만든다. 인자 순서: 종류, 행위자, 대상, 수치, 출처, 카드, 상태를 건 유닛.
static func make(type: int, actor = null, target = null, amount: int = 0, source = null, card = null, applier = null) -> BattleEvent:
	var e := BattleEvent.new()
	e.applier = applier
	e.type = type
	e.actor = actor
	e.target = target
	e.amount = amount
	e.source = source
	e.card = card
	return e
