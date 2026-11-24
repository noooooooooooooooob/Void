extends GutTest
# 의뢰 데이터: 카드 제목·장 줄, 게시판 정렬, 필터, 고를 수 있는지.

func _req(code: String, kind := RequestData.Kind.REPEAT, chapter := 0, urgent := false, locked := false) -> RequestData:
	var r := RequestData.new()
	r.code = code
	r.title = "제목 " + code
	r.kind = kind
	r.chapter = chapter
	r.urgent = urgent
	r.locked = locked
	return r

func _codes(list: Array[RequestData]) -> Array:
	var out := []
	for r in list:
		out.append(r.code)
	return out

func test_card_title_has_chapter_only_for_main():
	var main := _req("A", RequestData.Kind.MAIN, 3)
	main.title = "하수도에서 올라온 검은 것"
	assert_eq(main.card_title(), "3장 · 하수도에서 올라온 검은 것")
	var rep := _req("B")
	rep.title = "남부 항구 창고 청소"
	assert_eq(rep.card_title(), "남부 항구 창고 청소")

func test_chapter_line():
	assert_eq(_req("A", RequestData.Kind.MAIN, 3).chapter_line(), "CHAPTER 03  —  MAIN STORY")
	assert_eq(_req("B").chapter_line(), "REPEATABLE  —  SIDE REQUEST")

func test_client_line():
	var r := _req("A")
	r.client_ko = "하수도 감독관"
	assert_eq(r.client_line(), "의뢰인 · 하수도 감독관")

func test_selectable_unless_locked():
	assert_true(_req("A").is_selectable())
	assert_false(_req("B", RequestData.Kind.MAIN, 4, false, true).is_selectable())

func test_matches_filter():
	var main := _req("A", RequestData.Kind.MAIN, 3)
	var rep := _req("B")
	assert_true(main.matches(RequestData.Filter.ALL))
	assert_true(main.matches(RequestData.Filter.MAIN))
	assert_false(main.matches(RequestData.Filter.REPEAT))
	assert_true(rep.matches(RequestData.Filter.REPEAT))
	assert_false(rep.matches(RequestData.Filter.MAIN))

func test_sort_locked_last_urgent_first_main_before_repeat_then_code():
	var list: Array[RequestData] = [
		_req("REQ-0301"),
		_req("REQ-0400", RequestData.Kind.MAIN, 4, false, true),
		_req("REQ-0298"),
		_req("REQ-0350", RequestData.Kind.MAIN, 5),
		_req("REQ-0312", RequestData.Kind.MAIN, 3, true),
		_req("REQ-0320", RequestData.Kind.MAIN, 2),
	]
	var sorted := RequestData.sort_for_board(list)
	assert_eq(_codes(sorted), ["REQ-0312", "REQ-0320", "REQ-0350", "REQ-0298", "REQ-0301", "REQ-0400"])
	assert_eq(list.size(), 6, "원본 배열은 그대로")

func test_filtered_keeps_order():
	var list: Array[RequestData] = [_req("A", RequestData.Kind.MAIN, 1), _req("B"), _req("C")]
	assert_eq(_codes(RequestData.filtered(list, RequestData.Filter.REPEAT)), ["B", "C"])
	assert_eq(_codes(RequestData.filtered(list, RequestData.Filter.ALL)), ["A", "B", "C"])

func test_difficulty_clamped():
	var r := _req("A")
	r.difficulty = 7
	assert_eq(r.difficulty, 3)
	r.difficulty = 0
	assert_eq(r.difficulty, 1)

func test_load_all_from_dir():
	var list := RequestData.load_all("res://requests")
	assert_eq(list.size(), 4, "예시 의뢰 4개")
	assert_eq(list[0].code, "REQ-0312", "긴급 3장이 맨 앞")
	assert_true(list[list.size() - 1].locked, "잠긴 4장이 맨 뒤")
