class_name StatusInstance
extends RefCounted
## 유닛에 실제로 붙어 있는 상태 하나. 데이터(StatusData)는 공유하고, 수치·부여자는 유닛마다 따로.

## 상태 데이터 (트리거, 보정, 카드 대체)
var data: StatusData
## 이 상태를 가진 유닛.
## 유닛도 statuses 로 이 인스턴스를 들고 있으므로 약한 참조(WeakRef)로 둔다 — 서로 강하게 잡으면 메모리에서 안 풀린다.
var owner: BattleUnit:
	get:
		return _owner.get_ref() if _owner else null
	set(value):
		_owner = weakref(value) if value else null
## 마지막으로 이 상태를 건 유닛. 트리거 효과의 행위자가 된다 (예: 출혈 피해를 "준 쪽").
## 장비·패시브는 자기 자신이 건 것이라 owner 와 같은 이유로 약한 참조.
var applier: BattleUnit:
	get:
		return _applier.get_ref() if _applier else null
	set(value):
		_applier = weakref(value) if value else null
## 현재 수치
var stacks: int = 0
## 아직 붙어 있는지. 제거되면 false 가 되고, 이후 트리거는 무시된다.
var active: bool = true
## 이 상태의 트리거들이 BattleEvents 에 구독한 id. 제거할 때 전부 해제한다.
var subscription_ids: Array[int] = []

var _owner: WeakRef
var _applier: WeakRef
