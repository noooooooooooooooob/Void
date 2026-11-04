class_name Battle
extends RefCounted
## 전투 하나. 유닛·격자·이벤트·난수를 갖고, 피해·회복·방어도·상태 처리 규칙을 실행한다.
## 화면(씬) 없이 동작하는 순수 로직이라 테스트에서 바로 만들어 쓸 수 있다.
##
## 이 파일은 구현 계획의 Task 4~10 에 걸쳐 섹션별로 채워진다.
##   Task 4: 격자, 피해, 회복, 방어도, 상태 API
##   Task 6: 카드 사용 (조건, 비용, 대상, 대체, 소멸→제외)
##   Task 7: 덱과 턴 진행 (행동마다 속도, 즉시 재정렬, 드로우, 방어도 초기화, 전투 종료) / Task 8: 상태 트리거 / Task 9: 이동 / Task 10: 적 행동
## 규칙 출처: docs/superpowers/specs/2026-11-03-card-effect-system-design.md (3장, 4장)
##
## 격자 좌표: 편마다 따로인 격자의 Vector2i(열, 행). 열 0 = 뒤, 열 (그 편의 열 수 - 1) = 맨 앞(상대 쪽).
## 격자 크기는 전투마다 정한다. 행 수는 양쪽 공통, 열 수는 편마다 다를 수 있다. (기획 결정)
## 아군·적 모두 같은 규칙이라, 광역 오프셋의 +x 는 항상 "앞쪽"이다.
## (화면에서 아군은 왼쪽·적은 오른쪽에 그리는 것은 UI 의 몫)

## 전투에 참여한 모든 유닛 (죽은 유닛도 남아 있고 alive 로 구분한다)
var units: Array[BattleUnit] = []
## 이 전투의 이벤트 관리자. 상태·패시브·장비·화면이 여기에 구독한다.
var events := BattleEvents.new()
## 이 전투의 모든 난수(치명타, 섞기, 적 선택)는 여기서 뽑는다. 시드를 주면 결과가 재현된다.
var rng := RandomNumberGenerator.new()
## 스태미너가 0이 됐을 때 붙일 상태 (기절·탈진 등, 기획 미정이라 비워 둘 수 있음)
var stamina_break_status: StatusData = null
## 격자 행 수 (양쪽 편 공통)
var grid_rows: int = BattleTypes.DEFAULT_GRID_ROWS
## 이번 라운드의 행동 순서 (속도 순, 행동 단위)
var turn_order := TurnOrder.new()
## 지금 차례인 유닛 (next_turn 이 정한다)
var current: BattleUnit = null
## 전투 종료 이벤트를 이미 냈는지 (한 번만 내기 위해)
var _ended := false
## 키워드 데이터 폴더. 카드의 키워드 id 로 키워드의 규칙 부품(예: 소멸 → 사용 후 제외)을 찾는다.
var keyword_dir := "res://cards/keywords"
## 키워드 id → KeywordData. 한 번 읽은 키워드를 담아 둔다 (테스트에서는 직접 채워 넣는다).
var keyword_cache: Dictionary = {}
## 편 → 그 편 격자의 열 수
var grid_cols := {
	BattleTypes.Side.ALLY: BattleTypes.DEFAULT_GRID_COLS,
	BattleTypes.Side.ENEMY: BattleTypes.DEFAULT_GRID_COLS,
}


## units: 참여 유닛들. 배열 순서가 initial_index 가 된다 (속도가 같을 때 순서 기준).
## battle_seed: 난수 시드. 0 이어도 고정 시드로 동작한다(테스트 재현용).
## rows / ally_cols / enemy_cols: 이 전투의 격자 크기. 생략하면 기본 3행 × 4열.
## (전투 데이터에서 크기를 정해 넘겨 준다 — 전투 데이터 리소스는 나중에 만든다)
func _init(battle_units: Array[BattleUnit], battle_seed: int = 0,
		rows: int = BattleTypes.DEFAULT_GRID_ROWS,
		ally_cols: int = BattleTypes.DEFAULT_GRID_COLS,
		enemy_cols: int = BattleTypes.DEFAULT_GRID_COLS) -> void:
	units = battle_units
	rng.seed = battle_seed
	grid_rows = rows
	grid_cols[BattleTypes.Side.ALLY] = ally_cols
	grid_cols[BattleTypes.Side.ENEMY] = enemy_cols
	for i in units.size():
		units[i].battle = self
		units[i].initial_index = i


# --- 전투·라운드·차례 진행 ---
# 규칙 (설계 문서 3.1, 사용자 결정 2026-11-04):
#   라운드 시작 → 방어도 초기화 → 행동마다 속도 굴려 줄 세우기
#   차례(행동 하나): TURN_START → SP 가득 → 이동력 = 이동속도 → 드로우 → DRAW_PHASE → STANDBY_PHASE
#                    → (행동: 카드 사용·이동) → END_PHASE → 손패 전부 버림 → TURN_END
#   한쪽이 전멸하면 전투 종료

## 전투를 시작한다: 각 유닛의 덱을 데이터에서 복사해 섞고, 손패·버린 더미·제외 더미를 비운 뒤 첫 라운드를 연다.
func start_battle() -> void:
	for u in units:
		u.deck = u.data.deck.duplicate()
		_shuffle(u.deck)
		u.hand.clear()
		u.discard.clear()
		u.exiled.clear()
	events.emit(BattleEvent.make(BattleTypes.Event.BATTLE_START))
	start_round()


## 새 라운드를 연다.
## 1. 방어도 초기화: "방어도 유지" 상태(keeps_block)가 없는 유닛만. 방어도가 있었으면 BLOCK_RESET 발행.
## 2. ROUND_START 발행 → 3. 살아 있는 유닛들이 행동마다 속도를 굴려 행동 순서를 정한다.
func start_round() -> void:
	for u in units:
		if u.alive and u.block > 0 and not _keeps_block(u):
			u.block = 0
			events.emit(BattleEvent.make(BattleTypes.Event.BLOCK_RESET, null, u))
	events.emit(BattleEvent.make(BattleTypes.Event.ROUND_START))
	turn_order.start_round(living_all(), rng)


## 다음 차례(행동 하나)의 유닛을 정해서 돌려준다. 차례 진행(begin_turn)은 부르는 쪽이 한다.
## 라운드의 행동을 다 썼으면 ROUND_END → 새 라운드. 전투가 끝났거나 행동할 유닛이 없으면 null.
## 행동 횟수가 2 인 유닛은 한 라운드에 두 번 반환된다 (행동 하나 = 온전한 차례 하나).
func next_turn() -> BattleUnit:
	if winner() != -1:
		return null
	if turn_order.is_round_over():
		events.emit(BattleEvent.make(BattleTypes.Event.ROUND_END))
		start_round()
	var entry := turn_order.pop_next()
	current = entry.get("unit") if not entry.is_empty() else null
	return current


## 차례를 시작한다: TURN_START → SP 가득 회복 → 이동력 = 이동속도 → 드로우 → DRAW_PHASE → STANDBY_PHASE.
## 드로우: 아군은 draw_count 장, 적은 1장. (출혈 같은 DRAW_PHASE 효과로 죽을 수 있다)
## 반환: 차례를 이어갈 수 있으면 true (유닛이 살아 있음). false 면 부르는 쪽이 이 차례를 건너뛴다.
func begin_turn(u: BattleUnit) -> bool:
	events.emit(BattleEvent.make(BattleTypes.Event.TURN_START, u))
	u.sp = u.get_stat(BattleTypes.Stat.SP)
	u.move_left = u.get_stat(BattleTypes.Stat.MOVE)
	draw(u, u.data.draw_count if u.side == BattleTypes.Side.ALLY else 1)
	events.emit(BattleEvent.make(BattleTypes.Event.DRAW_PHASE, u))
	if u.alive:
		events.emit(BattleEvent.make(BattleTypes.Event.STANDBY_PHASE, u))
	return u.alive


## 차례를 끝낸다: END_PHASE → 손패를 전부 버린다(장마다 CARD_DISCARDED) → TURN_END.
func end_turn(u: BattleUnit) -> void:
	events.emit(BattleEvent.make(BattleTypes.Event.END_PHASE, u))
	var hand := u.hand.duplicate()
	u.hand.clear()
	for c in hand:
		u.discard.append(c)
		events.emit(BattleEvent.make(BattleTypes.Event.CARD_DISCARDED, u, null, 0, null, c))
	events.emit(BattleEvent.make(BattleTypes.Event.TURN_END, u))


## 이긴 편 (BattleTypes.Side). 아직 양쪽 다 살아 있으면 −1.
func winner() -> int:
	var allies := living(BattleTypes.Side.ALLY).size()
	var enemies := living(BattleTypes.Side.ENEMY).size()
	if allies > 0 and enemies == 0:
		return BattleTypes.Side.ALLY
	if enemies > 0 and allies == 0:
		return BattleTypes.Side.ENEMY
	return -1


## 살아 있는 모든 유닛 (전투 참여 순서)
func living_all() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.alive:
			out.append(u)
	return out


# --- 덱 ---

## u 가 카드를 n 장 뽑는다. 장마다 CARD_DRAWN 발행.
## reshuffle: 덱이 비었을 때 버린 더미를 섞어 덱으로 만들지 (제외 더미는 절대 쓰지 않는다).
##   - 드로우 페이즈(차례 시작): true → 섞어서 계속 뽑는다
##   - 행동 중 드로우(카드 효과 등): false → 덱이 비면 더 못 뽑는다 (사용자 결정 2026-11-04)
## 더 뽑을 카드가 없으면 거기서 멈춘다.
func draw(u: BattleUnit, n: int, reshuffle: bool = true) -> void:
	for i in n:
		if u.deck.is_empty():
			if not reshuffle or u.discard.is_empty():
				return
			u.deck = u.discard.duplicate()
			u.discard.clear()
			_shuffle(u.deck)
		var c: CardData = u.deck.pop_front()
		u.hand.append(c)
		events.emit(BattleEvent.make(BattleTypes.Event.CARD_DRAWN, u, null, 0, null, c))


## 배열을 전투의 난수로 섞는다 (Fisher–Yates). 같은 시드면 같은 결과.
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## u 에게 "방어도 유지" 상태가 있는지
func _keeps_block(u: BattleUnit) -> bool:
	for inst in u.statuses:
		if inst.data.keeps_block:
			return true
	return false


# --- 격자 ---

## 그 편 격자의 열 수
func cols_of(side: int) -> int:
	return grid_cols[side]


## 칸이 그 편 격자 안인지 (열 0 ~ 열 수-1, 행 0 ~ 행 수-1)
func in_grid(side: int, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols_of(side) and cell.y >= 0 and cell.y < grid_rows


## 그 편의 그 칸에 있는 살아 있는 유닛. 없으면 null.
func unit_at(side: int, cell: Vector2i) -> BattleUnit:
	for u in units:
		if u.alive and u.side == side and u.cell == cell:
			return u
	return null


## 그 편의 살아 있는 유닛들 (전투 참여 순서대로)
func living(side: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.alive and u.side == side:
			out.append(u)
	return out


## u 와 같은 편의 살아 있는 유닛들 (u 자신 포함)
func allies_of(u: BattleUnit) -> Array[BattleUnit]:
	return living(u.side)


## u 의 상대 편 살아 있는 유닛들
func enemies_of(u: BattleUnit) -> Array[BattleUnit]:
	return living(_other_side(u.side))


## 근접 공격 대상: u 와 같은 행에서 상대 격자의 맨 앞 열부터 찾아 처음 만나는 적.
## 그 행에 적이 없으면 null (= 근접 카드를 쓸 수 없음). (노션 구현 확정)
func melee_target(u: BattleUnit) -> BattleUnit:
	var enemy_side := _other_side(u.side)
	for col in range(cols_of(enemy_side) - 1, -1, -1):
		var hit := unit_at(enemy_side, Vector2i(col, u.cell.y))
		if hit:
			return hit
	return null


## 광역 대상: 기준 유닛(origin)의 칸에 오프셋들을 더한 칸의 유닛들.
## 기준 유닛이 있는 편의 격자 안에서만 찾고, 격자 밖·빈 칸은 무시한다. 범위가 비어 있으면 단일 대상.
func area_targets(origin: BattleUnit, area: Array[Vector2i]) -> Array[BattleUnit]:
	if area.is_empty():
		return [origin]
	var out: Array[BattleUnit] = []
	for offset in area:
		var cell := origin.cell + offset
		if not in_grid(origin.side, cell):
			continue
		var u := unit_at(origin.side, cell)
		if u and not out.has(u):
			out.append(u)
	return out


# --- 카드 ---
# 카드 사용 규칙 (설계 문서 3.3, 4.1~4.3, 노션 구현 확정)

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
	var ctx := _card_context(u, eff)
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
	var ctx := _card_context(u, eff)
	events.emit(BattleEvent.make(BattleTypes.Event.BEFORE_CARD_PLAYED, u, base, 0, eff, eff))

	# 1. 비용: SP 는 카드의 sp 값, 추가 비용은 costs 순서대로
	u.sp -= eff.sp
	for cost in eff.costs:
		cost.pay(ctx)

	# 2. 대상: 기준 유닛 주변의 범위 (범위가 비면 기준 유닛 하나)
	ctx.targets = area_targets(base, eff.area)

	# 3. 효과
	for effect in eff.effects:
		effect.apply(ctx)

	# 4. 카드 이동: 원래 카드가 간다 (대체 카드가 아니라).
	#    키워드 규칙(예: 소멸 → 사용 후 제외)이 먼저 카드를 옮길 기회를 갖고, 아무도 안 옮기면 버린 더미로.
	u.hand.erase(card)
	if not _run_after_use_rules(ctx, eff, card):
		u.discard.append(card)
	events.emit(BattleEvent.make(BattleTypes.Event.AFTER_CARD_PLAYED, u, base, 0, eff, eff))
	return true


## 카드 사용용 실행 정보: 행위자 = 주인 = 사용자, 출처 = 실제로 쓰는 카드
func _card_context(u: BattleUnit, eff: CardData) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.battle = self
	ctx.actor = u
	ctx.owner = u
	ctx.card = eff
	ctx.source = eff
	return ctx


## 대상 지정이 잘못됐으면 이유, 맞으면 "".
func _origin_error(u: BattleUnit, eff: CardData, origin: BattleUnit) -> String:
	match eff.attack_type:
		"melee":
			return "" if melee_target(u) else "melee_target"
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
			return melee_target(u)
		"self":
			return u
	return origin


## u 의 card 를 제외 더미로 보낸다 (이번 전투에서 다시 돌아오지 않음). CARD_EXILED 발행.
## 키워드 규칙(ExileAfterUseRule 등)이 부른다.
func exile_card(u: BattleUnit, card: CardData) -> void:
	u.exiled.append(card)
	events.emit(BattleEvent.make(BattleTypes.Event.CARD_EXILED, u, null, 0, null, card))


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
	if not keyword_cache.has(id):
		var path := keyword_dir.path_join(id + ".tres")
		keyword_cache[id] = load(path) as KeywordData if ResourceLoader.exists(path) else null
	return keyword_cache[id]


# --- 피해·회복·방어도 ---

## actor 가 target 에게 amount 만큼 피해를 준다. (설계 문서 3.5~3.6, 기획 결정)
## actor 는 null 일 수 있다 (예: 출혈을 건 유닛이 이미 죽음). source 는 이벤트에 담길 출처.
## 순서: 방어도 → HP / 대상 스태미너 감소 / 준 쪽 스태미너 회복 / 이벤트 / 사망
func apply_damage(actor: BattleUnit, target: BattleUnit, amount: int, source = null) -> void:
	if amount <= 0 or target == null or not target.alive:
		return

	# 1. 방어도가 먼저 막고, 남은 만큼 HP 가 깎인다.
	var blocked := mini(target.block, amount)
	target.block -= blocked
	target.hp -= amount - blocked

	# 2. 대상 스태미너는 막힌 양까지 포함한 전체 피해만큼 깎인다.
	#    0 보다 컸다가 0 이 되는 순간에만 "스태미너 0" 처리를 한다 (이미 0 이면 다시 안 함).
	var stamina_before := target.stamina
	target.stamina = maxi(0, target.stamina - amount)
	if stamina_before > 0 and target.stamina == 0:
		events.emit(BattleEvent.make(BattleTypes.Event.STAMINA_BROKEN, actor, target, 0, source))
		if stamina_break_status:
			apply_status(target, stamina_break_status, 1, actor)

	# 3. 피해를 준 쪽은 준 피해의 절반(내림)만큼 스태미너를 회복한다. 최대치를 넘지 않는다.
	if actor != null and actor.alive:
		var max_stamina := actor.get_stat(BattleTypes.Stat.STAMINA)
		actor.stamina = mini(max_stamina, actor.stamina + amount / 2)

	# 4. 이벤트: 준 쪽 기준(DEALT) → 받은 쪽 기준(TAKEN) 순서.
	events.emit(BattleEvent.make(BattleTypes.Event.DAMAGE_DEALT, actor, target, amount, source))
	events.emit(BattleEvent.make(BattleTypes.Event.DAMAGE_TAKEN, actor, target, amount, source))

	# 5. 사망
	if target.alive and target.hp <= 0:
		target.hp = 0
		_on_unit_died(target)


## target 의 HP 를 amount 만큼 회복한다. 최대 HP 를 넘지 않는다.
## HEALED 이벤트의 amount 는 실제로 회복한 양이다.
func heal(target: BattleUnit, amount: int, source = null) -> void:
	if amount <= 0 or target == null or not target.alive:
		return
	var max_hp := target.get_stat(BattleTypes.Stat.HP)
	var gained := mini(amount, max_hp - target.hp)
	target.hp += gained
	events.emit(BattleEvent.make(BattleTypes.Event.HEALED, null, target, gained, source))


## target 이 방어도(쉴드)를 amount 만큼 얻는다. 방어도는 라운드 시작 시 초기화된다(Task 7).
func add_block(target: BattleUnit, amount: int, source = null) -> void:
	if amount <= 0 or target == null or not target.alive:
		return
	target.block += amount
	events.emit(BattleEvent.make(BattleTypes.Event.BLOCK_GAINED, null, target, amount, source))


# --- 상태 ---
# 상태를 붙이고 떼는 것은 항상 이 함수들을 통한다.
# (이벤트 발행, 트리거 구독(Task 8), 행동 순서 갱신(Task 7)을 한곳에서 처리하기 위해)

## target 에 상태를 붙인다. 이미 있으면 수치를 합치고 건 유닛을 갱신한다. STATUS_APPLIED 발행.
func apply_status(target: BattleUnit, status: StatusData, stacks: int, applier: BattleUnit) -> StatusInstance:
	var inst := target.add_status(status, stacks, applier)
	events.emit(BattleEvent.make(BattleTypes.Event.STATUS_APPLIED, applier, target, stacks, status))
	_refresh_speeds()
	return inst


## target 의 상태 수치를 delta 만큼 바꾼다. 그 결과 사라지면 STATUS_REMOVED 발행.
func change_stacks(target: BattleUnit, id: String, delta: int) -> void:
	var inst := target.get_status(id)
	if inst == null:
		return
	if target.change_stacks(id, delta):
		_on_status_removed(target, inst)
	_refresh_speeds()


## target 의 상태를 뗀다. 있었으면 STATUS_REMOVED 발행.
func remove_status(target: BattleUnit, id: String) -> void:
	var inst := target.remove_status(id)
	if inst:
		_on_status_removed(target, inst)


## 상태가 사라진 뒤 공통 처리. (Task 8 에서 트리거 구독 해제를 여기에 더한다)
func _on_status_removed(target: BattleUnit, inst: StatusInstance) -> void:
	events.emit(BattleEvent.make(BattleTypes.Event.STATUS_REMOVED, null, target, 0, inst.data))
	_refresh_speeds()


## 상태 변화로 속도가 바뀌었으면 남은 행동 순서를 즉시 다시 정렬하고 TURN_ORDER_CHANGED 발행.
func _refresh_speeds() -> void:
	if turn_order.refresh():
		events.emit(BattleEvent.make(BattleTypes.Event.TURN_ORDER_CHANGED))


# --- 사망 ---

## 유닛이 죽었을 때 공통 처리: 남은 행동을 순서에서 빼고, 한쪽이 전멸했으면 전투 종료(한 번만).
func _on_unit_died(u: BattleUnit) -> void:
	u.alive = false
	turn_order.remove(u)
	events.emit(BattleEvent.make(BattleTypes.Event.UNIT_DIED, null, u))
	var w := winner()
	if w != -1 and not _ended:
		_ended = true
		events.emit(BattleEvent.make(BattleTypes.Event.BATTLE_END, null, null, w))


# --- 내부 도우미 ---

## 상대 편
func _other_side(side: int) -> int:
	return BattleTypes.Side.ENEMY if side == BattleTypes.Side.ALLY else BattleTypes.Side.ALLY
