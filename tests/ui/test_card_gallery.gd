extends GutTest

var data_dir: String

func before_each():
	data_dir = "user://test_gallery_%d" % Time.get_ticks_usec()

func after_each():
	for sub in ["common", "홍연", "세리안"]:
		var d := data_dir.path_join(sub)
		var dir := DirAccess.open(d)
		if dir:
			for f in dir.get_files():
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)
	DirAccess.remove_absolute(data_dir)

func _save(sub: String, id: String, name_ko: String) -> void:
	var c := CardData.new()
	c.id = id
	c.name_ko = name_ko
	DirAccess.make_dir_recursive_absolute(data_dir.path_join(sub))
	ResourceSaver.save(c, data_dir.path_join("%s/%s.tres" % [sub, id]))

func _gallery(deck := CardGallery.ALL) -> CardGallery:
	var g: CardGallery = preload("res://Scenes/ui/card_gallery/card_gallery.tscn").instantiate()
	g.data_dir = data_dir
	g.deck = deck
	add_child_autofree(g)
	return g

func _names(g: CardGallery) -> Array:
	return g.card_views().map(func(v): return v.card.name_ko)

func _three_decks() -> void:
	_save("common", "c1", "베기")
	_save("홍연", "c2", "피의 참격")
	_save("홍연", "c3", "혈갑")
	_save("세리안", "c4", "찌르기")


func test_all_shows_every_card_with_deck_sections():
	_three_decks()
	var g := _gallery()
	assert_eq(g.card_views().size(), 4)
	assert_eq(g.section_titles(), PackedStringArray(["공용", "세리안", "홍연"]))

func test_deck_options():
	_three_decks()
	var g := _gallery()
	assert_eq(g.deck_options(), PackedStringArray(["전체", "공용", "세리안", "홍연"]))

func test_filter_one_deck():
	_three_decks()
	var g := _gallery("홍연")
	assert_eq(_names(g), ["피의 참격", "혈갑"])

func test_changing_deck_refreshes():
	_three_decks()
	var g := _gallery()
	g.deck = "공용"
	assert_eq(_names(g), ["베기"])

func test_tabs_select_deck():
	_three_decks()
	var g := _gallery()
	g.deck_tabs.current_tab = 3  # 전체, 공용, 세리안, 홍연
	assert_eq(g.deck, "홍연")
	assert_eq(_names(g), ["피의 참격", "혈갑"])

func test_empty_message_when_no_cards():
	var g := _gallery()
	assert_eq(g.card_views().size(), 0)
	assert_true(g.empty_label.visible)


func test_sections_are_copies_of_scene_templates():
	# 덱 제목·카드 줄은 씬의 틀(에디터에서 모양을 고침)을 복제한다. 틀은 숨겨져 있고 카드에 세지 않는다
	_three_decks()
	var g := _gallery()
	var title_template: Label = g.get_node("%SectionTitleTemplate")
	var row_template: HFlowContainer = g.get_node("%CardRowTemplate")
	assert_false(title_template.visible)
	assert_false(row_template.visible)
	var titles := g.get_node("%Sections").get_children().filter(func(c): return c.has_meta("deck"))
	assert_eq(titles.size(), 3)
	assert_eq(titles[0].get_theme_font_size("font_size"), title_template.get_theme_font_size("font_size"))
	assert_eq(g.card_views().size(), 4)
