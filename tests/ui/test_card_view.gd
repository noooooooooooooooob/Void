extends GutTest

var kw_dir: String

func before_each():
	kw_dir = "user://test_kw_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(kw_dir)
	var kw := KeywordData.new()
	kw.id = "k1"
	kw.name_ko = "출혈"
	kw.description_ko = "드로우 턴에 수치만큼 피해"
	ResourceSaver.save(kw, kw_dir.path_join("출혈.tres"))

func after_each():
	DirAccess.remove_absolute(kw_dir.path_join("출혈.tres"))
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
	var v: CardView = add_child_autofree(preload("res://Scenes/ui/card_view/card_view.tscn").instantiate())
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

func test_show_amount_visible_with_value():
	var v := _view(_card())
	v.show_amount(9)
	var amount: Label = v.get_node("%Amount")
	assert_true(amount.visible)
	assert_eq(amount.text, "9")

func test_show_amount_negative_hides():
	var v := _view(_card())
	v.show_amount(9)
	v.show_amount(-1)
	assert_false(v.get_node("%Amount").visible)

func test_gallery_default_has_no_amount():
	var v := _view(_card())
	assert_false(v.get_node("%Amount").visible)

func test_set_dimmed():
	var v := _view(_card())
	v.set_dimmed(true)
	assert_lt(v.modulate.v, 1.0)
	v.set_dimmed(false)
	assert_eq(v.modulate, Color.WHITE)


# --- 강화 버전 모양 (2026-11-17: "+N" 배지 대신 카드 모양으로 구분) ---

func _real_upgradable() -> CardData:
	return load("res://cards/data/브람/돌주먹.tres")

func test_no_upgrade_badge():
	var v := _view(_card())
	assert_false(v.has_node("%UpgradeBadge"))

func test_is_upgraded_only_for_upgrade_versions():
	var base := _real_upgradable()
	assert_false(CardView.is_upgraded(base))
	assert_true(CardView.is_upgraded(base.upgrades[0]))
	assert_false(CardView.is_upgraded(_card()))

func test_upgraded_card_looks_different_and_back():
	var base := _real_upgradable()
	var v := _view(base)
	var normal_bg: Color = v.background_color()
	assert_eq(v.glow_size(), 0)
	v.set_card(base.upgrades[0])
	assert_eq(v.background_color(), v.upgraded_bg)
	assert_ne(v.background_color(), normal_bg)
	assert_gt(v.glow_size(), 0)
	assert_eq(v.border_color(), CardView.CATEGORY_COLORS[base.upgrades[0].category])
	v.set_card(base)
	assert_eq(v.background_color(), normal_bg)
	assert_eq(v.glow_size(), 0)
