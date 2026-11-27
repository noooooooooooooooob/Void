extends GutTest
# GameSettings autoload: 값 바꾸면 저장, 불러오기, 전체화면 거쳐도 창 크기 기억, 신호

const SCRIPT := "res://Scripts/settings/game_settings.gd"
const PATH := "user://test_settings.cfg"

func _settings() -> Node:
	var g: Node = load(SCRIPT).new()
	g.save_path = PATH
	autofree(g)
	return g

func after_each():
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)

func test_set_window_size_saves_file():
	var g := _settings()
	g.set_window_size(Vector2i(1280, 720))
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(PATH), OK)
	assert_eq(cfg.get_value("display", "width"), 1280)
	assert_eq(cfg.get_value("display", "height"), 720)

func test_load_settings_false_without_file():
	var g := _settings()
	assert_false(g.load_settings())
	assert_eq(g.display.mode, DisplaySettings.Mode.WINDOW)
	assert_eq(g.display.window_size, DisplaySettings.DEFAULT_SIZE)

func test_load_settings_reads_saved_file():
	_settings().set_mode(DisplaySettings.Mode.FULLSCREEN)
	var g := _settings()
	assert_true(g.load_settings())
	assert_eq(g.display.mode, DisplaySettings.Mode.FULLSCREEN)

func test_window_size_kept_through_fullscreen():
	var g := _settings()
	g.set_window_size(Vector2i(1280, 720))
	g.set_mode(DisplaySettings.Mode.FULLSCREEN)
	g.set_mode(DisplaySettings.Mode.WINDOW)
	assert_eq(g.display.window_size, Vector2i(1280, 720))

func test_display_changed_emitted():
	var g := _settings()
	watch_signals(g)
	g.set_mode(DisplaySettings.Mode.FULLSCREEN)
	assert_signal_emitted(g, "display_changed")
