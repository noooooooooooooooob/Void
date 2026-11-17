extends GutTest

func _line(type: int, kind: int, amount: int) -> ConsumableLine:
	var l := ConsumableLine.new()
	l.type = type
	l.kind = kind
	l.amount = amount
	return l

func test_flat_amount_ignores_max():
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.FLAT, 30).amount_for(100), 30)

func test_percent_amount_is_floored_share_of_max():
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.PERCENT, 25).amount_for(90), 22)

func test_amount_is_at_least_one():
	assert_eq(_line(ConsumableLine.Type.HEAL_SP, ConsumableLine.Kind.PERCENT, 10).amount_for(3), 1)

func test_zero_amount_is_zero():
	assert_eq(_line(ConsumableLine.Type.HEAL_SP, ConsumableLine.Kind.FLAT, 0).amount_for(3), 0)
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.PERCENT, 0).amount_for(100), 0)

func test_negative_flat_amount_keeps_sign():
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.FLAT, -20).amount_for(100), -20)

func test_negative_percent_is_floored_magnitude_with_sign():
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.PERCENT, -20).amount_for(99), -19)

func test_negative_amount_is_at_most_minus_one():
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.PERCENT, -1).amount_for(10), -1)

func test_describe_negative():
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.FLAT, -20).describe(), "HP 회복 -20")
	assert_eq(_line(ConsumableLine.Type.HEAL_SP, ConsumableLine.Kind.PERCENT, -10).describe(), "SP 회복 -10%")

func test_new_item_targets_allies_single():
	var item := ConsumableData.new()
	assert_eq(item.target, ConsumableData.Target.ALLY)
	assert_true(item.area.is_empty())

func test_allows_side():
	var item := ConsumableData.new()
	assert_true(item.allows_side(BattleTypes.Side.ALLY))
	assert_false(item.allows_side(BattleTypes.Side.ENEMY))
	item.target = ConsumableData.Target.ENEMY
	assert_false(item.allows_side(BattleTypes.Side.ALLY))
	assert_true(item.allows_side(BattleTypes.Side.ENEMY))
	item.target = ConsumableData.Target.BOTH
	assert_true(item.allows_side(BattleTypes.Side.ALLY))
	assert_true(item.allows_side(BattleTypes.Side.ENEMY))

func test_describe():
	assert_eq(_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.FLAT, 30).describe(), "HP 회복 +30")
	assert_eq(_line(ConsumableLine.Type.HEAL_SP, ConsumableLine.Kind.PERCENT, 20).describe(), "SP 회복 +20%")

func test_item_describes_all_lines():
	var item := ConsumableData.new()
	item.lines.assign([
		_line(ConsumableLine.Type.HEAL_HP, ConsumableLine.Kind.FLAT, 30),
		_line(ConsumableLine.Type.HEAL_SP, ConsumableLine.Kind.FLAT, 2)])
	assert_eq(item.describe_lines(), "HP 회복 +30\nSP 회복 +2")
