class_name EnemyAI
extends RefCounted
## 적의 차례 진행. Battle 이 하나 가지고 있고, Battle.run_enemy_turn 이 이것을 부른다.
## (battle.gd 가 길어져서 적 행동만 따로 떼어 낸 파일 — 2026-11-05)
##
## 규칙 (설계 문서 4.9, 노션 아이디어 박스):
## - 적도 아군과 같은 차례 순서를 거친다 (차례 시작 → SP 회복 → 드로우 → 행동 → 엔드 → 종료).
##   그래서 적에게 걸린 출혈·혈갑도 똑같이 발동한다.
## - 일반 적: 드로우 페이즈에 자기 덱에서 1장을 뽑고, 그 1장을 쓴다.
## - 보스: 덱을 섞지 않고 정해진 순서대로 1장씩 쓴다. 끝까지 쓰면 처음으로 돌아간다. (Battle.begin_turn 에서 처리)
## - 뽑은 카드를 쓸 수 없으면(근접 대상 없음, SP 부족 등) 한 장을 더 뽑아서 그 카드를 쓴다 (사용자 결정 2026-11-05).
##   일반 적: 덱에서 1장 더 — 행동 중 드로우라 덱이 비면 버린 더미를 섞지 않고 못 뽑는다.
##   보스: 정해진 순서의 다음 카드를 바로 꺼낸다.
##   그 카드도 쓸 수 없으면 그 차례는 행동하지 않는다.
## - 대상 선택:
##   근접 = 규칙대로 자동
##   원거리 = 살아 있는 아군 편 유닛 중 어그로 비율 가중 랜덤 (사용자 결정 2026-11-05). 모두 0 이면 균등.
##   아군·자신 = 자기 자신

## 이 적 행동이 속한 전투
var battle


func _init(owner_battle) -> void:
	battle = owner_battle


## 적 u 의 차례를 처음부터 끝까지 진행한다.
## 드로우 페이즈에 죽으면(출혈 등) 아무것도 하지 않고 끝난다.
func run_turn(u: BattleUnit) -> void:
	if not battle.begin_turn(u):
		return
	# 1. 드로우 페이즈에 뽑은 카드를 써 본다.
	if not _try_play(u, u.hand[0] if not u.hand.is_empty() else null):
		# 2. 못 쓰면 한 장 더 꺼내서 그 카드를 써 본다 (일반 적: 덱에서, 보스: 순서상 다음 카드).
		var before := u.hand.size()
		if u.data.is_boss:
			battle.draw_boss_card(u)
		else:
			battle.draw(u, 1, false)
		if u.hand.size() > before:
			_try_play(u, u.hand[u.hand.size() - 1])
	# 3. 차례 종료 (남은 손패는 전부 버린다)
	battle.end_turn(u)


## card 를 쓸 수 있으면 대상을 골라 쓰고 true. 못 쓰거나 카드가 없으면 false.
func _try_play(u: BattleUnit, card: CardData) -> bool:
	if card == null or not u.alive:
		return false
	var origin := _pick_origin(u, battle.effective_card(u, card))
	if battle.can_play(u, card, origin) != "":
		return false
	return battle.play_card(u, card, origin)


## 카드의 공격 종류에 따라 기준 유닛을 고른다.
## 근접은 Battle 이 자동으로 정하므로 null. 원거리는 어그로 가중 랜덤. 아군·자신은 자기 자신.
func _pick_origin(u: BattleUnit, card: CardData) -> BattleUnit:
	match card.attack_type:
		"ranged":
			return pick_ranged_target(u)
		"ally", "self":
			return u
	return null


## 적 u 의 원거리 공격 대상: 상대 편(플레이어 쪽) 살아 있는 유닛 중 어그로 비율로 가중 랜덤.
## 예) 어그로 100 / 300 → 25% / 75%. 어그로가 0 인 유닛은 다른 유닛에 어그로가 있으면 뽑히지 않는다.
## 모두 0 이면 균등하게 고른다. 대상이 없으면 null. (사용자 결정 2026-11-05)
func pick_ranged_target(u: BattleUnit) -> BattleUnit:
	var foes: Array[BattleUnit] = battle.enemies_of(u)
	if foes.is_empty():
		return null
	var weights: Array[int] = []
	var total := 0
	for f in foes:
		var w := maxi(0, f.get_stat(BattleTypes.Stat.AGGRO))
		weights.append(w)
		total += w
	if total <= 0:
		return foes[battle.rng.randi_range(0, foes.size() - 1)]
	# 0 이상 total 미만의 값을 뽑아, 누적 어그로가 그 값을 넘는 첫 유닛을 고른다.
	var roll: int = battle.rng.randi_range(0, total - 1)
	for i in foes.size():
		roll -= weights[i]
		if roll < 0:
			return foes[i]
	return foes[foes.size() - 1]
