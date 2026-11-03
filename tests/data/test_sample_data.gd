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
