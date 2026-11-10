extends GutTest
# 전투 화면: 세션 상태 표시와 입력(카드 고르기·대상 클릭·이동·차례 종료·다시 하기).

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY

func _card(name: String, attack_type: String, eff: CardEffect) -> CardData:
	var c := CardData.new()
	c.name_ko = name
	c.attack_type = attack_type
	c.sp = 1
	c.effects.assign([eff])
	return c

func _dmg() -> DamageEffect:
	var d := DamageEffect.new()
	d.percent = 100
	return d

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

# 아군 속도 10 (항상 먼저), 적 둘. 손패 5장 = 타격·사격·방어 + 타격·사격 (순서는 섞임)
func _data(enemy_hp := 45) -> BattleData:
	var hero := _unit_data("홍연", {"speed_min": 10, "speed_max": 10, "attack": 10, "defense": 15},
		[_card("타격", "melee", _dmg()), _card("사격", "ranged", _dmg()), _guard(),
		 _card("타격", "melee", _dmg()), _card("사격", "ranged", _dmg())])
	var e1 := _unit_data("적A", {"max_hp": enemy_hp, "speed_min": 2, "speed_max": 2}, [_card("타격", "melee", _dmg())])
	var e2 := _unit_data("적B", {"max_hp": enemy_hp, "speed_min": 1, "speed_max": 1}, [_card("사격", "ranged", _dmg())])
	var d := BattleData.new()
	d.allies.assign([_slot(hero, Vector2i(3, 1))])
	d.enemies.assign([_slot(e1, Vector2i(3, 1)), _slot(e2, Vector2i(2, 2))])
	return d

func _screen(data := _data()) -> BattleScreen:
	var s: BattleScreen = load("res://Scenes/ui/battle_screen/battle_screen.tscn").instantiate()
	s.battle_data = data
	s.enemy_delay = 0.0  # 테스트에서는 적 차례를 직접 진행
	add_child_autofree(s)
	return s

func _index_of(s: BattleScreen, name: String) -> int:
	var hand := s.session.active.hand
	for i in hand.size():
		if hand[i].name_ko == name:
			return i
	return -1

func _enemy(s: BattleScreen, name: String) -> BattleUnit:
	for u in s.session.battle.units:
		if u.data.display_name == name:
			return u
	return null


func test_hand_shows_active_unit_cards():
	var s := _screen()
	assert_eq(s.get_node("%Hand").get_child_count(), s.session.active.hand.size())

func test_hand_cards_show_computed_amount():
	var s := _screen()
	var i := _index_of(s, "방어")
	var view: CardView = s.get_node("%Hand").get_child(i)
	assert_eq(view.get_node("%Amount").text, "15")

func test_turn_queue_shows_session_queue():
	var s := _screen()
	assert_eq(s.get_node("%TurnQueue").get_child_count(), s.session.turn_queue().size())

func test_ranged_card_then_click_enemy_plays():
	var s := _screen()
	var foe := _enemy(s, "적B")
	var hand_before := s.session.active.hand.size()
	assert_true(s.select_card(_index_of(s, "사격")))
	assert_not_null(s.selected)
	assert_true(s.click_unit(foe))
	assert_eq(foe.hp, 35)
	assert_eq(s.session.active.hand.size(), hand_before - 1)
	assert_null(s.selected)

func test_click_invalid_target_does_nothing():
	var s := _screen()
	assert_true(s.select_card(_index_of(s, "사격")))
	assert_false(s.click_unit(s.session.active))  # 원거리는 상대 편만
	assert_not_null(s.selected)

func test_melee_card_click_plays_on_front_enemy():
	var s := _screen()
	var front := _enemy(s, "적A")
	assert_true(s.select_card(_index_of(s, "타격")))
	assert_true(s.click_unit(front))
	assert_eq(front.hp, 35)

func test_self_card_second_click_plays():
	var s := _screen()
	var i := _index_of(s, "방어")
	assert_true(s.select_card(i))
	assert_eq(s.session.active.block, 0)
	s.select_card(i)
	assert_eq(s.session.active.block, 15)
	assert_null(s.selected)

func test_unplayable_card_cannot_be_selected():
	var s := _screen()
	s.session.active.sp = 0
	s.refresh()
	assert_false(s.select_card(_index_of(s, "사격")))
	assert_null(s.selected)
	var view: CardView = s.get_node("%Hand").get_child(0)
	assert_lt(view.modulate.v, 1.0)

func test_input_ignored_during_enemy_turn():
	var s := _screen()
	s.press_end_turn()
	assert_true(s.session.is_enemy_turn())
	var foe := s.session.pending_enemy()
	assert_false(s.select_card(0))
	s.press_end_turn()
	assert_same(s.session.pending_enemy(), foe)

func test_enemy_turns_then_back_to_player():
	var s := _screen()
	var hero := s.session.active
	s.press_end_turn()
	s.session.step_enemy()
	s.session.step_enemy()
	assert_same(s.session.active, hero)
	assert_eq(s.get_node("%Hand").get_child_count(), hero.hand.size())

func test_click_reachable_cell_moves():
	var s := _screen()
	assert_true(s.click_cell(A, Vector2i(2, 1)))
	assert_eq(s.session.active.cell, Vector2i(2, 1))

func test_cancel_clears_selection_and_arrow():
	var s := _screen()
	s.select_card(_index_of(s, "사격"))
	assert_true(s.get_node("%TargetArrow").visible)
	s.cancel()
	assert_null(s.selected)
	assert_false(s.get_node("%TargetArrow").visible)

func test_result_overlay_on_win():
	var s := _screen(_data(1))
	s.select_card(_index_of(s, "타격"))
	s.click_unit(_enemy(s, "적A"))
	s.select_card(_index_of(s, "사격"))
	s.click_unit(_enemy(s, "적B"))
	assert_true(s.get_node("%ResultOverlay").visible)
	assert_eq(s.get_node("%ResultLabel").text, "승리")

func test_restart_resets_screen():
	var s := _screen(_data(1))
	s.select_card(_index_of(s, "타격"))
	s.click_unit(_enemy(s, "적A"))
	s.select_card(_index_of(s, "사격"))
	s.click_unit(_enemy(s, "적B"))
	var old := s.session
	s.restart()
	assert_ne(s.session, old)
	assert_false(s.get_node("%ResultOverlay").visible)
	for u in s.session.battle.units:
		assert_eq(u.hp, u.data.max_hp)

# 같은 카드 리소스를 여러 장 넣은 덱 (실제 시험 덱처럼 타격 4장이 한 .tres 를 가리킴)
func _shared_data() -> BattleData:
	var shot := _card("사격", "ranged", _dmg())
	var hero := _unit_data("홍연", {"speed_min": 10, "speed_max": 10, "attack": 10}, [shot, shot, shot, shot, shot])
	var d := _data()
	d.allies[0].unit = hero
	return d

func test_same_card_copies_are_selected_separately():
	var s := _screen(_shared_data())
	assert_true(s.select_card(0))
	assert_true(s.select_card(1))  # 다른 장을 누르면 선택만 바뀐다 (사용하지 않음)
	assert_eq(s.session.active.hand.size(), 5)
	var raised := 0
	for v in s.get_node("%Hand").get_children():
		if v.size_flags_vertical == Control.SIZE_SHRINK_BEGIN:
			raised += 1
	assert_eq(raised, 1)
	assert_eq(s.selected_index, 1)

func test_background_scene_from_battle_data():
	var root := Control.new()
	root.name = "TestBackground"
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	var d := _data()
	d.background = ps
	var s := _screen(d)
	var layer: Control = s.get_node("%BackgroundLayer")
	assert_eq(layer.get_child_count(), 1)
	assert_eq(layer.get_child(0).name, &"TestBackground")

# 아군·적 격자판을 하나씩 넣은 배경 씬 (실제 배경처럼 판은 battle_board.tscn 인스턴스)
func _board_background() -> PackedScene:
	var root := Control.new()
	root.name = "BoardBackground"
	for side in [A, E]:
		var b: BattleBoard = load("res://Scenes/ui/battle_screen/battle_board.tscn").instantiate()
		b.side = side
		b.name = "AllyBoard" if side == A else "EnemyBoard"
		root.add_child(b)
		b.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps

func _board_screen() -> BattleScreen:
	var d := _data()
	d.background = _board_background()
	return _screen(d)

func test_background_boards_replace_the_default_grids():
	var s := _board_screen()
	assert_false(s.get_node("%AllyGrid").visible)
	assert_false(s.get_node("%EnemyGrid").visible)
	var ally_board: BattleBoard = s.get_node("%BackgroundLayer").find_child("AllyBoard", true, false)
	var hero := s.session.active
	var token_cell: Node = s._tokens[hero].get_parent()
	assert_eq(token_cell.get_parent(), ally_board)

func test_board_cells_hidden_outside_battle_size():
	var s := _board_screen()
	var ally_board: BattleBoard = s.get_node("%BackgroundLayer").find_child("AllyBoard", true, false)
	var shown := ally_board.get_children().filter(func(c): return c is GridCell and c.visible).size()
	assert_eq(shown, s.session.battle.cols_of(A) * s.session.battle.grid_rows)

func test_board_cell_click_moves_once_after_restart():
	var s := _board_screen()
	s.restart()
	var hero := s.session.active
	var to: Vector2i = s.session.reachable_cells()[0]
	var cell: GridCell = s._cells[Vector3i(A, to.x, to.y)]
	cell.pressed.emit(A, to)
	assert_eq(hero.cell, to)
	assert_eq(s.session.active.cell, to)

func test_restart_with_boards_keeps_one_token_per_unit():
	var s := _board_screen()
	s.restart()
	var layer: Control = s.get_node("%BackgroundLayer")
	assert_eq(layer.find_children("*", "Control", true, false).filter(func(c): return c is UnitToken and not c.is_queued_for_deletion()).size(), s.session.battle.units.size())

func test_no_background_leaves_layer_empty():
	var s := _screen()
	assert_eq(s.get_node("%BackgroundLayer").get_child_count(), 0)

func test_real_test_battle_plays_through_with_hongyeon_and_bram():
	var s = load("res://Scenes/ui/battle_screen/battle_screen.tscn").instantiate()
	s.enemy_delay = 0.0
	add_child_autofree(s)
	var acted := {}
	for step in 500:
		if s.session.is_finished():
			break
		if s.session.is_enemy_turn():
			s.session.step_enemy()
			continue
		var hero: BattleUnit = s.session.active
		acted[hero.data.display_name] = true
		for card in hero.hand.duplicate():
			var targets: Array[BattleUnit] = s.session.targets_for(card)
			if not targets.is_empty():
				s.session.play(card, targets[0])
			if s.session.is_finished():
				break
		if not s.session.is_finished():
			s.session.end_player_turn()
	assert_true(s.session.is_finished())
	assert_true(acted.has("브람 웰번"), str(acted.keys()))
	assert_true(acted.has("홍연 (시험)"), str(acted.keys()))
