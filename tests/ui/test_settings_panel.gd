extends GutTest
# 설정 창: 저장값 보여 주기, 고르면 GameSettings 로, ESC·닫기 버튼으로 닫힘

const SCENE := "res://Scenes/ui/settings_panel/settings_panel.tscn"
const PATH := "user://test_settings.cfg"

var _old_path: String
var _old_display: DisplaySettings

func before_each():
	_old_path = GameSettings.save_path
	_old_display = GameSettings.display
	GameSettings.save_path = PATH
	GameSettings.display = DisplaySettings.new()

func after_each():
	GameSettings.save_path = _old_path
	GameSettings.display = _old_display
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)

func _panel() -> SettingsPanel:
	var p: SettingsPanel = load(SCENE).instantiate()
	add_child_autofree(p)
	return p

func _esc() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	return e

func test_starts_hidden():
	assert_false(_panel().visible)

func test_open_shows_saved_mode():
	GameSettings.display.mode = DisplaySettings.Mode.FULLSCREEN
	var p := _panel()
	p.open()
	assert_true(p.visible)
	assert_eq(p.get_node("%ModeOption").selected, 1)
	assert_true(p.get_node("%SizeOption").disabled, "전체화면이면 창 크기는 못 고른다")

func test_open_window_mode_enables_size():
	var p := _panel()
	p.open()
	assert_eq(p.get_node("%ModeOption").selected, 0)
	assert_false(p.get_node("%SizeOption").disabled)

func test_pick_fullscreen_calls_settings():
	var p := _panel()
	p.open()
	p.get_node("%ModeOption").item_selected.emit(1)
	assert_eq(GameSettings.display.mode, DisplaySettings.Mode.FULLSCREEN)
	assert_true(p.get_node("%SizeOption").disabled)

func test_pick_size_calls_settings():
	var p := _panel()
	p.open()
	p.get_node("%SizeOption").item_selected.emit(0)
	assert_eq(GameSettings.display.window_size, Vector2i(1280, 720))

func test_size_option_text():
	var p := _panel()
	p.open()
	assert_eq(p.get_node("%SizeOption").get_item_text(0), "1280 × 720")

func test_esc_closes_and_emits():
	var p := _panel()
	p.open()
	watch_signals(p)
	p._unhandled_input(_esc())
	assert_false(p.visible)
	assert_signal_emitted(p, "closed")

func test_close_button_closes():
	var p := _panel()
	p.open()
	p.get_node("%CloseButton").pressed.emit()
	assert_false(p.visible)
