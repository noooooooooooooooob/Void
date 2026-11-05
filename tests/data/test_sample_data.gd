extends GutTest
# 에디터로 만든 예시 데이터(.tres)가 올바르게 연결돼 있는지 확인.

func _hongyeon_with_passives() -> BattleUnit:
	var data: UnitData = load("res://entities/units/hongyeon.tres")
	var u := BattleUnit.new(data, BattleTypes.Side.ALLY, Vector2i.ZERO)
	for s in data.passives:
		u.add_status(s, 1, u)
	for e in data.equipment:
		for s in e.statuses:
			u.add_status(s, 1, u)
	return u


func test_hongyeon_loads_with_deck_passive_equipment():
	var data: UnitData = load("res://entities/units/hongyeon.tres")
	assert_eq(data.display_name, "홍연")
	assert_eq(data.deck.size(), 10)
	assert_eq(data.passives[0].id, "blood_lust")
	assert_eq(data.equipment[0].display_name, "시험용 검")
	assert_eq([data.crit_rate, data.crit_damage, data.aggro], [1, 175, 100])

func test_hongyeon_attack_with_sword_and_blood_lust():
	var u := _hongyeon_with_passives()
	assert_eq(u.get_stat(BattleTypes.Stat.ATTACK), 15)  # 10 + 검 5
	u.hp = u.data.max_hp / 2
	assert_eq(u.get_stat(BattleTypes.Stat.ATTACK), 17)  # floor(10 × 1.25) + 5

func test_exhaust_keyword_data_exiles_card_in_battle():
	# 실제 소멸 키워드(.tres)에 사용 후 제외 규칙이 들어 있고, 전투에서 카드가 제외 더미로 가는지
	var kw: KeywordData = load("res://cards/keywords/43vgq4le8g7ma4i9bc0u.tres")
	assert_eq(kw.name_ko, "소멸")
	assert_true(kw.rules.any(func(r): return r is ExileAfterUseRule))
	var me := Fixture.unit(BattleTypes.Side.ALLY, Vector2i(3, 0))
	var foe := Fixture.unit(BattleTypes.Side.ENEMY, Vector2i(3, 0))
	var units: Array[BattleUnit] = [me, foe]
	var battle := Battle.new(units)
	var card := CardData.new()
	card.attack_type = "melee"
	card.keywords = PackedStringArray(["43vgq4le8g7ma4i9bc0u"])
	me.hand.append(card)
	me.sp = 3
	assert_true(battle.play_card(me, card))
	assert_true(me.exiled.has(card))


# --- 에디터에서 만든 상태 데이터 (statuses/data) ---

func _status_by_id(id: String) -> StatusData:
	# 파일 이름이 아니라 Id 로 찾는다 (파일 이름을 바꿔도 테스트가 깨지지 않게)
	for f in DirAccess.get_files_at("res://statuses/data"):
		if f.get_extension() == "tres":
			var s := load("res://statuses/data".path_join(f)) as StatusData
			if s and s.id == id:
				return s
	return null

func _two_unit_battle() -> Array:
	var hero := Fixture.unit(BattleTypes.Side.ALLY, Vector2i(3, 0))
	var foe := Fixture.unit(BattleTypes.Side.ENEMY, Vector2i(3, 0))
	var units: Array[BattleUnit] = [hero, foe]
	var battle := Battle.new(units, 1)
	return [battle, hero, foe]

func test_status_data_files_exist():
	for id in ["bleed", "blood_armor", "blood_drop"]:
		assert_not_null(_status_by_id(id), id)

func test_bleed_data_ticks_on_draw_phase_and_credits_no_one():
	var r := _two_unit_battle()
	var battle: Battle = r[0]
	var hero: BattleUnit = r[1]
	var foe: BattleUnit = r[2]
	battle.start_battle()
	hero.stamina = 50
	battle.apply_status(foe, _status_by_id("bleed"), 4, hero)
	battle.begin_turn(foe)
	assert_eq(foe.hp, 96)
	assert_eq(hero.stamina, 50)

func test_blood_armor_data_blocks_on_turn_end():
	var r := _two_unit_battle()
	var battle: Battle = r[0]
	var hero: BattleUnit = r[1]
	battle.start_battle()
	battle.apply_status(hero, _status_by_id("blood_armor"), 6, hero)
	battle.begin_turn(hero)
	battle.end_turn(hero)
	assert_eq(hero.block, 6)

func test_blood_drop_data_counts_enemy_bleed_and_survives_consumption():
	var r := _two_unit_battle()
	var battle: Battle = r[0]
	var hero: BattleUnit = r[1]
	var foe: BattleUnit = r[2]
	hero.data.passives.assign([_status_by_id("blood_drop")])
	battle.start_battle()
	battle.apply_status(foe, _status_by_id("bleed"), 4, hero)
	battle.begin_turn(foe)
	assert_eq(hero.stacks_of("blood_drop"), 4)
	battle.change_stacks(hero, "blood_drop", -4)  # 비용으로 전부 소모한 것처럼
	assert_not_null(hero.get_status("blood_drop"))  # 패시브라 0 이 돼도 남음

