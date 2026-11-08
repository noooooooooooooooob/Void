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
	assert_gt(roster.units.size(), 0)
	for u in roster.units:
		assert_ne(u.display_name, "")
		assert_gt(u.deck.size(), 0)
