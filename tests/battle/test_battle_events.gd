extends GutTest

var events: BattleEvents
var log := []

func before_each():
	events = BattleEvents.new()
	log = []

func _logger(name: String) -> Callable:
	return func(_e): log.append(name)

func _emit(type := BattleTypes.Event.TURN_START) -> void:
	events.emit(BattleEvent.make(type))


func test_handlers_run_in_subscription_order():
	for n in ["a", "b", "c"]:
		events.subscribe(BattleTypes.Event.TURN_START, _logger(n))
	_emit()
	assert_eq(log, ["a", "b", "c"])

func test_only_matching_type_runs():
	events.subscribe(BattleTypes.Event.TURN_START, _logger("a"))
	_emit(BattleTypes.Event.TURN_END)
	assert_eq(log, [])

func test_unsubscribed_during_emit_is_skipped():
	var ids := {}
	events.subscribe(BattleTypes.Event.TURN_START, func(_e):
		log.append("a")
		events.unsubscribe(ids.b))
	ids.b = events.subscribe(BattleTypes.Event.TURN_START, _logger("b"))
	events.subscribe(BattleTypes.Event.TURN_START, _logger("c"))
	_emit()
	assert_eq(log, ["a", "c"])
	assert_false(events.is_subscribed(ids.b))

func test_subscribed_during_emit_runs_from_next_emit():
	var state := {"added": false}
	events.subscribe(BattleTypes.Event.TURN_START, func(_e):
		log.append("a")
		if not state.added:
			state.added = true
			events.subscribe(BattleTypes.Event.TURN_START, _logger("d")))
	events.subscribe(BattleTypes.Event.TURN_START, _logger("b"))
	_emit()
	assert_eq(log, ["a", "b"])
	_emit()
	assert_eq(log.slice(-3), ["a", "b", "d"])

func test_chain_depth_limit():
	var count := {"n": 0}
	events.subscribe(BattleTypes.Event.TURN_START, func(_e):
		count.n += 1
		_emit())
	_emit()
	assert_eq(count.n, BattleTypes.CHAIN_LIMIT)

func test_event_fields():
	var e := BattleEvent.make(BattleTypes.Event.DAMAGE_DEALT, "A", "B", 30, "src", "card")
	assert_eq(e.type, BattleTypes.Event.DAMAGE_DEALT)
	assert_eq([e.actor, e.target, e.amount, e.source, e.card], ["A", "B", 30, "src", "card"])
