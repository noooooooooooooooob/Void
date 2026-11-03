extends GutTest

var kw_dir: String

func before_each():
	kw_dir = "user://test_kw_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(kw_dir)
	var kw := KeywordData.new()
	kw.id = "k1"
	kw.name_ko = "출혈"
	kw.description_ko = "드로우 턴에 수치만큼 피해"
	ResourceSaver.save(kw, kw_dir.path_join("k1.tres"))

func after_each():
	DirAccess.remove_absolute(kw_dir.path_join("k1.tres"))
	DirAccess.remove_absolute(kw_dir)

func _card() -> CardData:
	var c := CardData.new()
	c.name_ko = "피의 참격"
	c.description_ko = "핏방울을 전부 소모"
	c.sp = 2
	c.cost = 3
	c.category = "special"
	c.attack_type = "ranged"
	c.area = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	c.keywords = PackedStringArray(["k1", "deleted"])
	c.upgrades = [CardData.new()] as Array[CardData]
	return c

func _view(card: CardData) -> CardView:
	var v: CardView = add_child_autofree(preload("res://ui/card_view/card_view.tscn").instantiate())
	v.keyword_dir = kw_dir
	v.set_card(card)
	return v


func test_texts():
	var v := _view(_card())
	assert_eq(v.name_label.text, "피의 참격")
	assert_eq(v.sp_label.text, "2")
	assert_eq(v.cost_label.text, "코스트 3")
	assert_eq(v.description_label.text, "핏방울을 전부 소모")
	assert_eq(v.attack_badge.text, "원")
	assert_eq(v.upgrade_badge.text, "+1")
	assert_true(v.upgrade_badge.visible)

func test_border_color_by_category():
	var v := _view(_card())
	assert_eq(v.border_color(), CardView.CATEGORY_COLORS["special"])
	var c := _card()
	c.category = "enemy"
	v.set_card(c)
	assert_eq(v.border_color(), CardView.CATEGORY_COLORS["enemy"])

func test_area_cells_lit():
	var v := _view(_card())
	assert_eq(v.lit_cells(), [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	var c := _card()
	c.area = [] as Array[Vector2i]
	v.set_card(c)
	assert_eq(v.lit_cells(), [Vector2i(0, 0)] as Array[Vector2i])

func test_keywords_skip_missing():
	var v := _view(_card())
	assert_eq(v.keywords_label.text, "출혈")
	assert_eq(v.keyword_entries().size(), 1)

func test_tooltip_shows_keyword_description_on_hover():
	var v := _view(_card())
	v.show_keyword_tooltip()
	assert_true(v.tooltip.visible)
	assert_string_contains(v.tooltip_text_for_test(), "드로우 턴에 수치만큼 피해")
	v.hide_keyword_tooltip()
	assert_false(v.tooltip.visible)

func test_no_tooltip_without_keywords():
	var c := _card()
	c.keywords = PackedStringArray()
	var v := _view(c)
	v.show_keyword_tooltip()
	assert_false(v.tooltip.visible)
	assert_false(v.keywords_label.visible)
	c.upgrades = [] as Array[CardData]
	v.set_card(c)
	assert_false(v.upgrade_badge.visible)
