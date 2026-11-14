class_name PerformanceRecorder
extends RefCounted
## 전투 이벤트를 받아 연출 단계(PerformanceStep)로 묶어 두는 기록기. 전투 화면이 전투마다 하나 만든다.
## 화면은 세션이 바뀔 때마다 take_steps() 로 쌓인 단계를 꺼내 연출 대기열에 넣는다.
##
## 규칙 (설계 1장):
## - BEFORE_CARD_PLAYED 가 오면 카드 단계를 연다. 카드 안에서 또 카드가 쓰이면 바깥 단계에 같이 담는다(깊이로 셈).
## - AFTER_CARD_PLAYED 로 깊이가 0 이 되면 유닛 상태를 찍고 단계를 닫는다.
## - 카드 밖의 이벤트는 하나씩 즉시 단계가 된다 (이벤트 직후 상태를 찍음).

## 기록하는 전투
var _battle: Battle
## 다 닫힌 단계들 (take_steps 가 꺼내 감)
var _steps: Array[PerformanceStep] = []
## 지금 열려 있는 카드 단계 (없으면 null)
var _open: PerformanceStep
## 카드 안의 카드 깊이 (BEFORE +1, AFTER −1)
var _depth := 0


## battle 의 모든 이벤트 종류를 구독한다.
func _init(battle: Battle) -> void:
	_battle = battle
	for type in BattleTypes.Event.values():
		battle.events.subscribe(type, _on_event)


## 쌓인 단계들을 돌려주고 비운다. 열려 있는 카드 단계는 아직 안 준다.
func take_steps() -> Array[PerformanceStep]:
	var out := _steps
	_steps = []
	return out


func _on_event(e: BattleEvent) -> void:
	# 1. 카드 시작: 바깥 카드면 새 단계를 연다
	if e.type == BattleTypes.Event.BEFORE_CARD_PLAYED:
		if _depth == 0:
			_open = PerformanceStep.new()
			_open.kind = PerformanceStep.Kind.CARD
			_open.actor = e.actor
			_open.target = e.target
			_open.card = e.card
		_depth += 1
		_open.events.append(e)
		return
	# 2. 카드 안의 이벤트: 열린 단계에 담고, 바깥 카드가 끝나면 닫는다
	if _depth > 0:
		_open.events.append(e)
		if e.type == BattleTypes.Event.AFTER_CARD_PLAYED:
			_depth -= 1
			if _depth == 0:
				_open.snapshot(_battle.units)
				_steps.append(_open)
				_open = null
		return
	# 3. 카드 밖의 이벤트: 하나씩 즉시 단계
	var s := PerformanceStep.new()
	s.kind = PerformanceStep.Kind.INSTANT
	s.actor = e.actor if e.actor is BattleUnit else null
	s.events.append(e)
	s.snapshot(_battle.units)
	_steps.append(s)
