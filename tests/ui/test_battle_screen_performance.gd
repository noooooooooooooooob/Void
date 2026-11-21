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

# 위치 트랙 연출: Actor x 키(에디터 Home 0 → Target 200), 길이 절반에 hit
func _perf_x(x_keys: Array, length: float) -> PackedScene:
	var p: CardPerformance = PerfBuild.build([[length * 0.5, "hit", []]], length, x_keys)
	var ps := PackedScene.new()
	ps.pack(p)
	p.free()
	return ps

# 카메라 연출: Camera:zoom 키, 길이 절반에 hit
func _perf_cam(zoom_keys: Array, length: float) -> PackedScene:
	var p: CardPerformance = PerfBuild.build([[length * 0.5, "hit", []]], length, [], [], zoom_keys)
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
			seen.append([_hp_text(s, hero), step.state[hero].hp, s._rows[hero].get_node("%Hp").text]))
	s.session.step_enemy()
	s.session.step_enemy()
	await wait_for_signal(_queue(s).drained, 3.0)
	assert_eq(seen.size(), 2)
	for e in seen:
		assert_eq(e[0], "%d/%d" % [e[1], hero.get_stat(BattleTypes.Stat.HP)])
		assert_eq(e[2], e[0])  # 옆 상태 패널도 같은 단계 값
	assert_gt(seen[0][1], seen[1][1])

func test_no_show_results_key_shows_at_end():
	var s := _screen(_data(45, null, _perf([[0.1, "hit", []]], 0.2)))
	_use(s, "연출타격")
	assert_eq(_hp_text(s, _unit(s, "적A")), "45/45")
	await wait_for_signal(_queue(s).drained, 2.0)
	assert_eq(_hp_text(s, _unit(s, "적A")), "35/45")

func test_auto_return_after_move():
	var s := _screen(_data(45, null, _perf_x([[0.0, 0.0], [0.05, 200.0]], 0.15)))
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

func test_actor_starts_on_own_sprite():
	var s := _screen(_data(45, null, _perf_x([[0.0, 0.0], [0.2, 0.0], [0.3, 200.0]], 0.4)))
	await wait_process_frames(2)
	var hero_sprite: Node2D = s._tokens[s.session.active].sprite()
	var home := hero_sprite.global_position
	_use(s, "연출타격")
	await wait_frames(2)
	var actor: Node2D = s.get_node("%PerformanceLayer").get_child(0).get_node("%Actor")
	assert_almost_eq(actor.global_position.x, home.x, 3.0)

func test_actor_reaches_target_sprite():
	var s := _screen(_data(45, null, _perf_x([[0.0, 0.0], [0.05, 200.0]], 0.3)))
	await wait_process_frames(2)  # 격자 배치가 끝난 뒤 (실제 게임에서는 늘 끝나 있음)
	_use(s, "연출타격")
	await wait_seconds(0.1)  # hit(0.15초) 흔들림 전에 잰다
	var actor: Node2D = s.get_node("%PerformanceLayer").get_child(0).get_node("%Actor")
	var foe_sprite: Node2D = s._tokens[_unit(s, "적A")].sprite()
	assert_almost_eq(actor.global_position, foe_sprite.global_position, Vector2(2, 2))

func test_actor_walks_back_home_before_cleanup():
	var s := _screen(_data(45, null, _perf_x([[0.0, 0.0], [0.05, 200.0]], 0.1)))
	await wait_process_frames(2)
	var home: Vector2 = s._tokens[s.session.active].sprite().global_position
	_use(s, "연출타격")
	var perf: CardPerformance = s.get_node("%PerformanceLayer").get_child(0)
	var actor: Node2D = perf.get_node("%Actor")
	var far := 0.0  # 가장 멀리 간 거리
	var last := actor.global_position
	while is_instance_valid(perf) and not perf.is_queued_for_deletion():
		last = actor.global_position
		far = maxf(far, absf(last.x - home.x))
		await wait_process_frames(1)
	assert_gt(far, 100.0)  # 대상까지 갔다가
	assert_almost_eq(last.x, home.x, 5.0)  # 지워지기 직전에는 거의 제자리 (마지막 한 프레임 차이)

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
	s.hitstop_speed = 0.0  # 0 배속 = 예전 정지
	var foe_sprite: AnimatedSprite2D = s._tokens[_unit(s, "적A")].sprite()
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	var perf := _queue(s).current_performance()
	assert_eq(perf.get_node("%AnimationPlayer").speed_scale, 0.0)
	assert_eq(foe_sprite.speed_scale, 0.0)
	await wait_seconds(0.2)
	assert_eq(perf.get_node("%AnimationPlayer").speed_scale, 1.0)
	assert_eq(foe_sprite.speed_scale, 1.0)

# 슬로우모션 (2026-11-21): 기본은 멈추지 않고 hitstop_speed 배속으로 느리게
func test_hitstop_slows_performance_and_target():
	var s := _screen()
	s.hitstop_time = 0.4  # 신호를 기다렸다 깨어나는 사이에 끝나지 않게 넉넉히
	s.hitstop_speed = 0.2
	var foe_sprite: AnimatedSprite2D = s._tokens[_unit(s, "적A")].sprite()
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	var perf := _queue(s).current_performance()
	assert_almost_eq(perf.get_node("%AnimationPlayer").speed_scale, 0.2, 0.001)
	assert_almost_eq(foe_sprite.speed_scale, 0.2, 0.001)
	await wait_seconds(0.5)
	if is_instance_valid(perf):  # 연출이 끝나 지워졌을 수 있음
		assert_eq(perf.get_node("%AnimationPlayer").speed_scale, 1.0)
	assert_eq(foe_sprite.speed_scale, 1.0)

func test_hitstop_defaults_slow_motion():
	var s: BattleScreen = load("res://Scenes/ui/battle_screen/battle_screen.tscn").instantiate()
	assert_almost_eq(s.hitstop_speed, 0.2, 0.001)
	assert_almost_eq(s.hitstop_time, 0.15, 0.001)
	s.free()

func test_card_override_hitstop_speed():
	var ps := _perf([[0.1, "hit", []]], 0.4)
	var p: CardPerformance = ps.instantiate()
	p.hitstop_speed = 0.5
	p.hitstop_time = 0.2
	ps.pack(p)
	p.free()
	var s := _screen(_data(45, null, ps))
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	assert_almost_eq(_queue(s).current_performance().get_node("%AnimationPlayer").speed_scale, 0.5, 0.001)

func test_hit_plays_target_hit_animation():
	var data := _data()
	var frames := SpriteFrames.new()
	for anim in [&"idle", &"hit"]:
		if not frames.has_animation(anim):
			frames.add_animation(anim)
		frames.add_frame(anim, PlaceholderTexture2D.new())
	frames.set_animation_loop(&"hit", false)
	data.enemies[0].unit.battle_frames = frames
	var s := _screen(data)
	var sprite: AnimatedSprite2D = s._tokens[_unit(s, "적A")].sprite()
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	assert_eq(sprite.animation, &"hit")

func test_hit_without_hit_animation_keeps_idle():
	var data := _data()
	var frames := SpriteFrames.new()
	if not frames.has_animation(&"idle"):
		frames.add_animation(&"idle")
	frames.add_frame(&"idle", PlaceholderTexture2D.new())
	data.enemies[0].unit.battle_frames = frames
	var s := _screen(data)
	var sprite: AnimatedSprite2D = s._tokens[_unit(s, "적A")].sprite()
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	assert_eq(sprite.animation, &"idle")

# 카드별 피격 반응 값 (2026-11-21): 연출 씬 루트에 값이 있으면 공통값 대신
func _perf_with(props: Dictionary) -> PackedScene:
	var ps := _perf([[0.1, "hit", []]], 0.6)
	var p: CardPerformance = ps.instantiate()
	for k in props:
		p.set(k, props[k])
	ps.pack(p)
	p.free()
	return ps

func test_card_override_flash_color():
	var s := _screen(_data(45, null, _perf_with({"flash_color": Color(0, 2, 0)})))
	var sprite: AnimatedSprite2D = s._tokens[_unit(s, "적A")].sprite()
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	assert_gt(sprite.modulate.g, sprite.modulate.r)

func test_card_override_knockback_return_keeps_pushed_longer():
	var s := _screen(_data(45, null, _perf_with({"knockback_return": 2.0, "hitstop_time": 0.0})))
	var sprite: AnimatedSprite2D = s._tokens[_unit(s, "적A")].sprite()
	var home := sprite.offset
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	await wait_seconds(0.4)  # 공통값 0.25초면 이미 돌아왔을 때
	assert_ne(sprite.offset, home)

func test_card_override_unit_shake_zero_keeps_sprite_still():
	var s := _screen(_data(45, null, _perf_with({"hit_unit_shake": 0.0, "hitstop_time": 0.0})))
	var sprite: AnimatedSprite2D = s._tokens[_unit(s, "적A")].sprite()
	var pos := sprite.position
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).hit, 1.0)
	await wait_process_frames(2)
	assert_eq(sprite.position, pos)

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

# 강조 (2026-11-21): 쓰러뜨림·치명타 모두 슬로우모션, 기준은 카드별 값이 있으면 그것
func _results_perf(props := {}) -> PackedScene:
	var ps := _perf([[0.1, "show_results", []]], 0.8)
	var p: CardPerformance = ps.instantiate()
	for k in props:
		p.set(k, props[k])
	ps.pack(p)
	p.free()
	return ps

func _perf_speed(s: BattleScreen) -> float:
	var perf := _queue(s).current_performance()
	return perf.get_node("%AnimationPlayer").speed_scale if perf else -1.0

func test_kill_emphasis_slows_instead_of_stopping():
	var s := _screen(_data(10, null, _results_perf()))
	s.hitstop_time = 0.4
	s.hitstop_speed = 0.3
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).step_results, 1.0)
	assert_almost_eq(_perf_speed(s), 0.3, 0.001)

func test_crit_emphasis_slows():
	var data := _data(1000, null, _results_perf())
	var hero: UnitData = data.allies[0].unit
	hero.crit_rate = 100
	for c in hero.deck:
		c.effects[0].can_crit = true
	var s := _screen(data)
	s.hitstop_time = 0.4
	s.hitstop_speed = 0.3
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).step_results, 1.0)
	assert_almost_eq(_perf_speed(s), 0.3, 0.001)

func test_no_crit_no_kill_no_emphasis_slow():
	var s := _screen(_data(1000, null, _results_perf()))
	s.hitstop_time = 0.4
	s.hitstop_speed = 0.3
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).step_results, 1.0)
	assert_eq(_perf_speed(s), 1.0)

func test_kill_emphasis_uses_card_values():
	var s := _screen(_data(10, null, _results_perf({"hitstop_speed": 0.5, "hitstop_time": 0.4})))
	s.hitstop_speed = 0.3
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).step_results, 1.0)
	assert_almost_eq(_perf_speed(s), 0.5, 0.001)

func test_crit_hitstop_boost_default():
	var s: BattleScreen = load("res://Scenes/ui/battle_screen/battle_screen.tscn").instantiate()
	assert_almost_eq(s.crit_hitstop_boost, 1.3, 0.001)
	s.free()

func test_zoom_punch_returns_to_one():
	var s := _screen(_data(45, null, _perf([[0.05, "zoom", [0.1, 0.5]]], 0.4)))
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).zoom, 1.0)
	await wait_frames(1)
	assert_gt(s.scale.x, 1.0)
	await wait_seconds(0.7)
	assert_eq(s.scale, Vector2.ONE)
	assert_eq(s.pivot_offset, Vector2.ZERO)

func test_overlapping_zooms_keep_center_until_last_one_ends():
	var s := _screen()
	var step := PerformanceStep.new()
	step.actor = _unit(s, "적A")
	s._on_zoom(step, 0.1, 0.1)
	s._on_zoom(step, 0.1, 0.6)
	await wait_seconds(0.3)
	assert_gt(s.scale.x, 1.0)
	assert_ne(s.pivot_offset, Vector2.ZERO)
	await wait_seconds(0.5)
	assert_eq(s.scale, Vector2.ONE)
	assert_eq(s.pivot_offset, Vector2.ZERO)

func test_overlapping_hitstops_each_resume():
	var s := _screen()
	var a: CardPerformance = PerfBuild.build([[0.5, "hit", []]], 1.0)
	var b: CardPerformance = PerfBuild.build([[0.5, "hit", []]], 1.0)
	add_child_autofree(a)
	add_child_autofree(b)
	a.play(null)
	b.play(null)
	var none: Array[BattleUnit] = []
	s._hitstop(a, none, 0.25)
	s._hitstop(b, none, 0.05)
	await wait_seconds(0.12)
	assert_eq(b.get_node("%AnimationPlayer").speed_scale, 1.0)
	assert_eq(a.get_node("%AnimationPlayer").speed_scale, 0.0)
	await wait_seconds(0.25)
	assert_eq(a.get_node("%AnimationPlayer").speed_scale, 1.0)

func test_damage_number_has_no_sign_and_is_red():
	var s := _screen()
	_use(s, "타격")
	var nums := s.get_node("%FloatLayer").get_children()
	assert_eq(nums.size(), 1)
	assert_eq(nums[0].text, "10")
	assert_eq(Color(nums[0].modulate, 1.0), s.damage_color)

func test_item_refused_and_dimmed_during_performance():
	var s := _screen()
	s.toggle_bag()
	assert_false(s.get_node("%BagPanel").slots()[0].is_dimmed())
	_use(s, "연출타격")
	assert_true(_queue(s).is_busy())
	assert_false(s.select_item(0))
	assert_true(s.get_node("%BagPanel").slots()[0].is_dimmed())
	await wait_for_signal(_queue(s).drained, 2.0)
	assert_false(s.get_node("%BagPanel").slots()[0].is_dimmed())
	assert_true(s.select_item(0))

func test_camera_zoom_scales_world_not_ui():
	var s := _screen(_data(45, null, _perf_cam([[0.0, Vector2.ONE], [0.1, Vector2(2, 2)]], 0.4)))
	await wait_process_frames(2)
	_use(s, "연출타격")
	await wait_seconds(0.25)
	assert_almost_eq(s.get_node("%World").scale, Vector2(2, 2), Vector2(0.05, 0.05))
	assert_eq(s.get_node("%Hand").get_global_transform().get_scale(), Vector2.ONE)

func test_world_returns_after_performance():
	var s := _screen(_data(45, null, _perf_cam([[0.0, Vector2.ONE], [0.1, Vector2(2, 2)]], 0.2)))
	await wait_process_frames(2)
	_use(s, "연출타격")
	await wait_for_signal(_queue(s).drained, 2.0)
	await wait_seconds(0.4)
	assert_almost_eq(s.get_node("%World").scale, Vector2.ONE, Vector2(0.01, 0.01))
	assert_almost_eq(s.get_node("%World").position, Vector2.ZERO, Vector2(0.5, 0.5))

func test_no_camera_world_untouched():
	var s := _screen()
	_use(s, "연출타격")
	await wait_seconds(0.15)
	assert_eq(s.get_node("%World").scale, Vector2.ONE)
	assert_eq(s.get_node("%World").position, Vector2.ZERO)


# 카메라가 Home·Target 중간(w=0.5)에 있고 실제 거리가 에디터와 달라도, 시작하자마자 월드가 어긋나지 않는다
func test_camera_start_does_not_shift_world():
	var s := _screen(_data(45, null, _perf_cam([[0.0, Vector2.ONE], [0.3, Vector2.ONE]], 0.4)))
	await wait_process_frames(2)
	_use(s, "연출타격")
	await wait_process_frames(4)
	assert_almost_eq(s.get_node("%World").position, Vector2.ZERO, Vector2(1, 1))

# 자신 카드는 대상이 자기라도 에디터 모양 그대로 움직인다 (설계 2장: 실제Target = 실제Home + d)
func test_self_card_keeps_editor_shape():
	var b := BlockEffect.new()
	b.percent = 100
	var c := CardData.new()
	c.name_ko = "연출방어"
	c.attack_type = "self"
	c.sp = 1
	c.effects.assign([b])
	c.performance = _perf_x([[0.0, 0.0], [0.05, 200.0]], 0.3)
	var d := _data()
	d.allies[0].unit.deck.assign([c, c, c, c, c])
	var s := _screen(d)
	await wait_process_frames(2)
	var sprite: Node2D = s._tokens[s.session.active].sprite()
	var home := sprite.global_position
	_use(s, "연출방어")
	await wait_seconds(0.12)
	var actor: Node2D = s.get_node("%PerformanceLayer").get_child(0).get_node("%Actor")
	# 에디터 200 × 그림 배율만큼 (자기 자신에게 뭉개지면 0)
	assert_almost_eq(actor.global_position.x - home.x, 200.0 * sprite.global_scale.x, 2.0)

# 카메라는 행위자 복귀와 함께 돌아오기 시작한다 (연출이 지워질 때까지 기다리지 않음)
func test_camera_returns_with_actor():
	var p: CardPerformance = PerfBuild.build([[0.05, "hit", []]], 0.15, [[0.0, 0.0], [0.05, 200.0]], [], [[0.0, Vector2.ONE], [0.1, Vector2(2, 2)]])
	var ps := PackedScene.new()
	ps.pack(p)
	p.free()
	var s := _screen(_data(45, null, ps))
	await wait_process_frames(2)
	_use(s, "연출타격")
	var perf: CardPerformance = s.get_node("%PerformanceLayer").get_child(0)
	await wait_for_signal(perf.done, 2.0)
	var smallest := 99.0
	while is_instance_valid(perf) and not perf.is_queued_for_deletion():
		smallest = minf(smallest, s.get_node("%World").scale.x)
		await wait_process_frames(1)
	assert_lt(smallest, 1.9)

# 연출 씬을 화면 크기로 짰을 때(Actor 에 그림 배율을 직접 넣음): 루트는 배율 1, Actor 는 유닛 그림과 같은 크기
func test_screen_scale_authoring_keeps_root_at_one():
	var p: CardPerformance = PerfBuild.build([[0.1, "hit", []]], 0.3)
	p.get_node("Actor").scale = Vector2(0.2, 0.2)
	var ps := PackedScene.new()
	ps.pack(p)
	p.free()
	var s := _screen(_data(45, null, ps))
	await wait_process_frames(2)
	var sprite: Node2D = s._tokens[s.session.active].sprite()
	_use(s, "연출타격")
	await wait_process_frames(1)
	var perf: CardPerformance = s.get_node("%PerformanceLayer").get_child(0)
	assert_almost_eq(perf.global_scale, sprite.global_scale / Vector2(0.2, 0.2), Vector2(0.001, 0.001))
	assert_almost_eq(perf.get_node("%Actor").global_scale, sprite.global_scale, Vector2(0.001, 0.001))
