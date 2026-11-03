class_name BattleEvents
extends RefCounted
## 전투 하나에 하나씩 있는 이벤트 관리자 (구독·발행).
## 전투 진행이 "지금 드로우 페이즈", "A 가 B 에게 피해" 같은 이벤트를 발행하면,
## 그 이벤트에 구독한 상태·패시브·장비가 반응한다. (설계 문서 4.6)
##
## Godot 시그널 대신 직접 만든 이유:
## - 처리 도중 구독이 해제되면(예: 반응하다가 상태가 사라짐) 그 자리에서 바로 건너뛰어야 한다.
## - 반응이 반응을 부르는 연쇄를 일정 깊이에서 끊어야 한다 (무한 반복 방지).
##
## 규칙:
## - 같은 이벤트의 구독자는 구독한 순서대로 실행한다. (기획 결정: 우선순위 값 없음)
## - 처리 도중 새로 구독한 것은 다음 발행부터 실행한다.
## - 처리 도중 구독 해제된 것은 아직 차례가 안 왔으면 건너뛴다.
## - 연쇄 깊이가 BattleTypes.CHAIN_LIMIT 에 닿으면 더 발행하지 않고 경고를 남긴다.

## 이벤트 종류 → 구독 목록 [{ id, handler }]. 배열 순서 = 구독 순서 = 실행 순서.
var _subs: Dictionary = {}
## 지금 살아 있는 구독 id 집합. 해제되면 여기서 빠진다.
var _active: Dictionary = {}
## 다음에 발급할 구독 id
var _next_id := 1
## 지금 처리 중인 발행의 깊이 (이벤트 처리 중에 또 발행하면 1씩 늘어남)
var _depth := 0


## 이벤트 종류 type 에 handler 를 구독한다. handler 는 BattleEvent 하나를 인자로 받는다.
## 반환한 id 로 나중에 unsubscribe 한다.
func subscribe(type: int, handler: Callable) -> int:
	var id := _next_id
	_next_id += 1
	if not _subs.has(type):
		_subs[type] = []
	_subs[type].append({"id": id, "handler": handler})
	_active[id] = true
	return id


## 구독을 해제한다. 이미 해제된 id 여도 괜찮다.
func unsubscribe(id: int) -> void:
	if not _active.erase(id):
		return
	for type in _subs:
		var list: Array = _subs[type]
		for i in list.size():
			if list[i].id == id:
				list.remove_at(i)
				return


## 아직 구독 중인지
func is_subscribed(id: int) -> bool:
	return _active.has(id)


## 이벤트를 발행한다. 그 종류의 구독자들을 구독 순서대로 부른다.
func emit(event: BattleEvent) -> void:
	# 연쇄 깊이 제한: 반응이 반응을 계속 부르면 여기서 끊는다.
	if _depth >= BattleTypes.CHAIN_LIMIT:
		push_warning("BattleEvents: 연쇄 깊이 %d 에 닿아 이벤트 %d 를 발행하지 않음" % [BattleTypes.CHAIN_LIMIT, event.type])
		return
	# 발행 시작 시점의 목록을 복사해서 돈다 → 도중에 새로 구독한 것은 이번엔 안 불린다.
	var list: Array = _subs.get(event.type, []).duplicate()
	_depth += 1
	for sub in list:
		# 도중에 해제된 구독은 건너뛴다 (예: 앞 구독자의 반응으로 상태가 사라진 경우).
		if not _active.has(sub.id):
			continue
		sub.handler.call(event)
	_depth -= 1
