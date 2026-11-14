extends GutTest
# 전투 화면 + 연출 대기열: 연출 씬이 있는 카드는 연출이 끝날 때까지 결과·입력·결과 창을 미룬다.

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY
const PerfBuild := preload("res://tests/performances/test_card_performance.gd")

func _perf(keys: Array, length := 0.3) -> PackedScene:
	var p: CardPerformance = PerfBuild.build(keys, length)
	var ps := PackedScene.new()
	ps.pack(p)
	p.free()
	return ps

# 기본 연출: 0.1초 hit, 0.2초 show_results, 길이 0.3초
func _std_perf() -> PackedScene:
	return _perf([[0.1, "hit", []], [0.2, "show_results", []]])

func _card(name: String, attack_type: String, perf: PackedScene = null) -> CardData:
	var d := DamageEffect.new()
	d.percent = 100
	d.can_crit = false
	var c := CardData.new()
	c.name_ko = name
	c.attack_type = attack_type
	c.sp = 1
	c.effects.assign([d])
	c.performance = perf
	return c

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

# 아군 1 (속도 10, 공격 10), 적 둘 (HP enemy_hp, 같은 행: 적A 전열 → 적B). 아군 손패: 연출 타격 ×3 + 맨손 타격 ×2
func _data(enemy_hp := 45, enemy_perf: PackedScene = null, hero_perf: PackedScene = null) -> BattleData:
	if hero_perf == null:
		hero_perf = _std_perf()
	var hero := _unit_data("홍연", {"speed_min": 10, "speed_max": 10, "attack": 10},
		[_card("연출타격", "melee", hero_perf), _card("연출타격", "melee", hero_perf), _card("연출타격", "melee", hero_perf),
		 _card("타격", "melee"), _card("타격", "melee")])
	var e1 := _unit_data("적A", {"max_hp": enemy_hp, "speed_min": 2, "speed_max": 2, "attack": 7}, [_card("타격", "melee", enemy_perf)])
	var e2 := _unit_data("적B", {"max_hp": enemy_hp, "speed_min": 1, "speed_max": 1, "attack": 5}, [_card("사격", "ranged", enemy_perf)])
	var d := BattleData.new()
	d.allies.assign([_slot(hero, Vector2i(3, 1))])
	d.enemies.assign([_slot(e1, Vector2i(3, 1)), _slot(e2, Vector2i(2, 1))])
	return d

func _screen(data := _data()) -> BattleScreen:
	var s: BattleScreen = load("res://Scenes/ui/battle_screen/battle_screen.tscn").instantiate()
	s.battle_data = data
	s.enemy_delay = 0.0
	add_child_autofree(s)
	return s

func _index_of(s: BattleScreen, name: String) -> int:
	var hand := s.session.active.hand
	for i in hand.size():
		if hand[i].name_ko == name:
			return i
	return -1

func _unit(s: BattleScreen, name: String) -> BattleUnit:
	for u in s.session.battle.units:
		if u.data.display_name == name:
			return u
	return null

func _hp_text(s: BattleScreen, u: BattleUnit) -> String:
	return s._tokens[u].get_node("%Hp").text

func _use(s: BattleScreen, name: String) -> void:
	var i := _index_of(s, name)
	s.select_card(i)
	s.select_card(i)  # 근접: 한 번 더 누르면 자동 대상에 사용

func _queue(s: BattleScreen) -> PerformanceQueue:
	return s.get_node("%PerformanceQueue")


func test_card_without_performance_is_immediate():
	var s := _screen()
	_use(s, "타격")
	assert_eq(_hp_text(s, _unit(s, "적A")), "35/45")
	assert_false(_queue(s).is_busy())

func test_hp_waits_for_show_results():
	var s := _screen()
	_use(s, "연출타격")
	assert_true(_queue(s).is_busy())
	assert_eq(_hp_text(s, _unit(s, "적A")), "45/45")
	await wait_for_signal(_queue(s).drained, 2.0)
	assert_eq(_hp_text(s, _unit(s, "적A")), "35/45")

func test_input_ignored_while_playing():
	var s := _screen()
	var hero := s.session.active
	_use(s, "연출타격")
	assert_false(s.select_card(0))
	s.press_end_turn()
	assert_same(s.session.active, hero)
	await wait_for_signal(_queue(s).drained, 2.0)
	assert_true(s.select_card(_index_of(s, "타격")))

func test_result_waits_for_queue():
	var s := _screen(_data(10))
	_use(s, "타격")  # 적A 처치 (연출 없음)
	_use(s, "연출타격")  # 다음 맨 앞 = 적B 처치 → 전투 끝
	assert_true(s.session.is_finished())
	assert_false(s.get_node("%ResultOverlay").visible)
	await wait_for_signal(_queue(s).drained, 2.0)
	assert_true(s.get_node("%ResultOverlay").visible)

func test_two_enemy_cards_show_their_own_hp():
	var s := _screen(_data(45, _std_perf()))
	var hero := s.session.active
	s.press_end_turn()
	var seen := []
	_queue(s).step_results.connect(func(step):
		if step.kind == PerformanceStep.Kind.CARD:
			seen.append([_hp_text(s, hero), step.state[hero].hp]))
	s.session.step_enemy()
	s.session.step_enemy()
	await wait_for_signal(_queue(s).drained, 3.0)
	assert_eq(seen.size(), 2)
	for e in seen:
		assert_eq(e[0], "%d/%d" % [e[1], hero.get_stat(BattleTypes.Stat.HP)])
	assert_gt(seen[0][1], seen[1][1])

func test_no_show_results_key_shows_at_end():
	var s := _screen(_data(45, null, _perf([[0.1, "hit", []]], 0.2)))
	_use(s, "연출타격")
	assert_eq(_hp_text(s, _unit(s, "적A")), "45/45")
	await wait_for_signal(_queue(s).drained, 2.0)
	assert_eq(_hp_text(s, _unit(s, "적A")), "35/45")

func test_auto_return_after_move():
	var s := _screen(_data(45, null, _perf([[0.0, "move", [-80.0, 0.0, 0.05]]], 0.15)))
	var hero := s.session.active
	var sprite: AnimatedSprite2D = s._tokens[hero].sprite()
	var before := sprite.visible
	_use(s, "연출타격")
	assert_eq(s.get_node("%PerformanceLayer").get_child_count(), 1)
	assert_false(sprite.visible)
	await wait_for_signal(_queue(s).drained, 2.0)
	assert_eq(sprite.visible, before)
	await wait_frames(1)
	assert_eq(s.get_node("%PerformanceLayer").get_child_count(), 0)

func test_move_goes_near_target_cell():
	var s := _screen(_data(45, null, _perf([[0.0, "move", [-80.0, 0.0, 0.05]]], 0.3)))
	_use(s, "연출타격")
	await wait_seconds(0.15)
	var perf: Node2D = s.get_node("%PerformanceLayer").get_child(0)
	var foe_center: Vector2 = s._tokens[_unit(s, "적A")].get_global_rect().get_center()
	assert_almost_eq(perf.global_position, foe_center + Vector2(-80, 0), Vector2(1, 1))
