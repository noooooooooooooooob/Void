extends GutTest
# 의뢰 게시판 (v6 01-A): 처음 선택, 필터, 잠김 건너뛰기, 키 이동, 수락·지도 시그널, 자세히 글.

const SCENE := "res://Scenes/ui/office_screen/requests_board.tscn"

func _req(code: String, kind := RequestData.Kind.REPEAT, chapter := 0, urgent := false, locked := false) -> RequestData:
	var r := RequestData.new()
	r.code = code
	r.title = "제목 " + code
	r.kind = kind
	r.chapter = chapter
	r.urgent = urgent
	r.locked = locked
	r.client_ko = "의뢰인 " + code
	r.objectives = PackedStringArray(["목표 1", "목표 2"])
	return r

# 긴급 본편 A, 반복 B·C, 잠긴 본편 D
func _list() -> Array[RequestData]:
	return [
		_req("C"),
		_req("D", RequestData.Kind.MAIN, 4, false, true),
		_req("A", RequestData.Kind.MAIN, 3, true),
		_req("B"),
	]

func _board(list := _list()) -> RequestsBoard:
	var b: RequestsBoard = load(SCENE).instantiate()
	add_child_autofree(b)
	b.set_requests(list)
	return b

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func _codes(list: Array[RequestData]) -> Array:
	var out := []
	for r in list:
		out.append(r.code)
	return out

func test_loads_sample_requests_from_folder():
	var b: RequestsBoard = load(SCENE).instantiate()
	add_child_autofree(b)
	assert_eq(b.requests.size(), 4)
	assert_eq(b.selected.code, "REQ-0312")

func test_cards_in_board_order_and_first_selected():
	var b := _board()
	assert_eq(_codes(b.visible_requests()), ["A", "B", "C", "D"])
	assert_eq(b.selected.code, "A")
	assert_eq(b._cards.size(), 4)
	assert_true(b._cards[0].selected)
	assert_false(b._cards[1].selected)

func test_filter_repeat_shows_only_repeat_and_reselects():
	var b := _board()
	b.set_filter(RequestData.Filter.REPEAT)
	assert_eq(_codes(b.visible_requests()), ["B", "C"])
	assert_eq(b._cards.size(), 2)
	assert_eq(b.selected.code, "B")

func test_filter_keeps_selection_when_still_visible():
	var b := _board()
	b.select(b.requests[2])  # C
	b.set_filter(RequestData.Filter.REPEAT)
	assert_eq(b.selected.code, "C")

func test_chip_texts():
	var b := _board()
	var labels := []
	for chip in b.get_node("%Filters").get_children():
		labels.append(chip.get_child(0).text)
	assert_eq(labels, ["전체 4", "본 이야기", "반복 의뢰"])

func test_locked_cannot_be_selected():
	var b := _board()
	b.select(b.requests[3])  # D (잠김)
	assert_eq(b.selected.code, "A")

func test_card_click_selects():
	var b := _board()
	b._cards[2].pressed.emit()
	assert_eq(b.selected.code, "C")
	assert_true(b._cards[2].selected)

func test_keys_move_and_skip_locked_and_stop_at_ends():
	var b := _board()
	b._unhandled_input(_key(KEY_S))
	assert_eq(b.selected.code, "B")
	b._unhandled_input(_key(KEY_DOWN))
	assert_eq(b.selected.code, "C")
	b._unhandled_input(_key(KEY_S))
	assert_eq(b.selected.code, "C", "잠긴 D 는 건너뛰고 끝에서 멈춤")
	b._unhandled_input(_key(KEY_W))
	assert_eq(b.selected.code, "B")
	b.move_selection(-1)
	b.move_selection(-1)
	assert_eq(b.selected.code, "A", "위 끝에서 멈춤")

func test_accept_emits_selected():
	var b := _board()
	watch_signals(b)
	b._unhandled_input(_key(KEY_E))
	assert_signal_emitted_with_parameters(b, "accepted", [b.requests[0]])

func test_accept_button_and_map_button():
	var b := _board()
	watch_signals(b)
	b.get_node("%AcceptButton").pressed.emit()
	assert_signal_emitted(b, "accepted")
	b.get_node("%MapButton").pressed.emit()
	assert_signal_emitted(b, "map_requested")

func test_detail_shows_selected_request():
	var b := _board()
	assert_eq(b.get_node("%ChapterLine").text, "CHAPTER 03  —  MAIN STORY")
	assert_eq(b.get_node("%DetailTitle").text, "제목 A")
	assert_eq(b.get_node("%ClientKo").text, "의뢰인 A")
	assert_true(b.get_node("%Stamp").visible, "긴급 도장")
	assert_true(b.get_node("%PortraitHint").visible, "초상 없음 → 안내 글")
	assert_eq(b._objective_rows.size(), 2)
	assert_eq(b._objective_rows[1].get_node("Text").text, "목표 2")
	b.select(b.requests[1])  # B
	assert_eq(b.get_node("%ChapterLine").text, "REPEATABLE  —  SIDE REQUEST")
	assert_false(b.get_node("%Stamp").visible)
	assert_false(b.get_node("%ObjectiveTemplate").visible)

func test_keys_ignored_when_hidden():
	var b := _board()
	b.visible = false
	b._unhandled_input(_key(KEY_S))
	assert_eq(b.selected.code, "A")

func test_card_shapes():
	var b := _board()
	var urgent: RequestCard = b._cards[0]
	assert_eq(urgent.get_node("%ChipLabel").text, "긴급")
	assert_eq(urgent.get_node("%Title").text, "3장 · 제목 A")
	assert_true(urgent.get_node("%PlateSelected").visible)
	var rep: RequestCard = b._cards[1]
	assert_eq(rep.get_node("%ChipLabel").text, "반복")
	assert_true(rep.get_node("%Plate").visible)
	var locked: RequestCard = b._cards[3]
	assert_true(locked.get_node("%PlateLocked").visible)
	assert_false(locked.get_node("%Title").visible)
	assert_eq(locked.size.y, 92.0)
