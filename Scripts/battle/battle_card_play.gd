class_name BattleCardPlay
extends RefCounted
## 전투 중 카드 사용 규칙. Battle 이 하나 가지고 있고, Battle.can_play / play_card / effective_card /
## exile_card 가 이것을 부른다. (battle.gd 가 길어져서 카드 사용 부분만 따로 떼어 낸 파일 — 2026-11-05)
##
## 규칙 (설계 문서 3.3, 4.1~4.3, 노션 구현 확정, CLAUDE.md):
## - 쓸 수 있는 조건: 살아 있음 → 손패에 있음 → SP → 대상 → 추가 비용 → 사용 조건
## - 대상: 근접 = 같은 행 맨 앞 적 자동 / 원거리 = 상대 편 지정 / 아군 = 아군(자신 포함) 지정 / 자신 = 사용자
## - 처리: SP 지불 → 추가 비용 지불(소모량 기록) → 범위 안 대상 → 효과 차례로 → 원래 카드를 버린 더미(또는 제외)로
## - 카드 대체: 손패에 있는 동안만. 사용 후 묘지·제외로 갈 때는 원래 카드.
## - 키워드 규칙(예: 소멸 → 사용 후 제외)이 사용 직후 카드를 옮길 수 있다.

## 이 카드 규칙이 속한 전투
var battle


func _init(owner_battle) -> void:
	battle = owner_battle



## u 가 손패의 card 를 볼 때·쓸 때 실제로 적용되는 카드.
## u 의 상태 중 replacements 에 card 가 있으면 대체 카드, 없으면 그대로.
## 대체는 손패에 있는 동안만이며, 사용 후 묘지·제외로 갈 때는 원래 카드로 간다. (사용자 확정)
## 그때그때 상태로 판단하므로, 상태가 사라지면 손패 안에서도 원래 카드로 돌아온다.
func effective_card(u: BattleUnit, card: CardData) -> CardData:
	for inst in u.statuses:
		if inst.data.replacements.has(card):
			return inst.data.replacements[card]
	return card


## u 가 card 를 쓸 수 있는지. "" 면 가능, 아니면 이유(UI 툴팁용):
## "dead" 죽음 / "not_in_hand" 손패에 없음 / "sp" SP 부족 / "melee_target" 같은 행에 적 없음 /
## "origin" 대상 지정이 잘못됨 / "cost" 추가 비용 부족 / "condition" 사용 조건 불만족
## origin: 원거리·아군 카드의 기준 유닛 (근접·자신 카드는 무시)
func can_play(u: BattleUnit, card: CardData, origin: BattleUnit = null) -> String:
	if not u.alive:
		return "dead"
	if not u.hand.has(card):
		return "not_in_hand"
	var eff := effective_card(u, card)
	if u.sp < eff.sp:
		return "sp"
	var target_reason := _origin_error(u, eff, origin)
	if target_reason != "":
		return target_reason
	var ctx := card_context(u, eff)
	for cost in eff.costs:
		if not cost.can_pay(ctx):
			return "cost"
	for cond in eff.conditions:
		if not cond.check(ctx):
			return "condition"
	return ""


## u 가 card 를 쓴다. 쓸 수 없으면 아무것도 바꾸지 않고 false.
## 순서: BEFORE_CARD_PLAYED → SP 지불 → 추가 비용 지불(소모량 기록) → 범위 안 대상 정하기 →
##       효과를 위에서부터 차례로 → 원래 카드를 버린 더미(또는 제외 더미)로 → AFTER_CARD_PLAYED
func play_card(u: BattleUnit, card: CardData, origin: BattleUnit = null) -> bool:
	if can_play(u, card, origin) != "":
		return false
	var eff := effective_card(u, card)
	var base := _resolve_origin(u, eff, origin)
	var ctx := card_context(u, eff)
	battle.events.emit(BattleEvent.make(BattleTypes.Event.BEFORE_CARD_PLAYED, u, base, 0, eff, eff))

	# 1. 비용: SP 는 카드의 sp 값, 추가 비용은 costs 순서대로
	u.sp -= eff.sp
	for cost in eff.costs:
		cost.pay(ctx)

	# 2. 대상: 기준 유닛 주변의 범위 (범위가 비면 기준 유닛 하나)
	ctx.targets = battle.area_targets(base, eff.area)

	# 3. 효과
	for effect in eff.effects:
		effect.apply(ctx)

	# 4. 카드 이동: 원래 카드가 간다 (대체 카드가 아니라).
	#    키워드 규칙(예: 소멸 → 사용 후 제외)이 먼저 카드를 옮길 기회를 갖고, 아무도 안 옮기면 버린 더미로.
	u.hand.erase(card)
	if not _run_after_use_rules(ctx, eff, card):
		u.discard.append(card)
	battle.events.emit(BattleEvent.make(BattleTypes.Event.AFTER_CARD_PLAYED, u, base, 0, eff, eff))
	return true


## 카드 사용용 실행 정보: 행위자 = 주인 = 사용자, 출처 = 실제로 쓰는 카드
func card_context(u: BattleUnit, eff: CardData) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.battle = battle
	ctx.actor = u
	ctx.owner = u
	ctx.card = eff
	ctx.source = eff
	return ctx


## 대상 지정이 잘못됐으면 이유, 맞으면 "".
func _origin_error(u: BattleUnit, eff: CardData, origin: BattleUnit) -> String:
	match eff.attack_type:
		"melee":
			return "" if battle.melee_target(u) else "melee_target"
		"ranged":
			return "" if origin and origin.alive and origin.side != u.side else "origin"
		"ally":
			return "" if origin and origin.alive and origin.side == u.side else "origin"
		"self":
			return ""
	return "origin"


## 공격 종류에 따른 기준 유닛: 근접 = 같은 행 맨 앞 적(자동), 원거리·아군 = 지정한 유닛, 자신 = 사용자
func _resolve_origin(u: BattleUnit, eff: CardData, origin: BattleUnit) -> BattleUnit:
	match eff.attack_type:
		"melee":
			return battle.melee_target(u)
		"self":
			return u
	return origin


## u 의 card 를 제외 더미로 보낸다 (이번 전투에서 다시 돌아오지 않음). CARD_EXILED 발행.
## 키워드 규칙(ExileAfterUseRule 등)이 부른다.
func exile_card(u: BattleUnit, card: CardData) -> void:
	u.exiled.append(card)
	battle.events.emit(BattleEvent.make(BattleTypes.Event.CARD_EXILED, u, null, 0, null, card))


## 실제로 쓴 카드(eff)에 붙은 키워드들의 규칙에 "사용 직후" 시점을 알린다.
## 규칙 중 하나라도 카드(원래 카드 card)를 옮겼으면 true. 한 번 옮겨지면 나머지 규칙은 묻지 않는다.
func _run_after_use_rules(ctx: EffectContext, eff: CardData, card: CardData) -> bool:
	for id in eff.keywords:
		var kw := _keyword(id)
		if kw == null:
			continue
		for rule in kw.rules:
			if rule and rule.after_use(ctx, card):
				return true
	return false


## 키워드 id → 키워드 데이터 (keyword_dir/<id>.tres). 없으면 null. 한 번 읽으면 캐시에 둔다.
func _keyword(id: String) -> KeywordData:
	if not battle.keyword_cache.has(id):
		var path: String = battle.keyword_dir.path_join(id + ".tres")
		battle.keyword_cache[id] = load(path) as KeywordData if ResourceLoader.exists(path) else null
	return battle.keyword_cache[id]
