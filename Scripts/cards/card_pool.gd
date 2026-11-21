class_name CardPool
extends RefCounted
## 카드 후보 찾기 도우미 (모두 static). 상점(Shop)이 진열 카드와 강화 후보를 고를 때 쓴다.
## - 게임의 카드 전부 읽기 (cards/data/ 아래 .tres)
## - 캐릭터의 카드 = 그 캐릭터 기본 덱 카드들의 deck_id 와 같은 카드 (적 전용 제외)
## - 강화본(CardData.upgrades 안의 카드)의 원래 카드 찾기, 강화 후보 고르기
## 강화본은 원래 카드 .tres 안에 든 리소스라 따로 파일이 없다. 그래서 "원래 카드 = upgrades 에 그 카드가 든 카드" 로 찾는다.

## 카드 데이터 기본 폴더 (카드 가져오기가 cards/data/<덱>/ 에 만든다)
const DEFAULT_DIR := "res://cards/data"


## dir 아래(하위 폴더 포함)의 카드 전부. 폴더가 없으면 빈 배열.
## (.remap 처리는 ResDir.tres_paths 가 한다)
static func load_all(dir: String = DEFAULT_DIR) -> Array[CardData]:
	var out: Array[CardData] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	# 1. 이 폴더의 카드
	for path in ResDir.tres_paths(dir):
		var card := load(path) as CardData
		if card:
			out.append(card)
	# 2. 하위 폴더 (덱마다 한 폴더)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(load_all(dir.path_join(sub)))
	return out


## 그 유닛 기본 덱 카드들의 deck_id (빈 값 = 공용 카드는 빼고, 겹치지 않게)
static func deck_ids_of(unit_data: UnitData) -> PackedStringArray:
	var out := PackedStringArray()
	for c in unit_data.deck:
		if c and not c.deck_id.is_empty() and not out.has(c.deck_id):
			out.append(c.deck_id)
	return out


## pool 중 그 유닛의 카드: deck_id 가 그 유닛 덱의 deck_id 중 하나이고 적 전용(enemy)이 아닌 카드.
## 공용 카드(deck_id "")는 주인 캐릭터가 없으므로 들어가지 않는다 (상점 설계 2026-11-17).
static func cards_for(unit_data: UnitData, pool: Array[CardData]) -> Array[CardData]:
	var ids := deck_ids_of(unit_data)
	var out: Array[CardData] = []
	for c in pool:
		if c and c.category != "enemy" and ids.has(c.deck_id):
			out.append(c)
	return out


## card 의 원래 카드: pool 중 upgrades 에 card 가 든 카드. 강화본이 아니면 card 자신.
static func find_base(card: CardData, pool: Array[CardData]) -> CardData:
	for c in pool:
		if c and card in c.upgrades:
			return c
	return card


## card 를 강화할 때 고를 수 있는 카드들: 원래 카드의 upgrades 에서 card 자신(과 빈 칸)을 뺀 것.
## 이미 강화한 카드를 다시 강화하면 원래 카드의 다른 강화로 바꾸는 것 (상점 설계 2026-11-17).
## 3개로 자르는 것은 상점(Shop)이 한다.
static func upgrade_options(card: CardData, pool: Array[CardData]) -> Array[CardData]:
	var out: Array[CardData] = []
	for up in find_base(card, pool).upgrades:
		if up and up != card:
			out.append(up)
	return out


## 파티 캐릭터의 카드 중 겹치지 않게 최대 n 장을 무작위로 고르고, 카드마다 주인을 붙인다.
## 상점 진열 카드와 전투 보상 카드 후보가 같이 쓴다 (상점 설계 2026-11-17, 전투 보상 설계 2026-11-19).
## - 파티원 순서대로 cards_for 를 모은다. 같은 카드가 두 캐릭터에 걸리면 먼저 찾은 파티원이 주인
## - 후보가 n 장보다 적으면 있는 만큼
## 반환: {"cards": Array[CardData], "owners": Array[BattleUnit]} — 두 배열은 같은 길이, 같은 순서
static func pick_party_cards(party: Array[BattleUnit], pool: Array[CardData], n: int,
		rng: RandomNumberGenerator) -> Dictionary:
	# 1. 후보 모으기 (주인 기억)
	var candidates: Array[CardData] = []
	var owner_of := {}
	for u in party:
		for c in cards_for(u.data, pool):
			if not owner_of.has(c):
				owner_of[c] = u
				candidates.append(c)
	# 2. 겹치지 않게 n 장 뽑기
	var cards: Array[CardData] = []
	var owners: Array[BattleUnit] = []
	while cards.size() < n and not candidates.is_empty():
		var c: CardData = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		cards.append(c)
		owners.append(owner_of[c])
	return {"cards": cards, "owners": owners}
