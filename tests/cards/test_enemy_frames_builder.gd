extends GutTest

const ART := "res://Art/enemies"
const OUT := "user://test_enemy_frames"
const TEMPLATE := "res://entities/units/test/test_enemy_a.tres"
const LANTERN := "mountain_shrine/paper_lantern"

func before_each():
	_clear(OUT)

func after_all():
	_clear(OUT)

func _clear(dir: String):
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(d))
		DirAccess.remove_absolute(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))

func test_scan_finds_enemies_grouped_by_setting():
	var found := EnemyFramesBuilder.scan(ART)
	assert_eq(found.size(), 21)
	assert_true(found.has(LANTERN))
	var lantern: Dictionary = found[LANTERN]
	assert_eq(lantern.size(), 3)
	assert_true(lantern.has(&"idle") and lantern.has(&"hit") and lantern.has(&"attack"))
	assert_eq(lantern[&"idle"][0], ART + "/mountain_shrine/paper_lantern/paper_lantern_idle.png")

func test_fill_frames_loops_only_idle():
	var frames := SpriteFrames.new()
	EnemyFramesBuilder.fill_frames(frames, EnemyFramesBuilder.scan(ART)[LANTERN])
	assert_false(frames.has_animation(&"default"))
	assert_true(frames.get_animation_loop(&"idle"))
	assert_false(frames.get_animation_loop(&"hit"))
	assert_false(frames.get_animation_loop(&"attack"))
	assert_eq(frames.get_frame_count(&"attack"), 1)
	assert_not_null(frames.get_frame_texture(&"hit", 0))

func test_apply_creates_frames_and_units_in_setting_folders():
	var b := EnemyFramesBuilder.new()
	var errors := b.apply(ART, OUT, load(TEMPLATE))
	assert_eq(errors.size(), 0)
	assert_eq(b.frames_added.size(), 21)
	assert_eq(b.units_added.size(), 21)
	assert_true(FileAccess.file_exists(OUT + "/mountain_shrine/paper_lantern_frames.tres"))
	var unit: UnitData = ResourceLoader.load(OUT + "/mountain_shrine/paper_lantern.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var tmpl: UnitData = load(TEMPLATE)
	assert_eq(unit.display_name, "paper_lantern")
	assert_eq(unit.max_hp, tmpl.max_hp)
	assert_eq(unit.deck.size(), tmpl.deck.size())
	assert_eq(unit.battle_scale, EnemyFramesBuilder.DEFAULT_SCALE)
	assert_true(unit.battle_frames.has_animation(&"attack"))
	assert_not_null(unit.battle_frames.get_frame_texture(&"idle", 0))

func test_apply_again_keeps_edited_unit_and_frames_uid():
	var b := EnemyFramesBuilder.new()
	b.apply(ART, OUT, load(TEMPLATE))
	var unit_path := OUT + "/mountain_shrine/paper_lantern.tres"
	var frames_path := OUT + "/mountain_shrine/paper_lantern_frames.tres"
	var unit: UnitData = load(unit_path)
	unit.display_name = "종이 등롱 요괴"
	unit.max_hp = 99
	ResourceSaver.save(unit, unit_path)
	var uid := ResourceLoader.get_resource_uid(frames_path)
	b.apply(ART, OUT, load(TEMPLATE))
	assert_eq(b.units_added.size(), 0)
	assert_eq(b.frames_updated.size(), 21)
	var again: UnitData = ResourceLoader.load(unit_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(again.display_name, "종이 등롱 요괴")
	assert_eq(again.max_hp, 99)
	assert_eq(ResourceLoader.get_resource_uid(frames_path), uid)
