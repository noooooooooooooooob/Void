extends GutTest

var site: VoidSiteData

func before_each():
	StageRun.navigate = false
	StageRun.end_run()
	site = load("res://voids/mountain_shrine.tres")
	StageRun.pending_site = site

func after_each():
	StageRun.end_run()
	StageRun.pending_site = null
	StageRun.navigate = true

func _screen() -> PartySelect:
	return add_child_autofree(load(Router.PATHS[Router.Screen.PARTY_SELECT]).instantiate())

func test_lists_only_characters_with_units():
	var p := _screen()
	var roster: RosterData = load("res://entities/roster.tres")
	assert_eq(p.choices.size(), roster.playable_units().size())
	for c in p.choices:
		assert_not_null(c.unit)

func test_first_character_selected_by_default():
	var p := _screen()
	assert_eq(p.chosen, [p.choices[0]])
	assert_false(p.get_node("%StartButton").disabled)

func test_toggle_and_max_party():
	var p := _screen()
	p.toggle(p.choices[0])
	assert_eq(p.chosen.size(), 0)
	assert_true(p.get_node("%StartButton").disabled)
	for c in p.choices:
		p.toggle(c)
	assert_eq(p.chosen.size(), mini(p.choices.size(), PartySelect.MAX_PARTY))

func test_start_runs_with_chosen_party_in_order():
	var p := _screen()
	p.toggle(p.choices[0])
	p.toggle(p.choices[2])
	p.toggle(p.choices[0])
	p.start()
	assert_true(StageRun.is_active())
	assert_eq(StageRun.site, site)
	assert_eq(StageRun.party.size(), 2)
	assert_eq(StageRun.party[0].data, p.choices[2].unit)
	assert_eq(StageRun.party[1].data, p.choices[0].unit)
	assert_eq(StageRun.party[0].cell, StageRun.PARTY_CELLS[0])
	assert_eq(StageRun.party[1].cell, StageRun.PARTY_CELLS[1])
	assert_eq(StageRun.last_screen, Router.Screen.STAGE_MAP)

func test_stage_map_esc_menu_and_abandon():
	StageRun.start_run(site, 3)
	var m = add_child_autofree(load(Router.PATHS[Router.Screen.STAGE_MAP]).instantiate())
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	m._unhandled_input(e)
	var pm: PauseMenu = m.get_node("%PauseMenu")
	assert_true(pm.visible)
	assert_true(pm.get_node("%AbandonButton").visible)
	assert_false(pm.get_node("%SkipButton").visible)
	pm.get_node("%AbandonButton").pressed.emit()
	assert_false(StageRun.is_active())
	assert_eq(StageRun.last_screen, Router.Screen.VOID_MAP)
