extends GutTest

var owner_unit: BattleUnit
var ctx: EffectContext

func before_each():
	owner_unit = Fixture.unit(BattleTypes.Side.ALLY, Vector2i.ZERO, {"max_hp": 100})
	ctx = EffectContext.new()
	ctx.owner = owner_unit
	ctx.actor = owner_unit


func test_fixed():
	assert_eq(FixedValue.new(2).evaluate(ctx), 2.0)

func test_stack_count_of_owner():
	owner_unit.add_status(Fixture.status("bleed"), 4, owner_unit)
	assert_eq(StackCountValue.new("bleed").evaluate(ctx), 4.0)
	assert_eq(StackCountValue.new("none").evaluate(ctx), 0.0)

func test_stack_count_of_actor():
	var other := Fixture.unit(BattleTypes.Side.ENEMY, Vector2i.ZERO)
	other.add_status(Fixture.status("blood"), 2, other)
	ctx.actor = other
	assert_eq(StackCountValue.new("blood", BattleTypes.Who.ACTOR).evaluate(ctx), 2.0)

func test_consumed():
	ctx.values["consumed:blood"] = 5
	assert_eq(ConsumedValue.new("blood").evaluate(ctx), 5.0)
	assert_eq(ConsumedValue.new("other").evaluate(ctx), 0.0)

func test_event_amount():
	assert_eq(EventAmountValue.new().evaluate(ctx), 0.0)
	ctx.event = BattleEvent.make(BattleTypes.Event.DAMAGE_DEALT, null, null, 30)
	assert_eq(EventAmountValue.new().evaluate(ctx), 30.0)

func test_missing_hp_percent():
	owner_unit.hp = 25
	assert_eq(MissingHpPercentValue.new().evaluate(ctx), 75.0)
