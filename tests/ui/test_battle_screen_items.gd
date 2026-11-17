extends GutTest
# 전투 화면의 소비 아이템: 가방 열기, 아이템 고르기, 카드처럼 끌어서 아군에게 쓰기.

const A := BattleTypes.Side.ALLY
const E := BattleTypes.Side.ENEMY

var s: BattleScreen

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

func _unit_data(name: String, stats: Dictionary, deck: Array) -> UnitData:
	var d := UnitData.new()
	d.display_name = name
	for k in stats:
		d.set(k, stats[k])
	d.deck.assign(deck)
	return d

func _slot(u: UnitData, cell: Vector2i) -> BattleSlot:
	var b := BattleSlot.new()
	b.unit = u
	b.cell = cell
	return b

# 아군 속도 10 (항상 먼저), 적 둘
func _data() -> BattleData:
	var hero := _unit_data("홍연", {"max_hp": 100, "max_sp": 3, "speed_min": 10, "speed_max": 10},
		[_card("타격", "melee", _dmg()), _card("사격", "ranged", _dmg()), _card("타격", "melee", _dmg()),
		 _card("타격", "melee", _dmg()), _card("사격", "ranged", _dmg())])
	var e1 := _unit_data("적A", {"speed_min": 2, "speed_max": 2, "attack": 1}, [_card("타격", "melee", _dmg())])
	var e2 := _unit_data("적B", {"speed_min": 1, "speed_max": 1, "attack": 1}, [_card("사격", "ranged", _dmg())])
	var d := BattleData.new()
	d.allies.assign([_slot(hero, Vector2i(3, 1))])
	d.enemies.assign([_slot(e1, Vector2i(3, 1)), _slot(e2, Vector2i(2, 2))])
	return d

func _item(name: String, type: int, amount: int) -> ConsumableData:
	var l := ConsumableLine.new()
	l.type = type
	l.amount = amount
	var item := ConsumableData.new()
	item.display_name = name
	item.lines.assign([l])
	return item

func before_each():
	s = load("res://Scenes/ui/battle_screen/battle_screen.tscn").instantiate()
	s.battle_data = _data()
	s.enemy_delay = 0.0
	s.test_items.assign([
		_item("회복약", ConsumableLine.Type.HEAL_HP, 30),
		_item("기력약", ConsumableLine.Type.HEAL_SP, 2)])
	add_child_autofree(s)

func _unit(name: String) -> BattleUnit:
	for u in s.session.battle.units:
		if u.data.display_name == name:
			return u
	return null

func _center(u: BattleUnit) -> Vector2:
	return s._tokens[u].get_global_rect().get_center()

func _slot_view(i: int) -> ItemSlot:
	return s.get_node("%BagPanel").slots()[i]


func test_bag_button_shows_count_and_toggles_panel():
	assert_eq(s.get_node("%BagButton").text, "가방 2/5")
	assert_false(s.is_bag_open())
	assert_false(s.get_node("%BagPanel").visible)
	s.toggle_bag()
	assert_true(s.is_bag_open())
	assert_true(s.get_node("%BagPanel").visible)
	assert_eq(_slot_view(0).get_node("%Name").text, "회복약")
	s.toggle_bag()
	assert_false(s.is_bag_open())

func test_bag_button_press_opens_bag():
	s.get_node("%BagButton").pressed.emit()
	assert_true(s.is_bag_open())

func test_toggle_bag_action_opens_bag():
	var ev := InputEventAction.new()
	ev.action = "toggle_bag"
	ev.pressed = true
	s._input(ev)
	assert_true(s.is_bag_open())

func test_use_hp_item_on_ally():
	var hero := s.session.active
	hero.hp = 50
	assert_true(s.select_item(0))
	assert_true(s.click_unit(hero))
	assert_eq(hero.hp, 80)
	assert_eq(s.session.inventory.items.size(), 1)
	assert_eq(s.selected_item, -1)
	assert_string_contains(s.get_node("%Log").text, "아이템: 회복약 → 홍연")
	assert_eq(s.get_node("%BagButton").text, "가방 1/5")

func test_use_sp_item_goes_over_max_and_shows_it():
	var hero := s.session.active
	assert_true(s.select_item(1))
	assert_true(s.click_unit(hero))
	assert_eq(hero.sp, 5)
	assert_eq(s.get_node("%SpLabel").text, "SP 5 / 3")

func test_item_use_costs_no_sp_and_keeps_the_turn():
	var hero := s.session.active
	hero.hp = 50
	var sp := hero.sp
	s.select_item(0)
	s.click_unit(hero)
	assert_eq(hero.sp, sp)
	assert_same(s.session.active, hero)
	assert_eq(hero.hand.size(), 5)

func test_drag_item_released_on_ally_uses_it():
	await wait_process_frames(2)
	var hero := s.session.active
	hero.hp = 50
	s.toggle_bag()
	s.get_node("%BagPanel").item_pressed.emit(0)
	assert_eq(s.selected_item, 0)
	assert_true(s._dragging_item)
	s._release_item_drag(_center(hero))   # 아군 박스 위에서 뗌
	assert_eq(hero.hp, 80)
	assert_eq(s.session.inventory.items.size(), 1)
	assert_eq(s.selected_item, -1)
	assert_false(s._dragging_item)

func test_drag_item_released_off_target_keeps_it():
	await wait_process_frames(2)
	s.toggle_bag()
	s.get_node("%BagPanel").item_pressed.emit(0)
	s._release_item_drag(Vector2(5, 5))    # 아무 유닛도 없는 곳
	assert_eq(s.selected_item, -1)
	assert_false(s._dragging_item)
	assert_eq(s.session.inventory.items.size(), 2)

func test_drag_item_released_on_enemy_keeps_it():
	await wait_process_frames(2)
	s.toggle_bag()
	s.get_node("%BagPanel").item_pressed.emit(0)
	s._release_item_drag(_center(_unit("적A")))
	assert_eq(s.selected_item, -1)
	assert_eq(s.session.inventory.items.size(), 2)
	assert_eq(_unit("적A").hp, _unit("적A").get_stat(BattleTypes.Stat.HP))

func test_plain_click_on_item_does_not_use_it():
	await wait_process_frames(2)
	s.toggle_bag()
	var panel: BagPanel = s.get_node("%BagPanel")
	panel.item_pressed.emit(0)
	panel.item_released.emit(0)   # 끌지 않고 그 자리에서 뗌 (마우스는 유닛 위가 아님)
	assert_eq(s.selected_item, -1)
	assert_eq(s.session.inventory.items.size(), 2)

func test_arrow_shows_while_item_is_selected_and_hides_after():
	s.toggle_bag()
	s.select_item(0)
	s._update_arrow()
	assert_true(s.get_node("%TargetArrow").visible)
	s.cancel()
	s._update_arrow()
	assert_false(s.get_node("%TargetArrow").visible)

func test_selected_item_highlights_ally_and_marks_slot():
	s.toggle_bag()
	s.select_item(0)
	assert_true(s._tokens[s.session.active]._highlight)
	assert_false(s._tokens[_unit("적A")]._highlight)
	assert_true(_slot_view(0).is_selected())

func test_using_item_keeps_bag_open():
	s.toggle_bag()
	s.select_item(0)
	s.click_unit(s.session.active)
	assert_true(s.is_bag_open())

func test_item_cannot_be_used_on_enemy():
	s.select_item(0)
	assert_false(s.click_unit(_unit("적A")))
	assert_eq(s.session.inventory.items.size(), 2)

func test_selecting_item_drops_selected_card_and_back():
	s.select_card(0)
	assert_true(s.select_item(0))
	assert_null(s.selected)
	assert_eq(s.selected_index, -1)
	s.select_card(0)
	assert_eq(s.selected_item, -1)

func test_empty_slot_cannot_be_selected():
	assert_false(s.select_item(3))
	assert_false(s.select_item(-1))
	assert_eq(s.selected_item, -1)

func test_item_refused_on_enemy_turn_but_bag_still_opens():
	s.press_end_turn()            # enemy_delay 0 → 적 차례 대기
	assert_true(s.session.is_enemy_turn())
	assert_false(s.select_item(0))
	s.toggle_bag()
	assert_true(s.is_bag_open())
	assert_true(_slot_view(0).is_dimmed())

func test_cancel_drops_item_first_then_closes_bag():
	s.toggle_bag()
	s.select_item(0)
	s.cancel()
	assert_eq(s.selected_item, -1)
	assert_true(s.is_bag_open())
	s.cancel()
	assert_false(s.is_bag_open())

func test_cancel_with_card_selected_keeps_bag_open():
	s.toggle_bag()
	s.select_card(0)
	s.cancel()
	assert_null(s.selected)
	assert_true(s.is_bag_open())

func test_closing_bag_drops_selected_item():
	s.toggle_bag()
	s.select_item(0)
	s.toggle_bag()
	assert_eq(s.selected_item, -1)

func test_end_turn_drops_selected_item():
	s.select_item(0)
	s.press_end_turn()
	assert_eq(s.selected_item, -1)

func test_restart_refills_test_bag():
	s.select_item(0)
	s.click_unit(s.session.active)
	s.restart()
	assert_eq(s.session.inventory.items.size(), 2)
	assert_eq(s.get_node("%BagButton").text, "가방 2/5")


# --- 적에게 쓰는 아이템·범위·HP 감소 (2026-11-17 consumable-targets) ---

func _bomb(area: Array[Vector2i] = []) -> ConsumableData:
	var item := _item("폭탄", ConsumableLine.Type.HEAL_HP, -20)
	item.target = ConsumableData.Target.ENEMY
	item.area = area
	return item

func _cell_color(side: int, cell: Vector2i) -> Color:
	return s._cells[Vector3i(side, cell.x, cell.y)].mark_color()

func test_enemy_item_highlights_enemies_not_allies():
	s.session.inventory.add(_bomb())
	s.toggle_bag()
	assert_true(s.select_item(2))
	assert_true(s._tokens[_unit("적A")]._highlight)
	assert_true(s._tokens[_unit("적B")]._highlight)
	assert_false(s._tokens[s.session.active]._highlight)

func test_enemy_item_used_on_enemy_lowers_hp():
	s.session.inventory.add(_bomb())
	var foe := _unit("적A")
	assert_true(s.select_item(2))
	assert_true(s.click_unit(foe))
	assert_eq(foe.hp, foe.get_stat(BattleTypes.Stat.HP) - 20)

func test_area_item_marks_area_cells_over_hovered_enemy():
	# 적A (3,1) 기준으로 적B (2,2) 는 (-1, 1)
	var area: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 1)]
	s.session.inventory.add(_bomb(area))
	s.toggle_bag()
	s.select_item(2)
	s._draw_marks([], _unit("적A"))
	var area_color: Color = s._cells.values()[0].mark_colors[GridCell.Mark.AREA]
	assert_eq(_cell_color(E, Vector2i(3, 1)), area_color)
	assert_eq(_cell_color(E, Vector2i(2, 2)), area_color)

func test_hp_lost_event_logged():
	var foe := _unit("적A")
	s._show_event(BattleEvent.make(BattleTypes.Event.HP_LOST, null, foe, 20, _bomb()), true)
	assert_string_contains(s.get_node("%Log").text, "적A HP -20")
