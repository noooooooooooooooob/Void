extends GutTest

const VOID_DIR := "res://voids"

func _site_paths() -> Array:
	var out := []
	for f in DirAccess.get_files_at(VOID_DIR):
		if f.ends_with(".tres"):
			out.append(VOID_DIR.path_join(f))
	return out

func test_seven_void_sites():
	assert_eq(_site_paths().size(), 7)

func test_each_site_is_filled():
	for p in _site_paths():
		var s = load(p)
		assert_true(s is VoidSiteData, p)
		assert_eq(s.id, p.get_file().get_basename(), p)
		assert_ne(s.display_name, "", p)
		assert_ne(s.description, "", p)
		assert_eq(s.floor_level, 1, p)
		assert_not_null(s.background, p)
		var bg: Node = s.background.instantiate()
		assert_true(bg is Control, p)
		bg.free()

func test_site_ids_unique():
	var ids := {}
	for p in _site_paths():
		ids[load(p).id] = true
	assert_eq(ids.size(), _site_paths().size())

func test_roster_has_playable_units():
	var roster: RosterData = load("res://entities/roster.tres")
	var units := roster.playable_units()
	assert_gt(units.size(), 0)
	assert_eq(units[0].display_name, "홍연 (시험)")
	for u in units:
		assert_gt(u.deck.size(), 0)

func test_ten_characters_with_art():
	var roster: RosterData = load("res://entities/roster.tres")
	assert_eq(roster.characters.size(), 10)
	var ids := {}
	for c in roster.characters:
		assert_ne(c.display_name, "", c.id)
		assert_not_null(c.illustration, c.id)
		assert_not_null(c.portrait, c.id)
		assert_ne(c.description, "", c.id)
		assert_true(ResourceLoader.exists("res://entities/characters/%s.tres" % c.id), c.id)
		ids[c.id] = true
	assert_eq(ids.size(), 10)

func test_portrait_is_crop_of_illustration():
	var roster: RosterData = load("res://entities/roster.tres")
	for c in roster.characters:
		assert_true(c.portrait is AtlasTexture, c.id)
		assert_eq(c.portrait.atlas, c.illustration, c.id)
		var r: Rect2 = c.portrait.region
		assert_gt(r.size.x, 0.0, c.id)
		assert_true(Rect2(Vector2.ZERO, c.illustration.get_size()).encloses(r), c.id)
