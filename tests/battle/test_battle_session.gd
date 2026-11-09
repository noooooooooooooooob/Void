extends GutTest
# BattleSession: 전투 화면과 Battle 사이의 진행 담당 (차례 진행, 입력, 적 차례, 승패).

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const Ev := BattleTypes.Event

func _card(name: String, attack_type: String, eff: CardEffect, sp := 1) -> CardData:
	var c := CardData.new()
	c.name_ko = name
	c.attack_type = attack_type
	c.sp = sp
	c.effects.assign([eff])
	return c

func _strike() -> CardData:
	var d := DamageEffect.new()
	d.percent = 100
	return _card("타격", "melee", d)

func _shot() -> CardData:
	var d := DamageEffect.new()
	d.percent = 100
	return _card("사격", "ranged", d)

func _guard() -> CardData:
	var b := BlockEffect.new()
	b.percent = 100
	b.target = BattleTypes.Target.SELF
	return _card("방어", "self", b)

func _unit_data(name: String, stats: Dictionary, deck: Array) -> UnitData:
	var d := UnitData.new()
	d.display_name = name
	for k in stats:
		d.set(k, stats[k])
	d.deck.assign(deck)
	return d

func _slot(u: UnitData, cell: Vector2i) -> BattleSlot:
	var s := BattleSlot.new()
	s.unit = u
	s.cell = cell
	return s

# 아군이 먼저 움직이도록 속도 고정: 아군 10, 적 1·2
func _data(enemy_hp := 45) -> BattleData:
	var hero := _unit_data("홍연", {"speed_min": 10, "speed_max": 10, "attack": 10, "defense": 15},
		[_strike(), _strike(), _shot(), _shot(), _guard()])
	var e1 := _unit_data("적A", {"max_hp": enemy_hp, "speed_min": 2, "speed_max": 2, "attack": 9}, [_strike()])
	var e2 := _unit_data("적B", {"max_hp": enemy_hp, "speed_min": 1, "speed_max": 1, "attack": 9}, [_shot()])
	var d := BattleData.new()
	d.allies.assign([_slot(hero, Vector2i(3, 1))])
	d.enemies.assign([_slot(e1, Vector2i(3, 1)), _slot(e2, Vector2i(2, 2))])
	return d

func _started(data := _data()) -> BattleSession:
	var s := BattleSession.new(data, [], 5)
	s.start()
	return s

func _hand_card(s: BattleSession, name: String) -> CardData:
	for c in s.active.hand:
		if c.name_ko == name:
			return c
	return null


func test_start_stops_at_first_player_turn():
	var s := _started()
	assert_not_null(s.active)
	assert_eq(s.active.data.display_name, "홍연")
	assert_false(s.is_enemy_turn())
	assert_eq(s.active.hand.size(), 5)

func test_allies_can_be_given_from_outside():
	var hero := BattleUnit.new(_unit_data("파티", {"speed_min": 10, "speed_max": 10}, [_guard()]), A, Vector2i(3, 0))
	hero.hp = 30
	var given: Array[BattleUnit] = [hero]
	var s := BattleSession.new(_data(), given, 1)
	s.start()
	assert_same(s.active, hero)
	assert_eq(hero.hp, 30)  # 의뢰 안에서 HP 유지
	assert_eq(s.battle.units.size(), 3)

func test_play_card_spends_sp_and_emits_changed():
	var s := _started()
	watch_signals(s)
	var sp := s.active.sp
	assert_true(s.play(_hand_card(s, "방어")))
	assert_eq(s.active.sp, sp - 1)
	assert_eq(s.active.block, 15)
	assert_signal_emitted(s, "changed")

func test_play_ignored_when_not_active():
	var s := _started()
	var card := _hand_card(s, "방어")
	var hero := s.active
	s.end_player_turn()
	assert_false(s.play(card))
	assert_eq(hero.block, 0)

func test_end_player_turn_moves_to_enemy_turn():
	var s := _started()
	s.end_player_turn()
	assert_null(s.active)
	assert_true(s.is_enemy_turn())
	assert_eq(s.pending_enemy().data.display_name, "적A")

func test_step_enemy_runs_enemy_and_advances():
	var s := _started()
	var hero := s.active
	s.end_player_turn()
	s.step_enemy()  # 적A: 타격 9
	assert_eq(hero.hp, hero.data.max_hp - 9)
	assert_eq(s.pending_enemy().data.display_name, "적B")
	s.step_enemy()  # 적B: 사격 → 새 라운드 → 홍연 차례
	assert_same(s.active, hero)

func test_player_kills_last_enemy_ends_immediately():
	var s := _started(_data(1))
	watch_signals(s)
	assert_true(s.play(_hand_card(s, "타격")))
	assert_true(s.play(_hand_card(s, "사격"), s.battle.living(E)[0]))
	assert_signal_emit_count(s, "finished", 1)
	assert_signal_emitted_with_parameters(s, "finished", [A])
	assert_null(s.active)
	assert_false(s.is_enemy_turn())
	s.advance()
	assert_signal_emit_count(s, "finished", 1)

func test_both_sides_wiped_in_one_action_ends_in_defeat():
	var s := _started()
	watch_signals(s)
	# 마지막 적이 먼저 죽어도, 행동이 끝났을 때 아군도 전멸이면 패배
	for u in s.battle.living(E):
		s.battle.apply_damage(null, u, 99999)
	for u in s.battle.living(A):
		s.battle.apply_damage(null, u, 99999)
	s.end_player_turn()
	assert_signal_emit_count(s, "finished", 1)
	assert_signal_emitted_with_parameters(s, "finished", [E])
	assert_null(s.active)

func test_dead_at_draw_phase_skips_turn():
	# 아군 차례 시작(드로우 페이즈)에 출혈로 죽으면 그 아군에서 멈추지 않는다 → 아군 전멸이면 패배
	var d := DamageEffect.new()
	d.use_flat = true
	d.flat = 999
	d.target = BattleTypes.Target.OWNER
	var trig := StatusTrigger.new()
	trig.event = Ev.DRAW_PHASE
	trig.filter = BattleTypes.Filter.OWNER_IS_ACTOR
	trig.effects.assign([d])
	var doom := Fixture.status("doom", false)
	doom.triggers.assign([trig])
	var s := _started()
	watch_signals(s)
	var hero := s.active
	s.battle.apply_status(hero, doom, 1, hero)
	s.end_player_turn()
	s.step_enemy()
	s.step_enemy()
	assert_false(hero.alive)
	assert_null(s.active)
	assert_signal_emitted_with_parameters(s, "finished", [E])

func test_targets_for_ranged_lists_living_enemies():
	var s := _started()
	assert_eq(s.targets_for(_hand_card(s, "사격")).size(), 2)

func test_targets_for_melee_is_front_enemy():
	var s := _started()
	var t := s.targets_for(_hand_card(s, "타격"))
	assert_eq(t.size(), 1)
	assert_eq(t[0].data.display_name, "적A")

func test_targets_for_self_is_active():
	var s := _started()
	assert_eq(s.targets_for(_hand_card(s, "방어")), [s.active] as Array[BattleUnit])

func test_targets_for_empty_when_no_sp():
	var s := _started()
	s.active.sp = 0
	assert_true(s.targets_for(_hand_card(s, "사격")).is_empty())

func test_reachable_cells_respects_move_left():
	var s := _started()
	var cells := s.reachable_cells()
	assert_true(cells.has(Vector2i(2, 1)))
	assert_true(cells.has(Vector2i(1, 1)))  # 이동력 2
	assert_false(cells.has(Vector2i(0, 1)))  # 3칸
	assert_false(cells.has(Vector2i(3, 1)))  # 자기 칸
	assert_true(s.move(Vector2i(3, 0)))
	assert_eq(s.active.cell, Vector2i(3, 0))
	assert_false(s.reachable_cells().has(Vector2i(1, 0)))  # 이동력 1 남음

func test_turn_queue_matches_turn_order():
	var s := _started()
	var q := s.turn_queue()
	assert_same(q[0].unit, s.active)
	var rest := s.battle.turn_order.remaining()
	assert_eq(q.size(), rest.size() + 1)
	for i in rest.size():
		assert_same(q[i + 1].unit, rest[i].unit)

func test_restart_creates_fresh_battle():
	var s := _started()
	s.play(_hand_card(s, "타격"))
	var s2 := s.restart()
	s2.start()
	assert_ne(s2.battle, s.battle)
	for u in s2.battle.units:
		assert_eq(u.hp, u.data.max_hp)

func test_card_preview():
	var s := _started()
	assert_eq(s.card_preview(_hand_card(s, "타격")), 10)
	assert_eq(s.card_preview(_hand_card(s, "방어")), 15)
	assert_eq(s.card_preview(CardData.new()), -1)
