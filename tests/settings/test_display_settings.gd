extends GutTest
# 화면 설정 값: 크기 목록 거르기, 모니터에 맞추기, 저장/불러오기

func test_sizes_fitting_1080p_screen():
	# 작업 표시줄 때문에 사용 가능 영역은 1920×1040 같은 값
	assert_eq(DisplaySettings.sizes_fitting(Vector2i(1920, 1040)),
		[Vector2i(1280, 720), Vector2i(1600, 900)] as Array[Vector2i])

func test_sizes_fitting_big_screen_has_all_three():
	assert_eq(DisplaySettings.sizes_fitting(Vector2i(3840, 2160)),
		[Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)] as Array[Vector2i])

func test_sizes_fitting_tiny_screen_keeps_smallest():
	assert_eq(DisplaySettings.sizes_fitting(Vector2i(1024, 600)),
		[Vector2i(1280, 720)] as Array[Vector2i])

func test_clamp_to_smaller_screen():
	var d := DisplaySettings.new()
	d.window_size = Vector2i(1920, 1080)
	d.clamp_to(Vector2i(1920, 1040))
	assert_eq(d.window_size, Vector2i(1600, 900))

func test_clamp_keeps_fitting_size():
	var d := DisplaySettings.new()
	d.window_size = Vector2i(1280, 720)
	d.clamp_to(Vector2i(3840, 2160))
	assert_eq(d.window_size, Vector2i(1280, 720))

func test_save_load_roundtrip():
	var d := DisplaySettings.new()
	d.mode = DisplaySettings.Mode.FULLSCREEN
	d.window_size = Vector2i(1920, 1080)
	var cfg := ConfigFile.new()
	d.save_to(cfg)
	assert_eq(cfg.get_value("display", "mode"), "fullscreen")
	var e := DisplaySettings.load_from(cfg)
	assert_eq(e.mode, DisplaySettings.Mode.FULLSCREEN)
	assert_eq(e.window_size, Vector2i(1920, 1080))

func test_load_bad_values_fall_back():
	var cfg := ConfigFile.new()
	cfg.set_value("display", "mode", "abc")
	cfg.set_value("display", "width", -5)
	cfg.set_value("display", "height", "x")
	var e := DisplaySettings.load_from(cfg)
	assert_eq(e.mode, DisplaySettings.Mode.WINDOW)
	assert_eq(e.window_size, DisplaySettings.DEFAULT_SIZE)

func test_window_mode_maps_to_display_server():
	var d := DisplaySettings.new()
	assert_eq(d.window_mode(), DisplayServer.WINDOW_MODE_WINDOWED)
	d.mode = DisplaySettings.Mode.FULLSCREEN
	assert_eq(d.window_mode(), DisplayServer.WINDOW_MODE_FULLSCREEN)
