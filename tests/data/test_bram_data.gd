extends GutTest

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event
const UNIT := "res://entities/units/bram_welburn.tres"

var bram: BattleUnit
var ally: BattleUnit
var foe: BattleUnit
var foe2: BattleUnit
var battle: Battle

func before_each():
	# 치명 1% 가 수치 검사를 흔들지 않게 끈다. 공격·방어는 기본값 10.
	var data: UnitData = load(UNIT).duplicate()
	data.crit_rate = 0
	bram = BattleUnit.new(data, A, Vector2i(2, 1))
	ally = Fixture.unit(A, Vector2i(2, 0))
	foe = Fixture.unit(E, Vector2i(3, 1))
	foe2 = Fixture.unit(E, Vector2i(3, 0))
	var units: Array[BattleUnit] = [bram, ally, foe, foe2]
	battle = Battle.new(units, 7)

func _card(ko: String, upgraded := false) -> CardData:
	for c in bram.data.deck:
		if c.name_ko == ko:
			return c.upgrades[0] if upgraded else c
	fail_test("카드 없음: " + ko)
	return null

func _play(ko: String, upgraded := false, origin: BattleUnit = null) -> bool:
	var c := _card(ko, upgraded)
	bram.hand.append(c)
	bram.sp = 99
	return battle.play_card(bram, c, origin)

func _turn_start() -> void:
	battle.events.emit(BattleEvent.make(Ev.TURN_START, bram))


func test_unit_matches_notion_and_has_full_deck():
	var data: UnitData = load(UNIT)
	assert_eq(data.display_name, "브람 웰번")
	assert_eq([data.speed_min, data.speed_max], [1, 10])
	assert_eq([data.crit_rate, data.crit_damage, data.aggro], [1, 175, 100])
	assert_eq(data.deck.size(), 10)

func test_every_card_and_upgrade_has_effects():
	for c in bram.data.deck:
		assert_false(c.effects.is_empty(), c.name_ko)
		assert_false(c.upgrades[0].effects.is_empty(), c.upgrades[0].name_ko)

func test_dol_jumeok():
	assert_true(_play("돌주먹"))
	assert_eq([foe.hp, bram.block], [92, 5])

func test_dol_jumeok_upgraded():
	assert_true(_play("돌주먹", true))
	assert_eq([foe.hp, bram.block], [92, 8])

func test_rock_arm_block():
	assert_true(_play("바위 팔 막기"))
	assert_eq(bram.block, 15)

func test_rock_arm_block_upgraded():
	assert_true(_play("바위 팔 막기", true))
	assert_eq(bram.block, 20)

func test_callus():
	bram.block = 20
	assert_true(_play("굳은살"))
	assert_eq(bram.block, 30)

func test_callus_upgraded():
	bram.block = 20
	assert_true(_play("굳은살", true))
	assert_eq(bram.block, 34)

func test_work_crew_shields_neighbours():
	assert_true(_play("작업조", false, bram))
	assert_eq([bram.block, ally.block], [8, 8])

func test_work_crew_upgraded():
	assert_true(_play("작업조", true, bram))
	assert_eq([bram.block, ally.block], [12, 12])

func test_hook_damages_and_pulls():
	foe.cell = Vector2i(0, 2)
	assert_true(_play("갈고리 걸기", false, foe))
	assert_eq([foe.hp, foe.cell], [94, Vector2i(3, 1)])

func test_hook_upgraded():
	foe.cell = Vector2i(0, 2)
	assert_true(_play("갈고리 걸기", true, foe))
	assert_eq([foe.hp, foe.cell], [91, Vector2i(3, 1)])

func test_split_removes_block_before_damage():
	foe.block = 5
	assert_true(_play("갈라치기"))
	assert_eq([foe.block, foe.hp], [0, 88])

func test_split_upgraded():
	foe.block = 5
	assert_true(_play("갈라치기", true))
	assert_eq([foe.block, foe.hp], [0, 84])

func test_taunt_card_applies_status_and_block():
	assert_true(_play("도발"))
	assert_not_null(bram.get_status("taunt"))
	assert_eq(bram.block, 5)
	assert_eq(battle.melee_target(foe2), bram)

func test_taunt_card_upgraded():
	assert_true(_play("도발", true))
	assert_eq(bram.block, 10)

func test_taunt_ends_on_brams_next_turn():
	assert_true(_play("도발"))
	_turn_start()
	assert_null(bram.get_status("taunt"))

func test_guard_card_redirects():
	assert_true(_play("대신 맞기", false, ally))
	battle.apply_damage(foe, ally, 30)
	assert_eq([ally.hp, bram.hp], [100, 70])

func test_guard_card_upgraded_reduces_by_30_percent():
	assert_true(_play("대신 맞기", true, ally))
	battle.apply_damage(foe, ally, 30)
	assert_eq([ally.hp, bram.hp], [100, 79])

func test_guard_ends_on_brams_next_turn():
	assert_true(_play("대신 맞기", false, ally))
	_turn_start()
	battle.apply_damage(foe, ally, 30)
	assert_eq([ally.hp, bram.hp], [70, 100])

func test_stone_throw_needs_block():
	var c := _card("돌 던지기")
	bram.hand.append(c)
	bram.sp = 99
	assert_eq(battle.can_play(bram, c, foe), "cost")

func test_stone_throw():
	bram.block = 10
	assert_true(_play("돌 던지기", false, foe))
	assert_eq([bram.block, foe.hp], [0, 90])

func test_stone_throw_upgraded():
	bram.block = 10
	assert_true(_play("돌 던지기", true, foe))
	assert_eq(foe.hp, 88)

func test_stone_throw_cannot_crit():
	bram.data.crit_rate = 100
	bram.block = 10
	assert_true(_play("돌 던지기", false, foe))
	assert_eq(foe.hp, 90)

func test_slam_hits_area_with_consumed_block():
	bram.block = 10
	assert_true(_play("내려찍기"))
	assert_eq([bram.block, foe.hp, foe2.hp], [0, 85, 85])

func test_slam_upgraded():
	bram.block = 10
	assert_true(_play("내려찍기", true))
	assert_eq([foe.hp, foe2.hp], [80, 80])


# --- 전투 진행 (BattleSession): 화면이 쓰는 경로 그대로 ---

func _enemy_data() -> UnitData:
	var d := DamageEffect.new()
	var strike := CardData.new()
	strike.attack_type = "melee"
	strike.sp = 1
	strike.effects.assign([d])
	var u := UnitData.new()
	u.display_name = "적"
	u.deck.assign([strike, strike, strike])
	return u

func _session(battle_seed: int) -> BattleSession:
	var data := BattleData.new()
	var ally_slot := BattleSlot.new()
	ally_slot.unit = load(UNIT)
	ally_slot.cell = Vector2i(3, 1)
	var enemy_slot := BattleSlot.new()
	enemy_slot.unit = _enemy_data()
	enemy_slot.cell = Vector2i(3, 1)
	data.allies.assign([ally_slot])
	data.enemies.assign([enemy_slot])
	var s := BattleSession.new(data, [], battle_seed)
	s.start()
	return s

func _to_player_turn(s: BattleSession) -> void:
	while s.is_enemy_turn() and not s.is_finished():
		s.step_enemy()

func _deck_card(s: BattleSession, ko: String) -> CardData:
	for c in s.active.data.deck:
		if c.name_ko == ko:
			return c
	return null

func test_stone_throw_preview_shows_damage_from_current_block():
	var s := _session(1)
	_to_player_turn(s)
	s.active.block = 10
	assert_eq(s.card_preview(_deck_card(s, "돌 던지기")), 10)

func test_slam_preview_scales_current_block():
	var s := _session(1)
	_to_player_turn(s)
	s.active.block = 10
	assert_eq(s.card_preview(_deck_card(s, "내려찍기")), 15)

func test_preview_does_not_consume_block():
	var s := _session(1)
	_to_player_turn(s)
	s.active.block = 10
	s.card_preview(_deck_card(s, "돌 던지기"))
	assert_eq(s.active.block, 10)

func test_preview_is_zero_without_block():
	var s := _session(1)
	_to_player_turn(s)
	s.active.block = 0
	assert_eq(s.card_preview(_deck_card(s, "돌 던지기")), 0)

func test_whole_battle_finishes_playing_every_usable_card():
	for battle_seed in 5:
		var s := _session(battle_seed)
		var played := {}
		for step in 300:
			if s.is_finished():
				break
			_to_player_turn(s)
			if s.is_finished():
				break
			for card in s.active.hand.duplicate():
				var targets := s.targets_for(card)
				if not targets.is_empty() and s.play(card, targets[0]):
					played[card.name_ko] = true
				if s.is_finished():
					break
			if not s.is_finished():
				s.end_player_turn()
		assert_true(s.is_finished(), "seed %d" % battle_seed)
		assert_gt(played.size(), 3, "seed %d 에서 쓴 카드 %s" % [battle_seed, played.keys()])
