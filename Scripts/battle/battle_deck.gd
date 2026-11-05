class_name BattleDeck
extends RefCounted
## 전투 중 덱 규칙 (전투 준비, 드로우, 섞기, 보스 순서 드로우). Battle 이 하나 가지고 있고,
## Battle.draw / draw_boss_card 와 전투 시작(start_battle)이 이것을 부른다.
## (battle.gd 가 길어져서 덱 부분만 따로 떼어 낸 파일 — 2026-11-05)
##
## 규칙 (설계 문서 3.1·3.2, CLAUDE.md):
## - 덱·손패·버린 카드 더미·제외 더미는 캐릭터마다 따로 있다.
## - 드로우 페이즈(차례 시작)에 덱이 비면 버린 더미를 섞어 덱으로 만든다.
## - 행동 중 드로우(카드 효과 등)는 덱이 비면 더 못 뽑는다 (사용자 결정 2026-11-04).
## - 제외 더미는 절대 섞지 않는다 (이번 전투에서 다시 돌아오지 않음).
## - 보스는 덱을 섞지 않고 정해진 순서대로 1장씩 쓴다. 끝까지 쓰면 처음으로 돌아간다.
## - 모든 섞기는 전투의 난수(battle.rng)를 쓴다 → 같은 시드면 같은 결과.

## 이 덱 규칙이 속한 전투
var battle


func _init(owner_battle) -> void:
	battle = owner_battle


## 전투 시작 준비: 덱을 데이터에서 복사해 섞고(원본 데이터는 그대로), 손패·버린 더미·제외 더미를 비운다.
func prepare(u: BattleUnit) -> void:
	u.deck = u.data.deck.duplicate()
	shuffle(u.deck)
	u.hand.clear()
	u.discard.clear()
	u.exiled.clear()


## u 가 카드를 n 장 뽑는다. 장마다 CARD_DRAWN 발행.
## reshuffle: 덱이 비었을 때 버린 더미를 섞어 덱으로 만들지 (제외 더미는 절대 쓰지 않는다).
##   - 드로우 페이즈(차례 시작): true → 섞어서 계속 뽑는다
##   - 행동 중 드로우(카드 효과 등): false → 덱이 비면 더 못 뽑는다
## 더 뽑을 카드가 없으면 거기서 멈춘다.
func draw(u: BattleUnit, n: int, reshuffle: bool = true) -> void:
	for i in n:
		if u.deck.is_empty():
			if not reshuffle or u.discard.is_empty():
				return
			u.deck = u.discard.duplicate()
			u.discard.clear()
			shuffle(u.deck)
		var c: CardData = u.deck.pop_front()
		u.hand.append(c)
		battle.events.emit(BattleEvent.make(BattleTypes.Event.CARD_DRAWN, u, null, 0, null, c))


## 보스는 덱을 섞지 않고 정해진 순서대로 1장씩 손패에 넣는다. 끝까지 쓰면 처음으로 돌아간다.
## 쓸 수 없는 카드였으면 적 행동(enemy_ai)이 이 함수를 한 번 더 불러 순서상 다음 카드를 바로 꺼낸다.
func draw_boss_card(u: BattleUnit) -> void:
	if u.data.deck.is_empty():
		return
	var c: CardData = u.data.deck[u.boss_index % u.data.deck.size()]
	u.boss_index += 1
	u.hand.append(c)
	battle.events.emit(BattleEvent.make(BattleTypes.Event.CARD_DRAWN, u, null, 0, null, c))


## 배열을 전투의 난수로 섞는다 (Fisher–Yates). 같은 시드면 같은 결과.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = battle.rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
