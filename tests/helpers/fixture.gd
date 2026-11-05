class_name Fixture
extends RefCounted
# 테스트용 유닛·상태·보정 생성 도우미.

static func unit(side: int, cell: Vector2i, stats: Dictionary = {}) -> BattleUnit:
	var data := UnitData.new()
	for key in stats:
		data.set(key, stats[key])
	return BattleUnit.new(data, side, cell)

static func status(id: String, uses_stacks := true) -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.uses_stacks = uses_stacks
	return s

static func modifier(stat: int, kind: int, amount: float, scale: ValueSource = null) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat
	m.kind = kind
	m.amount = amount
	m.scale = scale
	return m
