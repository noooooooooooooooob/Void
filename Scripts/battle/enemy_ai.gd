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
## - 쓸 수 없는 카드(근접 대상 없음, SP 부족 등)면 그 차례는 행동하지 않는다. 보스는 다음 차례에 다음 카드로 넘어간다.
## - 대상 선택(어그로 규칙이 정해질 때까지 단순 규칙):
##   근접 = 규칙대로 자동 / 원거리 = 살아 있는 아군 편 유닛 중 무작위(전투 난수) / 아군·자신 = 자기 자신

## 이 적 행동이 속한 전투
var battle


func _init(owner_battle) -> void:
	battle = owner_battle


## 적 u 의 차례를 처음부터 끝까지 진행한다.
## 드로우 페이즈에 죽으면(출혈 등) 아무것도 하지 않고 끝난다.
func run_turn(u: BattleUnit) -> void:
	if not battle.begin_turn(u):
		return
	if not u.hand.is_empty():
		var card: CardData = u.hand[0]
		var origin := _pick_origin(u, battle.effective_card(u, card))
		if battle.can_play(u, card, origin) == "":
			battle.play_card(u, card, origin)
	battle.end_turn(u)


## 카드의 공격 종류에 따라 기준 유닛을 고른다.
## 근접은 Battle 이 자동으로 정하므로 null. 원거리는 상대 편(플레이어) 중 무작위. 아군·자신은 자기 자신.
func _pick_origin(u: BattleUnit, card: CardData) -> BattleUnit:
	match card.attack_type:
		"ranged":
			var foes: Array[BattleUnit] = battle.enemies_of(u)
			if foes.is_empty():
				return null
			return foes[battle.rng.randi_range(0, foes.size() - 1)]
		"ally", "self":
			return u
	return null
