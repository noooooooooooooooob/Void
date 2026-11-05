class_name EffectContext
extends RefCounted
## 효과 한 번 실행에 필요한 정보 묶음. (설계 문서의 CardPlay)
## 카드를 쓸 때와 상태 트리거가 발동할 때 모두 이것을 만들어 효과·비용·배율에 넘긴다.
##
## 카드 사용: actor = owner = 카드를 쓴 유닛, card/source = 카드, targets = 범위 안의 대상들
## 상태 발동: actor = 없음(null — 상태로 생긴 효과는 아무도 "준" 것이 아님), owner = 상태를 가진 유닛,
##            applier = 그 상태를 건 유닛(기억만), source = 상태 데이터, event = 발동시킨 이벤트,
##            targets = [이벤트의 대상]. 수치 계산은 주인(owner)의 스탯으로 한다.

## 이 효과가 실행되는 전투 (Battle). 아군·적 목록, 피해 처리, 난수 등을 여기서 쓴다.
var battle
## 행위자: 카드를 쓴 유닛. 피해의 "준 쪽"(스태미너 회복·치명 판정 기준). 상태 발동이면 null.
var actor: BattleUnit
## 상태 발동일 때 그 상태를 건 유닛 (기억만 함 — 피해를 준 것으로 치지 않음). 카드 사용이면 null.
var applier: BattleUnit
## 주인: 상태를 가진 유닛. 카드 사용에서는 actor 와 같다.
var owner: BattleUnit
## 사용한 카드 (상태 발동이면 null)
var card: CardData
## 효과의 출처 (CardData 또는 StatusData). 이 효과가 일으킨 이벤트의 source 로 들어간다.
var source
## 효과 대상 목록 (Target.TARGETS 일 때 쓰는 대상)
var targets: Array[BattleUnit] = []
## 이번 실행 중 기록한 값. 예) "consumed:blood_drop" → 소모한 핏방울 수
var values: Dictionary = {}
## 상태를 발동시킨 이벤트 (카드 사용이면 null)
var event: BattleEvent


## BattleTypes.Who 값으로 행위자 또는 주인을 고른다.
func who(w: int) -> BattleUnit:
	return actor if w == BattleTypes.Who.ACTOR else owner
