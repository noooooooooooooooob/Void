extends GutTest

func after_each():
	StageRun.end_run()

func test_every_router_screen_has_a_scene():
	for screen in Router.PATHS:
		assert_true(ResourceLoader.exists(Router.PATHS[screen]), Router.PATHS[screen])
	assert_eq(Router.PATHS.size(), Router.Screen.size())

func test_office_end_day_is_disabled():
	var o = add_child_autofree(load(Router.PATHS[Router.Screen.OFFICE]).instantiate())
	assert_true(o.get_node("%EndDayButton").disabled)
	assert_false(o.get_node("%DepartButton").disabled)

func test_roster_lists_units_and_shows_deck():
	var r = add_child_autofree(load(Router.PATHS[Router.Screen.ROSTER]).instantiate())
	assert_eq(r.unit_buttons.size(), r.roster.units.size())
	var unit: UnitData = r.roster.units[0]
	assert_eq(r.selected, unit)
	assert_eq(r.card_views().size(), unit.deck.size())
	assert_string_contains(r.get_node("%NameLabel").text, unit.display_name)

func test_card_workshop_shows_only_common_cards():
	var w = add_child_autofree(load(Router.PATHS[Router.Screen.CARD_WORKSHOP]).instantiate())
	var g: CardGallery = w.get_node("%Gallery")
	assert_eq(g.deck, CardGallery.COMMON_LABEL)
	assert_gt(g.card_views().size(), 0)
	for v in g.card_views():
		assert_eq(v.card.deck_id, "")

func test_void_map_markers_and_selection():
	var m = add_child_autofree(load(Router.PATHS[Router.Screen.VOID_MAP]).instantiate())
	assert_eq(m.markers.size(), 7)
	assert_eq(m.markers.size(), m.sites.size())
	assert_false(m.get_node("%InfoPanel").visible)
	var s: VoidSiteData = m.sites[2]
	m.select(s)
	assert_true(m.get_node("%InfoPanel").visible)
	assert_eq(m.get_node("%SiteName").text, s.display_name)
	assert_false(m.get_node("%EnterButton").disabled)

func test_title_dev_panel_visible_in_debug_build():
	var t = add_child_autofree(load(Router.PATHS[Router.Screen.TITLE]).instantiate())
	assert_eq(t.get_node("%DevPanel").visible, OS.is_debug_build())
	assert_not_null(t.dev_site)
