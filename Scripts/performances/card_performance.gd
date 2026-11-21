class_name CardPerformance
extends Node2D
## 카드 연출 씬의 루트. 카드마다 Scenes/performances/<이름>.tscn 하나를 만들고 CardData.performance 에 넣는다.
## 전투 화면의 PerformanceQueue 가 이 씬을 띄우고 play() 한다.
## (설계 docs/superpowers/specs/2026-11-19-performance-timeline-design.md 1·2장 — 유니티 Timeline 처럼 에디터 ▶ 로 보며 짠다)
##
## 씬 구성 규약:
## - 씬은 **게임 화면 크기**로 짠다: 좌표 1 = 화면 1px. Actor·대상 미리보기 그림에 유닛 박스 그림 배율(0.2)을 직접 넣는다.
##   그래야 Camera 사각형이 실제 전투 화면 범위와 같다 (실행 땐 루트 배율 = 유닛 그림 배율 ÷ Actor 배율)
## - Home (Marker2D): 행위자가 원래 서 있는 자리. Actor 는 처음에 이 위에 둔다
## - Target (Marker2D): 기준 대상이 서 있는 자리. 자식으로 미리보기 그림을 둔다 (실행할 때 숨김)
## - %Actor (AnimatedSprite2D): 연출하는 캐릭터. 실행할 때 행위자의 battle_frames 가 들어간다.
##   동작 전환은 속성 트랙 Actor:animation, 이동은 Actor:position (Bezier 트랙 권장)
## - Camera (Camera2D, enabled 끔): 위치·zoom·회전 트랙으로 카메라 무빙. 전투 화면이 값을 읽어 월드를 움직인다
## - 이펙트·효과음 노드는 자유 (속성 트랙, Audio Playback 트랙)
## - %AnimationPlayer: 애니메이션 "perform" 하나. 전투 화면이 반응해야 하는 것만 Call Method 트랙(경로 ".")으로
##   hit / show_results / zoom 을 부른다
##
## 실행 중에는 AnimationPlayer 를 직접 진행시키며, 루트의 직계 Node2D 자식(Home·Target 제외)의 위치를
## 매 프레임 PerformanceSpace 로 "에디터 자리 → 실제 칸 자리" 로 바꿔 놓는다.
## 에디터에서는 이 스크립트가 돌지 않으므로 짠 그대로 보인다.

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
## hit 때 느려지는 시간 (초, 히트스톱 — 2026-11-21 부터 정지 대신 슬로우모션). 0 미만이면 공통값
@export var hitstop_time := -1.0
## 히트스톱 동안의 배속 (0 = 정지, 0.2 = 5배 느리게, 1 = 그대로). 0 미만이면 공통값
@export var hitstop_speed := -1.0
## hit 때 대상이 밀리는 거리 (픽셀, 넉백). 0 미만이면 공통값
@export var knockback := -1.0
## 넉백 뒤 제자리로 돌아오는 시간 (초). 0 미만이면 공통값
@export var knockback_return := -1.0
## hit 때 대상 캐릭터 그림·캐릭터 UI 흔들림 세기 (픽셀). 0 미만이면 공통값
@export var hit_unit_shake := -1.0
## hit 흔들림(화면·대상)이 이어지는 시간 (초). 0 미만이면 공통값
@export var shake_time := -1.0
## 피격 번쩍임 색 (1 보다 크면 하얗게 빛남). 완전 투명(알파 0)이면 공통값
@export var flash_color := Color(0, 0, 0, 0)
## 피격 번쩍임이 원래 색으로 돌아오는 시간 (초). 0 미만이면 공통값
@export var flash_time := -1.0
## 피격 효과음 음높이가 무작위로 흔들리는 폭 (0.08 = ±8%). 0 미만이면 공통값
@export var pitch_jitter := -1.0

@onready var _actor: AnimatedSprite2D = %Actor
@onready var _player: AnimationPlayer = %AnimationPlayer

var _running := false            # play() 뒤로 매 프레임 진행·자리 맞추기를 하는지
var _real_home := Vector2.ZERO   # 실제 행위자 자리 (루트 로컬). set_stage 전에는 Home 그대로
var _real_target := Vector2.ZERO # 실제 기준 대상 자리 (루트 로컬). set_stage 전에는 Target 그대로
var _staged := false             # set_stage 를 불렀는지
var _authored := {}              # 노드 → 애니메이션이 쓴 원래 위치 (화면 위치와 분리해서 기억)


## 실제 행위자 자리·기준 대상 자리를 루트 로컬 좌표로 알려 준다. 부르지 않으면 에디터에서 짠 자리 그대로.
func set_stage(real_home: Vector2, real_target: Vector2) -> void:
	_real_home = real_home
	_real_target = real_target
	_staged = true


## Actor 의 배율. 씬을 화면 크기로 짰으면 유닛 그림 배율(지금 0.2)이 들어 있다. 0 성분은 1 로 본다
func actor_scale() -> Vector2:
	var a := get_node(^"%Actor") as Node2D
	return Vector2(a.scale.x if a.scale.x != 0.0 else 1.0, a.scale.y if a.scale.y != 0.0 else 1.0)


## Home 의 루트 로컬 위치 (Home 이 없으면 원점)
func home_position() -> Vector2:
	var h := get_node_or_null(^"Home") as Node2D
	return h.position if h else Vector2.ZERO


## Target 의 루트 로컬 위치 (Target 이 없으면 Home 과 같음 — 자리 맞추기가 행위자 기준으로만 됨)
func target_position() -> Vector2:
	var t := get_node_or_null(^"Target") as Node2D
	return t.position if t else home_position()


## Camera 노드가 있는지 (없으면 전투 화면은 카메라를 움직이지 않는다)
func has_camera() -> bool:
	return get_node_or_null(^"Camera") is Node2D


## 지금 카메라 자세 (루트 로컬, 실제 칸 자리에 맞춘 위치). Camera 가 없으면 단위 변환
func camera_xform() -> Transform2D:
	var cam := get_node_or_null(^"Camera") as Node2D
	if cam == null:
		return Transform2D.IDENTITY
	var zoom: Vector2 = cam.zoom if cam is Camera2D else Vector2.ONE
	return CameraMath.camera_xform(cam.position, cam.rotation, zoom)


## 지금 화면상 Actor 위치 − 실제 행위자 자리 (0 이면 제자리. 복귀가 필요한지 볼 때 씀)
func actor_offset_from_home() -> Vector2:
	return _actor.position - _stage_home()


## Actor 의 원래(애니메이션 기준) 위치. 복귀 tween 이 씀
func get_actor_authored() -> Vector2:
	return _authored.get(_actor, _actor.position)


## Actor 의 원래(애니메이션 기준) 위치를 바꾼다. 화면 위치는 다음 프레임에 자리 맞추기로 정해진다
func set_actor_authored(p: Vector2) -> void:
	_authored[_actor] = p


## 연출을 시작한다. frames 가 있으면 Actor 의 그림 묶음을 그것으로 바꾼다.
## perform 이 끝나면 done 을 낸다. perform 이 없으면 다음 프레임에 바로 done.
func play(frames: SpriteFrames) -> void:
	if frames:
		_actor.sprite_frames = frames
	# Target 의 미리보기 그림은 에디터용
	var target := get_node_or_null(^"Target")
	if target:
		for c in target.get_children():
			if c is CanvasItem:
				c.visible = false
	# 지금 동작을 재생 상태로 (Actor:animation 트랙이 바꿔도 계속 재생됨). 그림 묶음이 없으면 건너뜀
	if _actor.sprite_frames and _actor.sprite_frames.has_animation(_actor.animation):
		_actor.play()
	# Camera 는 값만 읽는다. 켜져 있으면 게임 화면을 가로채므로 끈다 (규약: enabled 끔)
	for c in find_children("*", "Camera2D", true, false):
		c.enabled = false
	_running = true
	# 진행은 _process 에서 직접 한다 (진행 → 자리 맞추기 순서를 지키려고)
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if not _player.has_animation(PERFORM):
		done.emit.call_deferred()
		return
	# perform 이 반복(loop)으로 저장돼 있으면 끝나지 않아 전투가 멈추므로 한 번만 재생한다
	var anim := _player.get_animation(PERFORM)
	if anim.loop_mode != Animation.LOOP_NONE:
		push_warning("CardPerformance %s: perform 이 반복으로 설정돼 있어 한 번만 재생해요" % scene_file_path)
		anim.loop_mode = Animation.LOOP_NONE
	if not _player.animation_finished.is_connected(_on_finished):
		_player.animation_finished.connect(_on_finished)
	_player.play(PERFORM)
	# 첫 프레임 값을 바로 실제 칸 자리로 맞춰 둔다. 안 그러면 같은 프레임에 먼저 도는 전투 화면이
	# 맞추기 전 카메라 자세를 시작 자세로 기억해 월드가 어긋난다
	_sync(0.0)


## 매 프레임 진행·자리 맞추기
func _process(delta: float) -> void:
	if _running:
		_sync(delta)


## 원래 위치로 되돌림 → 애니메이션 진행(새 값을 씀) → 원래 위치 기억 → 실제 칸 자리로 바꿔 놓기.
## 원래 위치를 따로 기억해서, 위치 트랙이 없는 노드도 프레임마다 밀려 나가지 않는다.
func _sync(delta: float) -> void:
	var nodes := _mapped_nodes()
	for n in nodes:
		if _authored.has(n):
			n.position = _authored[n]
	# 끝난 뒤에 advance 하면 마지막 키 값을 다시 써서 복귀(set_actor_authored)를 덮으므로 재생 중일 때만
	if _player.is_playing():
		_player.advance(delta)
	var home := home_position()
	var target := target_position()
	for n in nodes:
		_authored[n] = n.position
		n.position = PerformanceSpace.map_point(n.position, home, target, _stage_home(), _stage_target())


## 자리 맞추기를 받는 노드: 루트의 직계 Node2D 자식 중 Home·Target 제외
func _mapped_nodes() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for c in get_children():
		if c is Node2D and c.name != &"Home" and c.name != &"Target":
			out.append(c)
	return out


func _stage_home() -> Vector2:
	return _real_home if _staged else home_position()


func _stage_target() -> Vector2:
	return _real_target if _staged else target_position()


## 히트스톱용: 타임라인과 씬 안의 모든 AnimatedSprite2D 를 멈추거나(true) 다시 움직인다(false).
func set_paused(on: bool) -> void:
	set_speed(0.0 if on else 1.0)


## 히트스톱 슬로우모션용: 타임라인과 씬 안의 모든 AnimatedSprite2D 를 s 배속으로 (1 = 보통, 0 = 정지)
func set_speed(s: float) -> void:
	_player.speed_scale = s
	for n in find_children("*", "AnimatedSprite2D", true, false):
		n.speed_scale = s


# --- 타임라인 Call Method 키용 함수 ---

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
