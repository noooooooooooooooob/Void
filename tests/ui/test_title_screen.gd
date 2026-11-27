extends GutTest
# 타이틀 + 메인 메뉴 (v6 T-A, T-B): 아무 키 → 메뉴, 비활성 줄 건너뛰기, ESC → 타이틀.

const SCENE := "res://Scenes/ui/title_screen/title_screen.tscn"
const Item := TitleScreen.Item

func _title() -> TitleScreen:
	var t: TitleScreen = load(SCENE).instantiate()
	add_child_autofree(t)
	return t

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func test_starts_in_title_state():
	var t := _title()
	assert_eq(t.state, TitleScreen.State.TITLE)
	assert_false(t.get_node("%Menu").visible)
	assert_true(t.get_node("%PressAnyKey").visible)

func test_any_key_shows_menu():
	var t := _title()
	t._unhandled_input(_key(KEY_X))
	assert_eq(t.state, TitleScreen.State.MENU)
	assert_true(t.get_node("%Menu").visible)

func test_menu_has_six_items_in_order():
	var t := _title()
	var names := []
	for c in t.get_node("%Menu").get_children():
		names.append(c.title_ko)
	assert_eq(names, ["이어하기", "새 게임", "불러오기", "설정", "제작진", "종료"])

func test_without_save_continue_and_load_disabled_and_cursor_on_new_game():
	var t := _title()
	t.show_menu()
	var items := t.get_node("%Menu").get_children()
	assert_true(items[Item.CONTINUE].disabled)
	assert_true(items[Item.LOAD].disabled)
	assert_eq(t.cursor, Item.NEW_GAME)
	assert_true(items[Item.NEW_GAME].selected)

func test_cursor_skips_disabled_and_wraps():
	var t := _title()
	t.show_menu()
	t.move_cursor(1)
	assert_eq(t.cursor, Item.SETTINGS, "불러오기는 건너뜀")
	t.move_cursor(-1)
	t.move_cursor(-1)
	assert_eq(t.cursor, Item.QUIT, "새 게임 위로는 이어하기(비활성)를 건너뛰고 맨 아래로")

func test_w_and_s_move_cursor():
	var t := _title()
	t.show_menu()
	t._unhandled_input(_key(KEY_S))
	assert_eq(t.cursor, Item.SETTINGS)
	t._unhandled_input(_key(KEY_W))
	assert_eq(t.cursor, Item.NEW_GAME)

func test_esc_returns_to_title():
	var t := _title()
	t.show_menu()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	t._unhandled_input(esc)
	assert_eq(t.state, TitleScreen.State.TITLE)
	assert_eq(t.cursor, -1)

func test_save_card_hidden_without_save():
	var t := _title()
	t.show_menu()
	assert_false(t.get_node("%SaveCard").visible)

func test_new_game_points_to_office():
	var t := _title()
	assert_not_null(t.office_scene)
	assert_eq(t.office_scene.resource_path, "res://Scenes/ui/office_screen/office_screen.tscn")

func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e

func test_click_on_title_shows_menu():
	# 화면 전체를 덮는 루트가 클릭을 먼저 받으므로 _gui_input 으로도 시작돼야 한다
	var t := _title()
	t._gui_input(_click())
	assert_eq(t.state, TitleScreen.State.MENU)

func test_e_key_activates_cursor_item():
	var t := _title()
	t.show_menu()
	t.move_cursor(1)  # 새 게임 → 불러오기(비활성) 건너뛰고 설정
	t.move_cursor(1)  # → 제작진 (아직 "준비 중")
	assert_eq(t.cursor, Item.CREDITS)
	t._unhandled_input(_key(KEY_E))
	assert_eq(t.get_node("%Notice").text, "준비 중입니다")

func test_enter_key_activates_cursor_item():
	var t := _title()
	t.show_menu()
	t.move_cursor(1)
	t.move_cursor(1)
	t._unhandled_input(_key(KEY_ENTER))
	assert_eq(t.get_node("%Notice").text, "준비 중입니다")

func test_settings_opens_panel():
	var t := _title()
	t.show_menu()
	t.activate(Item.SETTINGS)
	assert_true(t.get_node("%SettingsPanel").visible)

func test_esc_closes_panel_only():
	var t := _title()
	t.show_menu()
	t.activate(Item.SETTINGS)
	# 직접 호출 말고 실제 입력 전달 순서로 (패널이 먼저 받아 막아야 한다)
	get_viewport().push_input(_key(KEY_ESCAPE))
	assert_false(t.get_node("%SettingsPanel").visible)
	assert_eq(t.state, TitleScreen.State.MENU)
