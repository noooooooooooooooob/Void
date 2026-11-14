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

func test_hit_shakes_target_sprite_and_ui():
	var s := _screen()
	var foe := _unit(s, "적A")
	var box: Control = s._tokens[foe].ui_box()
	var sprite: AnimatedSprite2D = s._tokens[foe].sprite()
	var box_home := box.position
	var sprite_home := sprite.position
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	await wait_frames(2)
	assert_ne(box.position, box_home)
	assert_ne(sprite.position, sprite_home)
	await wait_for_signal(_queue(s).drained, 2.0)
	await wait_seconds(0.3)
	assert_eq(box.position, box_home)
	assert_eq(sprite.position, sprite_home)

func test_hit_shakes_screen_and_plays_sound():
	var s := _screen()
	s.hit_sound = AudioStreamWAV.new()
	var home := s.position
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	await wait_frames(2)
	assert_ne(s.position, home)
	var snd: AudioStreamPlayer = s.get_node("%HitSound")
	assert_eq(snd.stream, s.hit_sound)
	assert_almost_eq(snd.pitch_scale, 1.0, s.pitch_jitter + 0.001)

func test_card_override_hit_sound():
	var ps := _perf([[0.1, "hit", []]], 0.2)
	var p: CardPerformance = ps.instantiate()
	p.hit_sound = AudioStreamWAV.new()
	var override_sound := p.hit_sound
	ps.pack(p)
	p.free()
	var s := _screen(_data(45, null, ps))
	s.hit_sound = AudioStreamWAV.new()
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	assert_eq(s.get_node("%HitSound").stream.get_class(), "AudioStreamWAV")
	assert_ne(s.get_node("%HitSound").stream, s.hit_sound)

func test_hit_spawns_effect_on_target():
	var fx := Node2D.new()
	var fx_scene := PackedScene.new()
	fx_scene.pack(fx)
	fx.free()
	var s := _screen()
	s.hit_effect = fx_scene
	var layer := s.get_node("%PerformanceLayer")
	_use(s, "연출타격")
	var before := layer.get_child_count()
	await wait_for_signal(_queue(s).hit, 1.0)
	assert_eq(layer.get_child_count(), before + 1)
	var foe_center: Vector2 = s._tokens[_unit(s, "적A")].get_global_rect().get_center()
	assert_almost_eq(layer.get_child(layer.get_child_count() - 1).global_position, foe_center, Vector2(1, 1))

func test_hitstop_pauses_performance_and_target():
	var s := _screen()
	s.hitstop_time = 0.1
	var foe_sprite: AnimatedSprite2D = s._tokens[_unit(s, "적A")].sprite()
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	var perf := _queue(s).current_performance()
	assert_eq(perf.get_node("%AnimationPlayer").speed_scale, 0.0)
	assert_eq(foe_sprite.speed_scale, 0.0)
	await wait_seconds(0.2)
	assert_eq(perf.get_node("%AnimationPlayer").speed_scale, 1.0)
	assert_eq(foe_sprite.speed_scale, 1.0)

func test_card_override_hitstop_zero_skips_pause():
	var ps := _perf([[0.1, "hit", []]], 0.2)
	var p: CardPerformance = ps.instantiate()
	p.hitstop_time = 0.0
	ps.pack(p)
	p.free()
	var s := _screen(_data(45, null, ps))
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	assert_eq(_queue(s).current_performance().get_node("%AnimationPlayer").speed_scale, 1.0)

func test_hit_flashes_target():
	var s := _screen()
	var sprite: AnimatedSprite2D = s._tokens[_unit(s, "적A")].sprite()
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	assert_gt(sprite.modulate.r, 1.0)
	await wait_seconds(0.4)
	assert_eq(sprite.modulate, Color.WHITE)

func test_knockback_pushes_away_and_returns():
	var s := _screen()
	s.hitstop_time = 0.0
	var foe := _unit(s, "적A")
	var sprite: AnimatedSprite2D = s._tokens[foe].sprite()
	var home := sprite.offset
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	# 적은 아군보다 오른쪽 → 오른쪽(+x)으로 밀림
	assert_gt(sprite.offset.x, home.x)
	await wait_seconds(0.5)
	assert_eq(sprite.offset, home)

func test_bigger_damage_bigger_number():
	var s := _screen()
	assert_gt(s.number_scale(40, 45, false), s.number_scale(5, 45, false))
	assert_almost_eq(s.number_scale(0, 45, false), 1.0, 0.001)
	assert_almost_eq(s.number_scale(45, 45, true), (1.0 + s.big_number_boost) * s.crit_number_scale, 0.001)

func test_kill_adds_extra_screen_shake_at_results():
	var s := _screen(_data(10, null, _perf([[0.1, "show_results", []]], 0.3)))
	s.hit_shake = 6.0
	var home := s.position
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).step_results, 1.0)
	await wait_frames(2)
	assert_ne(s.position, home)
