extends GutTest
# 사무소 (v6 00-A): 레일 메뉴 7개 ↔ 패널 7개 열고 닫기, ESC, 숫자키, 자금 표시.

const SCENE := "res://Scenes/ui/office_screen/office_screen.tscn"

func _office() -> OfficeScreen:
	var o: OfficeScreen = load(SCENE).instantiate()
	add_child_autofree(o)
	return o

func _rail(o: OfficeScreen) -> Array:
	return o.get_node("%RailMenu").get_children()

func _panels(o: OfficeScreen) -> Array:
	return o.get_node("%Panels").get_children()

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func test_format_funds():
	assert_eq(OfficeScreen.format_funds(0), "0")
	assert_eq(OfficeScreen.format_funds(950), "950")
	assert_eq(OfficeScreen.format_funds(1250), "1,250")
	assert_eq(OfficeScreen.format_funds(1234567), "1,234,567")
	assert_eq(OfficeScreen.format_funds(-1250), "-1,250")

func test_seven_rail_items_and_panels_in_order():
	var o := _office()
	var names := []
	for r in _rail(o):
		names.append(r.title_ko)
	assert_eq(names, ["의뢰 게시판", "공허 지도", "사원 명부", "승급장", "스파", "창고", "일지"])
	assert_eq(_panels(o).size(), 7)
	for i in 7:
		assert_eq(_panels(o)[i].title_ko, names[i], "패널 %d 제목" % i)
		assert_eq(_panels(o)[i].number, i + 1)

func test_starts_with_no_panel_and_hint():
	var o := _office()
	assert_eq(o.open_index, -1)
	for p in _panels(o):
		assert_false(p.visible)
	assert_true(o.get_node("%EmptyHint").visible)

func test_rail_press_opens_panel():
	var o := _office()
	_rail(o)[2].pressed.emit()
	assert_eq(o.open_index, 2)
	assert_true(_panels(o)[2].visible)
	assert_true(_rail(o)[2].selected)
	assert_false(o.get_node("%EmptyHint").visible)

func test_same_rail_again_closes():
	var o := _office()
	o.toggle(1)
	o.toggle(1)
	assert_eq(o.open_index, -1)
	assert_false(_rail(o)[1].selected)
	assert_true(o.get_node("%EmptyHint").visible)

func test_other_rail_switches_immediately():
	var o := _office()
	o.toggle(0)
	o.toggle(4)
	assert_eq(o.open_index, 4)
	assert_false(_panels(o)[0].visible, "앞 패널은 연출 없이 바로 숨김")
	assert_true(_panels(o)[4].visible)
	assert_false(_rail(o)[0].selected)

func test_esc_closes_panel():
	var o := _office()
	o.open_panel(3)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	o._unhandled_input(esc)
	assert_eq(o.open_index, -1)

func test_close_button_closes_panel():
	var o := _office()
	o.open_panel(5)
	_panels(o)[5].close_requested.emit()
	assert_eq(o.open_index, -1)

func test_number_keys_open_panels():
	var o := _office()
	o._unhandled_input(_key(KEY_1))
	assert_eq(o.open_index, 0)
	o._unhandled_input(_key(KEY_7))
	assert_eq(o.open_index, 6)
	o._unhandled_input(_key(KEY_7))
	assert_eq(o.open_index, -1)

func test_funds_label_follows_value():
	var o := _office()
	o.funds = 1250
	assert_eq(o.get_node("%FundsLabel").text, "1,250")

func test_requests_board_sits_in_first_panel():
	var o := _office()
	var board := o.get_node("%RequestsBoard")
	assert_true(board is RequestsBoard)
	assert_true(_panels(o)[0].is_ancestor_of(board), "의뢰 게시판 패널 안")
	assert_true(board.accepted.is_connected(o._on_request_accepted), "수락 → 의뢰 시작")
	assert_false(_panels(o)[0].show_placeholder, "의뢰 게시판은 '준비 중' 글을 끈다")
	assert_true(_panels(o)[1].show_placeholder)

func test_map_button_opens_void_map_panel():
	var o := _office()
	o.open_panel(0)
	o.get_node("%RequestsBoard").map_requested.emit()
	assert_eq(o.open_index, 1)
	assert_true(_panels(o)[1].visible)
	assert_false(_panels(o)[0].visible)
