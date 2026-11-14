class_name Shaker
extends RefCounted
## 화면·캐릭터 그림·캐릭터 UI 를 "조금 랜덤하게" 흔드는 도우미 (설계 5장 hit, 사용자 결정).
## 전투 화면의 피격 반응이 부른다.
##
## - 매 프레임 세기 × 남은 비율 안에서 무작위 방향·거리로 흔들리고, 점점 약해져 time 초 뒤 정확히 원래 자리로 돌아온다.
## - 같은 노드를 흔드는 도중에 또 흔들어도 원래 자리를 잃지 않는다 (노드 meta 에 기준 위치를 둔다).
## - 넉백처럼 잠깐 자리를 옮기는 다른 반응도 origin() 으로 같은 기준 위치를 쓴다.

const _ORIGIN := &"_shake_origin"   # meta: 흔들기 전 원래 위치
const _COUNT := &"_shake_count"     # meta: 지금 진행 중인 흔들기·밀기 개수


## node 를 strength 픽셀 세기로 time 초 동안 흔든다. rng = 연출용 난수 (전투 rng 와 따로).
## node 가 트리 밖이거나 세기·시간이 0 이하면 아무것도 안 한다.
static func shake(node: CanvasItem, strength: float, time: float, rng: RandomNumberGenerator) -> void:
	if node == null or not node.is_inside_tree() or strength <= 0.0 or time <= 0.0:
		return
	var home := begin(node)
	var tw := node.create_tween()
	tw.tween_method(func(t: float):
		var left := strength * (1.0 - t)
		node.position = home + Vector2(rng.randf_range(-left, left), rng.randf_range(-left, left)),
		0.0, 1.0, time)
	tw.finished.connect(func(): end(node))


## node 의 원래 위치 (흔드는 중이면 흔들기 전 위치, 아니면 지금 위치)
static func origin(node: CanvasItem) -> Vector2:
	return node.get_meta(_ORIGIN, node.position)


## 자리를 잠깐 옮기는 반응을 시작한다: 원래 위치를 기억하고 개수를 센다. 원래 위치를 돌려준다.
static func begin(node: CanvasItem) -> Vector2:
	var home := origin(node)
	node.set_meta(_ORIGIN, home)
	node.set_meta(_COUNT, int(node.get_meta(_COUNT, 0)) + 1)
	return home


## 반응 하나가 끝남: 마지막 반응이면 원래 자리로 되돌리고 기억을 지운다.
static func end(node: CanvasItem) -> void:
	if not is_instance_valid(node) or not node.has_meta(_ORIGIN):
		return
	var n := int(node.get_meta(_COUNT, 1)) - 1
	if n > 0:
		node.set_meta(_COUNT, n)
		return
	node.position = node.get_meta(_ORIGIN)
	node.remove_meta(_ORIGIN)
	node.remove_meta(_COUNT)
