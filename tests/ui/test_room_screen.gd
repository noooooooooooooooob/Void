extends GutTest
# 방 화면: 이벤트(A/B), 상점(다음), 의뢰 성공(처음으로)마다 보이는 글자와 버튼.

const SCENE := "res://Scenes/ui/room_screen/room_screen.tscn"
const K := StageNode.Kind

func before_each():
	StageRun.end_run()
	StageRun.start_run(3)

func after_each():
	StageRun.end_run()

func _node(kind: StageNode.Kind) -> StageNode:
	for n in StageRun.progress.nodes:
		if n.kind == kind:
			return n
	return null

func _room() -> RoomScreen:
	var r: RoomScreen = load(SCENE).instantiate()
	add_child_autofree(r)
	return r

func test_event_shows_two_choices():
	StageRun.progress.entering = _node(K.EVENT)
	var r := _room()
	assert_eq(r.get_node("%TitleLabel").text, "이벤트")
	assert_true(r.get_node("%ChoiceA").visible)
	assert_true(r.get_node("%ChoiceB").visible)
	assert_false(r.get_node("%NextButton").visible)

func test_shop_shows_next_button():
	StageRun.progress.entering = _node(K.SHOP)
	var r := _room()
	assert_eq(r.get_node("%TitleLabel").text, "상점")
	assert_false(r.get_node("%ChoiceA").visible)
	assert_true(r.get_node("%NextButton").visible)
	assert_eq(r.get_node("%NextButton").text, "다음")

func test_clear_after_boss_goes_to_title():
	StageRun.progress.current = _node(K.BOSS)
	var r := _room()
	assert_eq(r.get_node("%TitleLabel").text, "의뢰 성공")
	assert_eq(r.get_node("%NextButton").text, "처음으로")
