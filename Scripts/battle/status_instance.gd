class_name StatusInstance
extends RefCounted
## 유닛에 실제로 붙어 있는 상태 하나. 데이터(StatusData)는 공유하고, 수치·부여자는 유닛마다 따로.

## 상태 데이터 (트리거, 보정, 카드 대체)
var data: StatusData
## 이 상태를 가진 유닛
var owner: BattleUnit
## 마지막으로 이 상태를 건 유닛. 트리거 효과의 행위자가 된다 (예: 출혈 피해를 "준 쪽").
var applier: BattleUnit
## 현재 수치
var stacks: int = 0
## 아직 붙어 있는지. 제거되면 false 가 되고, 이후 트리거는 무시된다.
var active: bool = true
## 이 상태의 트리거들이 BattleEvents 에 구독한 id. 제거할 때 전부 해제한다.
var subscription_ids: Array[int] = []
