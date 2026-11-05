@tool
class_name StatusTrigger
extends Resource
## 상태가 "언제 무엇을 할지" 하나. StatusData.triggers 에 넣는다.
## 상태가 붙으면 event 에 구독하고, 이벤트가 filter 조건에 맞으면 effects 를 차례로 실행한다.
## (설계 문서 4.5)
##
## 예) 출혈: event DRAW_PHASE, filter OWNER_IS_ACTOR(주인의 드로우 페이즈) → 수치만큼 고정 피해
##     핏방울: event DAMAGE_TAKEN, filter TARGET_IS_ENEMY_OF_OWNER, source_status_id "bleed"
##             (적이 받은 출혈 피해만, 누가 걸었든) → 핏방울 + 피해량
## 주의: 상태로 생긴 피해(출혈 등)는 행위자가 없다. 그래서 OWNER_IS_ACTOR 필터로는 상태 피해에 반응할 수 없다.

## 반응할 이벤트 (BattleTypes.Event)
@export var event: BattleTypes.Event = BattleTypes.Event.TURN_END
## 이벤트와 상태 주인의 관계 조건 (BattleTypes.Filter)
## ANY 항상 / OWNER_IS_ACTOR 주인이 이벤트를 일으켰을 때 / OWNER_IS_TARGET 주인이 이벤트를 받았을 때
@export var filter: BattleTypes.Filter = BattleTypes.Filter.ANY
## 비어 있지 않으면, 이벤트의 출처가 이 id 의 상태일 때만 반응한다. (예: "bleed" → 출혈 피해에만)
@export var source_status_id: String = ""
## 조건이 맞을 때 실행할 효과들. 카드와 같은 효과 부품을 쓴다.
@export var effects: Array[CardEffect] = []
