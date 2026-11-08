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

func _roster():
	return add_child_autofree(load(Router.PATHS[Router.Screen.ROSTER]).instantiate())

func _find(r, id: String) -> CharacterProfile:
	for c in r.roster.characters:
		if c.id == id:
			return c
	return null

func test_roster_lists_all_characters():
	var r = _roster()
	assert_eq(r.portrait_buttons.size(), r.roster.characters.size())
	assert_eq(r.selected, r.roster.characters[0])
	assert_true(r.portrait_buttons[0].button_pressed)

func test_roster_select_shows_profile_and_art():
	var r = _roster()
	var c := _find(r, "bram_welburn")
	r.select(c)
	assert_eq(r.get_node("%NameLabel").text, c.display_name)
	assert_eq(r.get_node("%Illustration").texture, c.illustration)
	assert_eq(r.get_node("%RoleValue").text, c.role)
	assert_eq(r.get_node("%TraitsRow").get_child_count() - 1, c.traits.size())
	assert_true(r.portrait_buttons[r.roster.characters.find(c)].button_pressed)
	assert_false(r.portrait_buttons[0].button_pressed)

func test_roster_deck_pages():
	var r = _roster()
	var c := _find(r, "hongyeon")
	r.select(c)
	assert_eq(r.card_views().size(), 8)
	assert_eq(r.page_count(), 2)
	r.next_page()
	assert_eq(r.card_views().size(), c.unit.deck.size() - 8)
	r.next_page()
	assert_eq(r.page, 1)
	r.prev_page()
	assert_eq(r.page, 0)

func test_roster_character_without_unit_has_no_deck():
	var r = _roster()
	r.select(_find(r, "mo_liang"))
	assert_eq(r.card_views().size(), 0)
	assert_true(r.get_node("%DeckEmpty").visible)

func test_roster_pixel_uses_nearest_filter():
	var r = _roster()
	assert_eq(r.get_node("%PixelImage").texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)

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
