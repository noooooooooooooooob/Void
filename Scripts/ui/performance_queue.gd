class_name PerformanceQueue
extends Node
## 연출 대기열. battle_screen.tscn 의 PerformanceQueue 노드. 전투 화면이 PerformanceRecorder 에서 꺼낸 단계를 push 하면
## 하나씩 재생한다. (설계 docs/superpowers/specs/2026-11-14-card-performance-design.md 1·2·6장)
##
## - 연출 씬이 없는 단계(즉시 단계, 연출 없는 카드)는 push 한 그 호출 안에서 바로 step_results 를 낸다 → 지금과 똑같이 동작.
## - 연출 씬이 있는 카드 단계를 만나면 씬을 띄우고 재생한다. 끝날 때까지 is_busy() 가 true 이고, 뒤 단계는 기다린다.
## - 실제 숫자·로그·박스 갱신, 피격 반응은 전투 화면이 시그널을 받아서 한다. 이 노드는 순서와 이동만 맡는다.

## 이 단계의 결과를 지금 보여 줄 때 (카드 단계면 show_results 키 또는 연출 끝, 나머지는 바로)
signal step_results(step: PerformanceStep)
## 연출의 hit 키마다 (피격 반응용). perf = 지금 재생 중인 연출 씬
signal hit(step: PerformanceStep, perf: CardPerformance)
## 연출의 zoom 키 (줌 펀치용)
signal zoom(step: PerformanceStep, strength: float, time: float)
## 바빴던 대기열이 다 비었을 때 (연출이 하나라도 있었을 때만)
signal drained()

## 연출이 끝난 뒤 원래 칸으로 돌아가는 기본 시간 (초). 연출 씬의 return_time 이 0 이상이면 그 값
@export var default_return_time := 0.2

## 연출 씬을 올려 둘 레이어 (전투 화면이 _ready 에서 넣음)
var layer: Control
## BattleUnit → UnitToken 을 돌려주는 함수 (전투 화면이 _ready 에서 넣음). 없는 유닛이면 null
var token_of: Callable

var _steps: Array[PerformanceStep] = []  # 기다리는 단계들
var _busy := false                       # 연출 씬을 재생 중인지
var _step: PerformanceStep               # 재생 중인 단계
var _perf: CardPerformance               # 재생 중인 연출 씬
var _sprite: AnimatedSprite2D            # 연출 동안 숨긴 행위자 박스의 그림
var _sprite_was_visible := false
var _home := Vector2.ZERO                # 연출 씬의 시작 위치 (화면 좌표)
var _moved := false                      # move 키로 움직였는지
var _shown := false                      # 이 단계의 결과를 이미 보여 줬는지
## 지금 움직이는 이동 tween (히트스톱 때 멈추려고 기억)
var move_tween: Tween


## 단계들을 대기열 뒤에 붙이고, 놀고 있으면 바로 처리를 시작한다.
func push(steps: Array[PerformanceStep]) -> void:
	_steps.append_array(steps)
	if not _busy:
		_run()


## 연출 씬을 재생 중인지 (이 동안 전투 화면은 입력·적 행동·결과 창을 미룬다)
func is_busy() -> bool:
	return _busy


## 지금 재생 중인 연출 씬 (없으면 null)
func current_performance() -> CardPerformance:
	return _perf


## 연출 씬이 나올 때까지 단계를 바로바로 처리한다. 연출 씬을 만나면 재생을 시작하고 멈춘다.
func _run() -> void:
	while not _steps.is_empty():
		var step: PerformanceStep = _steps.pop_front()
		if step.kind == PerformanceStep.Kind.CARD and step.card and step.card.performance:
			_start(step)
			return
		step_results.emit(step)


## 연출 씬 하나를 띄우고 재생한다 (설계 6장 1~3).
func _start(step: PerformanceStep) -> void:
	_busy = true
	_step = step
	_moved = false
	_shown = false
	_perf = step.card.performance.instantiate()
	layer.add_child(_perf)
	# 1. 행위자 박스의 그림 자리에 같은 크기로 띄우고, 박스의 그림은 숨긴다
	var token: UnitToken = token_of.call(step.actor) if token_of.is_valid() else null
	_sprite = token.sprite() if token else null
	if _sprite:
		_home = _sprite.global_position
		_perf.global_position = _home
		_perf.global_scale = _sprite.global_scale
		_sprite_was_visible = _sprite.visible
		_sprite.visible = false
	else:
		_home = _perf.global_position
	# 2. 타임라인 키 → 이동·피격·결과·줌
	_perf.move_requested.connect(_on_move)
	_perf.hit_reached.connect(func(): hit.emit(_step, _perf))
	_perf.results_requested.connect(_show_results)
	_perf.zoom_requested.connect(func(s, t): zoom.emit(_step, s, t))
	_perf.done.connect(_on_done)
	_perf.play(step.actor.data.battle_frames if step.actor else null)


## move 키: 기준 대상 박스의 중심 + offset 으로 time 초 동안 이동
func _on_move(offset: Vector2, time: float) -> void:
	var target: UnitToken = token_of.call(_step.target) if _step.target and token_of.is_valid() else null
	if target == null:
		return
	_moved = true
	_tween_to(target.get_global_rect().get_center() + offset, time)


func _tween_to(to: Vector2, time: float) -> Tween:
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	move_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	move_tween.tween_property(_perf, "global_position", to, maxf(time, 0.0))
	return move_tween


## show_results 키: 처음 한 번만 결과를 보여 준다
func _show_results() -> void:
	if _shown:
		return
	_shown = true
	step_results.emit(_step)


## perform 이 끝남: 결과를 아직 안 보여 줬으면 보여 주고, 움직였으면 원래 자리로 돌아간 뒤 정리 (설계 6장 4~5)
func _on_done() -> void:
	_show_results()
	if not _moved:
		_finish()
		return
	var t := _perf.return_time if _perf.return_time >= 0.0 else default_return_time
	_tween_to(_home, t).finished.connect(_finish)


## 연출 씬을 지우고 그림을 다시 보인 뒤 다음 단계로. 다 비었으면 drained.
func _finish() -> void:
	if _sprite and is_instance_valid(_sprite):
		_sprite.visible = _sprite_was_visible
	_perf.queue_free()
	_perf = null
	_sprite = null
	_step = null
	move_tween = null
	_busy = false
	_run()
	if not _busy:
		drained.emit()
