extends GutTest
# 가방 패널(BagPanel)과 칸(ItemSlot): 칸 5개 채우기, 누름·뗌 알림.

func _item(n: String) -> ConsumableData:
	var i := ConsumableData.new()
	i.display_name = n
	return i

func _panel(items: Array[ConsumableData], usable := true, selected := -1) -> BagPanel:
	var p: BagPanel = load("res://Scenes/ui/battle_screen/bag_panel.tscn").instantiate()
	add_child_autofree(p)
	p.show_items(items, usable, selected)
	return p

func _mouse(pressed: bool, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	return e

func test_panel_fills_five_slots_and_title():
	var p := _panel([_item("회복약"), _item("기력약")])
	assert_eq(p.slots().size(), 5)
	assert_eq(p.get_node("%Title").text, "가방 (2/5)")
	assert_eq(p.slots()[0].get_node("%Name").text, "회복약")
	assert_eq(p.slots()[2].get_node("%Name").text, "")

func test_slot_shows_lines_and_tooltip():
	var item := _item("회복약")
	item.description_ko = "상처를 낫게 한다"
	var l := ConsumableLine.new()
	l.amount = 30
	item.lines.assign([l])
	var p := _panel([item])
	assert_eq(p.slots()[0].get_node("%Lines").text, "HP 회복 +30")
	assert_eq(p.slots()[0].tooltip_text, "회복약\n상처를 낫게 한다\nHP 회복 +30")
	assert_eq(p.slots()[1].tooltip_text, "")

func test_pressing_filled_slot_reports_press_and_release():
	var p := _panel([_item("회복약"), _item("기력약")])
	watch_signals(p)
	p.slots()[1]._gui_input(_mouse(true))
	assert_signal_emitted_with_parameters(p, "item_pressed", [1])
	p.slots()[1]._gui_input(_mouse(false))
	assert_signal_emitted_with_parameters(p, "item_released", [1])
	assert_signal_emit_count(p, "item_pressed", 1)
	assert_signal_emit_count(p, "item_released", 1)

func test_empty_slot_and_other_buttons_report_nothing():
	var p := _panel([_item("회복약")])
	watch_signals(p)
	p.slots()[3]._gui_input(_mouse(true))
	p.slots()[3]._gui_input(_mouse(false))
	p.slots()[0]._gui_input(_mouse(true, MOUSE_BUTTON_RIGHT))
	p.slots()[0]._gui_input(_mouse(false))   # 누른 적 없는 뗌
	assert_signal_emit_count(p, "item_pressed", 0)
	assert_signal_emit_count(p, "item_released", 0)

func test_unusable_items_are_dimmed_and_selected_is_marked():
	var p := _panel([_item("회복약"), _item("기력약")], false, 1)
	assert_true(p.slots()[0].is_dimmed())
	assert_false(p.slots()[0].is_selected())
	assert_true(p.slots()[1].is_selected())
	p.show_items([_item("회복약")] as Array[ConsumableData], true, -1)
	assert_false(p.slots()[0].is_dimmed())
	assert_false(p.slots()[1].is_selected())
