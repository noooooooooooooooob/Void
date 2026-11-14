class_name CardPerformance
extends Node2D
## 카드 연출 씬의 루트. 카드마다 Scenes/performances/<이름>.tscn 하나를 만들고 CardData.performance 에 넣는다.
## 전투 화면의 PerformanceQueue 가 이 씬을 띄우고 play() 한다.
##
## 씬 구성 규약 (설계 5장):
## - %Actor (AnimatedSprite2D): 연출하는 캐릭터. 실행할 때 행위자의 battle_frames 가 들어간다.
##   에디터에서는 미리보기용 SpriteFrames 를 넣어 두면 된다.
## - %AnimationPlayer: 애니메이션 "perform" 하나를 재생한다. 동작 전환·이펙트는 일반 트랙으로,
##   아래 move / hit / show_results / zoom 은 Call Method 트랙(경로 ".")의 키로 부른다.
## - 이펙트 노드는 자유. 평소 숨기고 타임라인에서 켠다.
##
## 이 스크립트는 키를 시그널로 바꿔 알릴 뿐, 실제 이동·피격 반응·결과 표시는 PerformanceQueue / 전투 화면이 한다.

## 타임라인 move 키: 대상 칸 중심 + offset(화면 픽셀) 으로 time 초 동안 이동해 달라
signal move_requested(offset: Vector2, time: float)
## 타임라인 hit 키: 대상들의 맞는 반응을 보여 달라 (숫자는 띄우지 않음)
signal hit_reached()
## 타임라인 show_results 키: 이 카드의 결과(피해 숫자·HP·방어도·상태 등)를 지금 보여 달라
signal results_requested()
## 타임라인 zoom 키: 화면을 1 + strength 배로 확대했다가 time 초 동안 원래대로
signal zoom_requested(strength: float, time: float)
## perform 이 끝났다 (perform 이 없으면 play 직후)
signal done()

## 재생할 애니메이션 이름
const PERFORM := &"perform"

@export_group("카드별 변경 (비우면 공통값)")
## 연출이 끝난 뒤 원래 칸으로 돌아가는 시간 (초). 0 미만이면 전투 화면의 공통값
@export var return_time := -1.0
## 피격 이펙트 씬 (한 번 재생하고 스스로 지워지는 씬). 비우면 공통값
@export var hit_effect: PackedScene
## 피격 효과음. 비우면 공통값
@export var hit_sound: AudioStream
## hit 때 화면 흔들림 세기 (픽셀). 0 미만이면 공통값
@export var hit_shake := -1.0
## hit 때 멈추는 시간 (초, 히트스톱). 0 미만이면 공통값
@export var hitstop_time := -1.0
## hit 때 대상이 밀리는 거리 (픽셀, 넉백). 0 미만이면 공통값
@export var knockback := -1.0

@onready var _actor: AnimatedSprite2D = %Actor
@onready var _player: AnimationPlayer = %AnimationPlayer


## 연출을 시작한다. frames 가 있으면 Actor 의 그림 묶음을 그것으로 바꾼다.
## perform 이 끝나면 done 을 낸다. perform 이 없으면 다음 프레임에 바로 done.
func play(frames: SpriteFrames) -> void:
	if frames:
		_actor.sprite_frames = frames
	if not _player.has_animation(PERFORM):
		done.emit.call_deferred()
		return
	if not _player.animation_finished.is_connected(_on_finished):
		_player.animation_finished.connect(_on_finished)
	_player.play(PERFORM)


## 히트스톱용: 타임라인과 씬 안의 모든 AnimatedSprite2D 를 멈추거나(true) 다시 움직인다(false).
func set_paused(on: bool) -> void:
	var s := 0.0 if on else 1.0
	_player.speed_scale = s
	for n in find_children("*", "AnimatedSprite2D", true, false):
		n.speed_scale = s


# --- 타임라인 Call Method 키용 함수 ---

## 대상 칸 중심에서 (x, y) 픽셀 떨어진 곳으로 time 초 동안 이동한다.
func move(x: float, y: float, time: float) -> void:
	move_requested.emit(Vector2(x, y), time)


## 대상들이 맞는 반응을 보인다. 여러 번 찍어도 된다.
func hit() -> void:
	hit_reached.emit()


## 카드 결과를 한 번에 보여 준다. 처음 한 번만 효과가 있다(큐가 거른다).
func show_results() -> void:
	results_requested.emit()


## 화면을 1 + strength 배로 확대했다가 time 초 동안 원래대로 (줌 펀치).
func zoom(strength: float, time: float) -> void:
	zoom_requested.emit(strength, time)


func _on_finished(anim: StringName) -> void:
	if anim == PERFORM:
		done.emit()
